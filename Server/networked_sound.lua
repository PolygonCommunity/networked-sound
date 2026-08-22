-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local NetVal = NetworkedSound.NetVal
local StateIndex = NetworkedSound.StateIndex
local SoundState = NetworkedSound.SoundState

-- `🔹 Server`<br>
---@param self NetworkedSound
---@param sKey string
---@param xValue any
---@param xDefault any
local function setNonDefault(self, sKey, xValue, xDefault)
    if xValue == nil or xValue == xDefault then return end

    self:SetValue(sKey, xValue, true)
end

function NetworkedSound:Constructor(tLocation, sAsset, bIs2DSound, bAutoDestroy, iSoundType, fVolume, fPitch, fInnerRadius, fFalloffDistance, iAttenuationFunction, bKeepPlayingWhenSilent, iLoopMode, bAutoPlay)
    self.Super:Constructor(tLocation, Rotator(), "nanos-world::SM_None", CollisionType.NoCollision, SpawnMode.AfterConstructor)

    self:SetValue(NetVal.path, sAsset, true)

    setNonDefault(self, NetVal.is_2d_sound, bIs2DSound, false)
    setNonDefault(self, NetVal.auto_destroy, bAutoDestroy, true)
    setNonDefault(self, NetVal.sound_type, iSoundType, SoundType.SFX)
    setNonDefault(self, NetVal.volume, fVolume, 1)
    setNonDefault(self, NetVal.pitch, fPitch, 1)
    setNonDefault(self, NetVal.inner_radius, fInnerRadius, 400)
    setNonDefault(self, NetVal.falloff_distance, fFalloffDistance, 3600)
    setNonDefault(self, NetVal.attenuation_function, iAttenuationFunction, AttenuationFunction.Linear)
    setNonDefault(self, NetVal.keep_playing_when_silent, bKeepPlayingWhenSilent, false)
    setNonDefault(self, NetVal.loop_mode, iLoopMode, SoundLoopMode.Default)
    setNonDefault(self, NetVal.auto_play, bAutoPlay, true)

    local fCachedDuration = NetworkedSound.GetCachedDuration(sAsset)
    if fCachedDuration then
        self:SetDuration(fCachedDuration)
    end

    if type(bAutoPlay) == "nil" or bAutoPlay then
        self:Play()
    end

    self:SetNetworkAuthorityAutoDistributed(true)
    self:RequestDuration()
end

---@param self NetworkedSound
NetworkedSound.Subscribe("Destroy", function (self)
    Console.Debug("[NetworkedSound] Destroyed sound instance for asset '" .. tostring(self:GetPath()) .. "'")
end)

-- `🔹 Server`<br>
-- Sets the backend to use for this sound, if the client has it registered
---@param sBackend string?
function NetworkedSound:SetBackend(sBackend)
    self:SetValue(NetVal.backend, sBackend, true)
end

-- `🔹 Server`<br>
-- Sets the volume of the sound
---@param fVolume number
function NetworkedSound:SetVolume(fVolume)
    self:SetValue(NetVal.volume, fVolume, true)
end

-- `🔹 Server`<br>
-- Sets the pitch of the sound
---@param fPitch number
function NetworkedSound:SetPitch(fPitch)
    self:SetValue(NetVal.pitch, fPitch, true)
end

-- `🔹 Server`<br>
-- If a 3D Sound, sets the distance within the volume is 100%
---@param fInnerRadius number
function NetworkedSound:SetInnerRadius(fInnerRadius)
    self:SetValue(NetVal.inner_radius, fInnerRadius, true)
end

-- `🔹 Server`<br>
-- If a 3D Sound, sets the distance which the sound is inaudible
---@param fFalloffDistance number
function NetworkedSound:SetFalloffDistance(fFalloffDistance)
    self:SetValue(NetVal.falloff_distance, fFalloffDistance, true)
end

-- `🔹 Server`<br>
-- Sets the low pass filter frequency
---@param fFrequency number
function NetworkedSound:SetLowPassFilter(fFrequency)
    self:SetValue(NetVal.low_pass_filter, fFrequency, true)
