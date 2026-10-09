---@class YXIncubationComponent_C:ActorComponent
--Edit Below--
local YXIncubationComponent = {}
 
function YXIncubationComponent:ReceiveBeginPlay()
    YXIncubationComponent.SuperClass.ReceiveBeginPlay(self)
end

--[[
function YXIncubationComponent:ReceiveTick(DeltaTime)
    YXIncubationComponent.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

function YXIncubationComponent:ReceiveEndPlay()
    YXIncubationComponent.SuperClass.ReceiveEndPlay(self) 
end

return YXIncubationComponent