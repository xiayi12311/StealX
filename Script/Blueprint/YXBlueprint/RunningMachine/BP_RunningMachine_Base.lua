---@class BP_RunningMachine_Base_C:AActor
---@field StaticMesh UStaticMeshComponent
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
---@field RunningMachineID int32
--Edit Below--
local BP_RunningMachine_Base = {}

function BP_RunningMachine_Base:ReceiveBeginPlay()
    BP_RunningMachine_Base.SuperClass.ReceiveBeginPlay(self)
    self:LuaInit()
end
	
-- function BP_RunningMachine_Base:ReceiveTick(DeltaTime)
--     BP_RunningMachine_Base.SuperClass.ReceiveTick(self, DeltaTime)
-- end

-- function BP_RunningMachine_Base:ReceiveEndPlay()
--     BP_RunningMachine_Base.SuperClass.ReceiveEndPlay(self) 
-- end

-- 通过踩上来的 Pawn 找到其 PlayerController 上挂的 YXRunningMachineComponent
function BP_RunningMachine_Base:GetCompByPawn(Pawn)
    local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerPawn(Pawn)
    return PlayerController.YXRunningMachineComponent
end

function BP_RunningMachine_Base:Box_OnComponentBeginOverlap(OverlappedComponent, OtherActor, OtherComp, OtherBodyIndex, bFromSweep, SweepResult)
    if UGCGameSystem.IsServer() then
		ugcprint("[BP_RunningMachine_Base] Box_OnComponentBeginOverlap")
        local Comp = self:GetCompByPawn(OtherActor)
        if Comp then
            Comp:OnPawnEnter(self, OtherActor)
        else
            ugcprint("[BP_RunningMachine_Base] Pawn未挂YXRunningMachineComponent")
        end
    else
        local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerPawn(OtherActor)
        local PlayerState = UGCGameSystem.GetPlayerStateByPlayerPawn(OtherActor)
        local cfg = PlayerController.YXRunningMachineComponent:GetConfigByID(self.RunningMachineID)
        PlayerState.EnterRunningMachineDelegate:Broadcast(cfg.AddInterval, cfg.AddSpeed)
    end
end

function BP_RunningMachine_Base:Box_OnComponentEndOverlap(OverlappedComponent, OtherActor, OtherComp, OtherBodyIndex)
    if UGCGameSystem.IsServer() then
		ugcprint("[BP_RunningMachine_Base] Box_OnComponentEndOverlap")
        local Comp = self:GetCompByPawn(OtherActor)
        if Comp then
            Comp:OnPawnLeave(self, OtherActor)
        end
    else
        local PlayerState = UGCGameSystem.GetPlayerStateByPlayerPawn(OtherActor)
        PlayerState.LeaveRunningMachineDelegate:Broadcast()
    end
end

function BP_RunningMachine_Base:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;

	-- [Editor Generated Lua] BindingEvent Begin:
	self.Box.OnComponentBeginOverlap:Add(self.Box_OnComponentBeginOverlap, self);
	self.Box.OnComponentEndOverlap:Add(self.Box_OnComponentEndOverlap, self);
	-- [Editor Generated Lua] BindingEvent End;
end

-- [Editor Generated Lua] function define End;

return BP_RunningMachine_Base
