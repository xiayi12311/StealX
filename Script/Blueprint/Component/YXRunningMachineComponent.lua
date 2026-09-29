---@class YXRunningMachineComponent_C:ActorComponent
--Edit Below--
local YXRunningMachineComponent = {}
YXRunningMachineComponent.RunningMachineConfig = nil
-- 累加速度的计时器表,存每台正在被踩的跑步机对应的循环计时器句柄
YXRunningMachineComponent.PawnTimers = {}
-- 每台跑步机的累计值表,存玩家在这台跑步机上已经累加了多少速度倍率
YXRunningMachineComponent.SpeedAccum = {}

function YXRunningMachineComponent:ReceiveBeginPlay()
    YXRunningMachineComponent.SuperClass.ReceiveBeginPlay(self)
end

-- function YXRunningMachineComponent:ReceiveTick(DeltaTime)
--     YXRunningMachineComponent.SuperClass.ReceiveTick(self, DeltaTime)
-- end

function YXRunningMachineComponent:ReceiveEndPlay()
    -- 清理所有累加计时器
    if self.PawnTimers then
        for _, Timer in pairs(self.PawnTimers) do
            UGCTimerUtility.RemoveLuaTimer(Timer)
        end
        self.PawnTimers = {}
        self.SpeedAccum = {}
    end
    YXRunningMachineComponent.SuperClass.ReceiveEndPlay(self)
end

-- ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐ 配置加载与表数据访问相关 ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐
-- 加载跑步机配置表
function YXRunningMachineComponent:GetRunningMachineConfig()
    if not self.RunningMachineConfig then
        self.RunningMachineConfig = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath('Asset/Data/Table/YX_RunningMachineTable.YX_RunningMachineTable'))
    end
    return self.RunningMachineConfig
end

-- 按 ID 取配置行（遍历匹配 ID 字段，不依赖行 key 的格式）
function YXRunningMachineComponent:GetConfigByID(InID)
    local TableData = self:GetRunningMachineConfig()
    if TableData == nil then
        ugcprint("[YXRunningMachineComponent] 加载表失败: YX_RunningMachineTable")
        return nil
    end
    for _, Row in pairs(TableData) do
        if tonumber(Row.ID) == InID then
            return Row
        end
    end
    ugcprint("[YXRunningMachineComponent] 表中未配置ID: " .. tostring(InID))
    return nil
end

-- ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐ 跑步机逻辑相关 ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐
-- 玩家踏上跑步机（Machine: 跑步机 Actor, Pawn: 踏上的玩家 Pawn）：清零该机累计值，按配置间隔开始累加
function YXRunningMachineComponent:OnPawnEnter(Machine, Pawn)
    ugcprint("[YXRunningMachineComponent] OnPawnEnter")
    if not UGCGameSystem.IsServer() then
        return
    end
    if Machine == nil or Pawn == nil then
        return
    end
    local Cfg = self:GetConfigByID(Machine.RunningMachineID)
    if Cfg == nil then
        return
    end
    ugcprint("[YXRunningMachineComponent] OnPawnEnter " .. tostring(Cfg.Name))
    -- 踏上时清零
    self.SpeedAccum[Machine] = 0
    -- 防止重复重叠时叠加多个计时器
    self:StopMachineTimer(Machine)
    -- 踏上时创建，记录句柄
    self.PawnTimers[Machine] = UGCTimerUtility.CreateLuaTimer(Cfg.AddInterval, function()
        self:AddSpeed(Machine, Cfg)
    end, true)
end

-- 每个间隔给该跑步机的累计值加一次
function YXRunningMachineComponent:AddSpeed(Machine, Cfg)
    -- 每 AddInterval 秒加一次 AddSpeed
    self.SpeedAccum[Machine] = (self.SpeedAccum[Machine] or 0) + Cfg.AddSpeed
end

-- 玩家离开跑步机：停表并按累计值一次性结算属性
function YXRunningMachineComponent:OnPawnLeave(Machine, Pawn)
    if not UGCGameSystem.IsServer() then
        return
    end
    if Machine == nil or Pawn == nil then
        return
    end
    ugcprint("[YXRunningMachineComponent] OnPawnLeave")
    -- 离开时用句柄停掉计时器
    self:StopMachineTimer(Machine)
    local AddSpeed = self.SpeedAccum[Machine] or 0
    if AddSpeed > 0 then
        local Cfg = self:GetConfigByID(Machine.RunningMachineID)
        if Cfg then
            -- 离开时把累计值一次性结算到玩家属性上
            UGCAttributeSystem.AddGameAttributeValue(Pawn, Cfg.AttrName, AddSpeed)
        end
    end
    self.SpeedAccum[Machine] = nil
    ugcprint("[YXRunningMachineComponent] 结算AddSpeed: " .. AddSpeed)
end

-- 停掉并清理某台跑步机对应的累加计时器
function YXRunningMachineComponent:StopMachineTimer(Machine)
    local Timer = self.PawnTimers and self.PawnTimers[Machine]
    if Timer then
        UGCTimerUtility.RemoveLuaTimer(Timer)
        self.PawnTimers[Machine] = nil
    end
end

return YXRunningMachineComponent
