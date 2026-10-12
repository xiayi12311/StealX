---@class BPWidget_ViewZooming_C:UUserWidget
---@field Slider_Zooming USlider
--Edit Below--
-- 视角缩放 UI：用滑条控制第三人称相机臂长（SpringArm）实现拉近/拉远
--   滑条0.5 = 默认视角（不缩放）；滑条1 = 最大拉近（臂长 -ZoomInArmLengthOffset）；滑条0 = 最大拉远（臂长 +ZoomOutArmLengthOffset）
--   拉近与拉远幅度可不一致（分别由 ZoomInArmLengthOffset / ZoomOutArmLengthOffset 控制）
--   通过UGCGameplayTaskSystem.Player.AddCustomCameraData平滑过渡（客户端生效）
--   滑条拉满（=1）切第一人称；小于 1 切第三人称（经RPC由服务端执行）
--   仅本地客户端相机表现 + 视角模式切换，不涉及其他网络同步
local BPWidget_ViewZooming = { bInitDoOnce = false }

-- 拉近侧最大臂长幅度：滑条0.5→1，臂长相对默认减少这么多（正值，可按需调整）
BPWidget_ViewZooming.ZoomInArmLengthOffset = 200
-- 拉远侧最大臂长幅度：滑条0.5→0，臂长相对默认增加这么多（正值，可按需调整）
BPWidget_ViewZooming.ZoomOutArmLengthOffset = 1200
-- 相机逼近目标参数的渐进速度（数值越大过渡越快，可按需调整）
BPWidget_ViewZooming.FadeInSpeed = 10
-- 达到该值视为拉满（=1）：切第一人称；低于则第三人称（用阈值避免浮点误差漏判）
BPWidget_ViewZooming.FPPThreshold = 0.999

function BPWidget_ViewZooming:Construct()
	self.Slider_Zooming.OnValueChanged:Add(self.Slider_Zooming_OnValueChanged, self)
	ugcprint("[BPWidget_ViewZooming:Construct] 已绑定 Slider_Zooming.OnValueChanged")
end

function BPWidget_ViewZooming:Destruct()
	if self.CameraTask ~= nil then
		self.CameraTask:EndTask()
		self.CameraTask = nil
		ugcprint("[BPWidget_ViewZooming:Destruct] 已结束相机任务")
	end
end

-- 滑条值变化回调：按当前值刷新相机臂长与视角模式
function BPWidget_ViewZooming:Slider_Zooming_OnValueChanged(Value)
	ugcprint(string.format("[BPWidget_ViewZooming:Slider_Zooming_OnValueChanged] Value=%s", tostring(Value)))
	self:ApplyZoom(Value)
	self:UpdateViewMode(Value)
end

-- 视角模式：滑条拉满（≈1）切第一人称，其余切第三人称（本地请求，服务端执行）
function BPWidget_ViewZooming:UpdateViewMode(Value)
	if Value == nil then
		return
	end

	local bWantFPP = Value >= self.FPPThreshold
	if self.bViewModeFPP == bWantFPP then
		return
	end

	local PlayerController = UGCGameSystem.GetLocalPlayerController()
	if PlayerController == nil then
		ugcprint("[BPWidget_ViewZooming:UpdateViewMode] PlayerController 为空，跳过")

		return
	end

	self.bViewModeFPP = bWantFPP
	ugcprint(string.format("[BPWidget_ViewZooming:UpdateViewMode] Value=%.3f → %s",	Value, bWantFPP and "第一人称(FPP)" or "第三人称(TPP)"))
	PlayerController:RPC_Server_SetViewMode(bWantFPP)
end

-- 应用缩放：把滑条归一化值映射为SpringArm增量并下发相机任务
function BPWidget_ViewZooming:ApplyZoom(Value)
	-- ugcprint(string.format("[BPWidget_ViewZooming:ApplyZoom] Value=%.3f", Value))
	if Value == nil then
		ugcprint("[BPWidget_ViewZooming:ApplyZoom] Value 为 nil，忽略")

		return
	end

	if Value < 0 then 
		Value = 0 
	end

	if Value > 1 then 
		Value = 1 
	end

	local PlayerController = UGCGameSystem.GetLocalPlayerController()
	local PlayerPawn = UGCGameSystem.GetLocalPlayerPawn()
	if PlayerController == nil or PlayerPawn == nil then
		ugcprint(string.format("[BPWidget_ViewZooming:ApplyZoom] PC=%s Pawn=%s，跳过", tostring(PlayerController), tostring(PlayerPawn)))
		
		return
	end

	-- 结束上一次相机任务，避免任务堆积
	if self.CameraTask ~= nil then
		self.CameraTask:EndTask()
		self.CameraTask = nil
		ugcprint("[BPWidget_ViewZooming:ApplyZoom] 已结束上一次相机任务")
	end

	-- 0.5 = 默认视角；→1拉近（负增量，幅度 ZoomInArmLengthOffset），→0拉远（正增量，幅度 ZoomOutArmLengthOffset）
	local ArmLengthAdditive
	if Value >= 0.5 then
		ArmLengthAdditive = -(Value - 0.5) * 2 * self.ZoomInArmLengthOffset
	else
		ArmLengthAdditive = (0.5 - Value) * 2 * self.ZoomOutArmLengthOffset
	end

	-- ugcprint(string.format("[BPWidget_ViewZooming:ApplyZoom] Value=%.3f ArmLengthAdditive=%.1f FadeInSpeed=%s", Value, ArmLengthAdditive, tostring(self.FadeInSpeed)))
	self.CameraTask = UGCGameplayTaskSystem.Player.AddCustomCameraData.NewTask(PlayerController, PlayerPawn, self.FadeInSpeed, nil, nil, ArmLengthAdditive, nil)
	-- ugcprint(string.format("[BPWidget_ViewZooming:ApplyZoom] 相机任务=%s", tostring(self.CameraTask)))
end

return BPWidget_ViewZooming