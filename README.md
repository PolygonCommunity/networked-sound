# 🔊 Networked Sound

`Networked Sound` is a nanos world package allowing to spawn and control Sound entities from serverside with full client sync

## ✨ Features

- **Server-side Sounds** - Control sounds from the server
- **1:1 API** - Exact same API as the native clientside [Sound class](https://docs.nanos-world.com/docs/next/scripting-reference/classes/sound)
- **Auto Duration Query** - Automatically queries duration from clients and caches it
- **Time Sync** - Late-joining players hear sounds at the correct position
- **Dimension Support** - Sounds replicate only to players in the same dimension
- **Attachment System** - Attach sounds to entities
- **Lua Documentation** - Fully documented with LuaLS annotations

## 📦 Installation

1. Download the package
2. Place it in your server's `Packages/` directory
3. Add `networked-sounds` to your server configuration

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
