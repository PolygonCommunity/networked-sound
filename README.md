# 🔊 Networked Sound

`Networked Sound` is a nanos world package allowing to spawn and control Sound entities from serverside with full client sync

## ✨ Features

- Spawn and control sounds from the server
- Same API as the native clientside [Sound class](https://docs.nanos-world.com/docs/next/scripting-reference/classes/sound)
- Automatically queries duration from clients and caches it
- Late-joining players hear sounds at their current playback position
- Sounds replicate only to players in the same dimension
- Attach sounds to entities
- Fully documented with LuaLS annotations

## 📦 Installation

1. Download the package
2. Place it in your server's `Packages/` directory
3. Add `networked-sound` to your server configuration

## 🚀 Usage
```lua
local my_sound = NetworkedSound(
    Vector(-510, 145, 63), -- Location (if a 3D sound)
    "nanos-world::A_VR_Confirm", -- Asset Path
    false, -- Is 2D Sound
    true, -- Auto Destroy (if to destroy after finished playing)
    SoundType.SFX,
    1, -- Volume
    1 -- Pitch
)
```


Manually cache sound durations to prevent querying clients:
```lua
-- Cache durations at server startup
NetworkedSound.CacheDuration("package://my-package/Client/Sounds/sfx1.mp3", 1.2)
NetworkedSound.CacheDuration("package://my-package/Client/Sounds/sfx2.mp3", 2.5)
NetworkedSound.CacheDuration("package://my-package/Client/Sounds/sfx3.mp3", 0.4)
```

## 🎛️ Custom backends

By default sounds are played through the native `Sound` class, but you can implement your own backend to use a different audio system.

```lua
-- Client
---@type NetworkedSoundBackend
local tBackend = {
    spawn = function (self) end,
    destroy = function (self) end,
}

NetworkedSound.RegisterBackend("my-backend", tBackend)
```

You can make your backend the default for all sounds using `NetworkedSound.SetDefaultBackend("my-backend")`, or select one per sound serverside with `sound:SetBackend("my-backend")`.

## 💥 Fire and forget sounds

A gunshot or an impact needs no pause, no fade and no late-joiner resync, so it needs no entity either. PlayAt sends a single event to the players who can hear it. Nothing is replicated and the client instance destroys itself when done.

```lua
NetworkedSound.PlayAt(tImpactLocation, "nanos-world::A_Explosion_Distant", {
    volume = 0.8,
    falloff_distance = 5000,
})
```

Use a real `NetworkedSound` whenever you need to control the sound after it starts.

## 💾 Duration cache

The cache is saved to `networked_sound_durations.json` at the server root and reloaded on start, so each asset is queried once across the server's lifetime.

Queries are deduplicated per asset and retried on another player if the first doesn't answer within 5 seconds.