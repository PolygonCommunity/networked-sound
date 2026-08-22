-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local NetVal = NetworkedSound.NetVal
local StateIndex = NetworkedSound.StateIndex
local SoundState = NetworkedSound.SoundState

---@type table<NetworkedSound, NetworkedSoundBackend>
local tActiveBackends = {}

-- `🔸 Client`<br>
-- Returns the backend currently rendering this sound
---@param self NetworkedSound
---@return NetworkedSoundBackend?
local function getBackend(self)
    local tBackend = tActiveBackends[self]
    if not tBackend then return nil end

    if tBackend.is_valid and not tBackend.is_valid(self) then return nil end

    return tBackend
end

-- `🔸 Client`<br>
---@param tState table
---@return number
local function resolveOffset(tState)
    local fStartTime = tState[StateIndex.StartTime] or 0
    local fOffset = tState[StateIndex.Offset] or 0

    return (Client.GetTime() - fStartTime) / 1000 + fOffset
end

---@type table<SoundState, fun(tBackend: NetworkedSoundBackend, self: NetworkedSound, tState: table)>
local tStateHandlers = {
    [SoundState.Stopped] = function (tBackend, self)
        if tBackend.stop then tBackend.stop(self) end
    end,

    [SoundState.Playing] = function (tBackend, self, tState)
        if tBackend.play then tBackend.play(self, resolveOffset(tState)) end
    end,

    [SoundState.FadingIn] = function (tBackend, self, tState)
        local fDuration = tState[StateIndex.Param1] or 0
        local fVolumeLevel = tState[StateIndex.Param2] or 1

        if tBackend.fade_in then
            tBackend.fade_in(self, fDuration, fVolumeLevel, resolveOffset(tState))
        elseif tBackend.play then
            tBackend.play(self, resolveOffset(tState))
        end
    end,

    [SoundState.FadingOut] = function (tBackend, self, tState)
        local fDuration = tState[StateIndex.Param1] or 0
        local fVolumeLevel = tState[StateIndex.Param2] or 0

        if tBackend.fade_out then
            tBackend.fade_out(self, fDuration, fVolumeLevel)
        elseif tBackend.stop then
            tBackend.stop(self)
        end
    end,

    [SoundState.Paused] = function (tBackend, self)
        if tBackend.set_paused then tBackend.set_paused(self, true) end
    end,
}

-- `🔸 Client`<br>
---@param tBackend NetworkedSoundBackend
---@param self NetworkedSound
---@param tState table
local function applyState(tBackend, self, tState)
    local fnHandler = tStateHandlers[tState[StateIndex.Mode]]
    if not fnHandler then return end

    fnHandler(tBackend, self, tState)
end

---@type table<string, fun(tBackend: NetworkedSoundBackend, self: NetworkedSound, xValue: any)>
local tValueHandlers = {
    [NetVal.state] = applyState,

    [NetVal.volume] = function (tBackend, self, fVolume)
        if tBackend.set_volume then 
            tBackend.set_volume(self, fVolume)
        end
    end,

    [NetVal.pitch] = function (tBackend, self, fPitch)
        if tBackend.set_pitch then 
            tBackend.set_pitch(self, fPitch)
        end
    end,

    [NetVal.low_pass_filter] = function (tBackend, self, fFrequency)
        if tBackend.set_low_pass_filter then
            tBackend.set_low_pass_filter(self, fFrequency)
        end
    end,

    [NetVal.inner_radius] = function (tBackend, self, fRadius)
        if tBackend.set_inner_radius then
            tBackend.set_inner_radius(self, fRadius)
        end
    end,

    [NetVal.falloff_distance] = function (tBackend, self, fDistance)
        if tBackend.set_falloff_distance then
            tBackend.set_falloff_distance(self, fDistance)
        end
    end,
}

-- `🔸 Client`<br>
---@param self NetworkedSound
local function destroySound(self)
    local tBackend = tActiveBackends[self]
    tActiveBackends[self] = nil
    if not tBackend then return end

    if not tBackend.is_valid or tBackend.is_valid(self) then
        tBackend.destroy(self)
    end

    self:SetBackendData(nil)
end

-- `🔸 Client`<br>
---@param self NetworkedSound
local function spawnSound(self)
    local tBackend = NetworkedSound.GetBackend(self:GetBackendName())
    if not tBackend then return end

    tActiveBackends[self] = tBackend
    tBackend.spawn(self)

    local tState = self:GetState()
    if tState then
        applyState(tBackend, self, tState)
    end
end

NetworkedSound.Subscribe("Spawn", spawnSound)
NetworkedSound.Subscribe("Destroy", destroySound)

---@param self NetworkedSound
---@param sKey string
---@param xValue any
NetworkedSound.Subscribe("ValueChange", function (self, sKey, xValue)
    if sKey == NetVal.backend then
        if not tActiveBackends[self] then return end

        destroySound(self)
        spawnSound(self)
        return
    end

    local fnHandler = tValueHandlers[sKey]
    if not fnHandler or xValue == nil then return end

    local tBackend = getBackend(self)
    if not tBackend then return end

    fnHandler(tBackend, self, xValue)
end)

-- `🔸 Client`<br>
---@param eNetworkedSound NetworkedSound
---@param iAttempt integer?
local function durationRequest(eNetworkedSound, iAttempt)
    if not eNetworkedSound or not eNetworkedSound:IsValid() then return end

    local tBackend = getBackend(eNetworkedSound)
    if not tBackend or not tBackend.get_duration then return end

    local fDuration = tBackend.get_duration(eNetworkedSound)

    if not fDuration or fDuration <= 0 then
        iAttempt = (iAttempt or 1) + 1

        if iAttempt > 30 then
            Console.Warn("[NetworkedSound] Gave up reading duration of asset '" .. tostring(eNetworkedSound:GetPath()) .. "'")
            return
        end

        Timer.Bind(
            Timer.SetTimeout(function ()
                durationRequest(eNetworkedSound, iAttempt)
            end, 100),
            eNetworkedSound
        )
        return
    end

    Events.CallRemote(
        NetworkedSound.EventMap.DurationResponse,
        Reliability.Reliable,
        eNetworkedSound,
        math.floor(fDuration * 100) / 100
    )
end
Events.SubscribeRemote(NetworkedSound.EventMap.DurationRequest, durationRequest)