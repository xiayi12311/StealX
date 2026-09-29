---@class UGCPlayerController_C:BP_UGCPlayerController_C
---@field YXRunningMachineComponent YXRunningMachineComponent_C
--Edit Below--
local UGCPlayerController = {}
 
function UGCPlayerController:ReceiveBeginPlay()
    UGCPlayerController.SuperClass.ReceiveBeginPlay(self)
    UGCTimerUtility.CreateLuaTimer(3,
        function ()
        if UGCGameSystem.IsEnableGM(self) then
            -- 注册GM指令
            self:RegisterDefaultGMCommands()
        end
    end, false)
end

function UGCPlayerController:ReceiveTick(DeltaTime)
    UGCPlayerController.SuperClass.ReceiveTick(self, DeltaTime)
end

function UGCPlayerController:ReceiveEndPlay()
    UGCPlayerController.SuperClass.ReceiveEndPlay(self) 
end

function UGCPlayerController:GetReplicatedProperties()
    return
end

function UGCPlayerController:GetAvailableServerRPCs()
    return 

    "GM_Function"
end

local GMCommandTable = {}
function UGCPlayerController:GM_Function(InFunctionName,InData)
    ugcprint("UGCPlayerController:GM_Function " .. InFunctionName .. " " ..tostring(InData))
    -- 将命令名转换为小写
    local lowerCommand = string.lower(InFunctionName)
    
    -- 查找命令表中对应的处理函数
    local commandFunc = GMCommandTable[lowerCommand]
    if commandFunc then
        -- 调用对应的处理函数
        commandFunc(self, InData)
    else
        -- 如果找不到对应的命令，输出错误信息
        ugcprint("UGCPlayerController:GM_Function Unknown command: "..InFunctionName)
    end
end

--解释器
function UGCPlayerController:ParseCommand(Instring)
    local parts = {}
    for part in string.gmatch(Instring, "%S+") do
        table.insert(parts, part)
    end
    
    local command = ""
    local param = {}
    
    if #parts > 0 then
        -- 第一个部分作为命令，转换为小写
        command = string.lower(parts[1])
        
        -- 剩余部分作为参数，用逗号连接
        if #parts > 1 then
            for i = 2, #parts do
                -- 自动类型转换函数
                local function autoConvertType(value)
                    -- 检查是否为数字
                    if tonumber(value) then
                        return tonumber(value)
                    -- 检查是否为布尔值 true
                    elseif value:lower() == "true" then
                        return true
                    -- 检查是否为布尔值 false
                    elseif value:lower() == "false" then
                        return false
                    -- 检查是否为nil
                    elseif value:lower() == "nil" then
                        return nil
                    -- 默认返回字符串
                    else
                        return value
                    end
                end
                
                -- 对每个参数进行自动类型转换
                local convertedValue = autoConvertType(parts[i])
                table.insert(param, convertedValue)
            end
        end
    end
    
    self:GM_Function(command,param)
end

-- 增强版注册函数：支持自定义命令名
function UGCPlayerController:RegisterGMCommandEx(CommandName, Function)
    if type(CommandName) == "function" then
        local functionName = ""
        local funcInfo = debug.getinfo(CommandName, "n")
        if funcInfo and funcInfo.name then
            functionName = funcInfo.name
        else
            local callerInfo = debug.getinfo(2, "n")
            if callerInfo and callerInfo.name then
                functionName = callerInfo.name
            else
                functionName = "UnknownFunction"
            end
        end        
        -- 将函数名转换为小写
        local lowerFunctionName = string.lower(functionName)        
        -- 存储到GM命令表
        GMCommandTable[lowerFunctionName] = CommandName        
        ugcprint("UGCPlayerController:RegisterGMCommand - 函数 "..functionName.." 已注册为GM命令: "..lowerFunctionName)
        return
    end
    
    -- 将命令名转换为小写
    local lowerCommandName = string.lower(CommandName)
    
    -- 存储到GM命令表
    GMCommandTable[lowerCommandName] = Function

    if not self:HasAuthority() then
        if self.YXWidgetMangerComponent then
            local w = self.YXWidgetMangerComponent:GetWidgetWithName("GM_MainUI")
            if w and w.AddGMFunctionName then
                w:AddGMFunctionName(CommandName)
            end
        end
    end
    ugcprint("UGCPlayerController:RegisterGMCommandEx - 命令 "..CommandName.." 已注册为GM命令: "..lowerCommandName)
end

-- 示例：注册现有的GM函数
function UGCPlayerController:RegisterDefaultGMCommands()
    local function ShowFunction(InData)        
        local t1 = nil
        local t2 = nil
        if InData[1] == "GameMode" then
            t1 = UGCGameSystem.GetGameMode()
        elseif InData[1] == "GameState" then
            t1 = UGCGameSystem.GetGameState()
        elseif InData[1] == "PlayerController" then
            t1 = self
        elseif InData[1] == "PlayerState" then
            t1 = UGCGameSystem.GetPlayerStateByPlayerController(self)
        elseif InData[1] == "PlayerPawn" then
            t1 = UGCGameSystem.GetPlayerPawnByPlayerController(self)
        end

        t2 = t1[InData[2]]
        return UGCLog.Print(t2)
    end
    -- 注册GM_Function中定义的所有命令处理逻辑
    local defaultCommands = {
        ["SetGameAttributeValue"] = function(self, InData)
            if self:HasAuthority() then
                local PlayerPawn = UGCGameSystem.GetPlayerPawnByPlayerController(self)
                UGCAttributeSystem.SetGameAttributeValue(PlayerPawn, InData[1], InData[2])
            else
                UnrealNetwork.CallUnrealRPC(self, self, "GM_Function", "SetGameAttributeValue",InData)
            end
        end,
        ["AddGameAttributeValue"] = function(self, InData)
            if self:HasAuthority() then
                local PlayerPawn = UGCGameSystem.GetPlayerPawnByPlayerController(self)
                UGCAttributeSystem.AddGameAttributeValue(PlayerPawn, InData[1], InData[2])
            else
                UnrealNetwork.CallUnrealRPC(self, self, "GM_Function", "AddGameAttributeValue", InData)
            end
        end,
    }


    for commandName, func in pairs(defaultCommands) do
        self:RegisterGMCommandEx(commandName, func)
    end

end


return UGCPlayerController