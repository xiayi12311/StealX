---@class UGCPlayerPawn_C:BP_UGCPlayerPawn_C
--Edit Below--
local UGCPlayerPawn = {}
 
function UGCPlayerPawn:ReceiveBeginPlay()
    UGCPlayerPawn.SuperClass.ReceiveBeginPlay(self)

    if UGCGameSystem.IsServer() then
        self:InitInServer()
    else
        self:OnRep_CoverAllAvatarMeshInfo()
    end

    UGCAttributeSystem.AddGameAttributeChangedDelegate(self, "UGCGeneralMoveSpeedScale", function()
        local Value = UGCAttributeSystem.GetGameAttributeValue(self, "UGCGeneralMoveSpeedScale") or 0
        self.STCharacterMovement.MaxAcceleration = 8192 * Value
    end)
end

-- function UGCPlayerPawn:ReceiveTick(DeltaTime)
--     UGCPlayerPawn.SuperClass.ReceiveTick(self, DeltaTime)
--     -- local Velocity = self:GetVelocity()
--     -- local VelocityText = string.format("X=%.2f Y=%.2f Z=%.2f", Velocity.X, Velocity.Y, Velocity.Z)
--     -- --ugcprint("[UGCPlayerPawn] ReceiveTick " .. VelocityText)
--     -- UGCDebugSystem.PrintToScreen(VelocityText)
--     -- UGCDebugSystem.PrintToScreen(self.STCharacterMovement.MaxAcceleration)
-- end

--[[
function UGCPlayerPawn:ReceiveEndPlay()
    UGCPlayerPawn.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function UGCPlayerPawn:GetAvailableServerRPlayerControllers()
    return
end
--]]

function UGCPlayerPawn:GetReplicatedProperties()
    return {"__SubObjectRepList", "Lazy"}
end

function UGCPlayerPawn:InitInServer()
    -- 玩家死亡不生成死亡盒子
    UGCPlayerPawnSystem.SkipSpawnDeadTombBox(self, true)
    self.DynamicStateEnterHandle:Add(self.ChangeState, self)
end

function UGCPlayerPawn:ChangeState(CurState)
    ugcprint("[UGCPlayerPawn:ChangeState] " .. tostring(CurState.TagName))
    -- 获取状态标签
    local DeadTag = UGCGameplayTagSystem.RequestGameplayTag("PawnState.Dead")

    local PlayerKey = UGCGameSystem.GetPlayerKeyByPlayerPawn(self)
    if not UGCGameSystem.IsServer() then
        return
    end

    local PlayerState = UGCGameSystem.GetPlayerStateByPlayerPawn(self)
    local GameState = UGCGameSystem.GetGameState()
    if UGCGameplayTagSystem.IsValidTag(DeadTag) and UGCPersistEffectSystem.HasDynamicState(self, DeadTag) and tostring(CurState.TagName) == "PawnState.Dead" then
        -- 处理死亡状态逻辑：延时后复活玩家
        if PlayerKey then
            local RespawnDelayTime = 1        -- 复活延时（秒），可按需调整
            local IsDestoryAlivePawn = false  -- 角色已死亡，无需销毁存活角色
            local DestroyDelayTime = 0.01     -- 销毁延时，不能为0
            ugcprint(string.format("[UGCPlayerPawn:ChangeState] Player %s died, respawn after %ss", tostring(PlayerKey), tostring(RespawnDelayTime)))
            UGCPlayerPawnSystem.RespawnPlayer(PlayerKey, RespawnDelayTime, IsDestoryAlivePawn, DestroyDelayTime)
        else
            ugcprint("[UGCPlayerPawn:ChangeState] Enter Dead state but PlayerKey not found.")
        end
    end
end

return UGCPlayerPawn