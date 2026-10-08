---@class YX_GMUI_C:UUserWidget
---@field Btn_AddAttribute UButton
---@field Btn_SetAttribute UButton
---@field Button_Function UButton
---@field Button_GiveItem UButton
---@field Button_GM UButton
---@field CanvasPanel_GM UCanvasPanel
---@field CB_Attribute UComboBoxString
---@field EditableTextBox_Function UEditableTextBox
---@field EditableTextBox_ItemID UEditableTextBox
---@field TB_Attribute UEditableTextBox
---@field TextBlock_37 UTextBlock
---@field TextBlock_Linked UTextBlock
--Edit Below--
local YX_GMUI = { bInitDoOnce = false } 

YX_GMUI.bHint = true

function YX_GMUI:Construct()
	self:LuaInit();
    ugcprint("YX_GMUI:Construct") 
	local GameState = UGCGameSystem.GetGameState()
    self.Button_GM.OnClicked:Add(function()
        if self.CanvasPanel_GM:GetVisibility() == ESlateVisibility.SelfHitTestInvisible then
            self.CanvasPanel_GM:SetVisibility(ESlateVisibility.Collapsed)
        else
            self.CanvasPanel_GM:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            local PlayerController = UGCGameSystem.GetLocalPlayerController()
            self.EditableTextBox_Function:SetUserFocus(PlayerController)
        end
    end, self);

    self.Button_GiveItem.OnClicked:Add(function()
        local PlayerController = UGCGameSystem.GetLocalPlayerController()
        local ItemID, NumStr = string.match(self.EditableTextBox_ItemID.Text, "^%s*(%d+)%s*(%d*)")
        ItemID = tonumber(ItemID)
        local Num = NumStr == "" and 1 or tonumber(NumStr)
        if ItemID and Num and Num > 0 and math.floor(Num) == Num then
            PlayerController:RPC_Server_GMGiveItem(ItemID, Num)
        end
    end, self);
    
    self.Button_Function.OnClicked:Add(function()
        local tCode = self.EditableTextBox_Function.Text
        self:ParseCommand(tCode)
    end, self);
    self.EditableTextBox_Function.OnTextChanged:Add(self.OnGMFunctionTextChanged, self);
    self.EditableTextBox_Function.OnTextCommitted:Add(function(self,Text,CommitMethod)
        local PlayerController = UGCGameSystem.GetLocalPlayerController()
        if CommitMethod == ETextCommit.OnEnter then
            if self.TextBlock_Linked:GetText() == "" then
                self:ParseCommand(Text)
                if not self.bHint then
                    local tText = string.lower(Text)
                    if tText == "openhint" then
                        self.bHint = true
                    end
                end  
                self.EditableTextBox_Function:SetText("")              
            else
                self.EditableTextBox_Function:SetText(self.TextBlock_Linked:GetText())
            end
        end        
    end, self);
end

function YX_GMUI:Tick(MyGeometry, InDeltaTime)
    

end

-- function YX_GMUI:Destruct()

-- end

-- 解析字符串调用GM功能
function YX_GMUI:ParseCommand(tCode)   
    local PlayerController = UGCGameSystem.GetLocalPlayerController()
    PlayerController:ParseCommand(tCode)     
end

YX_GMUI.GMFunctionName = {}
function YX_GMUI:AddGMFunctionName(FunctionName)
    table.insert(self.GMFunctionName, FunctionName)
end

--输入字符时
function YX_GMUI:OnGMFunctionTextChanged(InText)
    -- 如果输入为空，清除提示文本
    if InText == "" then
        self.EditableTextBox_Function:SetHintText("")
        return
    end
    
    -- 将输入转换为小写进行匹配
    local lowerInput = string.lower(InText)
    local matchedCommands = {}
    
    -- 在GMFunctionName数组中查找匹配的命令
    for _, funcName in ipairs(self.GMFunctionName) do
        local lowerFuncName = string.lower(funcName)
        
        -- 使用字符串查找进行匹配
        if string.find(lowerFuncName, lowerInput, 1, true) then
            table.insert(matchedCommands, funcName)
        end
    end
    
    -- 根据匹配结果设置提示文本
    if #matchedCommands > 0 then
        -- 如果有多个匹配项，显示所有匹配的命令
        local hintText = "匹配命令: "
        hintText = matchedCommands[1]
        if self.bHint then
            self.TextBlock_Linked:SetText(hintText)
        end
        -- 
        
    else
        -- 如果没有匹配项，显示默认提示
        self.TextBlock_Linked:SetText("")
    end
end

-- [Editor Generated Lua] function define Begin:
function YX_GMUI:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
	self.Btn_AddAttribute.OnClicked:Add(self.OnBtnAddAttributeClicked, self);
	--self.Button_8.OnClicked:Add(self.Button_8_OnClicked, self);
	self.Btn_SetAttribute.OnClicked:Add(self.OnBtnSetAttributeClicked, self);
	-- [Editor Generated Lua] BindingEvent End;
end

function YX_GMUI:OnBtnAddAttributeClicked()
    ugcprint("[YX_GMUI] OnBtnAddAttributeClicked")
    local PlayerController = UGCGameSystem.GetLocalPlayerController()
    local AttributeString = self.CB_Attribute:GetSelectedOption()
    -- 选项是显示名，如 "UGC移动速度倍率（UGCGeneralMoveSpeedScale）"，需取括号内的属性名
    local AttributeName = string.match(AttributeString, "（([%w|]+)）") or string.match(AttributeString, "%(([%w|]+)%)") or ""
    local Value = tonumber(self.TB_Attribute.Text)
    if AttributeName == "" or Value == nil then
        ugcprint("[YX_GMUI] 无效的属性名或数值: " .. AttributeString .. " / " .. tostring(self.TB_Attribute.Text))
        return
    end
    PlayerController:GM_Function("AddGameAttributeValue", { AttributeName, Value })
end

function YX_GMUI:OnBtnSetAttributeClicked()
	ugcprint("[YX_GMUI] OnBtnSetAttributeClicked")
	local PlayerController = UGCGameSystem.GetLocalPlayerController()
	local AttributeString = self.CB_Attribute:GetSelectedOption()
	-- 选项是显示名，如 "UGC移动速度倍率（UGCGeneralMoveSpeedScale）"，需取括号内的属性名
	local AttributeName = string.match(AttributeString, "（([%w|]+)）") or string.match(AttributeString, "%(([%w|]+)%)") or ""
	local Value = tonumber(self.TB_Attribute.Text)
	if AttributeName == "" or Value == nil then
		ugcprint("[YX_GMUI] 无效的属性名或数值: " .. AttributeString .. " / " .. tostring(self.TB_Attribute.Text))
		return
	end
	PlayerController:GM_Function("SetGameAttributeValue", { AttributeName, Value })
end

-- [Editor Generated Lua] function define End;

return YX_GMUI