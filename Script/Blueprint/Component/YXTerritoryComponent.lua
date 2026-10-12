---@class YXTerritoryComponent_C:ActorComponent
--Edit Below--
-- 领地系统组件（挂在 PlayerController 上）：为玩家认领场景中预摆放的一块领地。
-- 服务端：认领规则为「取编号(TerritoryID)最小的空闲领地」——玩家按进入顺序依次拿到 1、2、3…；
--         玩家中途退出会释放自己的领地（编号回到空闲池），之后进游戏的玩家会接管该编号的领地；
--         已在游戏中的玩家编号不受影响。玩家离开时释放领地。
-- 客户端：依据领地同步过来的 OwnerKey 找到「自己的领地」，在屏幕上打印自己的 TerritoryID 与是否处于领地中。
-- 领地范围判定由领地 Actor（BP_Territory_Base）按碰撞盒子提供。
local YXTerritoryComponent = {}

-- 领地蓝图类路径（运行时用于查找场景中的领地；改领地蓝图位置时同步改这里）
YXTerritoryComponent.TerritoryClassPath = 'Asset/Blueprint/YXBlueprint/Territory/BP_Territory_Base.BP_Territory_Base_C'

-- 认领重试间隔（秒）与最大次数：等场景领地 Actor 就绪，直到认领成功或达到上限
YXTerritoryComponent.ClaimRetryInterval = 1.0
YXTerritoryComponent.MaxClaimAttempts = 10

-- 屏幕打印（仅客户端、仅本机玩家）的刷新间隔与显示持续时间（秒）
YXTerritoryComponent.ScreenPrintInterval = 0.2
YXTerritoryComponent.ScreenPrintDuration = 0.5

-- 屏幕打印颜色（白色）
YXTerritoryComponent.ScreenPrintColor = {A = 1, B = 1, G = 1, R = 1}

function YXTerritoryComponent:ReceiveBeginPlay()
    YXTerritoryComponent.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        self.MyTerritory = nil
        self.ClaimAttempts = 0
        -- 循环定时器：尝试认领领地，成功或达到上限后自行停止（不使用 Tick）
        self.ClaimTimerHandle = UGCTimerUtility.CreateLuaTimer(self.ClaimRetryInterval, function()
            self:OnClaimTick()
        end, true)
    else
        -- 循环定时器：定期在屏幕上打印「是否处于自己的领地中」（不使用 Tick）
        self.PrintTimerHandle = UGCTimerUtility.CreateLuaTimer(self.ScreenPrintInterval, function()
            self:UpdateTerritoryScreenPrint()
        end, true)
    end
end

function YXTerritoryComponent:ReceiveEndPlay()
    if UGCGameSystem.IsServer() then
        self:StopClaimTimer()
        self:ReleaseTerritory()
    else
        self:StopPrintTimer()
    end
    YXTerritoryComponent.SuperClass.ReceiveEndPlay(self)
end

-- ⭐ 归属（服务端） ⭐
-- 取本组件所属 PlayerController 对应的玩家 Key（无效返回 -1）
function YXTerritoryComponent:GetOwnerPlayerKey()
    return UGCGameSystem.GetPlayerKeyByPlayerController(self:GetOwner())
end

-- 取本玩家的领地（仅服务端有意义；可能为 nil）
function YXTerritoryComponent:GetMyTerritory()
    if self.MyTerritory ~= nil and UGCObjectUtility.IsObjectValid(self.MyTerritory) then
        return self.MyTerritory
    end
    return nil
end

-- 指定位置是否在本玩家的领地范围内（仅服务端用于孵化判定）
function YXTerritoryComponent:IsPositionInMyTerritory(Location)
    local Territory = self:GetMyTerritory()
    if Territory == nil then
        return false
    end

    return Territory:IsPointInside(Location)
end

-- ⭐ 领地查询（客户端&服务端） ⭐
-- 直接向场景查询所有领地 Actor（不依赖约定制的注册表）
function YXTerritoryComponent:GetTerritoryList()
    local TerritoryClass = UE.LoadClass(UGCGameSystem.GetUGCResourcesFullPath(self.TerritoryClassPath))
    if TerritoryClass == nil then
        ugcprint("[YXTerritoryComponent] 加载领地类失败: " .. self.TerritoryClassPath)
        return nil
    end

    return UGCActorComponentUtility.GetAllActorsOfClass(UGCGameSystem.GetGameState(), TerritoryClass)
end

-- 找到归属为指定玩家的领地（客户端依据同步过来的 OwnerKey 查找）
function YXTerritoryComponent:FindTerritoryByOwnerKey(PlayerKey)
    if PlayerKey == nil then
        return nil
    end

    local TerritoryList = self:GetTerritoryList()
    if TerritoryList == nil then
        return nil
    end

    for _, Territory in ipairs(TerritoryList) do
        if UGCObjectUtility.IsObjectValid(Territory) and Territory:IsOwnedByKey(PlayerKey) then
            return Territory
        end
    end

    return nil
end

-- 指定玩家当前是否处于自己的领地范围内（客户端&服务端都可用，按碰撞盒子判定）
function YXTerritoryComponent:IsPlayerInOwnTerritory(PlayerKey, Location)
    local Territory = self:FindTerritoryByOwnerKey(PlayerKey)
    if Territory == nil then
        return false
    end

    return Territory:IsPointInside(Location)
end

