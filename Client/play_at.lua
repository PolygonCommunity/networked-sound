-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

local PlayAtIndex = NetworkedSound.PlayAtIndex

---@param tPayload table
Events.SubscribeRemote(NetworkedSound.EventMap.PlayAt, function (tPayload)
    if type(tPayload) ~= "table" then return end

    local sAsset = tPayload[PlayAtIndex.Path]
    if type(sAsset) ~= "string" then return end

    local tBackend = NetworkedSound.GetBackend(tPayload[PlayAtIndex.Backend])
    if not tBackend then return end

    if not tBackend.play_at then
        Console.Warn("[NetworkedSound] Backend has no play_at implementation")
        return
    end

    tBackend.play_at({
        path = sAsset,
        location = tPayload[PlayAtIndex.Location] or Vector(),
        is_2d = tPayload[PlayAtIndex.Is2D] or false,
        volume = tPayload[PlayAtIndex.Volume] or 1,
        pitch = tPayload[PlayAtIndex.Pitch] or 1,
        sound_type = tPayload[PlayAtIndex.SoundType] or SoundType.SFX,
        inner_radius = tPayload[PlayAtIndex.InnerRadius] or 400,
        falloff_distance = tPayload[PlayAtIndex.FalloffDistance] or 3600,
        attenuation_function = tPayload[PlayAtIndex.AttenuationFunction] or AttenuationFunction.Linear,
    })
end)