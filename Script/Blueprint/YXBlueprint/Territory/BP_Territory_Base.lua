---@class BP_Territory_Base_C:AActor
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
--Edit Below--
-- 领地 Actor（场景中预摆放）：代表一块可被某个玩家认领的领地。
-- 归属（OwnerKey：0 = 未认领，其余为玩家 Key）通过属性同步给客户端；
-- 客户端据此找到「自己的领地」，服务端据此判断能否孵化。
-- 范围：完全由蓝图上的碰撞盒子 Box 的大小/位置/旋转决定，可直接在地图中摆放调整（Z 高度同样生效）。
local BP_Territory_Base = {}

-- 归属玩家 Key（复制属性；0 = 未认领）
BP_Territory_Base.OwnerKey = 0

function BP_Territory_Base:ReceiveBeginPlay()
    BP_Territory_Base.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        self.OwnerKey = 0
    end
end

function BP_Territory_Base:ReceiveEndPlay()
    BP_Territory_Base.SuperClass.ReceiveEndPlay(self)
end

function BP_Territory_Base:GetReplicatedProperties()
    return "OwnerKey"
end

function BP_Territory_Base:GetAvailableServerRPCs()
    return
end

-- ⭐ 归属 ⭐
-- 当前归属玩家 Key（0 = 未认领）
function BP_Territory_Base:GetOwnerKey()
    return tonumber(self.OwnerKey) or 0
end

function BP_Territory_Base:IsUnclaimed()
    return self:GetOwnerKey() == 0
end

function BP_Territory_Base:IsOwnedByKey(PlayerKey)
    local Owner = self:GetOwnerKey()
    return Owner ~= 0 and Owner == tonumber(PlayerKey)
end

-- 归属同步回调（客户端）
function BP_Territory_Base:OnRep_OwnerKey()
    ugcprint("[BP_Territory_Base] OnRep_OwnerKey " .. tostring(self.OwnerKey))
end

-- 认领（仅服务端）：未被认领时把归属设为该玩家 Key；已被认领则失败
function BP_Territory_Base:ClaimByKey(PlayerKey)
    if not UGCGameSystem.IsServer() then
        return false
    end
    if PlayerKey == nil then
        return false
    end
    if not self:IsUnclaimed() then
        return false
    end
    self.OwnerKey = tonumber(PlayerKey)
    ugcprint("[BP_Territory_Base] 领地被认领 OwnerKey=" .. tostring(self.OwnerKey))
    return true
end

-- 释放归属（仅服务端）：回到未认领，可被重新分配
function BP_Territory_Base:Release()
    if not UGCGameSystem.IsServer() then
        return
    end
    self.OwnerKey = 0
end

-- ⭐ 范围判定 ⭐
-- 点是否在领地碰撞盒子 Box 的范围内。
-- 判定用盒子的「水平投影（X/Y 足迹）」：以盒子的世界位置为中心，半尺寸 = BoxExtent × 盒子缩放；
-- Z 高度不参与判定（领地视为地面区域，蛋落在脚下、玩家原点在胶囊中心都能稳定判定）；
-- 不处理盒子的旋转（领地按世界轴对齐）。不处理 Z 也能避免把盒子压扁（Z 缩放为 0）时判定失效。
function BP_Territory_Base:IsPointInside(Location)
    if Location == nil or Location.X == nil then
        return false
    end
    local Box = self.Box
    if Box == nil then
        return false
    end
    local BoxExtent = Box.BoxExtent
    if BoxExtent == nil or BoxExtent.X == nil then
        return false
    end
    local BoxTransform = UGCActorComponentUtility.GetSceneComponentWorldTransform(Box)
    if BoxTransform == nil then
        return false
    end
    local BoxLoc, _, BoxScale = UGCMathUtility.BreakTransform(BoxTransform)
    if BoxLoc == nil or BoxLoc.X == nil then
        return false
    end
    -- 盒子缩放（组件/actor 缩放都体现在这里）；取不到时按 1 处理
    local SX, SY = 1, 1
    if BoxScale ~= nil and BoxScale.X ~= nil and BoxScale.Y ~= nil then
        SX = math.abs(BoxScale.X)
        SY = math.abs(BoxScale.Y)
    end
    local HalfX = math.abs(BoxExtent.X) * SX
    local HalfY = math.abs(BoxExtent.Y) * SY
    local DX = math.abs(Location.X - BoxLoc.X)
    local DY = math.abs(Location.Y - BoxLoc.Y)
    return DX <= HalfX and DY <= HalfY
end

return BP_Territory_Base