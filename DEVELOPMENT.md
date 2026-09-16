# DEVELOPMENT.md — Egg Heist Beta Foundation

Audience: student developer who can open Studio and run `rojo serve`.
Keep it small: if a system is not needed for the Beta loop, it is not here.

---

## 1. Architecture

```text
src/shared/   -> ReplicatedStorage.Shared   (no game APIs with side effects)
src/server/   -> ServerScriptService.Server (authority: data, eggs, chasers)
src/client/   -> StarterPlayerScripts.Client (presentation: input, UI, prompts)
tests/        -> TestEZ specs (Studio)
docs/         -> checklists
```

Rojo mapping lives in `default.project.json`. `src/server/ServerMain.server.luau`
and `src/client/ClientMain.client.luau` are the ONLY entry points; everything else
is a ModuleScript required from them.

Rules:

- **Server owns the truth.** Coins, speed, inventory, egg state, rewards, plots.
- **Client presents.** It fires intents and renders broadcasts. It never writes state.
- **Shared is dumb.** Types, constants, config, state-transition answers, remote names.
- **Server-to-server = direct calls.** RemoteEvents are client↔server only.

---

## 2. Server / client responsibilities

| Concern | Server | Client |
|---|---|---|
| Plot assignment | `PlotService` assigns/releases | Receives `PlotAssigned`, teleports camera/spawn |
| Training / speed | `TrainingService` validates + sets `Humanoid.WalkSpeed` | Fires `RequestTrain` (pad prompt / UI button) |
| Eggs | `EggService` owns state machine + carrier | Fires `RequestTakeEgg` / `RequestDeliverEgg`, shows state |
| Chasers | `ChaserService` targets carrier only | Renders NPC (no targeting logic) |
| Hatching | `HatchService` validates + rolls pool + writes inventory | Fires `RequestHatch`, shows `InventoryUpdated` |
| Data | `PlayerDataService` ONLY module touching DataStores | Never touches data |

---

## 3. Services

```text
PlayerDataService  Load/save/defaults, AddReward. Sole DataStore user.
PlotService        ClaimFreePlot / ReleasePlayerPlot / GetPlotForPlayer.
TrainingService    RequestTrain (cooldown + level cap), ApplySpeed.
EggService         RegisterEgg, RequestTakeEgg, RequestDeliverEgg, ResetEgg,
                   MarkHatched, ReleasePlayerEggs. Fires Claimed/Freed signals.
ChaserService      SetTargetToCarrier / ClearTarget / ClearTargetsForPlayer,
                   BindNpc, placeholder follow loop (carrier ONLY).
HatchService       RequestHatch (must be DELIVERED), weighted pool roll.
```

Wiring (in `ServerMain.server.luau`): `EggService.Claimed → ChaserService.SetTargetToCarrier`,
`EggService.Freed → ChaserService.ClearTarget`. Signals (BindableEvents) avoid a
require cycle between Egg and Chaser. Add new cross-service links the same way:
expose a signal, connect it in `ServerMain`, never `require` sideways.

---

## 4. Egg state machine

```text
AVAILABLE -> CLAIMED -> CARRIED -> DELIVERED -> HATCHED
CLAIMED -> AVAILABLE  (reset / carrier left)
CARRIED -> AVAILABLE  (drop / carrier left / reset)
```

- Lives in `src/shared/EggStateMachine.luau` (pure, dependency-free, unit-tested).
- `EggService` is the only writer; every mutation goes through `AssertTransition`.
- `HATCHED` is terminal in Beta. To respawn eggs, add an explicit `RESPAWNING`
  state + timer in `EggService` (do NOT silently reset HATCHED → AVAILABLE; keep
  the transition table honest). Test in `tests/EggStateMachine.spec.luau`.

---

## 5. Chaser targeting

The critical invariant: **`ChaserService._targets[eggId] == CarrierUserId`**.

- Set ONLY in `ServerMain` from `EggService.Claimed(player, eggId)`.
- Cleared on deliver / reset / carrier-leave (`EggService.Freed`, `PlayerRemoving`).
- The follow loop iterates `_targets` and `MoveTo`s the CARRIER's position.
  There is deliberately NO nearest-player search anywhere in the file — if you add
  pathfinding/leash/stun later, keep reading the target from this table.
