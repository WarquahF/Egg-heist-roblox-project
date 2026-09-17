# Egg Heist — Beta Development Foundation

Multiplayer Roblox game loop: **Train → Steal → Escape → Return → Hatch → Collect → Upgrade → Repeat.**

This repo contains the **Beta foundation only**: project structure, service boundaries,
server-authoritative placeholders, config, docs, and test scaffolding.
Humans own gameplay logic, economy, security tuning, and final art.

> AI builds the foundation. Humans understand the systems.
> The server owns the truth. GitLab owns the history.
> Beta proves the gameplay loop. Final art comes later.

## Layout

```text
src/shared/   -> ReplicatedStorage.Shared (Types, Constants, Config, EggStateMachine, RemoteNames)
src/server/   -> ServerScriptService.Server (Services + ServerMain.server.luau)
src/client/   -> StarterPlayerScripts.Client (Controllers + ClientMain.client.luau)
tests/        -> TestEZ specs (run in Studio)
docs/         -> Beta checklist and notes
```

See `DEVELOPMENT.md` for architecture, how-to guides, and testing.

## Quickstart (Linux dev + Studio playtest)

1. Install toolchain: `aftman install` (provides `rojo`, `wally`, `stylua`, `selene`).
2. Serve: `rojo serve default.project.json`
3. In Roblox Studio (Windows/macOS): connect the Rojo plugin to `localhost:34872`.
4. Playtest in Studio with 2–4 players (Test tab → Clients and Servers) for the Beta loop.
5. Lint/format before pushing: `stylua --check src tests` and `selene src tests`.

## Beta loop status

Foundation scaffolding with explicit TODOs for human developers.
Nothing here is final balance, final art, or monetization (all intentionally excluded).
