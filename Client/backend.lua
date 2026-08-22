-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

---@class NetworkedSoundBackend
---@field spawn fun(self: NetworkedSound)
---@field destroy fun(self: NetworkedSound)
---@field is_valid? fun(self: NetworkedSound): boolean
---@field play? fun(self: NetworkedSound, fOffset: number)
---@field stop? fun(self: NetworkedSound)
---@field fade_in? fun(self: NetworkedSound, fDuration: number, fVolumeLevel: number, fOffset: number) Falls back to `play`
---@field fade_out? fun(self: NetworkedSound, fDuration: number, fVolumeLevel: number) Falls back to `stop`
---@field set_paused? fun(self: NetworkedSound, bPaused: boolean)
---@field set_volume? fun(self: NetworkedSound, fVolume: number)
---@field set_pitch? fun(self: NetworkedSound, fPitch: number)
---@field set_low_pass_filter? fun(self: NetworkedSound, fFrequency: number)
---@field set_inner_radius? fun(self: NetworkedSound, fRadius: number)
---@field set_falloff_distance? fun(self: NetworkedSound, fDistance: number)
---@field get_duration? fun(self: NetworkedSound): number? Used to answer server duration requests
---@field play_at? fun(tParams: PlayAtParams)

---@class PlayAtParams
---@field path string
---@field location Vector
---@field is_2d boolean
---@field volume number
---@field pitch number
---@field sound_type SoundType
---@field inner_radius number
---@field falloff_distance number
---@field attenuation_function AttenuationFunction

local tBackends = {}
local sDefaultBackend = "sound"

---@type table<NetworkedSound, any>
local tBackendData = {}

-- `🔸 Client`<br>
-- Sets the backend data for this sound
---@param xData any
function NetworkedSound:SetBackendData(xData)
    tBackendData[self] = xData
end

-- `🔸 Client`<br>
-- Returns whatever the backend stored for this sound
---@return any
function NetworkedSound:GetBackendData()
    return tBackendData[self]
end

-- `🔸 Client`<br>
---@param sName string
---@param tBackend NetworkedSoundBackend
function NetworkedSound.RegisterBackend(sName, tBackend)
    assert(type(sName) == "string", "backend name must be a string")
    assert(type(tBackend) == "table", "backend must be a table")
    assert(type(tBackend.spawn) == "function", "backend '" .. sName .. "' is missing spawn")
    assert(type(tBackend.destroy) == "function", "backend '" .. sName .. "' is missing destroy")

    tBackends[sName] = tBackend
    Console.Log("[NetworkedSound] Registered backend '" .. sName .. "'")
end

-- `🔸 Client`<br>
-- Sets the default backend to use when no backend is specified
---@param sName string
function NetworkedSound.SetDefaultBackend(sName)
    assert(tBackends[sName], "unknown backend '" .. tostring(sName) .. "'")
    sDefaultBackend = sName
end

-- `🔸 Client`<br>
-- Returns the default backend name
---@return string
function NetworkedSound.GetDefaultBackend()
    return sDefaultBackend
end

-- `🔸 Client`<br>
---@param sName string?
---@return NetworkedSoundBackend?
function NetworkedSound.GetBackend(sName)
    local tBackend = tBackends[sName or sDefaultBackend]
    if not tBackend then
        Console.Error("[NetworkedSound] Unknown backend '" .. tostring(sName or sDefaultBackend) .. "'")
        return nil
    end

    return tBackend
end