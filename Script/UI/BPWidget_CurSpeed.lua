---@class BPWidget_CurSpeed_C:UUserWidget
---@field NewAnimation_1 UWidgetAnimation
---@field TextBlock_CurSpeed UTextBlock
---@field TextBlock_CurSpeedScale UTextBlock
--Edit Below--
local BPWidget_CurSpeed = { bInitDoOnce = false }
function BPWidget_CurSpeed:Construct()
    local PlayerState = UGCGameSystem.GetLocalPlayerState()
    self.BindRetryCount = 0
    self:BindSpeedDelegate()
    self:RefreshSpeed()
    PlayerState.EnterRunningMachineDelegate:Add(self.StartPlayFloatTextAndShakeAnimation, self)
    PlayerState.LeaveRunningMachineDelegate:Add(self.StopPlayFloatText, self)
end

-- function BPWidget_CurSpeed:Tick(MyGeometry, InDeltaTime)
-- end

-- -- function BPWidget_CurSpeed:Destruct()
-- end

function BPWidget_CurSpeed:GetDisplaySpeed()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if PC == nil then
        return 0
    end
    local Pawn = UGCGameSystem.GetPlayerPawnByPlayerController(PC)
    if Pawn then
        return UGCAttributeSystem.GetGameAttributeValue(Pawn, "UGCGeneralMoveSpeedScale") or 0
    end
    return 0
end

function BPWidget_CurSpeed:RefreshSpeed()
    local PlayerState = UGCGameSystem.GetLocalPlayerState()
    local Value = self:GetDisplaySpeed()
    self.TextBlock_CurSpeed:SetText(tostring(PlayerState.PlayerCurSpeed))
    self.TextBlock_CurSpeedScale:SetText(string.format("%.4f", Value))
end

function BPWidget_CurSpeed:BindSpeedDelegate()
    local PlayerController = UGCGameSystem.GetLocalPlayerController()
    local PlayerPawn = PlayerController and UGCGameSystem.GetPlayerPawnByPlayerController(PlayerController)
    if PlayerPawn then
        UGCAttributeSystem.AddGameAttributeChangedDelegate(PlayerPawn, "UGCGeneralMoveSpeedScale", function()
            self:RefreshSpeed()
        end)
    else
        -- Construct时Pawn可能还没生成，延迟重试（最多10次）
        if self.BindRetryCount < 10 then
            self.BindRetryCount = self.BindRetryCount + 1
            UGCTimerUtility.CreateLuaTimer(1, function()
                self:BindSpeedDelegate()
            end, false)
        end
    end
end

function BPWidget_CurSpeed:RefreshSpeedOnRunningMachine()
    local PlayerState = UGCGameSystem.GetLocalPlayerState()
    if PlayerState == nil then
        return
    end
    self.TextBlock_CurSpeedScale:SetText(string.format("%.3f", PlayerState.PlayerCurSpeed))
end

function BPWidget_CurSpeed:StartPlayFloatTextAndShakeAnimation(AddInterval, AddSpeed)
    local PlayerController = UGCGameSystem.GetLocalPlayerController()
    local PlayerState = UGCGameSystem.GetLocalPlayerState()
    self.FloatTextTimer = UGCTimerUtility.CreateLuaTimer(AddInterval, function()
        PlayerController.YXFloatTextComponent:ShowFloatText(string.format(" +%s 速度", AddSpeed))
        self:PlayAnimation(self.NewAnimation_1, 0, 1, EUMGSequencePlayMode.Forward, 1)
        self.TextBlock_CurSpeed:SetText(tostring(PlayerState.PlayerCurSpeed))
    end, true)
end

function BPWidget_CurSpeed:StopPlayFloatText()
    if self.FloatTextTimer then
        UGCTimerUtility.RemoveLuaTimer(self.FloatTextTimer)
        self.FloatTextTimer = nil
    end
end

return BPWidget_CurSpeed