---@class BPWidget_FloatText_C:UUserWidget
---@field NewAnimation_1 UWidgetAnimation
---@field TextBlock_FloatText UTextBlock
--Edit Below--
local BPWidget_FloatText = { bInitDoOnce = false }
-- 飘字整体缩放（1=原始大小，1.5=放大50%，0.8=缩小20%）
local TextScale = 0.5
-- 飘字上升高度（屏幕像素），由 Lua 计算后叠加到屏幕坐标上。
-- 如果 BP 里的动画本身已带上升位移，改成 0 避免位移叠加
local RiseHeight = 80
-- BP 动画缺失时的兜底时长（秒）
local DefaultDuration = 1
function BPWidget_FloatText:Construct()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    -- 以下均为每个飘字实例独立的状态（在 Construct/Init 中初始化，不要放类定义处）
    self.bPlaying = false
    self.bHiddenByCamera = false
    self.Elapsed = 0
    self.Duration = DefaultDuration
    self.HeightOffset = 0
    self.OverlapOffsetX = 0
    self.FloatOwner = nil
    self.FinishedCallback = nil
end
function BPWidget_FloatText:Destruct()
    self.bPlaying = false
end
-- 由 YXFloatTextComponent 调用：绑定锚点并开始播放
-- InOwner: 锚点Actor；InHeightOffset: 锚点头顶高度(cm)；InOverlapOffsetX: 多条飘字横向错开偏移(屏幕像素)
function BPWidget_FloatText:InitFloatText(InOwner, InHeightOffset, InOverlapOffsetX, InText, InFinishedCallback)
    self.FloatOwner = InOwner
    self.HeightOffset = InHeightOffset or 100
    self.OverlapOffsetX = InOverlapOffsetX or 0
    self.FinishedCallback = InFinishedCallback
    self.Elapsed = 0
    -- 飘字不接收点击，避免挡住操作
    self:SetVisibility(ESlateVisibility.HitTestInvisible)
    -- 整体缩放
    self:SetRenderScale(Vector2D.New(TextScale, TextScale))
    if self.NewAnimation_1 then
        local EndTime = self.NewAnimation_1:GetEndTime()
        self.Duration = (EndTime and EndTime > 0) and EndTime or DefaultDuration
        self:PlayAnimation(self.NewAnimation_1, 0, 1, EUMGSequencePlayMode.Forward, 1)
    else
        ugcprint("[BPWidget_FloatText] 未绑定动画 NewAnimation_1，使用兜底时长")
    end
    self:SetText(InText)
    -- 先算一次位置，避免第一帧闪现在屏幕左上角
    self.bPlaying = true
    self:UpdatePosition()
end
function BPWidget_FloatText:SetText(InText)
    if self.TextBlock_FloatText then
        self.TextBlock_FloatText:SetText(tostring(InText or ""))
    else
        ugcprint("[BPWidget_FloatText] 找不到文本控件 TextBlock_FloatText，请把控件里的TextBlock改名为 TextBlock_FloatText")
    end
end
-- 每帧执行：
--   Owner世界坐标 + 头顶高度偏移
--        ↓
--   ProjectWorldLocationToWidgetPosition（世界坐标 → 屏幕控件坐标）
--        ↓
--   ScreenPosition + 横向错开偏移 + 当前动画上升偏移
--        ↓
--   SetPositionInViewport
function BPWidget_FloatText:UpdatePosition()
    local Owner = self.FloatOwner
    if Owner == nil or (Owner.IsValid and not Owner:IsValid()) then
        return
    end
    -- 锚点世界坐标：角色位置 + 头顶高度
    local WorldLocation = Owner:K2_GetActorLocation()
    WorldLocation.Z = WorldLocation.Z + self.HeightOffset
    -- 转到镜头后方时不显示（避免投影出镜像坐标乱飞）
    if self:IsBehindCamera(WorldLocation) then
        if not self.bHiddenByCamera then
            self.bHiddenByCamera = true
            self:SetVisibility(ESlateVisibility.Collapsed)
        end
        return
    elseif self.bHiddenByCamera then
        self.bHiddenByCamera = false
        self:SetVisibility(ESlateVisibility.HitTestInvisible)
    end
    -- 世界坐标 → 屏幕坐标（返回值已是控件坐标）
    local ScreenPosition = UGCWidgetUtility.ProjectWorldLocationToWidgetPosition(WorldLocation)
    if ScreenPosition == nil then
        return
    end
    -- 当前动画进度 → 上升偏移（ease-out：先快后慢）
    local Progress = self.Elapsed / self.Duration
    if self.NewAnimation_1 then
        Progress = self:GetAnimationCurrentTime(self.NewAnimation_1) / self.Duration
    end
    Progress = math.min(math.max(Progress, 0), 1)
    local EaseOut = 1 - (1 - Progress) * (1 - Progress)
    self:SetPositionInViewport(
        Vector2D.New(ScreenPosition.X + self.OverlapOffsetX, ScreenPosition.Y - RiseHeight * EaseOut),
        false)
end
-- 判断世界坐标是否在镜头朝向的后方（用控制朝向做点积，纯Lua计算，无额外API依赖）
function BPWidget_FloatText:IsBehindCamera(WorldLocation)
    local LocalPC = UGCGameSystem.GetLocalPlayerController()
    if LocalPC == nil then
        return false
    end
    local CameraManager = LocalPC.PlayerCameraManager
    local CameraLocation = CameraManager and CameraManager:GetCameraLocation() or LocalPC:K2_GetActorLocation()
    -- 锚点相对镜头的方向向量
    local DirX = WorldLocation.X - CameraLocation.X
    local DirY = WorldLocation.Y - CameraLocation.Y
    local DirZ = WorldLocation.Z - CameraLocation.Z
    -- 由控制旋转（Yaw/Pitch）求镜头前向向量（UE坐标系：X前 Y右 Z上）
    local Rotation = LocalPC:GetControlRotation()
    local YawRad = math.rad(Rotation.Yaw)
    local PitchRad = math.rad(Rotation.Pitch)
    local FwdX = math.cos(PitchRad) * math.cos(YawRad)
    local FwdY = math.cos(PitchRad) * math.sin(YawRad)
    local FwdZ = math.sin(PitchRad)
    return DirX * FwdX + DirY * FwdY + DirZ * FwdZ <= 0
end
function BPWidget_FloatText:Tick(MyGeometry, InDeltaTime)
    if not self.bPlaying then
        return
    end
    self.Elapsed = self.Elapsed + InDeltaTime
    local Owner = self.FloatOwner
    local bOwnerInvalid = Owner == nil or (Owner.IsValid and not Owner:IsValid())
    -- 播放结束或锚点已销毁时结束，通知组件回收
    if self.Elapsed >= self.Duration or bOwnerInvalid then
        self:Finish()
        return
    end
    self:UpdatePosition()
end
-- 播放结束，通知组件回收
function BPWidget_FloatText:Finish()
    if not self.bPlaying then
        return
    end
    self.bPlaying = false
    if self.FinishedCallback then
        local Callback = self.FinishedCallback
        self.FinishedCallback = nil
        Callback(self)
    end
end
-- 组件强制回收时调用（同屏超限淘汰 / 组件销毁）
function BPWidget_FloatText:StopFloat()
    self.bPlaying = false
    self.FinishedCallback = nil
    if self.NewAnimation_1 and self:IsAnimationPlaying(self.NewAnimation_1) then
        self:StopAnimation(self.NewAnimation_1)
    end
end
return BPWidget_FloatText