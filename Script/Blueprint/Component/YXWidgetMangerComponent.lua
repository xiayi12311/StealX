---@class YXWidgetMangerComponent_C:ActorComponent
--Edit Below--
local YXWidgetMangerComponent = {}
 

YXWidgetMangerComponent.WidgetTable = {}
function YXWidgetMangerComponent:ReceiveBeginPlay()
    YXWidgetMangerComponent.SuperClass.ReceiveBeginPlay(self)
    if self:GetOwner():HasAuthority() == false then
        self.WidgetTable = 
        {
            
        }
        
    end
end

-- function YXWidgetMangerComponent:ReceiveTick(DeltaTime)
--     YXWidgetMangerComponent.SuperClass.ReceiveTick(self, DeltaTime)
-- end

function YXWidgetMangerComponent:ReceiveEndPlay()
    YXWidgetMangerComponent.SuperClass.ReceiveEndPlay(self) 
end

function YXWidgetMangerComponent:GetWidgetWithName(UIName, bCreateWhenNotFound)
    ugcprint("[YXWidgetMangerComponent:GetWidgetWithName] "..tostring(UIName).." "..tostring(bCreateWhenNotFound))
    bCreateWhenNotFound = bCreateWhenNotFound == nil and true or bCreateWhenNotFound
    if self.WidgetTable[UIName] == nil then
        return
    else
        if self.WidgetTable[UIName].Widget == nil and bCreateWhenNotFound then
            local UIClass = UE.LoadClass( self.WidgetTable[UIName].Path)
            if UIClass then
                local Widget = UserWidget.NewWidgetObjectBP(self:GetOwner(), UIClass)
                if Widget ~= nil then
                    Widget:AddToViewport(self.WidgetTable[UIName].ZOrder);
                    Widget:SetVisibility(ESlateVisibility.Collapsed);
                    self.WidgetTable[UIName].Widget = Widget;  

                    local PlayerState = UGCGameSystem.GetLocalPlayerState()
                    PlayerState.YXWidgetInitCompletedDelegate:Broadcast(UIName)
                end
            else
                ugcprint("[YXWidgetMangerComponent:GetWidgetWithName] UIClass is nil. Path:"..tostring(self.WidgetTable[UIName].Path))
            end
        end
    end
    return self.WidgetTable[UIName].Widget;
end

function YXWidgetMangerComponent:ShowUIByName(UIName, bCreateWhenNotFound)
    if self.WidgetTable == nil then return end
    bCreateWhenNotFound = bCreateWhenNotFound == nil and true or bCreateWhenNotFound
    local Widget = self:GetWidgetWithName(UIName, bCreateWhenNotFound)
    if Widget ~= nil then
        print("YXWidgetMangerComponent ShowUI ".. UIName)
        Widget:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        if Widget.OnOpen then
            Widget:OnOpen()
        end
    end
end

function YXWidgetMangerComponent:HiddenUIByName(UIName, bCreateWhenNotFound)
    if self.WidgetTable == nil then return end
    bCreateWhenNotFound = bCreateWhenNotFound == nil and true or bCreateWhenNotFound
    local Widget = self:GetWidgetWithName(UIName, bCreateWhenNotFound)
    if Widget ~= nil then
        print("YXWidgetMangerComponent HiddenUI ".. UIName)
        Widget:SetVisibility(ESlateVisibility.Collapsed);
        if Widget.OnClose then
            Widget:OnClose()
        end
    end
end

-- 弹出Tips服务器端
function YXWidgetMangerComponent:ShowTipsUI_Server(InString)
    self:GetOwner():RPC_Client_ShowTipsUI(InString)
end

function YXWidgetMangerComponent:CheerTipsUI_Server(InString)
    self:GetOwner():RPC_Client_CheerTipsUI(InString)
end

-- 弹出Tips
function YXWidgetMangerComponent:ShowTipsUI(InString)
    self:GetWidgetWithName("PopupTips"):ShowTipsUI(InString)
end

function YXWidgetMangerComponent:ShowTipsUI_Success(InString)
    self:GetWidgetWithName("PopupTips"):ShowTipsUI_Success(InString)
end

function YXWidgetMangerComponent:CheerTipsUI(InString)
    self:GetWidgetWithName("CheerTips"):ShowTipsUI(InString)
end


return YXWidgetMangerComponent