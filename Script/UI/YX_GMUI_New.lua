---@class YX_GMUI_C:UUserWidget
---@field Button_GM UButton
---@field CanvasPanel_GM UCanvasPanel
--Edit Below--
local YX_GMUI_New = { bInitDoOnce = false } 

function YX_GMUI_New:Construct()
	self:LuaInit();
	
end

-- function YX_GMUI_New:Tick(MyGeometry, InDeltaTime)
-- end
-- function YX_GMUI_New:Destruct()
-- end
-- [Editor Generated Lua] function define Begin:
function YX_GMUI_New:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
	self.Button_GM.OnClicked:Add(self.Button_GM_OnClicked, self);
	-- [Editor Generated Lua] BindingEvent End;
end

function YX_GMUI_New:Button_GM_OnClicked()
	if self.CanvasPanel_GM:GetVisibility() == ESlateVisibility.Collapsed then
		self.CanvasPanel_GM:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    else
        self.CanvasPanel_GM:SetVisibility(ESlateVisibility.Collapsed)
	end
end

-- [Editor Generated Lua] function define End;

return YX_GMUI_New