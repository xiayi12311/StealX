---@class BPWidget_IteractionButtons_C:UUserWidget
---@field Button_Drop UButton
---@field Button_Steal UButton
---@field ProgressBar_Pick UProgressBar
---@field WidgetSwitcher_PickDrop UWidgetSwitcher
--Edit Below--
-- 交互按钮 UI：控制蛋的拾取与放下
--   WidgetSwitcher_PickDrop：index 0 = 偷取(pick)，index 1 = 放下(drop)
--   已持有蛋 → 显示 drop；未持有且附近有可拾取的蛋 → 显示 pick；都没有 → 折叠
--   长按 pick 满 HoldDuration 秒才真正拾取，ProgressBar_Pick 显示长按进度
--   全部用 CreateLuaTimer 驱动（不使用 Tick）
local BPWidget_IteractionButtons = { bInitDoOnce = false }

-- 长按拾取所需时长（秒）
BPWidget_IteractionButtons.HoldDuration = 1.5
-- 交互状态刷新间隔（秒）
BPWidget_IteractionButtons.RefreshInterval = 0.1
-- 长按进度刷新间隔（秒）
BPWidget_IteractionButtons.ProgressInterval = 0.05

function BPWidget_IteractionButtons:Construct()
	self:LuaInit();
	
end

-- function BPWidget_IteractionButtons:Tick(MyGeometry, InDeltaTime)

-- end

function BPWidget_IteractionButtons:Destruct()
	self:StopTimers()
end

-- [Editor Generated Lua] function define Begin:
function BPWidget_IteractionButtons:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
	self.Button_Steal.OnPressed:Add(self.Button_Steal_OnPressed, self);
	self.Button_Steal.OnReleased:Add(self.Button_Steal_OnReleased, self);
	self.Button_Drop.OnClicked:Add(self.Button_Drop_OnClicked, self);
	-- [Editor Generated Lua] BindingEvent End;

	self.bHoldingPick = false
	self.HoldElapsed = 0
	self.ProgressBar_Pick:SetPercent(0)
	self:RefreshState()

	-- 循环定时器：按间隔刷新交互按钮显示
	self.RefreshTimer = UGCTimerUtility.CreateLuaTimer(self.RefreshInterval, function()
		self:RefreshState()
	end, true)
end

function BPWidget_IteractionButtons:Button_Steal_OnPressed()
	-- 开始长按：起一个循环计时器推进进度
	self.bHoldingPick = true
	self.HoldElapsed = 0
	self.ProgressBar_Pick:SetPercent(0)
	if self.ProgressTimer ~= nil then
		UGCTimerUtility.RemoveLuaTimer(self.ProgressTimer)
	end
	self.ProgressTimer = UGCTimerUtility.CreateLuaTimer(self.ProgressInterval, function()
		self:OnPickHoldProgress()
	end, true)
end

function BPWidget_IteractionButtons:Button_Steal_OnReleased()
	-- 未按满时长就松开：取消本次拾取并清空进度
	self:CancelPickHold()
end

function BPWidget_IteractionButtons:Button_Drop_OnClicked()
	local PlayerController = UGCGameSystem.GetLocalPlayerController()
	PlayerController:RPC_Server_DropEgg()
end

-- [Editor Generated Lua] function define End;

-- 长按进度推进：进度满即拾取
function BPWidget_IteractionButtons:OnPickHoldProgress()
	if not self.bHoldingPick then
		return
	end
	self.HoldElapsed = (self.HoldElapsed or 0) + self.ProgressInterval
	local Percent = self.HoldElapsed / self.HoldDuration
	if Percent > 1 then
		Percent = 1
	end
	self.ProgressBar_Pick:SetPercent(Percent)
	if self.HoldElapsed >= self.HoldDuration then
		local PlayerController = UGCGameSystem.GetLocalPlayerController()
		self:CancelPickHold()
		PlayerController:RPC_Server_PickEgg()
	end
end

-- 按当前交互状态刷新显示与切换项
function BPWidget_IteractionButtons:RefreshState()
	local State = self:GetInteractionState()
	if State == "Drop" then
		self.WidgetSwitcher_PickDrop:SetActiveWidgetIndex(1)
		self.WidgetSwitcher_PickDrop:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
	elseif State == "Pick" then
		self.WidgetSwitcher_PickDrop:SetActiveWidgetIndex(0)
		self.WidgetSwitcher_PickDrop:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
	else
		self.WidgetSwitcher_PickDrop:SetVisibility(ESlateVisibility.Collapsed)
		self:CancelPickHold()
	end
end

-- 从本地PC的蛋组件取交互状态："Pick" / "Drop" / "None"
function BPWidget_IteractionButtons:GetInteractionState()
	local PlayerController = UGCGameSystem.GetLocalPlayerController()
	if PlayerController == nil or PlayerController.YXEggComponent == nil then
		return "None"
	end
	return PlayerController.YXEggComponent:GetInteractionState()
end

-- 取消长按并清空进度
function BPWidget_IteractionButtons:CancelPickHold()
	self.bHoldingPick = false
	self.HoldElapsed = 0
	if self.ProgressTimer ~= nil then
		UGCTimerUtility.RemoveLuaTimer(self.ProgressTimer)
		self.ProgressTimer = nil
	end
	if self.ProgressBar_Pick then
		self.ProgressBar_Pick:SetPercent(0)
	end
end

-- 移除全部定时器
function BPWidget_IteractionButtons:StopTimers()
	if self.RefreshTimer ~= nil then
		UGCTimerUtility.RemoveLuaTimer(self.RefreshTimer)
		self.RefreshTimer = nil
	end
	self:CancelPickHold()
end

return BPWidget_IteractionButtons