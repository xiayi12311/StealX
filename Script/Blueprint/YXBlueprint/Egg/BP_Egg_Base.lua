---@class BP_Egg_Base_C:AActor
---@field StaticMesh UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field EggTypeID int32
--Edit Below--
-- 宠物蛋 Actor：蛋的状态机、随机体重与孵化逻辑（仅服务端推进），状态通过属性同步给客户端。
-- 蛋的外观大小暂不随体重缩放，保持蓝图默认大小（后续需要时再接缩放表现）。
--
-- 蛋状态流转（安全区/绑定暂未实现）：
--   Free(0)       在地上，任何玩家可拾取
--   Held(1)       被玩家持有，可随地放下回到 Free
--   Incubating(2) 已放下并开始孵化（当前由 GM 指令触发），放下后不可取回
local BP_Egg_Base = {}

-- 蛋状态常量
BP_Egg_Base.STATE_FREE = 0
BP_Egg_Base.STATE_HELD = 1
BP_Egg_Base.STATE_INCUBATING = 2

-- 蛋表 / 稀有度表路径
BP_Egg_Base.EggTablePath = 'Asset/Data/Table/YX_EggTable.YX_EggTable'
BP_Egg_Base.RarityTablePath = 'Asset/Data/Table/YX_EggRarityTable.YX_EggRarityTable'

-- 体重归一化基准：孵化时间 = 稀有度基础时间 × (体重 / 该基准)
-- 必须与蛋表 Weight 的量纲一致（当前蛋表体重为百位，如 90/100）；表里填 100 的蛋孵化时间就等于稀有度配置的基础时间
BP_Egg_Base.WeightBase = 100

-- 体重随机：在「表内基准体重」上乘以一个全局浮动系数，系数取 [MinScale, MaxScale]
-- 分布偏小（大蛋稀有）：系数 = MinScale + (MaxScale - MinScale) * RandomFloat()^BiasExp，BiasExp > 1 时结果偏向 MinScale
-- 当前 MinScale = MaxScale = 1，即体重等于基准值（随机暂时关闭）
BP_Egg_Base.RandMinScale = 1.0
BP_Egg_Base.RandMaxScale = 1.0
BP_Egg_Base.RandBiasExp = 2.0

-- 携带（拾取）时蛋相对角色原点的 Z 偏移。
-- 角色 Actor 原点在胶囊体中心，原点上方约 130 为“头顶”高度
BP_Egg_Base.CarryOffsetZ = 100

-- 放下时蛋相对“角色脚下地面”的额外抬高：0 = 蛋原点贴地；
-- 若蛋模型的网格原点不在底部（放地上会陷进地面或仍略悬空），微调此值即可
BP_Egg_Base.DropGroundOffsetZ = 0

-- 复制属性（服务端与客户端都需要初始值）
BP_Egg_Base.EggState = BP_Egg_Base.STATE_FREE
-- 孵化总时长（秒）：服务器开始孵化时写入，客户端据此本地倒计时并打印到屏幕
BP_Egg_Base.IncubateTime = 0

-- 随机体重（仅服务端使用：决定孵化时间与宠物体型，暂不用于蛋外观缩放）
BP_Egg_Base.Weight = 1

-- 持有该蛋的玩家 Key（0 = 无人持有）；同步给客户端，用于判断“我是否已持有蛋”
BP_Egg_Base.HolderKey = 0

-- 客户端本地倒计时（秒），仅客户端倒计时显示用，不参与同步
BP_Egg_Base.ClientIncubateRemain = nil

function BP_Egg_Base:ReceiveBeginPlay()
    BP_Egg_Base.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        self.Config = nil
        self:LoadConfig()
        self:SetState(self.STATE_FREE)
    end
end

function BP_Egg_Base:ReceiveTick(DeltaTime)
    BP_Egg_Base.SuperClass.ReceiveTick(self, DeltaTime)
    self:TickIncubateScreen(DeltaTime)
end

function BP_Egg_Base:ReceiveEndPlay()
    BP_Egg_Base.SuperClass.ReceiveEndPlay(self)
end

function BP_Egg_Base:GetReplicatedProperties()
    return "EggState", "IncubateTime", "HolderKey"
end

function BP_Egg_Base:GetAvailableServerRPCs()
    return
end

