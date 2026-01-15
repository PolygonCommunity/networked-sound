-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

function NetworkedSound:Constructor(tLocation, sAsset, bIs2DSound, bAutoDestroy, iSoundType, fVolume, fPitch, fInnerRadius, fFalloffDistance, iAttenuationFunction, bKeepPlayingWhenSilent, iLoopMode, bAutoPlay)
    ActorProxy.Constructor(self)

    if tLocation ~= Vector.Zero then
        self:SetLocation(tLocation)
    end

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

function NetworkedSound:Destructor()
    self:ClearAutoDestroyTimer()
    ActorProxy.Destructor(self)
end

-- `🔹 Server`<br>
-- Finds and assigns a query player for duration requests
function NetworkedSound:AssignQueryPlayer()
    local tPlayers, bAll = self:GetReplicatedPlayers()
    local pQueryPlayer = nil
    if bAll then
        local pAnyPlayer = Player.GetAll()[1]
        pQueryPlayer = pAnyPlayer
    else
        pQueryPlayer = tPlayers[1]
    end

    if not pQueryPlayer then return end
    self:SetValue("query_player", pQueryPlayer)

    if not NetworkedSound.AssetDurationCache[self:GetPath()] then
        Events.CallRemote(NetworkedSound.EventMap.DurationRequest, pQueryPlayer, self:GetID())
    end
end

-- `🔹 Server`<br>
-- Returns the current query player
---@return Player?
function NetworkedSound:GetQueryPlayer()
    return self:GetValue("query_player")
end

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
    self:StartAutoDestroyTimer()
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

    -- todo: start auto destroy timer?
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
        Timer.SetTimeout(function ()
            self:SetValue("auto_destroyed", true, true)
            self:Destroy()
        end, fFadeOutDuration * 1000)
    end
end

-- `🔹 Server`<br>
-- Pauses the sound
---@param bPause boolean?
function NetworkedSound:SetPaused(bPause)
    if type(bPause) == "nil" then bPause = true end

    local iAutoDestroyTimer = self:GetAutoDestroyTimer()
    if iAutoDestroyTimer then
        if bPause then
            Timer.Pause(iAutoDestroyTimer)
        else
            Timer.Resume(iAutoDestroyTimer)
        end
    end

    if bPause then
        local fStartTime = self:GetStartTime() or 0
        local fElapsedTime = (Server.GetTime() - fStartTime) / 1000
        self:SetValue("paused_offset", fElapsedTime)
    else
        local fPausedOffset = self:GetValue("paused_offset", 0)
        self:SetValue("start_time", Server.GetTime() - (fPausedOffset * 1000), true)
        self:SetValue("paused_offset", nil)
    end

    self:SetValue("paused", bPause, true)
    self:SetValue("is_playing", not bPause)
end

-- `🔹 Server`<br>
-- Stops the sound
function NetworkedSound:Stop()
    self:ClearAutoDestroyTimer()
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
-- Starts the auto destroy timer
function NetworkedSound:StartAutoDestroyTimer()
    local fDuration = self:GetDuration()
    if not fDuration then return end

    self:ClearAutoDestroyTimer()

    local fPlayStartTime = self:GetStartTime()
    if not fPlayStartTime then return end

    if not self:IsAutoDestroy() then return end

    local fStartTimeOffset = self:GetValue("play_offset", 0)
    fDuration = fDuration - fStartTimeOffset

    local fRemainingTime = fDuration * 1000 - (Server.GetTime() - fPlayStartTime)
    local iAutoDestroyTimer = Timer.SetTimeout(function ()
        self:SetValue("auto_destroyed", true, true)
        self:Destroy()
    end, fRemainingTime)
    self:SetValue("auto_destroy_timer", iAutoDestroyTimer)
end

-- `🔹 Server`<br>
-- Clears the auto destroy timer
function NetworkedSound:ClearAutoDestroyTimer()
    local iAutoDestroyTimer = self:GetAutoDestroyTimer()
    if not iAutoDestroyTimer then return end

    Timer.ClearTimeout(iAutoDestroyTimer)
    self:SetValue("auto_destroy_timer", nil)
end

-- `🔹 Server`<br>
-- Returns the auto destroy timer ID
---@return integer?
function NetworkedSound:GetAutoDestroyTimer()
    return self:GetValue("auto_destroy_timer")
end