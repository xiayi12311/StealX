---@class UGCPlayerPawn_C:BP_UGCPlayerPawn_C
--Edit Below--
local UGCPlayerPawn = {}
 

function UGCPlayerPawn:ReceiveBeginPlay()
    UGCPlayerPawn.SuperClass.ReceiveBeginPlay(self)
    UGCAttributeSystem.AddGameAttributeChangedDelegate(self, "UGCGeneralMoveSpeedScale", function()
        local Value = UGCAttributeSystem.GetGameAttributeValue(self, "UGCGeneralMoveSpeedScale") or 0
        self.STCharacterMovement.MaxAcceleration = 8192 * Value
    end)

end



function UGCPlayerPawn:ReceiveTick(DeltaTime)
    UGCPlayerPawn.SuperClass.ReceiveTick(self, DeltaTime)
    -- local Velocity = self:GetVelocity()
    -- local VelocityText = string.format("X=%.2f Y=%.2f Z=%.2f", Velocity.X, Velocity.Y, Velocity.Z)
    -- --ugcprint("[UGCPlayerPawn] ReceiveTick " .. VelocityText)
    -- UGCDebugSystem.PrintToScreen(VelocityText)
    -- UGCDebugSystem.PrintToScreen(self.STCharacterMovement.MaxAcceleration)
end


--[[
function UGCPlayerPawn:ReceiveEndPlay()
    UGCPlayerPawn.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function UGCPlayerPawn:GetAvailableServerRPCs()
    return
end
--]]

function UGCPlayerPawn:GetReplicatedProperties()
    return {"__SubObjectRepList", "Lazy"}
end


return UGCPlayerPawn