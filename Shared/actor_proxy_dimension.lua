local tActorByDimension = {}

if Server then
    local function removeActor(eActor, iDimension)
        tActorByDimension[iDimension] = tActorByDimension[iDimension] or {}
        tActorByDimension[iDimension][eActor] = nil

        if not next(tActorByDimension[iDimension]) then
            tActorByDimension[iDimension] = nil
        end
    end

    function ActorProxy:Constructor()
        Timer.SetTimeout(function ()
            if not self:IsValid() then return end
            if self:GetDimension() == 1 and self:IsAutoReplicationEnabled() then
                self:SetDimension(1)
            end
        end, 0)
    end

    function ActorProxy:Destructor()
        local iDimension = self:GetValue("dimension")
        if iDimension then
            removeActor(self, iDimension)
        end
    end

    -- `🔹 Server`<br>
    -- Sets whether auto replication based on dimension is enabled for this Actor Proxy
    ---@param bEnabled boolean
    function ActorProxy:SetAutoReplicationEnabled(bEnabled)
        self:SetValue("auto_dimension_replication", bEnabled)

        local iDimension = self:GetValue("dimension")
        if not bEnabled and iDimension then
            removeActor(self, iDimension)
        end
    end

    -- `🔹 Server`<br>
    -- Returns whether auto replication based on dimension is enabled for this Actor Proxy
    ---@return boolean
    function ActorProxy:IsAutoReplicationEnabled()
        return self:GetValue("auto_dimension_replication", true)
    end

    -- `🔹 Server`<br>
    ---@param iDimension integer
    function ActorProxy:SetDimension(iDimension)
        if not self:IsAutoReplicationEnabled() then
            Console.Warn("ActorProxy `%s#%d` tried to set dimension but auto replication is disabled", self:GetClassName(), self:GetID())
            return
        end

        local iOldDimension = self:GetValue("dimension")
        if iOldDimension == iDimension then return end

        if iOldDimension then
            removeActor(self, iOldDimension)
        end

        self:SetValue("dimension", iDimension, true)

        local tPlayers = {}
        for _, pPlayer in pairs(Player.GetPairs()) do
            if pPlayer:GetDimension() == iDimension then
                tPlayers[#tPlayers + 1] = pPlayer
            end
        end
        self:SetReplicatedPlayers(tPlayers)

        tActorByDimension[iDimension] = tActorByDimension[iDimension] or {}
        tActorByDimension[iDimension][self] = true
        Console.Log("ActorProxy `%s#%d` set to dimension `%d`", self:GetClassName(), self:GetID(), iDimension)
    end

    ---@param pPlayer Player
    local function playerSpawn(pPlayer)
        local iDimension = pPlayer:GetDimension()

        local tDimensionActors = tActorByDimension[iDimension]
        if not tDimensionActors then return end

        -- Replicate all actors in this dimension to the player
        for eActorProxy, _ in pairs(tDimensionActors) do
            eActorProxy:AddReplicatedPlayer(pPlayer)
        end
    end
    Player.Subscribe("Spawn", playerSpawn)

    local function playerDimensionChange(pPlayer, iOldDimension, iNewDimension)
        -- Remove from old dimension actors
        local tOldDimensionActors = tActorByDimension[iOldDimension]
        if tOldDimensionActors then
            for eActorProxy, _ in pairs(tOldDimensionActors) do
                eActorProxy:RemoveReplicatedPlayer(pPlayer)
            end
        end

        -- Add to new dimension actors
        local tNewDimensionActors = tActorByDimension[iNewDimension]
        if tNewDimensionActors then
            for eActorProxy, _ in pairs(tNewDimensionActors) do
                eActorProxy:AddReplicatedPlayer(pPlayer)
            end
        end
    end
    Player.Subscribe("DimensionChange", playerDimensionChange)

    for _, pPlayer in pairs(Player.GetPairs()) do
        playerSpawn(pPlayer)
    end
end

---`🔸 Client`<br>`🔹 Server`<br>
---@return integer
function ActorProxy:GetDimension()
    return self:GetValue("dimension", 1)
end