local ObjectPool = {}
ObjectPool.__index = ObjectPool

-- 构造函数
function ObjectPool.new()
    local self = setmetatable({}, ObjectPool)
    self._pools = {}               -- 按类型存储池 {type = {stack, template, onGet, onRelease}}
    self._activeObjects = {}       -- 活跃对象追踪 {obj = type}
    self._totalCreated = {}        -- 各类型对象总数 {type = count}
    self._maxCapacity = 1000       -- 默认单类型最大容量
    return self
end

-- 预加载对象
-- @param objectType 类型标识（如"Bullet"）
-- @param template 模板（Instance或构造函数）
-- @param onGet 获取时的回调（可选，用于绑定固定事件）
-- @param onRelease 回收时的回调（可选，用于断开固定事件）
-- @param count 预加载数量
function ObjectPool:Preload(objectType, template, onGet, onRelease, count)
    if not self._pools[objectType] then
        self._pools[objectType] = {
            stack = {},
            template = template,
            onGet = onGet,
            onRelease = onRelease
        }
        self._totalCreated[objectType] = 0
    end

    count = count or 1
    for _ = 1, count do
        local obj = self:_createObject(objectType)
        self:_releaseObject(objectType, obj)
    end
end

-- 从池中获取对象
function ObjectPool:Get(objectType, ...)
    local pool = self._pools[objectType]
    if not pool then error("ObjectPool: Type '"..objectType.."' not initialized") end

    local obj
    if #pool.stack > 0 then
        obj = table.remove(pool.stack) -- 从池中取出
    else
        if self._totalCreated[objectType] >= self._maxCapacity then
            warn("ObjectPool: Pool for "..objectType.." reached max capacity")
            return nil
        end
        obj = self:_createObject(objectType) -- 动态创建
    end

    -- 标记为活跃对象
    self._activeObjects[obj] = objectType

    -- 调用onGet回调（绑定固定事件）
    if pool.onGet then
        pool.onGet(obj, ...)
    end

    return obj
end

-- 回收对象到池中
function ObjectPool:Release(objectType, obj)
    if not self._activeObjects[obj] then
        warn("ObjectPool: Attempt to release an unmanaged object: " .. objectType)
        return false
    end

    -- 调用onRelease回调（断开固定事件）
    local pool = self._pools[objectType]
    if pool and pool.onRelease then
        pool.onRelease(obj)
    end

    -- 断开所有托管事件
    self:_disconnectTrackedEvents(obj)

    -- 重置对象状态并回收
    self:_releaseObject(objectType, obj)
    self._activeObjects[obj] = nil
    return true
end

-- 托管外部事件（由池负责断开）
function ObjectPool:TrackEvent(obj, connection)
    if not obj._managedConnections then
        obj._managedConnections = {}
    end
    table.insert(obj._managedConnections, connection)
end

-- 强制回收所有活跃对象
function ObjectPool:ReleaseAll()
    for obj, objectType in pairs(self._activeObjects) do
        self:Release(objectType, obj)
    end
end

-- 设置单类型最大容量
function ObjectPool:SetMaxCapacity(objectType, capacity)
    self._maxCapacity = math.max(1, capacity)
end

-- 私有方法：创建新对象
function ObjectPool:_createObject(objectType)
    local pool = self._pools[objectType]
    local obj

    if type(pool.template) == "function" then
        obj = pool.template()
    elseif typeof(pool.template) == "Instance" then
        obj = pool.template:Clone()
    else
        error("ObjectPool: Invalid template for type '"..objectType.."'")
    end

    -- 标记对象类型（用于泄漏检测）
    --- obj._objectPoolType = objectType
    self._totalCreated[objectType] = (self._totalCreated[objectType] or 0) + 1
    --- print('_createObject', objectType, self._totalCreated[objectType])

    return obj
end

-- 私有方法：回收对象
function ObjectPool:_releaseObject(objectType, obj)
    -- 基础状态重置
    if obj:IsA("BasePart") then
        -- obj.Anchored = true
        -- obj.CanCollide = false
        -- obj.Transparency = 1
    end
    obj.Parent = nil

    -- 放回池中
    table.insert(self._pools[objectType].stack, obj)
    --- print('_releaseObject', objectType, #self._pools[objectType].stack)
end

-- 私有方法：断开所有托管事件
function ObjectPool:_disconnectTrackedEvents(obj)
    -- if obj._managedConnections then
    --     for _, connection in ipairs(obj._managedConnections) do
    --         connection:Disconnect()
    --     end
    --     obj._managedConnections = nil
    -- end
end

return ObjectPool
