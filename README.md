# iZaap NPC Doctor https://discord.gg/j79bSAptDN

Simple NPC doctor that lets players get treated at fixed locations.

## Features
- Spawns one or multiple doctor peds from config
- Works with **qb-ambulancejob** (dead/laststand detection + revive)
- Heals players if they’re alive, revives them if they’re down
- Progress bar support (QB progressbar / progressbar resource)
- Interaction support:
  - **ox_target**
  - **qb-target**
  - **jg-textui** (press E)
- Optional map blip

## Requirements
- **QB-Core** (or QBX) recommended  
- **qb-ambulancejob** (for revive events)
- One of these for interaction:
  - ox_target / qb-target / jg-textui
- One of these for progress:
  - qb-core progressbar functions or `progressbar` resource

## Installation
1. Drop the resource in your server resources folder
2. Add it to your `server.cfg`:
   - `ensure izaap_npc_doctor`
3. Configure locations and options in `config.lua`

## Basic Config
- **Doctors / Locations**
  - `Config.Doctors` (list) or `Config.Doctor` (single)
- **Price / Cooldown**
  - `Config.Price`
  - `Config.CooldownMs`
- **Blip**
  - `Config.Blip.Enabled = true/false`
  - `Sprite / Scale / Color / Name`
- **Revive event**
  - `Config.ReviveEvent = "qb"` (default) or `"qbplayer"` or `"custom"`
  - If custom: `Config.CustomReviveEvent = "your:event:name"`

## Notes
- If you use `ox_target`, it will be used automatically when started.
- When a player is down (dead/laststand), the script avoids playing animations to prevent conflicts.

## Support
If your server uses a different ambulance/hospital resource, set a custom revive event in the config.

https://discord.gg/j79bSAptDN