-- ⭐ 表数据 ⭐
-- 按蛋 Actor 上配置的 EggTypeID 读取蛋表配置行
function BP_Egg_Base:LoadConfig()
    local TableData = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(self.EggTablePath))
    if TableData == nil then
        ugcprint("[BP_Egg_Base] 加载蛋表失败: " .. self.EggTablePath)
        return
    end
    for _, Row in pairs(TableData) do
        if tonumber(Row.ID) == tonumber(self.EggTypeID) then
            self.Config = Row
            break
        end
    end
    if self.Config == nil then
        ugcprint("[BP_Egg_Base] 蛋表中未找到 EggTypeID=" .. tostring(self.EggTypeID))
        return
    end
    -- 体重随机：以表内 Weight 为基准体重，乘一个全局浮动系数
    local BaseWeight = tonumber(self.Config.Weight) or 1
    if BaseWeight <= 0 then
        BaseWeight = 1
    end
    self.Weight = self:RollWeight(BaseWeight)
end

-- 在基准体重上随机一个浮动系数：系数 = MinScale + (MaxScale - MinScale) * RandomFloat()^BiasExp
-- BiasExp > 1 时结果偏向 MinScale，即偏小、大蛋稀有
function BP_Egg_Base:RollWeight(BaseWeight)
    local MinScale = tonumber(self.RandMinScale) or 1
    local MaxScale = tonumber(self.RandMaxScale) or 1
    if MaxScale < MinScale then
        MaxScale = MinScale
    end
    local BiasExp = tonumber(self.RandBiasExp) or 1
    if BiasExp < 1 then
        BiasExp = 1
    end
    local T = UGCMathUtility.RandomFloat() ^ BiasExp
    local Factor = MinScale + (MaxScale - MinScale) * T
    return BaseWeight * Factor
end

-- 取该蛋所属稀有度配置行
function BP_Egg_Base:GetRarityRow()
    if self.Config == nil then
        return nil
    end
    local RarityTable = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(self.RarityTablePath))
    if RarityTable == nil then
        return nil
    end
    for _, Row in pairs(RarityTable) do
        if tostring(Row.Rarity) == tostring(self.Config.Rarity) then
            return Row
        end
    end
    return nil
end

-- ⭐ 状态 ⭐
function BP_Egg_Base:SetState(NewState)
    if not UGCGameSystem.IsServer() then
        return
    end
    self.EggState = NewState
    ugcprint("[BP_Egg_Base] EggTypeID=" .. tostring(self.EggTypeID) .. " 状态切换为 " .. tostring(NewState))
end

function BP_Egg_Base:IsFree()
    return self.EggState == self.STATE_FREE
end

function BP_Egg_Base:IsHeld()
    return self.EggState == self.STATE_HELD
end

function BP_Egg_Base:IsIncubating()
    return self.EggState == self.STATE_INCUBATING
end

-- ⭐ 属性同步回调 ⭐
function BP_Egg_Base:OnRep_EggState()
    ugcprint("[BP_Egg_Base] OnRep_EggState " .. tostring(self.EggState))
end

-- 孵化总时长同步到客户端：作为客户端本地倒计时的起点
function BP_Egg_Base:OnRep_IncubateTime()
    self.ClientIncubateRemain = tonumber(self.IncubateTime) or 0
end

-- 持有者变更（客户端用于抑制描边，无需额外表现）
function BP_Egg_Base:OnRep_HolderKey()
end

-- 是否被指定玩家持有
function BP_Egg_Base:IsHeldByKey(PlayerKey)
    local Holder = tonumber(self.HolderKey) or 0
    return Holder ~= 0 and Holder == tonumber(PlayerKey)
end

-- ⭐ 孵化剩余时间显示（仅客户端；UGCDebugSystem.PrintToScreen 只在客户端生效）⭐
-- 每帧打印一条（默认 Duration=0 只保持一帧），屏幕左上角始终显示当前剩余时间
function BP_Egg_Base:TickIncubateScreen(DeltaTime)
    if UGCGameSystem.IsServer() then
        return
    end
    if self.EggState ~= self.STATE_INCUBATING then
        self.ClientIncubateRemain = nil
        return
    end
    if self.ClientIncubateRemain == nil then
        -- 孵化总时长可能晚于状态同步过来，还没有就先不显示
        local Total = tonumber(self.IncubateTime) or 0
        if Total <= 0 then
            return
        end
        self.ClientIncubateRemain = Total
    end
    self.ClientIncubateRemain = self.ClientIncubateRemain - (tonumber(DeltaTime) or 0)
    if self.ClientIncubateRemain < 0 then
        self.ClientIncubateRemain = 0
    end
    UGCDebugSystem.PrintToScreen(string.format("孵蛋剩余时间：%.1f 秒", self.ClientIncubateRemain))
end

