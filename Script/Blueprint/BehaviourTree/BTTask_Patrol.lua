---@class BTTask_Patrol_C:BTTask_LuaBase
--Edit Below--
local BTTask_Patrol = {}

-- 巡逻目标点写入的黑板键名，需与行为树中移动节点读取的键一致
BTTask_Patrol.PATROL_BLACKBOARD_KEY = "RandomMovingCoordinates"
-- 以自身为中心查找随机可达点的半径
BTTask_Patrol.PATROL_RADIUS = 2000

--- 任务执行入口点
-- 以当前 Pawn 位置为中心取一个随机可到达点，写入黑板键供移动节点使用
---@param OwnerController AAIController 拥有此任务节点的AI控制器
---@param ControlledPawn APawn AI控制器当前控制的Pawn对象
function BTTask_Patrol:ReceiveExecuteAI(OwnerController, ControlledPawn)
    ugcprint("[BTTask_Patrol] 开始执行任务") 
    local Origin = ControlledPawn:K2_GetActorLocation()
    local bFindSuccess, TargetPoint = UGCNavigationSystem.GetRandomReachablePointInRadius(ControlledPawn, Origin, BTTask_Patrol.PATROL_RADIUS)
    ugcprint(string.format("[BTTask_Patrol] 取随机可达点 成功=%s Origin=%s TargetPoint=(%s, %s, %s) Radius=%d", tostring(bFindSuccess), tostring(Origin), tostring(TargetPoint.X), tostring(TargetPoint.Y), tostring(TargetPoint.Z), BTTask_Patrol.PATROL_RADIUS))
    if not bFindSuccess then
        -- 未取到可用点，返回失败交给行为树重试
        ugcprint("[BTTask_Patrol] 未取到可用点，返回失败交给行为树重试")
        self:FinishExecute(false)
        return
    end

    local Blackboard = OwnerController:GetBlackboardComponent()
    if not Blackboard then
        ugcprint("[BTTask_Patrol] 黑板为空，无法写入巡逻点")
        self:FinishExecute(false)
        return
    end
    
    Blackboard:SetValueAsVector(self.PATROL_BLACKBOARD_KEY, TargetPoint)
    ugcprint(string.format("[BTTask_Patrol] 已写入巡逻点 %s=%s", self.PATROL_BLACKBOARD_KEY, tostring(TargetPoint)))
    self:FinishExecute(true)
end

-- --- 任务Tick函数
-- -- 当任务处于活动状态时每帧调用
-- ---@param OwnerController AAIController 拥有此任务节点的AI控制器
-- ---@param ControlledPawn APawn AI控制器当前控制的Pawn对象
-- ---@param DeltaSeconds float 自上一帧以来的时间（秒）
-- function BTTask_Patrol:ReceiveTickAI(OwnerController, ControlledPawn, DeltaSeconds)
--     -- 在此实现每帧逻辑
--     -- 注意：任务需保持活动状态才会触发Tick
-- end

-- --- 任务中止事件
-- -- 当任务被外部中断时调用（如装饰器条件失败）
-- ---@param OwnerController AAIController 拥有此任务节点的AI控制器
-- ---@param ControlledPawn APawn AI控制器当前控制的Pawn对象
-- function BTTask_Patrol:ReceiveAbortAI(OwnerController, ControlledPawn)
--     -- 完成中止流程
-- 	self:FinishAbort()
-- end




return BTTask_Patrol