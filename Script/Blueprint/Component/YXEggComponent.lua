---@class YXEggComponent_C:ActorComponent
--Edit Below--
-- 宠物蛋系统组件（挂在 PlayerController 上）：负责拾取/放下/触发孵化。
-- 所有会改变蛋状态的逻辑只在服务端执行；当前用 GM 指令驱动（后续再接交互按键与射线）。
-- 安全区/绑定相关逻辑暂未实现。
local YXEggComponent = {}

-- 可调参数
YXEggComponent.PickRange = 300          -- 拾取距离（以玩家为圆心）

-- 蛋蓝图类路径（运行时用于查找场景中的蛋；改蛋蓝图位置时同步改这里）
YXEggComponent.EggClassPath = 'Asset/Blueprint/YXBlueprint/Egg/BP_Egg_Base.BP_Egg_Base_C'

function YXEggComponent:ReceiveBeginPlay()
    YXEggComponent.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        self.HeldEgg = nil
    end
end

--[[
function YXEggComponent:ReceiveTick(DeltaTime)
    YXEggComponent.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

function YXEggComponent:ReceiveEndPlay()
    YXEggComponent.SuperClass.ReceiveEndPlay(self)
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

-- 直接向场景查询所有蛋 Actor（不再依赖蛋主动注册到 GameState）
function YXEggComponent:GetEggList()
    local EggClass = UE.LoadClass(UGCGameSystem.GetUGCResourcesFullPath(YXEggComponent.EggClassPath))
    if EggClass == nil then
        ugcprint("[YXEggComponent] 加载蛋类失败: " .. YXEggComponent.EggClassPath)
        return nil
    end
    return UGCActorComponentUtility.GetAllActorsOfClass(UGCGameSystem.GetGameState(), EggClass)
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
    local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
    if PawnLoc == nil then
        return
    end
    local EggList = self:GetEggList()
    if EggList == nil then
        ugcprint("[YXEggComponent] 场景中没有可拾取的蛋")
        return
    end

    local Nearest, NearestDist = nil, YXEggComponent.PickRange
    for _, Egg in ipairs(EggList) do
        if UGCObjectUtility.IsObjectValid(Egg) and Egg:IsFree() then
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

    if Nearest == nil then
        ugcprint("[YXEggComponent] 附近没有可拾取的蛋")
        return
    end
    if Nearest:PickUpByPawn(Pawn) then
        self.HeldEgg = Nearest
        ugcprint("[YXEggComponent] 拾取蛋成功")
    end
end

-- ⭐ 放下（仅服务端）：把当前携带的蛋放回地面 ⭐
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

-- ⭐ 触发孵化（仅服务端，GM 驱测用）⭐
-- 把当前携带的蛋放到脚下并开始孵化（后续接入安全区后由「在自家基地内放下」自动触发）
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
    Egg:StartIncubate()
    self.HeldEgg = nil
end

return YXEggComponent