- `GetTarget(eggId)` exists so tests and debug commands can assert the relation.

---

## 6. Client/server communication

Remote names are defined ONCE in `src/shared/RemoteNames.luau`.

```text
C -> S : RequestTrain | RequestTakeEgg(eggId) | RequestDeliverEgg(eggId) | RequestHatch(eggId)
S -> C : InventoryUpdated | PlotAssigned | EggStateChanged | SpeedChanged
```

Server creates them at boot (`Remotes.EnsureAll`); client waits for them
(`ClientRemotes.Get`). Every C→S handler validates, in order:

1. Argument types sane (`typeof(eggId) == "string"`)
2. Rate limit (cooldown per player)
3. Game state (`AVAILABLE`? already carrying? correct `CarrierUserId`?)
4. Proximity (`MAX_INTERACT_DISTANCE`; plot check is a marked TODO)
5. Mutate + broadcast (one `FireClient`/`FireAllClients` per change, not per frame)

---

## 7. How to run

Linux dev machine + Studio on Windows/macOS (Studio does not run natively on Linux):

```bash
aftman install
rojo serve default.project.json
```

In Studio with the Rojo plugin: connect to `localhost:34872`, then Playtest
(F5 for 1 player; Test tab → Clients and Servers → 2–4 players for multiplayer).
The dev placeholder map (4 plots, runway, 3 eggs, 3 chasers) builds itself on first
run via `DEV_BUILD_PLACEHOLDERS` in `ServerMain`. Set it to `false` once the real
map exists — Services only need `EggId`/`ChaserId`/`PlotId` attributes + prompts.

Lint/format before pushing:

```bash
stylua src tests
selene src tests
```

---

## 8. How to test

- Unit: `tests/EggStateMachine.spec.luau` (TestEZ in Studio). Covers happy path,
  resets, and rejected transitions like `HATCHED → CARRIED`.
- Manual Beta: `docs/BETA_CHECKLIST.md` — single player, 2–4 players, edge cases
  (leave-while-carrying, double-claim, spam, far interact, hatch-with-nothing).
- Headless CI is a TODO: current `.gitlab-ci.yml` only asserts the foundation files
  exist. Do not claim CI covers gameplay until TestEZ runs headless.

---

## 9. How to add things

**New egg:** add one entry to `src/shared/Config/Eggs.luau` (`Rarity`, `HatchPoolId`,
`ChaserId`, placeholder color), place a Part in the map with attribute
`EggId = "<SameKey>"` + a `TakePrompt`, and a chaser Model with the same `EggId`.
`EggService` auto-registers `EggId`-tagged parts; no service edits needed.

**New reward:** append to the right pool in `src/shared/Config/Rewards.luau`
(`RewardId`, `Rarity`, `Name`, `CoinValue`, `Weight`). Use fictional `Creator_NNN`
IDs only (see §11). `HatchService` rolls weights automatically.

**New service:** create `src/server/Services/<Name>Service.luau` with
`Init(deps)`/`Start()`, require it ONLY in `ServerMain.server.luau`, passdeps
explicitly, and use signals for cross-service events. Do not `require` another
service directly. Document its ownership in §3 above.

---

## 10. How to contribute (GitLab)

- Branch from `main`: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
- One focused commit per step (see `README` history), e.g.
  `feat: add egg state model`, `test: add egg state tests`. Never one giant commit.
- Push, open a Merge Request, fill in: what loop step it touches, how you
  playtested (players count), checklist results. Keep MRs small enough to review
  in one sitting. `main` stays playable: the Beta loop must not regress.

---

## 11. IP rule

No real streamer/creator names, likenesses, voices, logos, or branding anywhere.
`Creator_001…` in `Rewards.luau` are fictional placeholders. The art/content team
replaces models/names later; systems store opaque `RewardId` strings so no code
changes are needed. Never hardcode a real person into config or code.

## 12. What is intentionally NOT in Beta

Monetization, gamepasses, dev products, trading, PvP, pets, clans, leaderboards
(beyond placeholders), quests, dailies, battle passes, economy tuning, matchmaking,
voice, real creator content, final art/animations, big UI. See the Beta checklist:
if it is not on the loop Join→Plot→Train→Steal→Chase→Escape→Return→Hatch, it waits.
