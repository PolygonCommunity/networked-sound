-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

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