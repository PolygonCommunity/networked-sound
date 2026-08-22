-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

-- `🔹 Server`<br>
---@class NetworkedSound : Actor, Entity
---@overload fun(tLocation: Vector, sAsset: string, bIs2DSound?: boolean, bAutoDestroy?: boolean, iSoundType?: SoundType, fVolume?: number, fPitch?: number, fInnerRadius?: number, fFalloffDistance?: number, iAttenuationFunction?: AttenuationFunction, bKeepPlayingWhenSilent?: boolean, iLoopMode?: SoundLoopMode, bAutoPlay?: boolean): NetworkedSound
NetworkedSound = StaticMesh.Inherit("NetworkedSound") --[[@as NetworkedSound]]
NetworkedSound.AssetDurationCache = {}

NetworkedSound.EventMap = {
    DurationRequest = "NS1", -- Sent by server to client to request duration
    DurationResponse = "NS2", -- Sent by client to server with duration
    PlayAt = "NS3", -- Sent by server to client to play a sound at a location without creating a NetworkedSound instance
}

NetworkedSound.NetVal = {
    path = "%1",
    is_2d_sound = "%2",
    auto_destroy = "%3",
    sound_type = "%4",
    volume = "%5",
    pitch = "%6",
    inner_radius = "%7",
    falloff_distance = "%8",
    attenuation_function = "%9",
    keep_playing_when_silent = "%a",
    loop_mode = "%b",
    auto_play = "%c",
    duration = "%d",
    low_pass_filter = "%e",
    state = "%f",
    backend = "%g",
}

-- Reverse lookup for debugging purposes
NetworkedSound.NetValName = {}
for sName, sKey in pairs(NetworkedSound.NetVal) do
    NetworkedSound.NetValName[sKey] = sName
end

---@enum SoundState
NetworkedSound.SoundState = {
    Stopped = 0,
    Playing = 1,
    FadingIn = 2,
    FadingOut = 3,
    Paused = 4,
}

NetworkedSound.StateIndex = {
    Mode = 1, -- SoundState
    StartTime = 2, -- server time the transition happened at
    Offset = 3, -- playback position at StartTime
    Param1 = 4, -- fade duration
    Param2 = 5, -- fade volume level
}

NetworkedSound.PlayAtIndex = {
    Path = 1,
    Location = 2,
    Is2D = 3,
    Volume = 4,
    Pitch = 5,
    SoundType = 6,
    InnerRadius = 7,
    FalloffDistance = 8,
    AttenuationFunction = 9,
    Backend = 10,
}

local NetVal = NetworkedSound.NetVal
local StateIndex = NetworkedSound.StateIndex
local SoundState = NetworkedSound.SoundState

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the sound asset path
---@return string
function NetworkedSound:GetPath()
    local sPath = self:GetValue(NetVal.path)
    return sPath
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns whether the sound is a 2D sound
---@return boolean
function NetworkedSound:Is2D()
    return self:GetValue(NetVal.is_2d_sound, false)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is set to auto destroy
--- @return boolean
function NetworkedSound:IsAutoDestroy()
    return self:GetValue(NetVal.auto_destroy, true)
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the sound type of the sound
---@return SoundType
function NetworkedSound:GetSoundType()
    return self:GetValue(NetVal.sound_type, SoundType.SFX)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the volume of the sound
---@return number
function NetworkedSound:GetVolume()
    return self:GetValue(NetVal.volume, 1)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the pitch of the sound
--- @return number
function NetworkedSound:GetPitch()
    return self:GetValue(NetVal.pitch, 1)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the inner radius of the sound
--- @return number
function NetworkedSound:GetInnerRadius()
    return self:GetValue(NetVal.inner_radius, 400)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the falloff distance of the sound
--- @return number
function NetworkedSound:GetFalloffDistance()
    return self:GetValue(NetVal.falloff_distance, 3600)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the attenuation function of the sound
--- @return AttenuationFunction
function NetworkedSound:GetAttenuationFunction()
    return self:GetValue(NetVal.attenuation_function, AttenuationFunction.Linear)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound keeps playing when silent
--- @return boolean
function NetworkedSound:KeepPlayingWhenSilent()
    return self:GetValue(NetVal.keep_playing_when_silent, false)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the loop mode of the sound
--- @return SoundLoopMode
function NetworkedSound:GetLoopMode()
    return self:GetValue(NetVal.loop_mode, SoundLoopMode.Default)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is set to auto play
--- @return boolean
function NetworkedSound:IsAutoPlay()
    return self:GetValue(NetVal.auto_play, true)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the duration of the sound
--- @return number?
function NetworkedSound:GetDuration()
    local fDuration = self:GetValue(NetVal.duration)
    return fDuration
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the low pass filter of the sound
--- @return number
function NetworkedSound:GetLowPassFilter()
    return self:GetValue(NetVal.low_pass_filter, 0)
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the backend name of the sound
--- @return string?
function NetworkedSound:GetBackendName()
    local sBackend = self:GetValue(NetVal.backend)
    return sBackend
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the raw replicated playback state
--- @return table?
function NetworkedSound:GetState()
    local tState = self:GetValue(NetVal.state)
    return tState
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the current playback state
--- @return SoundState
function NetworkedSound:GetSoundState()
    local tState = self:GetState()
    if not tState then return SoundState.Stopped end

    return tState[StateIndex.Mode]
end

---`🔸 Client`<br>`🔹 Server`<br>
--- @return boolean
function NetworkedSound:IsPlaying()
    local iMode = self:GetSoundState()
    return iMode == SoundState.Playing or iMode == SoundState.FadingIn or iMode == SoundState.FadingOut
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is paused
--- @return boolean
function NetworkedSound:IsPaused()
    return self:GetSoundState() == SoundState.Paused
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the time the current playback state started
---@return number?
function NetworkedSound:GetStartTime()
    local tState = self:GetState()
    return tState and tState[StateIndex.StartTime]
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the playback position the current state started at
---@return number
function NetworkedSound:GetPlayOffset()
    local tState = self:GetState()
    return tState and tState[StateIndex.Offset] or 0
end

Package.Export("NetworkedSound", NetworkedSound)