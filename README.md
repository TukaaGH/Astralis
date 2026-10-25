# Astralis

Free, keyless controls for [Fust Survival](https://www.roblox.com/games/79862723087324).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TukaaGH/Astralis/main/mainloader.lua"))()
```

## Features

- Silent aim with adjustable FOV, hit chance, and optional NPC targeting.
- Adjustable recoil and spread.
- Player and NPC visuals: boxes, names, distance, health, and weapons.
- Perfect farm targets the current red weak point during normal gathering swings.
- Freecam, smooth Zoom with a target FOV slider, and FOV adjustment.
- No bob, No sway, Remove Grass, Remove Fog, and Always Day.
- Rebindable camera keys, visual customization, Reset world, and Unload.

## Controls

RightShift opens the menu. Freecam defaults to F6. Enable Zoom and hold Z to zoom; its target FOV and key are adjustable. Freecam uses WASD, E/Space to rise, Q/LeftCtrl to descend, and LeftShift to move faster. Hide the menu to navigate with Freecam.

Perfect farm preserves normal swing timing and reach. It needs an existing red weak point; the first hit on an unmarked resource remains manual.

## Executors

Supported list: Potassium, Volt, Madium, Wave, Synapse Z, Real, Volcano, Isaeva, Opiumware, and MacSploit. Executor names are matched without case sensitivity. Synz and Synapze Z are accepted aliases for Synapse Z.

The loader checks required APIs before starting. Runtime verification currently covers Potassium; compatibility with every version of the other listed executors has not been independently verified.

## Support

[Discord](https://discord.gg/fXwShKMAb7)

## Repository layout

`mainloader.lua` selects a game using `supportedGames.lua`. The registry chooses a versioned game entry point and obfuscated payload. `assets/` contains the public UI and ESP libraries. Existing root library URLs remain available for previous builds.

The game implementation is distributed as an obfuscated build. See LICENSE and NOTICE for the public libraries and their attribution.
