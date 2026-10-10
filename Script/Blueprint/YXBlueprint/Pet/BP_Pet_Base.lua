---@class BP_Pet_Base_C:AActor
---@field Halloween_Prop02 UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
--Edit Below--
local BP_Pet_Base = {}
 
--[[
function BP_Pet_Base:ReceiveBeginPlay()
    BP_Pet_Base.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function BP_Pet_Base:ReceiveTick(DeltaTime)
    BP_Pet_Base.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_Pet_Base:ReceiveEndPlay()
    BP_Pet_Base.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_Pet_Base:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_Pet_Base:GetAvailableServerRPCs()
    return
end
--]]

return BP_Pet_Base