end

-- `🔹 Server`<br>
-- Returns the current playback position, in seconds
---@return number
function NetworkedSound:GetElapsedTime()
    local tState = self:GetState()
    if not tState then return 0 end

    local fOffset = tState[StateIndex.Offset] or 0

    local iMode = tState[StateIndex.Mode]
    if iMode == SoundState.Stopped or iMode == SoundState.Paused then
        return fOffset
    end

    return (Server.GetTime() - (tState[StateIndex.StartTime] or 0)) / 1000 + fOffset
end

-- `🔹 Server`<br>
---@param iMode SoundState
---@param fOffset number?
---@param xParam1 any
---@param xParam2 any
function NetworkedSound:SetState(iMode, fOffset, xParam1, xParam2)
    self:SetValue(NetVal.state, {
        iMode,
        Server.GetTime(),
        fOffset or 0,
        xParam1,
        xParam2,
    }, true)
end

-- `🔹 Server`<br>
-- Starts the sound
---@param fStartTime number?
function NetworkedSound:Play(fStartTime)
    self:SetState(SoundState.Playing, fStartTime or 0)
    self:UpdateLifeSpan()
end

-- `🔹 Server`<br>
-- Plays the sound with a fade effect
---@param fFadeInDuration number
---@param fFadeVolumeLevel number?
---@param fStartTime number?
function NetworkedSound:FadeIn(fFadeInDuration, fFadeVolumeLevel, fStartTime)
    self:SetState(SoundState.FadingIn, fStartTime or 0, fFadeInDuration, fFadeVolumeLevel or 1)
    self:UpdateLifeSpan()
end

-- `🔹 Server`<br>
-- Stops the sound with a fade effect
---@param fFadeOutDuration number
---@param fFadeVolumeLevel number?
---@param bDestroyAfterFadeout boolean?
function NetworkedSound:FadeOut(fFadeOutDuration, fFadeVolumeLevel, bDestroyAfterFadeout)
    self:SetState(SoundState.FadingOut, self:GetElapsedTime(), fFadeOutDuration, fFadeVolumeLevel or 0)

    if bDestroyAfterFadeout then
        self:SetLifeSpan(fFadeOutDuration)
    end
end

-- `🔹 Server`<br>
-- Pauses the sound
---@param bPause boolean?
function NetworkedSound:SetPaused(bPause)
    if type(bPause) == "nil" then bPause = true end

    local fElapsedTime = self:GetElapsedTime()

    if bPause then
        self:SetState(SoundState.Paused, fElapsedTime)
        self:SetLifeSpan(0)
        return
    end

    self:SetState(SoundState.Playing, fElapsedTime)
    self:UpdateLifeSpan()
end

-- `🔹 Server`<br>
-- Stops the sound
function NetworkedSound:Stop()
    self:SetState(SoundState.Stopped, 0)
    self:SetLifeSpan(0)
end

-- `🔹 Server`<br>
-- Stops the sound after the provided delay
---@param fDelay number
function NetworkedSound:StopDelayed(fDelay)
    Timer.Bind(
        Timer.SetTimeout(function ()
            self:Stop()
        end, fDelay * 1000),
        self
    )
end

-- `🔹 Server`<br>
-- Sets the duration of the sound
---@param fDuration number
function NetworkedSound:SetDuration(fDuration)
    self:SetValue(NetVal.duration, fDuration, true)
end

-- `🔹 Server`<br>
-- Updates the life span of the sound
function NetworkedSound:UpdateLifeSpan()
    if not self:IsAutoDestroy() then
        self:SetLifeSpan(0)
        return
    end

    if self:GetLoopMode() == SoundLoopMode.Forever then
        self:SetLifeSpan(0)
        return
    end

    local iMode = self:GetSoundState()
    if iMode ~= SoundState.Playing and iMode ~= SoundState.FadingIn then return end

    local fDuration = self:GetDuration() or 20
    local fRemainingTime = fDuration - self:GetElapsedTime()

    self:SetLifeSpan(math.max(fRemainingTime, 0.01))
end