-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

function NetworkedSound:Constructor(tLocation, sAsset, bIs2DSound, bAutoDestroy, iSoundType, fVolume, fPitch, fInnerRadius, fFalloffDistance, iAttenuationFunction, bKeepPlayingWhenSilent, iLoopMode, bAutoPlay)
    self.Super:Constructor(tLocation, Rotator(), "nanos-world::SM_None")

    self:SetValue("path", sAsset, true)
    self:SetValue("is_2d_sound", bIs2DSound, true)
    self:SetValue("auto_destroy", bAutoDestroy, true)
    self:SetValue("sound_type", iSoundType, true)
    self:SetVolume(fVolume)
    self:SetPitch(fPitch)
    self:SetInnerRadius(fInnerRadius)
    self:SetFalloffDistance(fFalloffDistance)
    self:SetValue("attenuation_function", iAttenuationFunction, true)
    self:SetValue("keep_playing_when_silent", bKeepPlayingWhenSilent, true)
    self:SetValue("loop_mode", iLoopMode, true)
    self:SetValue("auto_play", bAutoPlay, true)

    if type(bAutoPlay) == "nil" or bAutoPlay then
        self:Play()
    end

    local fCachedDuration = NetworkedSound.GetCachedDuration(sAsset)
    if fCachedDuration then
        self:SetDuration(fCachedDuration)
    end

    Timer.SetTimeout(self.AssignQueryPlayer, 0, self)
end

---@param self NetworkedSound
NetworkedSound.Subscribe("Destroy", function (self)
    Console.Log("[NetworkedSound] Destroyed sound instance for asset '" .. self:GetPath() .. "'.")
end)

-- `🔹 Server`<br>
-- Sets the volume of the sound
---@param fVolume number
function NetworkedSound:SetVolume(fVolume)
    self:SetValue("volume", fVolume, true)
end

-- `🔹 Server`<br>
-- Sets the pitch of the sound
---@param fPitch number
function NetworkedSound:SetPitch(fPitch)
    self:SetValue("pitch", fPitch, true)
end

-- `🔹 Server`<br>
-- If a 3D Sound, sets the distance within the volume is 100%
---@param fInnerRadius number
function NetworkedSound:SetInnerRadius(fInnerRadius)
    self:SetValue("inner_radius", fInnerRadius, true)
end

-- `🔹 Server`<br>
-- If a 3D Sound, sets the distance which the sound is inaudible
---@param fFalloffDistance number
function NetworkedSound:SetFalloffDistance(fFalloffDistance)
    self:SetValue("falloff_distance", fFalloffDistance, true)
end

-- `🔹 Server`<br>
-- Sets the low pass filter frequency
---@param fFrequency number
function NetworkedSound:SetLowPassFilter(fFrequency)
    self:SetValue("low_pass_filter", fFrequency, true)
end

local function clearPlayValues(self)
    if self:GetValue("play") then
        self:SetValue("play", nil, true)
    end

    if self:GetValue("fade_in") then
        self:SetValue("fade_in", nil, true)
    end

    if self:GetValue("fade_out") then
        self:SetValue("fade_out", nil, true)
    end
end

-- `🔹 Server`<br>
-- Starts the sound
---@param fStartTime number?
function NetworkedSound:Play(fStartTime)
    clearPlayValues(self)

    self:SetValue("start_time", Server.GetTime(), true)
    self:SetValue("play", fStartTime or 0, true)
    self:SetValue("is_playing", true)
    self:SetValue("play_offset", fStartTime or 0)
    self:UpdateLifeSpan()
end

-- `🔹 Server`<br>
-- Plays the sound with a fade effect
---@param fFadeInDuration number
---@param fFadeVolumeLevel number?
---@param fStartTime number?
function NetworkedSound:FadeIn(fFadeInDuration, fFadeVolumeLevel, fStartTime)
    clearPlayValues(self)

    self:SetValue("start_time", Server.GetTime(), true)
    self:SetValue("fade_in", { fFadeInDuration, fFadeVolumeLevel or 1, fStartTime or 0 }, true)
    self:SetValue("is_playing", true)
    self:SetValue("play_offset", fStartTime or 0)
    self:UpdateLifeSpan()
end

-- `🔹 Server`<br>
-- Stops the sound with a fade effect
---@param fFadeOutDuration number
---@param fFadeVolumeLevel number?
---@param bDestroyAfterFadeout boolean?
function NetworkedSound:FadeOut(fFadeOutDuration, fFadeVolumeLevel, bDestroyAfterFadeout)
    clearPlayValues(self)

    self:SetValue("fade_out", { fFadeOutDuration, fFadeVolumeLevel or 0 }, true)

    if bDestroyAfterFadeout then
        self:SetLifeSpan(fFadeOutDuration)
    end
end

-- `🔹 Server`<br>
-- Pauses the sound
---@param bPause boolean?
function NetworkedSound:SetPaused(bPause)
    if type(bPause) == "nil" then bPause = true end

    if bPause then
        local fStartTime = self:GetStartTime() or 0
        local fElapsedTime = (Server.GetTime() - fStartTime) / 1000
        self:SetValue("paused_offset", fElapsedTime)
        self:SetLifeSpan(0)
    else
        local fPausedOffset = self:GetValue("paused_offset", 0)
        self:SetValue("start_time", Server.GetTime() - (fPausedOffset * 1000), true)
        self:SetValue("paused_offset", nil)
        self:UpdateLifeSpan()
    end

    self:SetValue("paused", bPause, true)
    self:SetValue("is_playing", not bPause)
end

-- `🔹 Server`<br>
-- Stops the sound
function NetworkedSound:Stop()
    self:SetLifeSpan(0)
    self:SetValue("is_playing", false)
    clearPlayValues(self)
end

-- `🔹 Server`<br>
-- Stops the sound after the provided delay
---@param fDelay number
function NetworkedSound:StopDelayed(fDelay)
    Timer.SetTimeout(function ()
        self:Stop()
    end, fDelay * 1000)
end

-- `🔹 Server`<br>
-- Sets the duration of the sound
---@param fDuration number
function NetworkedSound:SetDuration(fDuration)
    self:SetValue("duration", fDuration, true)
end

-- `🔹 Server`<br>
-- Updates the life span of the sound
function NetworkedSound:UpdateLifeSpan()
    if self:GetLoopMode() == SoundLoopMode.Forever then
        self:SetLifeSpan(0)
        return
    end

    local fDuration = self:GetDuration()
    if not fDuration then return end

    local fPlayStartTime = self:GetStartTime()
    if not fPlayStartTime then return end

    local fStartTimeOffset = self:GetValue("play_offset", 0)
    fDuration = fDuration - fStartTimeOffset

    local fElapsedTime = (Server.GetTime() - fPlayStartTime) / 1000
    local fRemainingTime = fDuration - fElapsedTime
    self:SetLifeSpan(fRemainingTime)
end