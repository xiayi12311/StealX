local UGCPlayerState = {}
local Delegate = require("common.Delegate")

-- 玩家总速度
UGCPlayerState.PlayerTotalSpeed = 0

-- 玩家当前速度
UGCPlayerState.PlayerCurrentSpeed = 0
UGCPlayerState.PlayerCurrentSpeedDelegate = Delegate.New()

-- 玩家进入跑步机委托
UGCPlayerState.EnterRunningMachineDelegate = Delegate.New()
-- 玩家离开跑步机委托
UGCPlayerState.LeaveRunningMachineDelegate = Delegate.New()

-- 玩家跑步机增加速度
UGCPlayerState.PlayerRunningMachineAddSpeed = 0

function UGCPlayerState:ReceiveBeginPlay()
    UGCPlayerState.SuperClass.ReceiveBeginPlay(self)
end

function UGCPlayerState:ReceiveTick(DeltaTime)
    UGCPlayerState.SuperClass.ReceiveTick(self, DeltaTime)
end

function UGCPlayerState:ReceiveEndPlay()
    UGCPlayerState.SuperClass.ReceiveEndPlay(self) 
end

function UGCPlayerState:GetReplicatedProperties()
    return 
    "PlayerCurrentSpeed"
end

function UGCPlayerState:GetAvailableServerRPCs()
    return
end

function UGCPlayerState:OnRep_PlayerCurrentSpeed()
    ugcprint("[UGCPlayerState] OnRep_PlayerCurrentSpeed " .. tostring(self.PlayerCurrentSpeed))
    self.PlayerCurrentSpeedDelegate:Broadcast(self.PlayerCurrentSpeed)
end

function UGCPlayerState:RPC_Client_PlayerCurrentSpeed()
    if self:HasAuthority() then
        UnrealNetwork.CallUnrealRPC(self, self, "RPC_Client_PlayerCurrentSpeed", self.PlayerCurrentSpeed)
    else
        self.PlayerCurrentSpeedDelegate:Broadcast(self.PlayerCurrentSpeed)
    end
end

return UGCPlayerState