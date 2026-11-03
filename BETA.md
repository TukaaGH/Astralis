# Astralis Beta

Astralis 1.1.0-beta.1 uses the BETA GitHub branch, its own canonical loader and native UI, and the protected gameplay supplied as d.protected (11).lua. The emulator remains identical to stable.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TukaaGH/Astralis/BETA/mainloader.lua"))()
```

The November 3 UI hotfix waits for a usable respawn rig before replacing the preview, cancels stale retries and copies only visible body parts and clothing. It passed 27 isolated respawn checks and 78 native UI/cleanup checks. The protected gameplay remains unchanged. Additional frame, input-gate and motion-discovery performance fixes are staged locally and are not in this protected payload yet. Live gameplay respawn frame times have not been verified.

Stable uses main/mainloader.lua. The former main/betaloader.lua route was removed. No plaintext gameplay is published. Live Volt compatibility remains unverified.
