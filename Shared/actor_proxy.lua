-- `🔹 Server`<br>
---@class ActorProxy : BaseClass
---@overload fun(): ActorProxy
ActorProxy = BaseClass.Inherit("ActorProxy", ClassLib.FL.ServerAuthority)

if Server then
    ---`🔹 Server`<br>
    -- Attaches this Actor to any other Actor, optionally at a specific bone
    ---@param eOther Actor @Other actor to attach
    ---@param iAttachmentRule AttachmentRule? @Attachment rule to use
    ---@param sBoneName string? @Bone name to attach to (optional)
    ---@param iLifespanWhenDetached integer? @Seconds before destroying this Actor when detached, setting it to 0 will automatically destroy this actor when detached, setting it to 10 will destroy this after 10 seconds when detached
    ---@param bUseAbsoluteRotation boolean? @Whether to force attached object to use absolute rotation (will not follow parent)
    function ActorProxy:AttachTo(eOther, iAttachmentRule, sBoneName, iLifespanWhenDetached, bUseAbsoluteRotation)
        local iSelfDimension = self:GetDimension()
        local iOtherDimension = eOther:GetDimension()
        if iOtherDimension ~= iSelfDimension then
            assert(nil, string.format("AttachTo: You can't attach a Prop from another dimension (Actor: %d - Other Actor: %d)! Please move the Actor to the same dimension as the Other Actor first!", iSelfDimension, iOtherDimension))
            return
        end

        self:SetValue("attachment", {
            eOther,
            iAttachmentRule,
            sBoneName,
            iLifespanWhenDetached,
            bUseAbsoluteRotation
        }, true)
    end

    ---`🔹 Server`<br>
    -- Detaches this Actor from AttachedTo Actor
    function ActorProxy:Detach()
        self:SetValue("attachment", nil, true)
    end

    --- `🔹 Server`<br>
    -- Sets this Actor's relative location in local space (only if this actor is attached)
    ---@param tLocation Vector
    function ActorProxy:SetRelativeLocation(tLocation)
        if not self:GetValue("attachment") then
            Console.Warn("Actor `%s#%d` is not attached to any Actor!", self:GetClassName(), self:GetID())
            return
        end
        self:SetValue("relative_location", tLocation, true)
    end

    --- `🔹 Server`<br>
    -- Sets this Actor's relative rotation in local space (only if this actor is attached)
    ---@param tRotation Rotator
    function ActorProxy:SetRelativeRotation(tRotation)
        if not self:GetValue("attachment") then
            Console.Warn("Actor `%s#%d` is not attached to any Actor!", self:GetClassName(), self:GetID())
            return
        end
        self:SetValue("relative_rotation", tRotation, true)
    end

    ---`🔹 Server`<br>
    -- Sets this Actor's location in the game world
    ---@param tLocation Vector
    function ActorProxy:SetLocation(tLocation)
        self:SetValue("location", tLocation, true)
    end

    ---`🔹 Server`<br>
    -- Sets this Actor's rotation in the game world
    ---@param tRotation Rotator
    function ActorProxy:SetRotation(tRotation)
        self:SetValue("rotation", tRotation, true)
    end

    ---`🔹 Server`<br>
    -- Sets this Actor's scale in the game world
    ---@param tScale Vector
    function ActorProxy:SetScale(tScale)
        self:SetValue("scale", tScale, true)
    end
