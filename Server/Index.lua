-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local tSoundByDimension = {}

-- `🔹 Server`<br>
---@param iDimension integer
---@return table<integer, true> @Map of Sound IDs in the given dimension
local function getDimensionSounds(iDimension)
    tSoundByDimension[iDimension] = tSoundByDimension[iDimension] or {}
    return tSoundByDimension[iDimension]
end

-- `🔹 Server`<br>
---@param eSound NetworkedSound
---@param iDimension integer
local function addSoundToDimension(eSound, iDimension)
    tSoundByDimension[iDimension] = tSoundByDimension[iDimension] or {}
    tSoundByDimension[iDimension][eSound:GetID()] = eSound
end

-- `🔹 Server`<br>
---@param eSound NetworkedSound
---@param iDimension integer
local function removeSoundFromDimension(eSound, iDimension)
    tSoundByDimension[iDimension] = tSoundByDimension[iDimension] or {}
    tSoundByDimension[iDimension][eSound:GetID()] = nil
end

function NetworkedSound:Constructor(tLocation, sAsset, bIs2DSound, bAutoDestroy, iSoundType, fVolume, fPitch, fInnerRadius, fFalloffDistance, iAttenuationFunction, bKeepPlayingWhenSilent, iLoopMode, bAutoPlay)
    self:SetLocation(tLocation)
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

    Timer.SetTimeout(function ()
        local iDimension = self:GetValue("dimension")
        if not iDimension then
            self:SetDimension(1)
        end
    end, 0)

    Timer.SetTimeout(self.AssignQueryPlayer, 0, self)
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
-- Sets the location of the sound
---@param tLocation Vector
function NetworkedSound:SetLocation(tLocation)
    self:SetValue("location", tLocation, true)
end

-- `🔹 Server`<br>
-- Sets the rotation of the sound
---@param tRotation Rotator
function NetworkedSound:SetRotation(tRotation)
    self:SetValue("rotation", tRotation, true)
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

-- `🔹 Server`<br>
---@param self NetworkedSound
---@param sEvent string
---@param ... any
local function broadcastEvent(self, sEvent, ...)
    local tPlayers, bAll = self:GetReplicatedPlayers()
    if bAll then
        Events.BroadcastRemote(sEvent, self:GetID(), ...)
        return
    else
        for _, pPlayer in ipairs(tPlayers) do
            Events.CallRemote(sEvent, pPlayer, self:GetID(), ...)
        end
    end
end

-- `🔹 Server`<br>
-- Starts the sound
---@param fStartTime number?
function NetworkedSound:Play(fStartTime)
    self:SetValue("play_start_time", Server.GetTime(), true)
    self:SetValue("start_time", fStartTime or 0, true)

    broadcastEvent(self, NetworkedSound.EventMap.PlaySound, fStartTime or 0)
    self:StartAutoDestroyTimer()
    self:SetValue("is_playing", true)
end

-- `🔹 Server`<br>
-- Returns the time the sound started playing
---@return number?
function NetworkedSound:GetPlayStartTime()
    return self:GetValue("play_start_time")
end

-- `🔹 Server`<br>
-- Returns the start time offset of the sound
---@return number
function NetworkedSound:GetStartTime()
    return self:GetValue("start_time", 0)
end

-- `🔹 Server`<br>
-- Plays the sound with a fade effect
---@param fFadeInDuration number
---@param fFadeVolumeLevel number?
---@param fStartTime number?
function NetworkedSound:FadeIn(fFadeInDuration, fFadeVolumeLevel, fStartTime)
    self:SetValue("play_start_time", Server.GetTime(), true)
    self:SetValue("start_time", fStartTime or 0, true)
    self:SetValue("is_playing", true)

    broadcastEvent(self, NetworkedSound.EventMap.FadeInSound, fFadeInDuration, fFadeVolumeLevel or 1, fStartTime or 0)
end

-- `🔹 Server`<br>
-- Stops the sound with a fade effect
---@param fFadeOutDuration number
---@param fFadeVolumeLevel number?
---@param bDestroyAfterFadeout boolean?
function NetworkedSound:FadeOut(fFadeOutDuration, fFadeVolumeLevel, bDestroyAfterFadeout)
    broadcastEvent(self, NetworkedSound.EventMap.FadeOutSound, fFadeOutDuration, fFadeVolumeLevel or 1, bDestroyAfterFadeout or false)

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

    self:SetValue("is_playing", not bPause)
    broadcastEvent(self, NetworkedSound.EventMap.SetPaused, bPause)
end

-- `🔹 Server`<br>
-- Stops the sound
function NetworkedSound:Stop()
    broadcastEvent(self, NetworkedSound.EventMap.FadeOutSound)
    self:ClearAutoDestroyTimer()
    self:SetValue("is_playing", false)
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
    local fDuration = self:GetValue("duration")
    if not fDuration then return end

    self:ClearAutoDestroyTimer()

    local fPlayStartTime = self:GetPlayStartTime()
    if not fPlayStartTime then return end

    if not self:IsAutoDestroy() then return end

    local fStartTimeOffset = self:GetStartTime()
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

