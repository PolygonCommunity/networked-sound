-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

---@type NetworkedSoundBackend
local tBackend = {
    spawn = function (self)
        local eSound = Sound(
            self:GetLocation(),
            self:GetPath(),
            self:Is2D(),
            false,
            self:GetSoundType(),
            self:GetVolume(),
            self:GetPitch(),
            self:GetInnerRadius(),
            self:GetFalloffDistance(),
            self:GetAttenuationFunction(),
            self:KeepPlayingWhenSilent(),
            self:GetLoopMode(),
            false
        )

        eSound:SetLowPassFilter(self:GetLowPassFilter())
        eSound:AttachTo(self, AttachmentRule.SnapToTarget)

        self:SetBackendData(eSound)
    end,

    destroy = function (self)
        self:GetBackendData():Destroy()
    end,

    is_valid = function (self)
        local eSound = self:GetBackendData()
        return eSound ~= nil and eSound:IsValid()
    end,

    play = function (self, fOffset)
        local eSound = self:GetBackendData()
        eSound:SetPaused(false)
        eSound:Play(fOffset)
    end,

    stop = function (self)
        self:GetBackendData():Stop()
    end,

    fade_in = function (self, fDuration, fVolumeLevel, fOffset)
        local eSound = self:GetBackendData()
        eSound:SetPaused(false)
        eSound:FadeIn(fDuration, fVolumeLevel, fOffset)
    end,

    fade_out = function (self, fDuration, fVolumeLevel)
        self:GetBackendData():FadeOut(fDuration, fVolumeLevel)
    end,

    set_paused = function (self, bPaused)
        self:GetBackendData():SetPaused(bPaused)
    end,

    set_volume = function (self, fVolume)
        self:GetBackendData():SetVolume(fVolume)
    end,

    set_pitch = function (self, fPitch)
        self:GetBackendData():SetPitch(fPitch)
    end,

    set_low_pass_filter = function (self, fFrequency)
        self:GetBackendData():SetLowPassFilter(fFrequency)
    end,

    set_inner_radius = function (self, fRadius)
        self:GetBackendData():SetInnerRadius(fRadius)
    end,

    set_falloff_distance = function (self, fDistance)
        self:GetBackendData():SetFalloffDistance(fDistance)
    end,

    get_duration = function (self)
        return self:GetBackendData():GetDuration()
    end,

    play_at = function (tParams)
        Sound(
            tParams.location,
            tParams.path,
            tParams.is_2d,
            true,
            tParams.sound_type,
            tParams.volume,
            tParams.pitch,
            tParams.inner_radius,
            tParams.falloff_distance,
            tParams.attenuation_function,
            false,
            SoundLoopMode.Default,
            true
        )
    end,
}

NetworkedSound.RegisterBackend("sound", tBackend)