else
    -- `🔸 Client`<br>
    -- Sets the Actor instance this Proxy represents
    ---@param eActor Entity<Actor>
    function ActorProxy:SetActorInstance(eActor)
        self:SetValue("actor_instance", eActor)
    end

    -- `🔸 Client`<br>
    -- Gets the Actor instance this Proxy represents
    ---@return ActorType?
    function ActorProxy:GetActorInstance()
        return self:GetValue("actor_instance")
    end

    ---@alias ValueChangeData {set: string, clear?: string, skip_if?: table<string>, requires?: table<string>}

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
    function ActorProxy:AddValueChangeMap(sKey, tData)
        tValueChangeMap[sKey] = tData
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
    ---@param self ActorProxy
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
    ---@param self ActorProxy
    ---@param sKey string
    ---@param sWaitForKey string
    local function deferUntilRequire(self, sKey, sWaitForKey)
        local tRequireMap = self:GetValue("require_map") or {}
        tRequireMap[sWaitForKey] = tRequireMap[sWaitForKey] or {}
        tRequireMap[sWaitForKey][sKey] = true
        self:SetValue("require_map", tRequireMap)
    end

    -- `🔸 Client`<br>
    ---@param self ActorProxy
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
    ---@param self ActorProxy
    ---@param sKey string
    local function applyDeferredChanges(self, sKey)
        local tRequireMap = self:GetValue("require_map") or {}
        local tDeferredKeys = tRequireMap[sKey]
        if not tDeferredKeys then return end

        for sDeferredKey, _ in pairs(tDeferredKeys) do
            local xDeferredValue = self:GetValue(sDeferredKey)
            if xDeferredValue ~= nil then
                self.ClassCall("ValueChange", self, sDeferredKey, xDeferredValue)
            end
        end

        tRequireMap[sKey] = nil
        self:SetValue("require_map", tRequireMap)
    end

    ---@param self ActorProxy
    ---@param sKey string
    ---@param xValue any
    local function valueChange(self, sKey, xValue)
        local eInstance = self:GetActorInstance()
        if not eInstance then return end

        local tMethod = tValueChangeMap[sKey]
        if not tMethod then return end

        if xValue and tMethod.set then
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
                eInstance[tMethod.set](eInstance, table.unpack(xValue))
            else
                Console.Debug("Calling Set method: %s with value: %s", tMethod.set, tostring(xValue))
                eInstance[tMethod.set](eInstance, xValue)
            end

            applyDeferredChanges(self, sKey)
            return
        end

        if not xValue and tMethod.clear then
            eInstance[tMethod.clear](eInstance)
        end
    end

    ---@param self ActorProxy
    local function destroyInstance(self)
        local eInstance = self:GetActorInstance()
        if not eInstance then return end

        eInstance:Destroy()
    end

    ActorProxy.ClassSubscribe("ValueChange", function (self, sKey, xValue)
        valueChange(self, sKey, xValue)
    end)

    ActorProxy.ClassSubscribe("Destroy", function (self)
        destroyInstance(self)
    end)

    ActorProxy.ClassSubscribe("ClassRegister", function (tClass)
        tClass.ClassSubscribe("ValueChange", valueChange)
        tClass.ClassSubscribe("Destroy", destroyInstance)
    end)
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Gets the Actor this Actor is attached to
---@return Actor?
function ActorProxy:GetAttachedTo()
    local tAttachmentData = self:GetAttachmentData()
    if not tAttachmentData then
        return nil
    end

    return tAttachmentData.actor
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the attachment data of this Actor
---@return {actor: Actor, attachment_rule: AttachmentRule, bone_name: string, lifespan_when_detached: integer, use_absolute_rotation: boolean}|nil
function ActorProxy:GetAttachmentData()
    local tRawData = self:GetValue("attachment")
    if not tRawData then
        return nil
    end

    return {
        actor = tRawData[1],
        attachment_rule = tRawData[2] or AttachmentRule.SnapToTarget,
        bone_name = tRawData[3] or "",
        lifespan_when_detached = tRawData[4] or -1,
        use_absolute_rotation = tRawData[5] or false,
    }
end

--- `🔸 Client`<br>`🔹 Server`<br>
-- Returns the location of this Actor
---@return Vector
function ActorProxy:GetLocation()
    return self:GetValue("location") or Vector.Zero
end
--- `🔸 Client`<br>`🔹 Server`<br>
-- Returns the rotation of this Actor
---@return Rotator
function ActorProxy:GetRotation()
    return self:GetValue("rotation") or Rotator.Zero
end

--- `🔸 Client`<br>`🔹 Server`<br>
-- Returns the scale of this Actor
---@return Vector
function ActorProxy:GetScale()
    return self:GetValue("scale") or Vector.One
end

--- `🔸 Client`<br>`🔹 Server`<br>
-- Returns the relative location of this Actor
---@return Vector
function ActorProxy:GetRelativeLocation()
    return self:GetValue("relative_location") or Vector.Zero
end

--- `🔸 Client`<br>`🔹 Server`<br>
-- Returns the relative rotation of this Actor
---@return Rotator
function ActorProxy:GetRelativeRotation()
    return self:GetValue("relative_rotation") or Rotator.Zero
end