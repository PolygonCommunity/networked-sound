-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

---@type table<string, table<NetworkedSound, boolean>>
local tWaitingSounds = {}

---@type table<NetworkedSound, string>
local tSoundAsset = {}

---@type table<string, {sound: NetworkedSound, player: Player, timer: integer, tried: table<Player, boolean>, attempts: integer}>
local tActiveQueries = {}

local attemptQuery

-- `🔹 Server`<br>
---@param self NetworkedSound
local function forgetSound(self)
    local sAsset = tSoundAsset[self]
    tSoundAsset[self] = nil
    if not sAsset then return end

    local tWaiting = tWaitingSounds[sAsset]
    if not tWaiting then return end

    tWaiting[self] = nil
    if next(tWaiting) == nil then
        tWaitingSounds[sAsset] = nil
    end
end

-- `🔹 Server`<br>
---@param sAsset string
local function stopQuery(sAsset)
    local tQuery = tActiveQueries[sAsset]
    if not tQuery then return end

    tActiveQueries[sAsset] = nil
    if tQuery.timer then
        Timer.ClearTimeout(tQuery.timer)
    end
end

-- `🔹 Server`<br>
---@param sAsset string
---@param tTried table<Player, boolean>
---@return NetworkedSound?, Player?
local function pickQueryTarget(sAsset, tTried)
    local tWaiting = tWaitingSounds[sAsset]
    if not tWaiting then return nil, nil end

    for eSound in pairs(tWaiting) do
        if not eSound:IsValid() then
            tWaiting[eSound] = nil
            tSoundAsset[eSound] = nil
        else
            local pAuthority = eSound:GetNetworkAuthority()
            if pAuthority and pAuthority:IsValid() and not tTried[pAuthority] then
                return eSound, pAuthority
            end
        end
    end

    return nil, nil
end

-- `🔹 Server`<br>
---@param sAsset string
---@param tTried table<Player, boolean>
---@param iAttempts integer
attemptQuery = function (sAsset, tTried, iAttempts)
    stopQuery(sAsset)

    if NetworkedSound.GetCachedDuration(sAsset) then return end

    if iAttempts >= 3 then
        Console.Warn("[NetworkedSound] No player answered the duration of asset '" .. sAsset .. "', keeping the fallback")
        return
    end

    local eSound, pQueryPlayer = pickQueryTarget(sAsset, tTried)
    if not eSound or not pQueryPlayer then return end

    tTried[pQueryPlayer] = true

    tActiveQueries[sAsset] = {
        sound = eSound,
        player = pQueryPlayer,
        tried = tTried,
        attempts = iAttempts + 1,
        timer = Timer.SetTimeout(function ()
            attemptQuery(sAsset, tTried, iAttempts + 1)
        end, 5000),
    }

    Events.CallRemote(NetworkedSound.EventMap.DurationRequest, pQueryPlayer, Reliability.Reliable, eSound)
end

-- `🔹 Server`<br>
-- Registers a sound to be queried for its duration, if the server doesn't have it cached yet
function NetworkedSound:RequestDuration()
    local sAsset = self:GetPath()
    if not sAsset then return end
    if NetworkedSound.GetCachedDuration(sAsset) then return end

    tSoundAsset[self] = sAsset
    tWaitingSounds[sAsset] = tWaitingSounds[sAsset] or {}
    tWaitingSounds[sAsset][self] = true
end

-- `🔹 Server`<br>
-- Returns the player currently asked for this sound asset duration
---@return Player?
function NetworkedSound:GetQueryPlayer()
    local tQuery = tActiveQueries[self:GetPath()]
    return tQuery and tQuery.player
end

-- `🔹 Server`<br>
-- Returns whether this player and sound are the ones we asked
---@param pPlayer Player
---@return boolean
function NetworkedSound:IsQueryAnswer(pPlayer)
    local tQuery = tActiveQueries[self:GetPath()]
    return tQuery ~= nil and tQuery.player == pPlayer and tQuery.sound == self
end

-- `🔹 Server`<br>
---@param sAsset string
---@param fDuration number
function NetworkedSound.ResolveDuration(sAsset, fDuration)
    stopQuery(sAsset)

    local tWaiting = tWaitingSounds[sAsset]
    tWaitingSounds[sAsset] = nil
    if not tWaiting then return end

    for eSound in pairs(tWaiting) do
        tSoundAsset[eSound] = nil

        if eSound:IsValid() then
            eSound:SetDuration(fDuration)
            eSound:UpdateLifeSpan()
        end
    end
end

---@param self NetworkedSound
---@param pOldAuthority Player?
---@param pNewAuthority Player?
NetworkedSound.Subscribe("NetworkAuthorityChange", function (self, pOldAuthority, pNewAuthority)
    local sAsset = tSoundAsset[self]
    if not sAsset then return end

    local tQuery = tActiveQueries[sAsset]

    if tQuery and tQuery.sound == self and tQuery.player == pOldAuthority then
        attemptQuery(sAsset, tQuery.tried, tQuery.attempts)
        return
    end

    if not tQuery and pNewAuthority then
        attemptQuery(sAsset, {}, 0)
    end
end)

NetworkedSound.Subscribe("Destroy", forgetSound)