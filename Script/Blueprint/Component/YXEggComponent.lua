---@class YXEggComponent_C:ActorComponent
--Edit Below--
-- 宠物蛋系统组件（挂在 PlayerController 上）：负责拾取/放下/触发孵化。
-- 所有会改变蛋状态的逻辑只在服务端执行；交互按键/射线与 GM 指令均可驱动。
-- 孵化规则：只能在「持有者自己的领地」范围内孵化——玩家在自家领地内点交互按钮「孵化」时触发。
local YXEggComponent = {}

-- 可调参数
YXEggComponent.PickRange = 300          -- 拾取距离（以玩家为圆心）

-- 蛋蓝图类路径（运行时用于查找场景中的蛋；改蛋蓝图位置时同步改这里）
YXEggComponent.EggClassPath = 'Asset/Blueprint/YXBlueprint/Egg/BP_Egg_Base.BP_Egg_Base_C'

-- 最近可拾取蛋的白色描边（仅客户端）
YXEggComponent.OutlineThickness = 3                          -- 描边粗细
YXEggComponent.OutlineColor = {A = 1, B = 1, G = 1, R = 1}   -- 白色
YXEggComponent.OutlineInterval = 0.2                         -- 检索最近蛋的间隔（秒）

function YXEggComponent:ReceiveBeginPlay()
    YXEggComponent.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        self.HeldEgg = nil
    else
        self.OutlinedEgg = nil   -- 当前已描边的蛋（仅客户端）
        -- 循环定时器：定期刷新“最近可拾取蛋”的描边（不使用 Tick）
        self.OutlineTimerHandle = UGCTimerUtility.CreateLuaTimer(self.OutlineInterval, function()
            self:UpdateNearestEggOutline()
        end, true)
    end
end

function YXEggComponent:ReceiveEndPlay()
    if UGCGameSystem.IsServer() then
        -- 玩家离开/掉线/PC 销毁时释放持有的蛋，避免蛋被“幽灵持有”而无人可拾
        self:ReleaseHeldEggOnLeave()
    end
    self:CleanupOutline()
    self:ClearOutline()
    YXEggComponent.SuperClass.ReceiveEndPlay(self)
end

-- 玩家离开时释放持有的蛋（仅服务端）
function YXEggComponent:ReleaseHeldEggOnLeave()
    local Egg = self.HeldEgg
    self.HeldEgg = nil
    if Egg == nil or not UGCObjectUtility.IsObjectValid(Egg) then
        return
    end

    local Pawn = self:GetOwnerPawn()
    if Pawn ~= nil and UGCObjectUtility.IsObjectValid(Pawn) then
        Egg:DropByPawn(Pawn)     -- 角色仍可用：正常落地
    else
        Egg:ReleaseInPlace()     -- 角色已销毁：就地释放
    end
    
    ugcprint("[YXEggComponent] 玩家离开，已释放持有的蛋")
end

-- 停止描边刷新定时器
function YXEggComponent:CleanupOutline()
    if self.OutlineTimerHandle ~= nil then
        UGCTimerUtility.RemoveLuaTimer(self.OutlineTimerHandle)
        self.OutlineTimerHandle = nil
    end
end

-- ⭐ 玩家查询 ⭐
function YXEggComponent:GetOwnerController()
    return self:GetOwner()
end

function YXEggComponent:GetOwnerPawn()
    local Controller = self:GetOwnerController()
    if Controller == nil then
        return nil
    end

    return UGCGameSystem.GetPlayerPawnByPlayerController(Controller)
end

-- 直接向场景查询所有蛋 Actor（不再依赖蛋主动注册到GameState）
function YXEggComponent:GetEggList()
    local EggClass = UE.LoadClass(UGCGameSystem.GetUGCResourcesFullPath(self.EggClassPath))
    if EggClass == nil then
        ugcprint("[YXEggComponent] 加载蛋类失败: " .. self.EggClassPath)
        return nil
    end

    return UGCActorComponentUtility.GetAllActorsOfClass(UGCGameSystem.GetGameState(), EggClass)
end

-- 查找距玩家最近、且可拾取（Free）的蛋；服务端拾取与客户端描边共用同一判定
function YXEggComponent:FindNearestFreeEgg()
    local Pawn = self:GetOwnerPawn()
    if Pawn == nil then
        return nil
    end

    local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
    if PawnLoc == nil then
        return nil
    end

    local EggList = self:GetEggList()
    if EggList == nil then
        return nil
    end

    local Nearest, NearestDist = nil, tonumber(self.PickRange) or 300
    for _, Egg in ipairs(EggList) do
        if UGCObjectUtility.IsObjectValid(Egg) and Egg:IsFree() and not Egg:IsOccupied() then
            local EggLoc = UGCActorComponentUtility.GetActorLocation(Egg)
            if EggLoc then
                local DX = EggLoc.X - PawnLoc.X
                local DY = EggLoc.Y - PawnLoc.Y
                local DZ = EggLoc.Z - PawnLoc.Z
                local Dist = math.sqrt(DX * DX + DY * DY + DZ * DZ)
                if Dist <= NearestDist then
                    Nearest, NearestDist = Egg, Dist
                end
            end
        end
    end
    return Nearest
