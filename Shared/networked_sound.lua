
---@class NetworkedSound : ActorProxy
---@overload fun(tLocation: Vector, sAsset: string, bIs2DSound?: boolean, bAutoDestroy?: boolean, iSoundType?: SoundType, fVolume?: number, fPitch?: number, fInnerRadius?: number, fFalloffDistance?: number, iAttenuationFunction?: AttenuationFunction, bKeepPlayingWhenSilent?: boolean, iLoopMode?: SoundLoopMode, bAutoPlay?: boolean): NetworkedSound
NetworkedSound = ActorProxy.Inherit("NetworkedSound", ClassLib.FL.ServerAuthority)
NetworkedSound.AssetDurationCache = {}

NetworkedSound.EventMap = {
    DurationRequest = "NS1", -- Sent by server to client to request duration
    DurationResponse = "NS2", -- Sent by client to server with duration
}

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the sound asset path
---@return string
function NetworkedSound:GetPath()
    return self:GetValue("path")
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns whether the sound is a 2D sound
---@return boolean
function NetworkedSound:Is2D()
    return self:GetValue("is_2d_sound")
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is set to auto destroy
--- @return boolean
function NetworkedSound:IsAutoDestroy()
    return self:GetValue("auto_destroy", true)
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the sound type of the sound
---@return SoundType
function NetworkedSound:GetSoundType()
    return self:GetValue("sound_type", SoundType.SFX)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the volume of the sound
---@return number
function NetworkedSound:GetVolume()
    return self:GetValue("volume", 1)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the pitch of the sound
--- @return number
function NetworkedSound:GetPitch()
    return self:GetValue("pitch", 1)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the inner radius of the sound
--- @return number
function NetworkedSound:GetInnerRadius()
    return self:GetValue("inner_radius", 400)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the falloff distance of the sound
--- @return number
function NetworkedSound:GetFalloffDistance()
    return self:GetValue("falloff_distance", 3600)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the attenuation function of the sound
--- @return AttenuationFunction
function NetworkedSound:GetAttenuationFunction()
    return self:GetValue("attenuation_function", AttenuationFunction.Linear)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound keeps playing when silent
--- @return boolean
function NetworkedSound:KeepPlayingWhenSilent()
    return self:GetValue("keep_playing_when_silent", false)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the loop mode of the sound
--- @return SoundLoopMode
function NetworkedSound:GetLoopMode()
    return self:GetValue("loop_mode", SoundLoopMode.Default)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is set to auto play
--- @return boolean
function NetworkedSound:IsAutoPlay()
    return self:GetValue("auto_play", true)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the duration of the sound
--- @return number?
function NetworkedSound:GetDuration()
    return self:GetValue("duration", nil)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns the low pass filter of the sound
--- @return number
function NetworkedSound:GetLowPassFilter()
    return self:GetValue("low_pass_filter", 0)
end

---`🔸 Client`<br>`🔹 Server`<br>
--- Returns whether the sound is playing
--- @return boolean
function NetworkedSound:IsPlaying()
    return self:GetValue("is_playing", false)
end

---`🔸 Client`<br>`🔹 Server`<br>
-- Returns the time the sound started playing
---@return number?
function NetworkedSound:GetStartTime()
    return self:GetValue("start_time")
end

Package.Export("NetworkedSound", NetworkedSound)