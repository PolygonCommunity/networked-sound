-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local fRebuildFade <const> = 0.08

local tRenderedFlat = {}

-- `🔸 Client`<br>
---@param self NetworkedSound
---@return boolean
local function shouldRenderFlat(self)
    if self:Is2D() then return true end

    local pPlayer = Client.GetLocalPlayer()
    if not pPlayer then return false end

    local eAttachedTo = self:GetAttachedTo()
    return eAttachedTo ~= nil and eAttachedTo == pPlayer:GetControlledCharacter()
end

-- `🔸 Client`<br>
---@param self NetworkedSound
---@return Sound
local function createSound(self)
    local bFlat = shouldRenderFlat(self)
    tRenderedFlat[self] = bFlat

    local eSound = Sound(
        self:GetLocation(),
        self:GetPath(),
        bFlat,
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

    if not bFlat then
        eSound:AttachTo(self, AttachmentRule.SnapToTarget)
    end

    self:SetBackendData(eSound)
    return eSound
end

-- `🔸 Client`<br>
---@param self NetworkedSound
---@return Sound, boolean
local function ensureRenderMode(self)
    local eSound = self:GetBackendData()

    if tRenderedFlat[self] == shouldRenderFlat(self) then
        return eSound, false
    end

    if eSound and eSound:IsValid() then
        eSound:FadeOut(fRebuildFade, 0, true)
    end

    return createSound(self), true
end

---@type NetworkedSoundBackend
local tBackend = {
    spawn = function (self)
        createSound(self)
    end,

    destroy = function (self)
        tRenderedFlat[self] = nil
        self:GetBackendData():Destroy()
    end,

    is_valid = function (self)
        local eSound = self:GetBackendData()
        return eSound ~= nil and eSound:IsValid()
    end,

    play = function (self, fOffset)
        local eSound, bRebuilt = ensureRenderMode(self)
        eSound:SetPaused(false)

        if bRebuilt then
            eSound:FadeIn(fRebuildFade, self:GetVolume(), fOffset)
            return
        end

        eSound:Play(fOffset)
    end,

    stop = function (self)
        self:GetBackendData():Stop()
    end,

    fade_in = function (self, fDuration, fVolumeLevel, fOffset)
        local eSound = ensureRenderMode(self)
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