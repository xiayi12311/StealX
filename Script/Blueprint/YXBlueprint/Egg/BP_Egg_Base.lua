---@class BP_Egg_Base_C:AActor
---@field STCustomMesh USTCustomMeshComponent
---@field DefaultSceneRoot USceneComponent
--Edit Below--
local BP_Egg_Base = {}
 
--[[
function BP_Egg_Base:ReceiveBeginPlay()
    BP_Egg_Base.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function BP_Egg_Base:ReceiveTick(DeltaTime)
    BP_Egg_Base.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_Egg_Base:ReceiveEndPlay()
    BP_Egg_Base.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_Egg_Base:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_Egg_Base:GetAvailableServerRPCs()
    return
end
--]]

return BP_Egg_Base