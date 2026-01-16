-- Copyright (C) 2026 NegativeName
-- SPDX-License-Identifier: GPL-3.0-or-later

Package.Require("networked_sound.lua")
Package.Require("duration.lua")
Package.Require("query_player.lua")

Timer.SetTimeout(function ()
    local eSoundInstance = NetworkedSound(Vector(), "package://networked-sound/Client/test.mp3", false)

    Timer.SetTimeout(function ()
        eSoundInstance:SetPaused(true)
    
        Timer.SetTimeout(function ()
            eSoundInstance:SetPaused(false)
        end, 500)
    end, 500)
end, 2000)