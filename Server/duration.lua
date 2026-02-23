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
    Console.Debug("[NetworkedSound] Cached duration of asset '" .. sAsset .. "' as " .. tostring(fDuration) .. " seconds.")
end

-- `🔹 Server`<br>
-- Returns the cached duration of a sound asset
---@param sAsset string
---@return number?
function NetworkedSound.GetCachedDuration(sAsset)
    return NetworkedSound.AssetDurationCache[sAsset]
end

---@param pPlayer Player
---@param eNetworkedSound NetworkedSound
---@param fDuration number
Events.SubscribeRemote(NetworkedSound.EventMap.DurationResponse, function (pPlayer, eNetworkedSound, fDuration)
    if not eNetworkedSound or not eNetworkedSound:IsValid() or not eNetworkedSound:IsA(NetworkedSound) then return end
    if type(fDuration) ~= "number" then return end
    if eNetworkedSound:GetQueryPlayer() ~= pPlayer then return end

    eNetworkedSound:SetDuration(fDuration)

    if eNetworkedSound:IsPlaying() then
        eNetworkedSound:UpdateLifeSpan()
    end

    NetworkedSound.CacheDuration(eNetworkedSound:GetPath(), fDuration)
    eNetworkedSound:SetValue("query_player", nil)
end)