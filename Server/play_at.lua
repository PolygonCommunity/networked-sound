-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local PlayAtIndex = NetworkedSound.PlayAtIndex

---@class PlayAtOptions
---@field is_2d boolean?
---@field volume number?
---@field pitch number?
---@field sound_type SoundType?
---@field inner_radius number?
---@field falloff_distance number? Defaults to 3600
---@field attenuation_function AttenuationFunction?
---@field dimension integer? Defaults to 0
---@field backend string? Client backend to render it with
---@field reliability Reliability? Defaults to Reliability.Reliable
---@field players Player[]? Explicitly send to these players instead of broadcasting to the dimension

-- `🔹 Server`<br>
-- Plays a sound directly, without creating a NetworkedSound instance <br>
-- The sound is played on the clients, and the server has no control over it
---@param tLocation Vector
---@param sAsset string
---@param tOptions PlayAtOptions?
function NetworkedSound.PlayAt(tLocation, sAsset, tOptions)
    assert(type(sAsset) == "string", "asset must be a string")
    tOptions = tOptions or {}

    local tPayload = {}
    tPayload[PlayAtIndex.Path] = sAsset
    tPayload[PlayAtIndex.Location] = tLocation
    tPayload[PlayAtIndex.Is2D] = tOptions.is_2d
    tPayload[PlayAtIndex.Volume] = tOptions.volume
    tPayload[PlayAtIndex.Pitch] = tOptions.pitch
    tPayload[PlayAtIndex.SoundType] = tOptions.sound_type
    tPayload[PlayAtIndex.InnerRadius] = tOptions.inner_radius
    tPayload[PlayAtIndex.FalloffDistance] = tOptions.falloff_distance
    tPayload[PlayAtIndex.AttenuationFunction] = tOptions.attenuation_function
    tPayload[PlayAtIndex.Backend] = tOptions.backend

    local iDimension = tOptions.dimension or 0
    local eReliability = tOptions.reliability or Reliability.Reliable

    if tOptions.players then
        for _, pPlayer in ipairs(tOptions.players) do
            Events.CallRemote(NetworkedSound.EventMap.PlayAt, pPlayer, eReliability, tPayload)
        end
        return
    end

    -- No position to cull against, everyone in the dimension hears it
    if tOptions.is_2d then
        Events.BroadcastRemoteDimension(
            NetworkedSound.EventMap.PlayAt,
            iDimension,
            eReliability,
            tPayload
        )
        return
    end

    Events.BroadcastRemoteInRadiusDimension(
        NetworkedSound.EventMap.PlayAt,
        tLocation,
        tOptions.falloff_distance or 3600,
        iDimension,
        eReliability,
        tPayload
    )
end