end

-- ⭐ 描边（仅客户端）：给最近可拾取的蛋加白色描边，让玩家知道会拾哪一个 ⭐
-- 描边只对本地玩家生效（客户端上存在所有玩家的 PC 副本，非本地的不处理）
function YXEggComponent:UpdateNearestEggOutline()
    if UGCGameSystem.IsServer() then
        return
    end

    if not self:IsLocalPlayerComponent() then
        return
    end

    -- 已持有蛋时，不再给其他蛋加描边
    if self:IsLocalPlayerHoldingEgg() then
        self:ClearOutline()
        return
    end

    local Nearest = self:FindNearestFreeEgg()
    if Nearest == self.OutlinedEgg then
        return
    end

    self:ClearOutline()
    self.OutlinedEgg = Nearest
    if Nearest ~= nil then
        UGCGameSystem.DrawOutline(Nearest, true, self.OutlineThickness, self.OutlineColor)
    end
end

-- 本组件是否属于本机玩家（比较本地 PC 与本组件所属 PC）
function YXEggComponent:IsLocalPlayerComponent()
    local LocalController = UGCGameSystem.GetLocalPlayerController()
    if LocalController == nil then
        return false
    end

    return self:GetOwnerController() == LocalController
end

-- 本地玩家当前是否已持有蛋（依据蛋同步过来的 HolderKey 判定）
function YXEggComponent:IsLocalPlayerHoldingEgg()
    local MyKey = UGCGameSystem.GetLocalPlayerKey()
    if MyKey == nil then
        return false
    end

    local EggList = self:GetEggList()
    if EggList == nil then
        return false
    end

    for _, Egg in ipairs(EggList) do
        if UGCObjectUtility.IsObjectValid(Egg) and Egg:IsHeldByKey(MyKey) then
            return true
        end
    end

    return false
end

-- 供交互UI查询（仅客户端）的交互状态：
--   "Incubate"（已持有蛋且在自己领地内）/ "Drop"（已持有蛋）/ "Pick"（附近有可拾取蛋）/ "None"
function YXEggComponent:GetInteractionState()
    if UGCGameSystem.IsServer() then
        return "None"
    end

    if not self:IsLocalPlayerComponent() then
        return "None"
    end

    if self:IsLocalPlayerHoldingEgg() then
        if self:IsLocalPlayerInOwnTerritory() then
            return "Incubate"
        end
        return "Drop"
    end

    if self:FindNearestFreeEgg() ~= nil then
        return "Pick"
    end

    return "None"
end

-- 取消当前描边
function YXEggComponent:ClearOutline()
    local Egg = self.OutlinedEgg
    self.OutlinedEgg = nil
    if Egg ~= nil and UGCObjectUtility.IsObjectValid(Egg) then
        UGCGameSystem.DrawOutline(Egg, false, self.OutlineThickness, self.OutlineColor)
    end
end

-- ⭐ 死亡掉落（仅服务端）：玩家死亡时，把携带中的蛋放在玩家死亡的位置 ⭐
-- 由 UGCPlayerPawn:ChangeState 在进入死亡状态时调用（早于角色被销毁）
function YXEggComponent:DropEggOnDeath(DeathPawn)
    if not UGCGameSystem.IsServer() then
        return
    end

    local Egg = self.HeldEgg
    if Egg == nil or not UGCObjectUtility.IsObjectValid(Egg) then
        self.HeldEgg = nil
        return
    end

    if DeathPawn == nil or not UGCObjectUtility.IsObjectValid(DeathPawn) then
        return
    end
    -- 复用放下逻辑：按死亡位置落脚并回到 Free，任何玩家可再拾取
    Egg:DropByPawn(DeathPawn)
    self.HeldEgg = nil
    ugcprint("[YXEggComponent] 玩家死亡，蛋已掉落在死亡位置")
end

