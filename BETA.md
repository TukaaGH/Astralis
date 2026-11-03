# Astralis Beta

Astralis 1.1.0-beta.1 is published on the BETA GitHub branch, with the new native UI and updated protected gameplay. This branch uses its own registry, loader and UI; the emulator is byte-for-byte identical to stable. Only protected gameplay is published.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TukaaGH/Astralis/BETA/mainloader.lua"))()
```

Stable uses main/mainloader.lua. The former main/betaloader.lua entry point and duplicate beta routes were removed; use the URL above for beta. Shared assets remain where runtime code requires them.

The source and native UI passed static, isolated UI and loader checks. The supplied protected gameplay parses and compiles, but was not executed end-to-end during publication. Volt API aliases are included; live Volt compatibility is not verified.
