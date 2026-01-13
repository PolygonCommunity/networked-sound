-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

---@param self NetworkedSound
NetworkedSound.ClassSubscribe("Spawn", function (self)
    Timer.SetTimeout(function ()
        local eSoundInstance = Sound(
            self:GetLocation(),
            self:GetPath(),
            self:Is2D(),
            self:IsAutoDestroy(),
            self:GetSoundType(),
            self:GetVolume(),
            self:GetPitch(),
            self:GetInnerRadius(),
            self:GetFalloffDistance(),
            self:GetAttenuationFunction(),
            self:KeepPlayingWhenSilent(),
            self:GetLoopMode(),
            self:IsAutoPlay()
        )

        eSoundInstance:SetLowPassFilter(self:GetLowPassFilter())

        local fStartTimeOffset = self:GetValue("start_time")
        if fStartTimeOffset then
            local fPlayStartTime = self:GetValue("play_start_time", 0)
            local fElapsedTime = Client.GetTime() - fPlayStartTime
            fStartTimeOffset = fStartTimeOffset + (fElapsedTime / 1000)
            eSoundInstance:Play(fStartTimeOffset)
        end

        local eAttachedTo = self:GetAttachedTo()
        if eAttachedTo then
            local iAttachmentRule = self:GetValue("attachment_rule", AttachmentRule.SnapToTarget)
            local sBoneName = self:GetValue("attached_bone", "")
            eSoundInstance:AttachTo(eAttachedTo, iAttachmentRule, sBoneName)
        end
        self:SetValue("sound_instance", eSoundInstance)
    end, 0)
end)

function NetworkedSound:Destructor()
    local bAutoDestroyed = self:GetValue("auto_destroyed", false)
    if not bAutoDestroyed then
        local eSoundInstance = self:GetSoundInstance()
        eSoundInstance:Destroy()
    end
end

---@type table<string, fun(self: NetworkedSound, xValue: any, eSoundInstance: Sound)>
local tValueChangeMap = {
    ["location"] = function (_, tLocation, eSoundInstance)
        eSoundInstance:SetLocation(tLocation)
    end,
    ["rotation"] = function (_, tRotation, eSoundInstance)
        eSoundInstance:SetRotation(tRotation)
    end,
    ["volume"] = function (_, fVolume, eSoundInstance)
        eSoundInstance:SetVolume(fVolume)
    end,
    ["pitch"] = function (_, fPitch, eSoundInstance)
        eSoundInstance:SetPitch(fPitch)
    end,
    ["inner_radius"] = function (_, fInnerRadius, eSoundInstance)
        eSoundInstance:SetInnerRadius(fInnerRadius)
    end,
    ["falloff_distance"] = function (_, fFalloffDistance, eSoundInstance)
        eSoundInstance:SetFalloffDistance(fFalloffDistance)
    end,
    ["low_pass_filter"] = function (_, fFrequency, eSoundInstance)
        eSoundInstance:SetLowPassFilter(fFrequency)
    end
}

---@param self NetworkedSound
---@param sKey string
---@param xValue any
NetworkedSound.ClassSubscribe("ValueChange", function (self, sKey, xValue)
    local eSoundInstance = self:GetSoundInstance()
    if eSoundInstance and tValueChangeMap[sKey] then
        tValueChangeMap[sKey](self, xValue, eSoundInstance)
    end
end)

-- `🔸 Client`<br>
---@param iSoundID integer
---@param sMethodName string
---@param ... any
local function callNativeMethod(iSoundID, sMethodName, ...)
    Timer.SetTimeout(function (...)
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then return end

        local eSoundInstance = oNetworkedSound:GetSoundInstance()
        if not eSoundInstance then return end

        eSoundInstance[sMethodName](eSoundInstance, ...)
    end, 0, ...)
end

Events.SubscribeRemote(NetworkedSound.EventMap.DurationRequest, function (iSoundID)
    Timer.SetTimeout(function () 
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then return end
        ---@cast oNetworkedSound NetworkedSound

        local eSoundInstance = oNetworkedSound:GetSoundInstance()
        if not eSoundInstance then return end

        -- Reduce to 2 decimal places
        local fDuration = eSoundInstance:GetDuration()
        local fSimplified = math.floor(fDuration * 100) / 100
        Events.CallRemote(NetworkedSound.EventMap.DurationResponse, iSoundID, fSimplified)
    end, 0)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.PlaySound, function (iSoundID, fStartTime)
    callNativeMethod(iSoundID, "Play", fStartTime)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.FadeInSound, function (iSoundID, fDuration, fTargetVolume, fStartTime)
    callNativeMethod(iSoundID, "FadeIn", fDuration, fTargetVolume, fStartTime)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.AttachTo, function (iSoundID, eActor, iAttachmentRule, sBoneName)
    callNativeMethod(iSoundID, "AttachTo", eActor, iAttachmentRule, sBoneName)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.Detach, function (iSoundID, iDetachmentRule)
    callNativeMethod(iSoundID, "Detach", iDetachmentRule)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.FadeOutSound, function (iSoundID, fFadeOutDuration, fFadeVolumeLevel, bDestroyAfterFadeout)
    Timer.SetTimeout(function ()
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then return end
        ---@cast oNetworkedSound NetworkedSound

        local eSoundInstance = oNetworkedSound:GetSoundInstance()
        if not eSoundInstance then return end

        if not fFadeOutDuration and not fFadeVolumeLevel and not bDestroyAfterFadeout then
            eSoundInstance:Stop()
            return
        end

        eSoundInstance:FadeOut(fFadeOutDuration, fFadeVolumeLevel, bDestroyAfterFadeout)
    end, 0)
end)

Events.SubscribeRemote(NetworkedSound.EventMap.SetPaused, function (iSoundID, bPaused)
    callNativeMethod(iSoundID, "SetPaused", bPaused)
end)

-- `🔸 Client`<br>
-- Returns the nanos world sound instance
---@return Sound
function NetworkedSound:GetSoundInstance()
    return self:GetValue("sound_instance")
end