-- `🔹 Server`<br>
-- Caches the duration of a sound asset <br>
-- This prevents the need to ask the client for the duration when spawning the sound
---@param sAsset string
---@param fDuration number
function NetworkedSound.CacheDuration(sAsset, fDuration)
    -- Check if already cached
    if NetworkedSound.AssetDurationCache[sAsset] then
        return
    end

    NetworkedSound.AssetDurationCache[sAsset] = fDuration
end

-- `🔹 Server`<br>
-- Returns the cached duration of a sound asset
---@param sAsset string
---@return number?
function NetworkedSound.GetCachedDuration(sAsset)
    return NetworkedSound.AssetDurationCache[sAsset]
end

-- `🔹 Server`<br>
-- Attaches this Sound to any other Actor, optionally at a specific bone
---@param eActor Entity
---@param iAttachmentRule AttachmentRule?
---@param sBoneName string?
function NetworkedSound:AttachTo(eActor, iAttachmentRule, sBoneName)
    self:SetValue("attached_to", eActor, true)
    self:SetValue("attached_bone", sBoneName or "", true)
    self:SetValue("attachment_rule", iAttachmentRule or AttachmentRule.SnapToTarget, true)

    broadcastEvent(self, NetworkedSound.EventMap.AttachTo, eActor, iAttachmentRule or AttachmentRule.SnapToTarget, sBoneName or "")
end

-- `🔹 Server`<br>
-- Detaches this Sound from AttachedTo Actor
function NetworkedSound:Detach()
    self:SetValue("attached_to", nil, true)
    self:SetValue("attached_bone", nil, true)
    self:SetValue("attachment_rule", nil, true)

    broadcastEvent(self, NetworkedSound.EventMap.Detach)
end

-- `🔹 Server`<br>
-- Sets the dimension of the sound
function NetworkedSound:SetDimension(iDimension)
    local iOldDimension = self:GetValue("dimension")
    if iOldDimension then
        removeSoundFromDimension(self, iOldDimension)
    end

    self:SetValue("dimension", iDimension)

    local tPlayers = {}
    for _, pPlayer in pairs(Player.GetPairs()) do
        if pPlayer:GetDimension() == iDimension then
            tPlayers[#tPlayers + 1] = pPlayer
        end
    end
    self:SetReplicatedPlayers(tPlayers)

    addSoundToDimension(self, iDimension)
end

---@param self NetworkedSound
NetworkedSound.ClassSubscribe("Destroy", function (self)
    self:ClearAutoDestroyTimer()

    local iDimension = self:GetValue("dimension")
    if iDimension then
        removeSoundFromDimension(self, iDimension)
    end
end)

local function spawn(pPlayer)
    local iDimension = pPlayer:GetDimension()

    local tSoundsInDimension = getDimensionSounds(iDimension)
    for iSoundID, _ in pairs(tSoundsInDimension) do
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then goto continue end
        ---@cast oNetworkedSound NetworkedSound
        oNetworkedSound:AddReplicatedPlayer(pPlayer)
        ::continue::
    end
end
Player.Subscribe("Spawn", spawn)

for _, pPlayer in pairs(Player.GetPairs()) do
    spawn(pPlayer)
end

Player.Subscribe("DimensionChange", function (pPlayer, iOldDimension, iNewDimension)
    local tSoundsInOldDimension = getDimensionSounds(iOldDimension)
    for iSoundID, _ in pairs(tSoundsInOldDimension) do
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then goto continue end
        ---@cast oNetworkedSound NetworkedSound
        oNetworkedSound:RemoveReplicatedPlayer(pPlayer)
        ::continue::
    end

    local tSoundsInNewDimension = getDimensionSounds(iNewDimension)
    for iSoundID, _ in pairs(tSoundsInNewDimension) do
        local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
        if not oNetworkedSound then goto continue end
        ---@cast oNetworkedSound NetworkedSound
        oNetworkedSound:AddReplicatedPlayer(pPlayer)
        ::continue::
    end
end)

---@param pPlayer Player
---@param iSoundID integer
---@param fDuration number
Events.SubscribeRemote(NetworkedSound.EventMap.DurationResponse, function (pPlayer, iSoundID, fDuration)
    if type(iSoundID) ~= "number" or type(fDuration) ~= "number" then return end

    local oNetworkedSound = NetworkedSound.GetByID(iSoundID)
    if not oNetworkedSound then return end
    ---@cast oNetworkedSound NetworkedSound

    if oNetworkedSound:GetQueryPlayer() ~= pPlayer then return end

    oNetworkedSound:SetDuration(fDuration)

    if oNetworkedSound:IsPlaying() then
        oNetworkedSound:StartAutoDestroyTimer()
    end

    NetworkedSound.CacheDuration(oNetworkedSound:GetPath(), fDuration)
end)

--[[ Timer.SetTimeout(function ()
    NetworkedSound.CacheDuration("package://networked-sounds/Client/test.mp3", 221.67)
    local eSound = NetworkedSound(Vector(), "package://networked-sounds/Client/test.mp3", true, true, SoundType.SFX, 1, 1, nil, nil, nil, nil, nil, false)
    eSound:Play()
end, 1000) ]]