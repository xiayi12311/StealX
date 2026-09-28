local UGCPlayerState = {}

-- 玩家当前速度
UGCPlayerState.CurPlayerSpeed = 0

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
end

function UGCPlayerState:GetAvailableServerRPCs()
    return
end

-- function UGCPlayerState:HandleBeginPlayInServer()
--     -- 在玩家PostLogin之后执行初始化逻辑
--     local Message = UGCGenericMessageSystem.Messages.UGC.Player.PlayerEnter
--     UGCGenericMessageSystem.ListenGlobalMessage(self, Message, UGCActorComponentUtility.GetOwner(self), 
--         function (...)
--             self:OnPlayerEnter(...) 
--         end
--     );

--     Message = UGCGenericMessageSystem.Messages.UGC.Player.PlayerExit
--     UGCGenericMessageSystem.ListenGlobalMessage(self, Message, UGCActorComponentUtility.GetOwner(self),
--         function (...)
--             self:OnPlayerExit(...)
--         end
--     )

--     --  GamePart初始化    
--     UGCGenericMessageSystem.ListenGlobalMessage(self, UGCGenericMessageSystem.Messages.UGC.GamePart.GamePartLoadedForPlayer, self, self.OnGamePartLoaded)


--     -- 监听关闭通知事件，执行数据存档
--     UGCGenericMessageSystem.ListenGlobalMessage(
--         UGCGameSystem.GameState,
--         UGCGenericMessageSystem.UserDefinedMessages.UGC.UGCDSShutDownManager.DSCloseNotify,
--         self,
--         function()
--             local UID = UGCGameSystem.GetUIDByPlayerState(self)
--             local Data = UGCPlayerStateSystem.GetPlayerArchiveData(UID)
--             UGCPlayerStateSystem.SavePlayerArchiveData(UID, Data)
--         end
--     )
-- end

-- function UGCPlayerState:OnPlayerEnter(_, PlayerKey)
--     if UGCGameSystem.GetPlayerKeyByPlayerState(self) ~= PlayerKey then
--         return
--     end

--     self.YXUID = UGCGameSystem.GetUIDByPlayerState(self)
--     ugcprint("[UGCPlayerState:OnPlayerEnter] "..tostring(self.YXUID))

--     local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerState(self)
--     local Uid = UGCGameSystem.GetUIDByPlayerState(self)
--     local Data = UGCPlayerStateSystem.GetPlayerArchiveData(Uid)

-- end


return UGCPlayerState