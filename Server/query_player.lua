local tPlayerDimensionMap = {}
local tPendingSounds = {}

---@param self NetworkedSound
NetworkedSound.Subscribe("Destroy", function (self)
    local iDimension = self:GetDimension()
    if tPendingSounds[iDimension] then
        tPendingSounds[iDimension][self] = nil
    end
end)

-- `🔹 Server`<br>
-- Finds and assigns a query player for duration requests
function NetworkedSound:AssignQueryPlayer()
    local iDimension = self:GetDimension()
    local tPlayers = tPlayerDimensionMap[iDimension]
    if not tPlayers then
        tPendingSounds[iDimension] = tPendingSounds[iDimension] or {}
        tPendingSounds[iDimension][self] = self
        return
    end

    local tPlayerList = {}
    for _, pPlayer in pairs(tPlayers) do
        table.insert(tPlayerList, pPlayer)
    end

    local pQueryPlayer = tPlayerList[math.random(1, #tPlayerList)]

    if not pQueryPlayer then return end
    self:SetValue("query_player", pQueryPlayer)

    if not NetworkedSound.AssetDurationCache[self:GetPath()] then
        Events.CallRemote(NetworkedSound.EventMap.DurationRequest, pQueryPlayer, self)
    end

    if tPendingSounds[iDimension] then
        tPendingSounds[iDimension][self] = nil
    end
end

-- `🔹 Server`<br>
-- Returns the current query player
---@return Player?
function NetworkedSound:GetQueryPlayer()
    return self:GetValue("query_player")
end

---@param pPlayer Player
local function spawn(pPlayer)
    local iDimension = pPlayer:GetDimension()
    tPlayerDimensionMap[iDimension] = tPlayerDimensionMap[iDimension] or {}
    tPlayerDimensionMap[iDimension][pPlayer] = pPlayer

    if not tPendingSounds[iDimension] then return end
    for _, eNetworkedSound in pairs(tPendingSounds[iDimension]) do
        eNetworkedSound:AssignQueryPlayer()
    end
end
Player.Subscribe("Ready", spawn)

---@param pPlayer Player
---@param iOldDimension integer
---@param iNewDimension integer
local function dimensionChange(pPlayer, iOldDimension, iNewDimension)
    if tPlayerDimensionMap[iOldDimension] then
        tPlayerDimensionMap[iOldDimension][pPlayer] = nil
    end

    tPlayerDimensionMap[iNewDimension] = tPlayerDimensionMap[iNewDimension] or {}
    tPlayerDimensionMap[iNewDimension][pPlayer] = pPlayer

    if not tPendingSounds[iNewDimension] then return end
    for _, eNetworkedSound in pairs(tPendingSounds[iNewDimension]) do
        eNetworkedSound:AssignQueryPlayer()
    end
end
Player.Subscribe("DimensionChange", dimensionChange)

local function playerDestroy(pPlayer)
    local iDimension = pPlayer:GetDimension()
    if tPlayerDimensionMap[iDimension] then
        tPlayerDimensionMap[iDimension][pPlayer] = nil
    end
end
Player.Subscribe("Destroy", playerDestroy)

for _, pPlayer in pairs(Player.GetPairs()) do
    spawn(pPlayer)
end