-- 本组件是否属于本机玩家（比较本地 PC 与本组件所属 PC）
function YXTerritoryComponent:IsLocalPlayerComponent()
    local LocalController = UGCGameSystem.GetLocalPlayerController()
    if LocalController == nil then
        return false
    end

    return self:GetOwner() == LocalController
end

-- ⭐ 认领/释放（仅服务端） ⭐
-- 认领一块空闲领地（仅服务端）：取编号(TerritoryID)最小、且未被认领的领地（编号需 >= 1）
-- 这样玩家按进入顺序拿到 1、2、3…；有人退出空出的编号会被之后进来的玩家接管
function YXTerritoryComponent:ClaimTerritory()
    if not UGCGameSystem.IsServer() then
        return
    end

    if self:GetMyTerritory() ~= nil then
        return
    end

    self.MyTerritory = nil

    local PlayerKey = self:GetOwnerPlayerKey()
    if PlayerKey == nil or PlayerKey < 0 then
        ugcprint("[YXTerritoryComponent] 认领领地失败：取不到玩家 Key")
        return
    end

    local TerritoryList = self:GetTerritoryList()
    if TerritoryList == nil or #TerritoryList == 0 then
        ugcprint("[YXTerritoryComponent] 场景中没有领地 Actor")
        return
    end

    -- 找出编号最小、且未被认领的领地
    local Best, BestID = nil, nil
    for _, Territory in ipairs(TerritoryList) do
        if UGCObjectUtility.IsObjectValid(Territory) and Territory:IsUnclaimed() then
            local ID = Territory:GetTerritoryID()
            if ID >= 1 and (BestID == nil or ID < BestID) then
                Best, BestID = Territory, ID
            end
        end
    end

    if Best == nil then
        ugcprint("[YXTerritoryComponent] 没有空闲领地可分配（检查领地 TerritoryID 是否配置为 1~8）")
        return
    end

    if Best:ClaimByKey(PlayerKey) then
        self.MyTerritory = Best
        ugcprint("[YXTerritoryComponent] 玩家 " .. tostring(PlayerKey) .. " 认领领地成功 TerritoryID=" .. tostring(BestID))
    end
end

-- 释放领地（仅服务端）：玩家离开时把领地放回空闲池
function YXTerritoryComponent:ReleaseTerritory()
    local Territory = self.MyTerritory
    self.MyTerritory = nil
    if Territory ~= nil and UGCObjectUtility.IsObjectValid(Territory) then
        Territory:Release()
    end
end

-- ⭐ 认领重试 ⭐
function YXTerritoryComponent:OnClaimTick()
    if self:GetMyTerritory() ~= nil then
        self:StopClaimTimer()
        return
    end
    
    self.ClaimAttempts = (self.ClaimAttempts or 0) + 1
    self:ClaimTerritory()
    if self:GetMyTerritory() ~= nil then
        self:StopClaimTimer()
    elseif self.ClaimAttempts >= (tonumber(self.MaxClaimAttempts) or 10) then
        self:StopClaimTimer()
        ugcprint("[YXTerritoryComponent] 多次尝试后仍未分配到领地")
    end
end

function YXTerritoryComponent:StopClaimTimer()
    if self.ClaimTimerHandle ~= nil then
        UGCTimerUtility.RemoveLuaTimer(self.ClaimTimerHandle)
        self.ClaimTimerHandle = nil
    end
end

-- ⭐ 屏幕打印（仅客户端、仅本机玩家） ⭐
-- 打印本机玩家自己的领地编号(TerritoryID)，以及当前是否处于该领地范围内
function YXTerritoryComponent:UpdateTerritoryScreenPrint()
    if UGCGameSystem.IsServer() then
        return
    end

    if not self:IsLocalPlayerComponent() then
        return
    end

    -- PrintToScreen 每调用一次就是「新增一行」并保持 Duration 秒；
    -- 按固定间隔重复调用会把这些行叠在一起（显示成多行）。
    -- 因此先清掉上一轮遗留的屏幕打印，再打印当轮，保证屏幕上始终只有一行。
    UGCDebugSystem.FlushOnScreenDebugMessages()

    local MyKey = UGCGameSystem.GetLocalPlayerKey()
    local MyTerritory = self:FindTerritoryByOwnerKey(MyKey)
    if MyTerritory == nil then
        UGCDebugSystem.PrintToScreen("领地ID：无（尚未分配到领地）", self.ScreenPrintColor, self.ScreenPrintDuration)
        return
    end

    local MyID = MyTerritory:GetTerritoryID()
    local Prefix = "领地ID：" .. tostring(MyID) .. "   "
    local Pawn = UGCGameSystem.GetLocalPlayerPawn()
    local InTerritory = false
    if Pawn ~= nil and UGCObjectUtility.IsObjectValid(Pawn) then
        InTerritory = MyTerritory:IsPointInside(UGCActorComponentUtility.GetActorLocation(Pawn))
    end

    if InTerritory then
        UGCDebugSystem.PrintToScreen(Prefix .. "处于自己的领地中", self.ScreenPrintColor, self.ScreenPrintDuration)
    else
        UGCDebugSystem.PrintToScreen(Prefix .. "不在自己的领地中", self.ScreenPrintColor, self.ScreenPrintDuration)
    end
end

function YXTerritoryComponent:StopPrintTimer()
    if self.PrintTimerHandle ~= nil then
        UGCTimerUtility.RemoveLuaTimer(self.PrintTimerHandle)
        self.PrintTimerHandle = nil
    end
end

return YXTerritoryComponent