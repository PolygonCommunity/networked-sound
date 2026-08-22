-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local CACHE_FILE <const> = "networked_sound_durations.json"

local MIN_DURATION <const> = 0.05
local MAX_DURATION <const> = 600

local bCacheDirty = false
local iSaveTimer = nil

-- `🔹 Server`<br>
---@param fDuration any
---@return number?
local function sanitizeDuration(fDuration)
    if type(fDuration) ~= "number" then return nil end
    if fDuration ~= fDuration then return nil end

    if fDuration < MIN_DURATION then return MIN_DURATION end
    if fDuration > MAX_DURATION then return MAX_DURATION end

    return fDuration
end

-- `🔹 Server`<br>
-- Writes the cache to disk
local function saveCache()
    if iSaveTimer then
        Timer.ClearTimeout(iSaveTimer)
        iSaveTimer = nil
    end

    if not bCacheDirty then return end
    bCacheDirty = false

    local oFile = File(CACHE_FILE, true)
    oFile:Write(JSON.stringify(NetworkedSound.AssetDurationCache))
    oFile:Close()

    Console.Debug("[NetworkedSound] Persisted the duration cache")
end

-- `🔹 Server`<br>
local function scheduleSave()
    bCacheDirty = true
    if iSaveTimer then return end

    iSaveTimer = Timer.SetTimeout(saveCache, 5000)
end

-- `🔹 Server`<br>
local function loadCache()
    if not File.Exists(CACHE_FILE) then return end

    local oFile = File(CACHE_FILE)
    oFile:ReadJSONAsync(function (tCache)
        oFile:Close()

        if type(tCache) ~= "table" then
            Console.Warn("[NetworkedSound] Failed to read the duration cache, ignoring it")
            return
        end

        local iCount = 0
        for sAsset, fDuration in pairs(tCache) do
            local fSanitizedDuration = type(sAsset) == "string" and sanitizeDuration(fDuration) or nil
            if fSanitizedDuration then
                NetworkedSound.AssetDurationCache[sAsset] = fSanitizedDuration
                iCount = iCount + 1
            end
        end

        Console.Log("[NetworkedSound] Restored " .. iCount .. " cached asset durations")
    end)
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
    scheduleSave()

    Console.Debug("[NetworkedSound] Cached duration of asset '" .. sAsset .. "' as " .. tostring(fDuration) .. " seconds")
end

-- `🔹 Server`<br>
-- Returns the cached duration of a sound asset
---@param sAsset string
---@return number?
function NetworkedSound.GetCachedDuration(sAsset)
    return NetworkedSound.AssetDurationCache[sAsset]
end

-- `🔹 Server`<br>
-- Forgets the cached duration of a single asset, so it gets queried again<br>
-- Use it when the asset file behind a path has changed
---@param sAsset string
function NetworkedSound.ForgetDuration(sAsset)
    if NetworkedSound.AssetDurationCache[sAsset] == nil then return end

    NetworkedSound.AssetDurationCache[sAsset] = nil
    scheduleSave()
end

-- `🔹 Server`<br>
-- Forgets every cached duration and resets the cache file
function NetworkedSound.ClearDurationCache()
    NetworkedSound.AssetDurationCache = {}
    bCacheDirty = true
    saveCache()
end

---@param pPlayer Player
---@param eNetworkedSound NetworkedSound
---@param fDuration number
Events.SubscribeRemote(NetworkedSound.EventMap.DurationResponse, function (pPlayer, eNetworkedSound, fDuration)
    if not eNetworkedSound or not eNetworkedSound:IsValid() or not eNetworkedSound:IsA(NetworkedSound) then
        return
    end

    if not eNetworkedSound:IsQueryAnswer(pPlayer) then
        return
    end

    local fSanitizedDuration = sanitizeDuration(fDuration)
    if not fSanitizedDuration then return end

    local sAsset = eNetworkedSound:GetPath()

    NetworkedSound.CacheDuration(sAsset, fSanitizedDuration)
    NetworkedSound.ResolveDuration(sAsset, fSanitizedDuration)
end)

Package.Subscribe("Unload", saveCache)

loadCache()