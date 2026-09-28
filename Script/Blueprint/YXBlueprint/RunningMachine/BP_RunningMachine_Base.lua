---@class BP_RunningMachine_Base_C:AActor
---@field StaticMesh UStaticMeshComponent
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
--Edit Below--
local BP_RunningMachine_Base = {}
 
function BP_RunningMachine_Base:ReceiveBeginPlay()
    BP_RunningMachine_Base.SuperClass.ReceiveBeginPlay(self)
	self:LuaInit()
end

--[[
function BP_RunningMachine_Base:ReceiveTick(DeltaTime)
    BP_RunningMachine_Base.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

function BP_RunningMachine_Base:ReceiveEndPlay()
    BP_RunningMachine_Base.SuperClass.ReceiveEndPlay(self) 
end

--[[
function BP_RunningMachine_Base:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_RunningMachine_Base:GetAvailableServerRPCs()
    return
end
--]]

-- [Editor Generated Lua] function define Begin:
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

function BP_RunningMachine_Base:Box_OnComponentBeginOverlap(OverlappedComponent, OtherActor, OtherComp, OtherBodyIndex, bFromSweep, SweepResult)
	if UGCGameSystem.IsServer() then
		ugcprint("[BP_RunningMachine_Base] Box_OnComponentBeginOverlap")
		local PlayerState = UGCGameSystem.GetPlayerStateByPlayerPawn(OtherActor)
		PlayerState.PlayerRunningMachineAddSpeed = 0
		UGCTimerUtility.CreateLuaTimer(0.5, function()
			PlayerState.PlayerRunningMachineAddSpeed = PlayerState.PlayerRunningMachineAddSpeed + 1
		end, true)
	end
end

function BP_RunningMachine_Base:Box_OnComponentEndOverlap(OverlappedComponent, OtherActor, OtherComp, OtherBodyIndex)
	if UGCGameSystem.IsServer() then
		ugcprint("[BP_RunningMachine_Base] Box_OnComponentEndOverlap")
		local PlayerState = UGCGameSystem.GetPlayerStateByPlayerPawn(OtherActor)
		UGCAttributeSystem.AddGameAttributeValue(OtherActor, "UGCGeneralMoveSpeedScale", PlayerState.PlayerRunningMachineAddSpeed)
		ugcprint("[BP_RunningMachine_Base] PlayerRunningMachineAddSpeed: " .. PlayerState.PlayerRunningMachineAddSpeed)
	end
end

-- [Editor Generated Lua] function define End;

return BP_RunningMachine_Base