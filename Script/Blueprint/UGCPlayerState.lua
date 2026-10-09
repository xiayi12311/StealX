local UGCPlayerState = {}
local Delegate = require("common.Delegate")

-- 玩家总速度
UGCPlayerState.PlayerTotalSpeed = 0

-- 玩家当前速度倍率
UGCPlayerState.PlayerCurSpeedScale = 1

-- 玩家当前速度
UGCPlayerState.PlayerCurSpeed = 1
UGCPlayerState.PlayerCurSpeedDelegate = Delegate.New()

-- 玩家进入跑步机委托
UGCPlayerState.EnterRunningMachineDelegate = Delegate.New()

-- 玩家离开跑步机委托
UGCPlayerState.LeaveRunningMachineDelegate = Delegate.New()

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
    "PlayerCurSpeed"
end

function UGCPlayerState:GetAvailableServerRPCs()
    return
end

function UGCPlayerState:OnRep_PlayerCurSpeed()
    ugcprint("[UGCPlayerState] OnRep_PlayerCurSpeed " .. tostring(self.PlayerCurSpeed))
end

return UGCPlayerState