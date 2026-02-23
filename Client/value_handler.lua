---@alias ValueChangeData {set: string | fun(self: NetworkedSound, eInstance: Actor, ...), clear?: string | fun(self: NetworkedSound, eInstance: Actor), skip_if?: table<string>, requires?: table<string>}

local tValueChangeMap = {
    ["location"] = {  set = "SetLocation", skip_if = { "attachment" } },
    ["rotation"] = {  set = "SetRotation"  },
    ["scale"]    = {  set = "SetScale"     },
    ["attachment"] = { set = "AttachTo", clear = "Detach" },
    ["relative_location"] = { set = "SetRelativeLocation", requires = {"attachment"} },
    ["relative_rotation"] = { set = "SetRelativeRotation", requires = {"attachment"} },
}

-- `🔸 Client`<br>
---@param sKey string
---@param tData ValueChangeData
function NetworkedSound:AddValueChangeMap(sKey, tData)
    tValueChangeMap[sKey] = tData
    Console.Debug("Added ValueChangeMap for key: %s", sKey)
end

-- `🔸 Client`<br>
-- Checks whether the value needs to be unpacked
---@param xValue any
---@return boolean
local function shouldUnpack(xValue)
    if type(xValue) ~= "table" then return false end
    local tMT = getmetatable(xValue)
    return not (tMT and tMT.__index)
end

-- `🔸 Client`<br>
---@param self NetworkedSound
---@param tSkipIf table<string>
local function shouldSkip(self, tSkipIf)
    for _, sSkipKey in ipairs(tSkipIf) do
        local xSkipValue = self:GetValue(sSkipKey)
        if xSkipValue then
            return true
        end
    end
    return false
end

-- `🔸 Client`<br>
-- Defers the key until a required key is set
---@param self NetworkedSound
---@param sKey string
---@param sWaitForKey string
local function deferUntilRequire(self, sKey, sWaitForKey)
    local tRequireMap = self:GetValue("require_map") or {}
    tRequireMap[sWaitForKey] = tRequireMap[sWaitForKey] or {}
    tRequireMap[sWaitForKey][sKey] = true
    self:SetValue("require_map", tRequireMap)
end

-- `🔸 Client`<br>
---@param self NetworkedSound
---@param sInKey string
---@param tRequires table<string>
---@return boolean
local function handleRequires(self, sInKey, tRequires)
    local bAllPresent = true
    for _, sKey in pairs(tRequires) do
        local xValue = self:GetValue(sKey)
        if not xValue then
            bAllPresent = false
            deferUntilRequire(self, sInKey, sKey)
        end
    end
    return bAllPresent
end

-- `🔸 Client`<br>
-- Apply all changes that were deferred waiting for this key
---@param self NetworkedSound
---@param sKey string
local function applyDeferredChanges(self, sKey)
    local tRequireMap = self:GetValue("require_map") or {}
    local tDeferredKeys = tRequireMap[sKey]
    if not tDeferredKeys then return end

    for sDeferredKey, _ in pairs(tDeferredKeys) do
        local xDeferredValue = self:GetValue(sDeferredKey)
        if xDeferredValue ~= nil then
            ValueChange(self, sDeferredKey, xDeferredValue)
        end
    end

    tRequireMap[sKey] = nil
    self:SetValue("require_map", tRequireMap)
end

---@param self NetworkedSound
---@param sKey string
---@param xValue any
function ValueChange(self, sKey, xValue)
    local tMethod = tValueChangeMap[sKey]
    if not tMethod then
        applyDeferredChanges(self, sKey)
        return
    end

    local eInstance = self:GetActorInstance()
    if not eInstance then
        local tPendingChanges = self:GetValue("pending_changes") or {}
        tPendingChanges[sKey] = xValue
        self:SetValue("pending_changes", tPendingChanges)
        return
    end

    if not eInstance or not eInstance:IsValid() then
        return
    end

    if xValue ~= nil and tMethod.set then
        -- Check skip conditions
        if tMethod.skip_if and shouldSkip(self, tMethod.skip_if) then
            return
        end

        -- Check requires
        if not handleRequires(self, sKey, tMethod.requires or {}) then
            return
        end

        local bUnpack = shouldUnpack(xValue)
        if bUnpack then
            Console.Debug("Calling Set method with unpacked values: %s with values: %s", tMethod.set, NanosTable.Dump(xValue))
            if type(tMethod.set) == "function" then
                tMethod.set(self, eInstance, table.unpack(xValue))
            else
                eInstance[tMethod.set](eInstance, table.unpack(xValue))
            end
        else
            Console.Debug("Calling Set method: %s with value: %s", tMethod.set, tostring(xValue))

            if type(tMethod.set) == "function" then
                tMethod.set(self, eInstance, xValue)
            else
                eInstance[tMethod.set](eInstance, xValue)
            end
        end

        applyDeferredChanges(self, sKey)
        return
    end

    if xValue == nil and tMethod.clear then
        Console.Debug("Calling Clear method: %s", tMethod.clear)
        if type(tMethod.clear) == "function" then
            tMethod.clear(self, eInstance)
        else
            eInstance[tMethod.clear](eInstance)
        end

    end
end

---@param self NetworkedSound
local function destroyInstance(self)
    local eInstance = self:GetActorInstance()
    if not eInstance or not eInstance:IsValid() then return end

    eInstance:Destroy()
end

---@param self NetworkedSound
NetworkedSound.Subscribe("ValueChange", function (self, sKey, xValue)
    ValueChange(self, sKey, xValue)
end)

---@param self NetworkedSound
NetworkedSound.Subscribe("Destroy", function (self)
    destroyInstance(self)
end)

-- `🔸 Client`<br>
-- Sets the Actor instance this Proxy represents
---@param eActor Entity<Actor>
function NetworkedSound:SetActorInstance(eActor)
    self:SetValue("actor_instance", eActor)

    -- Apply pending changes
    local tPendingChanges = self:GetValue("pending_changes")
    if tPendingChanges then
        for sKey, xValue in pairs(tPendingChanges) do
            ValueChange(self, sKey, xValue)
        end
        self:SetValue("pending_changes", nil)
    end
end

-- `🔸 Client`<br>
-- Gets the Actor instance this Proxy represents
---@return ActorType?
function NetworkedSound:GetActorInstance()
    return self:GetValue("actor_instance")
end