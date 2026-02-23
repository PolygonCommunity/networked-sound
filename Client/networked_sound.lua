-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

---@param self NetworkedSound
NetworkedSound.Subscribe("Spawn", function (self)
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
        false
    )

    eSoundInstance:SetLowPassFilter(self:GetLowPassFilter())

    eSoundInstance:AttachTo(self, AttachmentRule.SnapToTarget)
    self:SetActorInstance(eSoundInstance)

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

---@param eNetworkedSound NetworkedSound
local function durationRequest(eNetworkedSound)
    local eSoundInstance = eNetworkedSound:GetValue("actor_instance")
    if not eSoundInstance then return end
    ---@cast eSoundInstance Sound

    local fDuration = eSoundInstance:GetDuration()
    if fDuration == 0 then
        Timer.Bind(
            Timer.SetTimeout(function ()
                durationRequest(eNetworkedSound)
            end, 100),
            eNetworkedSound
        )
        return
    end

    Events.CallRemote(NetworkedSound.EventMap.DurationResponse, eNetworkedSound, math.floor(fDuration * 100) / 100)
end
Events.SubscribeRemote(NetworkedSound.EventMap.DurationRequest, durationRequest)