-- ⭐ 拾取（仅服务端）：拾取附近最近的、未被持有的蛋 ⭐
function YXEggComponent:TryPickEgg()
    ugcprint("[YXEggComponent] TryPickEgg")
    if not UGCGameSystem.IsServer() then
        return
    end
    if self.HeldEgg ~= nil and UGCObjectUtility.IsObjectValid(self.HeldEgg) then
        ugcprint("[YXEggComponent] 已持有蛋，不能再次拾取")
        return
    end
    self.HeldEgg = nil

    local Pawn = self:GetOwnerPawn()
    if Pawn == nil then
        return
    end

    local Nearest = self:FindNearestFreeEgg()
    if Nearest == nil then
        ugcprint("[YXEggComponent] 附近没有可拾取的蛋")
        return
    end

    if Nearest:PickUpByPawn(Pawn) then
        self.HeldEgg = Nearest
        ugcprint("[YXEggComponent] 拾取蛋成功")
    end
end

-- 服务端：落点是否在本玩家自己的领地范围内
function YXEggComponent:IsDropInMyTerritory(Location)
    local Controller = self:GetOwnerController()
    if Controller == nil or Controller.YXTerritoryComponent == nil then
        return false
    end
    return Controller.YXTerritoryComponent:IsPositionInMyTerritory(Location)
end

-- 客户端：本机玩家当前是否处于「自己的领地」范围内（交互按钮据此切换成“孵化”）
function YXEggComponent:IsLocalPlayerInOwnTerritory()
    if UGCGameSystem.IsServer() then
        return false
    end

    local Controller = self:GetOwnerController()
    if Controller == nil or Controller.YXTerritoryComponent == nil then
        return false
    end

    local Pawn = UGCGameSystem.GetLocalPlayerPawn()
    if Pawn == nil or not UGCObjectUtility.IsObjectValid(Pawn) then
        return false
    end

    local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
    if PawnLoc == nil then
        return false
    end

    return Controller.YXTerritoryComponent:IsPlayerInOwnTerritory(UGCGameSystem.GetLocalPlayerKey(), PawnLoc)
end

-- ⭐ 放下（仅服务端）：把当前携带的蛋放回地面（回到 Free，任何玩家可再拾取）⭐
function YXEggComponent:TryDropEgg()
    if not UGCGameSystem.IsServer() then
        return
    end

    local Egg = self.HeldEgg
    if Egg == nil or not UGCObjectUtility.IsObjectValid(Egg) then
        self.HeldEgg = nil
        ugcprint("[YXEggComponent] 当前没有携带蛋")
        return
    end

    local Pawn = self:GetOwnerPawn()
    if Pawn == nil then
        return
    end

    Egg:DropByPawn(Pawn)
    self.HeldEgg = nil
end

-- ⭐ 在自家领地内孵化（仅服务端，交互按钮「孵化」触发）⭐
-- 把当前携带的蛋放到脚下并开始孵化；落点必须在玩家自己的领地范围内，否则拒绝（蛋仍拿在手上）
function YXEggComponent:TryIncubateEggInTerritory()
    if not UGCGameSystem.IsServer() then
        return
    end

    local Egg = self.HeldEgg
    if Egg == nil or not UGCObjectUtility.IsObjectValid(Egg) then
        self.HeldEgg = nil
        ugcprint("[YXEggComponent] 当前没有携带蛋，无法孵化")
        return
    end

    local Pawn = self:GetOwnerPawn()
    if Pawn == nil then
        return
    end

    -- 盒体判定只看水平足迹，用玩家位置与蛋的落点等价；不在自家领地内则不放、不孵化
    local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
    if not self:IsDropInMyTerritory(PawnLoc) then
        ugcprint("[YXEggComponent] 孵化被拒绝：不在自己的领地内")
        return
    end

    Egg:DropByPawn(Pawn)
    self.HeldEgg = nil
    local PlayerKey = UGCGameSystem.GetPlayerKeyByPlayerController(self:GetOwnerController())
    Egg:StartIncubate(PlayerKey)
    ugcprint("[YXEggComponent] 在自家领地内孵化，蛋开始孵化")
end

-- ⭐ 触发孵化（仅服务端，GM 驱测用）⭐
-- 把当前携带的蛋放到脚下并开始孵化；此为 GM 测试手段，会绕过「必须在自家领地内」的限制
function YXEggComponent:TryIncubateEgg()
    if not UGCGameSystem.IsServer() then
        return
    end

    local Egg = self.HeldEgg
    if Egg == nil or not UGCObjectUtility.IsObjectValid(Egg) then
        self.HeldEgg = nil
        ugcprint("[YXEggComponent] 当前没有携带蛋，无法触发孵化")
        return
    end

    local Pawn = self:GetOwnerPawn()
    if Pawn == nil then
        return
    end

    Egg:DropByPawn(Pawn)
    local PlayerKey = UGCGameSystem.GetPlayerKeyByPlayerController(self:GetOwnerController())
    Egg:StartIncubate(PlayerKey)
    self.HeldEgg = nil
end

return YXEggComponent