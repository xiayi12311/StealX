---@class YXFloatTextComponent_C:ActorComponent
--Edit Below--
local YXFloatTextComponent = {}

-- 飘字 Widget 资源路径
local WidgetClassPath = 'Asset/UI/BPWidget_FloatText.BPWidget_FloatText_C'

-- 锚点高度（相对角色脚部，cm）：
--   角色脚部
--      │  HeadHeight(100)
--      ▼
--   角色头部
--      │  AboveHeadOffset
--      ▼
--   飘字锚点（约头部位置）
local HeadHeight = 50
local AboveHeadOffset = 0

-- 多条飘字同屏时的横向错开间距（屏幕像素）
local OverlapSpacing = 60
-- 同屏最大飘字数量（超出时强制结束最早的一条）
local MaxVisibleCount = 6
-- 横向错开槽位偏移序列（乘 OverlapSpacing），长度需 >= MaxVisibleCount
local SlotOffsetRanks = { 0, 1, -1, 2, -2, 3 }

function YXFloatTextComponent:ReceiveBeginPlay()
    YXFloatTextComponent.SuperClass.ReceiveBeginPlay(self)
    -- 注意：实例级数据必须在这里初始化，不能放在类定义处（否则多个实例共享同一份数据会互相污染）
    self.ActiveFloatTexts = {}  -- 当前存活的飘字 Widget 列表
    self.WidgetSlots = {}       -- Widget -> 横向错开槽位序号
    local Owner = self:GetOwner()
    if Owner then
        Owner.YXFloatTextComponent = self
    end
end

function YXFloatTextComponent:ReceiveEndPlay()
    if self.ActiveFloatTexts then
        for _, Widget in pairs(self.ActiveFloatTexts) do
            self:DestroyFloatTextWidget(Widget)
        end
        self.ActiveFloatTexts = {}
        self.WidgetSlots = {}
    end
    YXFloatTextComponent.SuperClass.ReceiveEndPlay(self)
end

-- 在拥有该组件的角色头顶弹出一条飘字（纯客户端 UI，DS 上自动跳过）
-- 用法示例：PC.YXFloatTextComponent:ShowFloatText("+0.05 速度")
function YXFloatTextComponent:ShowFloatText(InText)
    -- 没有本地玩家（DS 服务器）时不创建
    if UGCGameSystem.GetLocalPlayerController() == nil then
        return
    end
    if not self.ActiveFloatTexts then
        self.ActiveFloatTexts = {}
        self.WidgetSlots = {}
    end

    -- 同屏数量超限时，强制结束最早的一条
    while #self.ActiveFloatTexts >= MaxVisibleCount do
        self:FinishFloatText(self.ActiveFloatTexts[1])
    end

    -- 组件挂在 PlayerController 上时锚点取其 Pawn，直接挂在角色上时取自身
    local AnchorActor = self:GetAnchorActor()
    if AnchorActor == nil then
        return
    end

    local HeightOffset = HeadHeight + AboveHeadOffset

    UGCWidgetUtility.CreateWidgetAsync(
        UGCGameSystem.GetUGCResourcesFullPath(WidgetClassPath),
        function (Widget)
            if Widget == nil then return end
            -- 创建期间组件已结束（对局结束等）：直接丢弃
            if self.ActiveFloatTexts == nil or self:GetOwner() == nil then
                UGCWidgetUtility.DestroyWidget(Widget)
                return
            end
            Widget:AddToViewport(1000)
            -- 槽位在回调里分配，同帧连发也能拿到不同槽位
            local SlotIndex = self:GetFreeSlotIndex()
            local OverlapOffsetX = SlotOffsetRanks[SlotIndex] * OverlapSpacing
            Widget:InitFloatText(AnchorActor, HeightOffset, OverlapOffsetX, InText,
                function (InWidget) self:FinishFloatText(InWidget) end)
            table.insert(self.ActiveFloatTexts, Widget)
            self.WidgetSlots[Widget] = SlotIndex
        end)
end

-- 获取锚点 Actor：Owner 是 PlayerController 时返回其 Pawn，否则返回 Owner 本身
function YXFloatTextComponent:GetAnchorActor()
    local Owner = self:GetOwner()
    if Owner == nil then
        return nil
    end
    local Pawn = UGCGameSystem.GetPlayerPawnByPlayerController(Owner)
    return Pawn or Owner
end

-- 找一个未被占用的横向错开槽位（1 ~ MaxVisibleCount）
function YXFloatTextComponent:GetFreeSlotIndex()
    if self.WidgetSlots == nil then
        return 1
    end
    local UsedSlots = {}
    for _, SlotIndex in pairs(self.WidgetSlots) do
        UsedSlots[SlotIndex] = true
    end
    for SlotIndex = 1, MaxVisibleCount do
        if not UsedSlots[SlotIndex] then
            return SlotIndex
        end
    end
    return 1  -- 理论上不会走到这里（同屏数量有上限）
end

-- 飘字播放结束（Widget 回调）或被超限淘汰时调用，回收 Widget 并释放槽位
function YXFloatTextComponent:FinishFloatText(Widget)
    if Widget == nil or self.ActiveFloatTexts == nil then
        return
    end
    for Index, ActiveWidget in ipairs(self.ActiveFloatTexts) do
        if ActiveWidget == Widget then
            table.remove(self.ActiveFloatTexts, Index)
            break
        end
    end
    self.WidgetSlots[Widget] = nil
    self:DestroyFloatTextWidget(Widget)
end

function YXFloatTextComponent:DestroyFloatTextWidget(Widget)
    if Widget == nil then
        return
    end
    Widget:StopFloat()
    if Widget:IsInViewport() then
        Widget:RemoveFromViewport()
    end
    UGCWidgetUtility.DestroyWidget(Widget)
end

return YXFloatTextComponent