-- ⭐ 拾取 / 放下（仅服务端） ⭐
-- 被玩家拾取：蛋附着到玩家身上（头顶携带），进入 Held 状态
function BP_Egg_Base:PickUpByPawn(Pawn)
    if not UGCGameSystem.IsServer() then
        return false
    end
    if Pawn == nil or not self:IsFree() then
        return false
    end
    -- 附着到玩家，并把蛋摆到头顶位置
    UGCActorComponentUtility.AttachToActor(self, Pawn, 0, 0, 0, "")
    local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
    if PawnLoc then
        UGCActorComponentUtility.SetActorLocation(self, Vector.New(PawnLoc.X, PawnLoc.Y, PawnLoc.Z + (tonumber(self.CarryOffsetZ) or 100)))
    end
    self.HolderKey = tonumber(UGCGameSystem.GetPlayerKeyByPlayerPawn(Pawn)) or 0
    self:SetState(self.STATE_HELD)
    return true
end

-- 放下蛋：脱离携带并贴到角色脚下的地面，回到 Free 状态（当前没有绑定规则，任何位置都可放下）
function BP_Egg_Base:DropByPawn(Pawn)
    if not UGCGameSystem.IsServer() then
        return
    end
    local Root = UGCActorComponentUtility.GetRootComponent(self)
    if Root then
        UGCActorComponentUtility.DetachFromParent(Root, true, false)
    end
    if Pawn then
        local PawnLoc = UGCActorComponentUtility.GetActorLocation(Pawn)
        if PawnLoc then
            -- 角色原点在胶囊体中心，减去站立半高得到脚下地面高度
            local HalfHeight = UGCPawnAttrSystem.GetStandHalfHeight(Pawn) or 88
            local GroundZ = PawnLoc.Z - HalfHeight + (tonumber(self.DropGroundOffsetZ) or 0)
            UGCActorComponentUtility.SetActorLocation(self, Vector.New(PawnLoc.X, PawnLoc.Y, GroundZ))
        end
    end
    self.HolderKey = 0
    self:SetState(self.STATE_FREE)
end

-- ⭐ 孵化（仅服务端） ⭐
-- 当前由 GM 指令触发；后续接入安全区后改为「在自家基地内放下时触发」
function BP_Egg_Base:StartIncubate()
    if not UGCGameSystem.IsServer() then
        return
    end
    if self:IsIncubating() then
        return
    end
    self:SetState(self.STATE_INCUBATING)
    local IncubateTime = self:CalcIncubateTime()
    self.IncubateTime = IncubateTime   -- 同步给客户端做倒计时显示
    ugcprint("[BP_Egg_Base] 开始孵化，孵化时间=" .. tostring(IncubateTime) .. " 秒")
    UGCTimerUtility.CreateLuaTimer(IncubateTime, function()
        self:FinishIncubate()
    end, false)
end

-- 孵化时间 = 稀有度基础时间 × (随机体重 / 体重基准)
function BP_Egg_Base:CalcIncubateTime()
    local Weight = tonumber(self.Weight) or 1
    local RarityRow = self:GetRarityRow()
    local BaseTime = tonumber(RarityRow and RarityRow.BaseIncubateTime) or 10
    return BaseTime * (Weight / (tonumber(self.WeightBase) or 1))
end

-- 宠物体型 = 随机体重 × 稀有度体型系数
function BP_Egg_Base:CalcPetScale()
    local Weight = tonumber(self.Weight) or 1
    local RarityRow = self:GetRarityRow()
    local Coef = tonumber(RarityRow and RarityRow.PetSizeCoef) or 1
    return Weight * Coef
end

function BP_Egg_Base:FinishIncubate()
    if not UGCGameSystem.IsServer() then
        return
    end
    self:SpawnPet()
    UGCActorComponentUtility.DestroyActor(self)
end

-- 生成宠物（占位 BP，路径由蛋表 PetClassPath 指定，后补造型时改表即可）
function BP_Egg_Base:SpawnPet()
    -- local PetClassPath = self.Config and self.Config.PetClassPath
    -- local PetClassPath = UGCGameSystem.GetUGCResourcesFullPath('Asset/Blueprint/YXBlueprint/Pet/BP_Pet_Base.BP_Pet_Base_C')
    -- if PetClassPath == nil or PetClassPath == "" then
    --     ugcprint("[BP_Egg_Base] 蛋表未配置 PetClassPath，跳过生成宠物")
    --     return
    -- end
    local PetClass = self.Config.PetClass
    if PetClass == nil then
        ugcprint("[BP_Egg_Base] 加载宠物类失败: " .. tostring(PetClass))
        return
    end
    local Loc = UGCActorComponentUtility.GetActorLocation(self)
    local Scale = self:CalcPetScale()
    local Pet = UGCActorComponentUtility.SpawnActor(
        UGCGameSystem.GetGameState(), PetClass, Loc, Rotator.New(0, 0, 0), Vector.New(Scale, Scale, Scale), nil)
    ugcprint("[BP_Egg_Base] 孵化完成，生成宠物 Scale=" .. tostring(Scale) .. " Pet=" .. tostring(Pet))
end

return BP_Egg_Base