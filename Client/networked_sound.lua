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

        self:SetActorInstance(eSoundInstance)
    end, 0)

    self:AddValueChangeMap("play", {
        ---@param eInstance Sound
        ---@param fStartOffset number
        set = function (_, eInstance, fStartOffset)
            local fStartTime = self:GetStartTime() or 0

            local fOffset = (Client.GetTime() - fStartTime) / 1000 + fStartOffset
            eInstance:Play(fOffset)
        end,

        ---@param eInstance Sound
        clear = function (_, eInstance)
            eInstance:Stop()
        end,
        requires = { "start_time" }
    })

    self:AddValueChangeMap("fade_in", {
        ---@param eInstance Sound
        ---@param fFadeInDuration number
        ---@param fFadeVolumeLevel number
        ---@param fStartOffset number
        set = function (_, eInstance, fFadeInDuration, fFadeVolumeLevel, fStartOffset)
            local fStartTime = self:GetStartTime() or 0

            local fOffset = (Client.GetTime() - fStartTime) / 1000 + fStartOffset
            eInstance:FadeIn(fFadeInDuration, fFadeVolumeLevel, fOffset)
        end,

        ---@param eInstance Sound
        clear = function (_, eInstance)
            eInstance:Stop()
        end,

        requires = { "start_time" }
    })

    self:AddValueChangeMap("fade_out", {
        ---@param eInstance Sound
        ---@param fFadeOutDuration number
        ---@param fFadeVolumeLevel number
        set = function (_, eInstance, fFadeOutDuration, fFadeVolumeLevel)
            eInstance:FadeOut(fFadeOutDuration, fFadeVolumeLevel)
        end,

        ---@param eInstance Sound
        clear = function (_, eInstance)
            eInstance:Stop()
        end,
    })

    self:AddValueChangeMap("paused", { set = "SetPaused" })
end)

Events.SubscribeRemote(NetworkedSound.EventMap.DurationRequest, function (iSoundID)
    Timer.SetTimeout(function () 
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then return end
        ---@cast oNetworkedSound NetworkedSound

        local eSoundInstance = oNetworkedSound:GetValue("actor_instance")
        if not eSoundInstance then return end
        ---@cast eSoundInstance Sound

        -- Reduce to 2 decimal places
        local fDuration = eSoundInstance:GetDuration()
        local fSimplified = math.floor(fDuration * 100) / 100
        Events.CallRemote(NetworkedSound.EventMap.DurationResponse, iSoundID, fSimplified)
    end, 0)
end)