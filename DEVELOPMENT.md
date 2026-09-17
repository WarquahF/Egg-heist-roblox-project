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
                   Guarded loads, BindToClose flush, capped inventory restore.
PlotService        ClaimFreePlot (idempotent) / ReleasePlayerPlot /
                   GetPlotForPlayer / OwnsPlot. NOTHING else.
TrainingService    RequestTrain (cooldown + own plot + own-pad proximity +
                   level cap), ApplySpeed. Sole WalkSpeed writer.
EggService         RegisterEgg, RequestTakeEgg, RequestDeliverEgg (own-plot
                   incubator proximity, records DeliveredBy/DeliveredPlot),
                   ResetEgg, MarkHatched, ReleasePlayerEggs. Fires Claimed/Freed.
ChaserService      SetTargetToCarrier (verified vs carrier) / ClearTarget /
                   ClearTargetsForPlayer, BindNpc, follow loop with per-tick
                   carrier re-verification + stale-target sweep (carrier ONLY).
HatchService       RequestHatch (DELIVERED + delivered-by-me + delivered-to-my-
                   plot + hatch cooldown), server-side pool roll.
PlotZones          (server helper, not a service) own-plot part lookup +
                   server-measured proximity for Egg/Training services.
ValidationRules    (shared, pure) CanClaim/CanDeliver/CanHatch/CanTrain/
                   ApplyTrainXP/ShouldChase/SanitizeEggId — the single decision
                   point Services call and specs cover.
```

Wiring (in `ServerMain.server.luau`): `EggService.Claimed → ChaserService.SetTargetToCarrier`,
`EggService.Freed → ChaserService.ClearTarget`. Signals (BindableEvents) avoid a
require cycle between Egg and Chaser. Add new cross-service links the same way:
expose a signal, connect it in `ServerMain`, never `require` sideways.

Gameplay contracts (no duplication — each row has exactly ONE owner):

```text
EggService         registration, claiming, carrying, delivery, state, carrier info
PlotService        assignment, ownership, release, ownership queries
TrainingService    training requests, cooldowns, XP + movement progression
ChaserService      activation, carrier targeting, target cleanup, lifecycle
HatchService       hatch validation, consuming delivered eggs, rolling rewards,
                   adding rewards to the server inventory
PlayerDataService  loading, saving, defaults, persistence safety
```

Stable IDs (code depends on THESE, never on model internals or object paths):

```text
EggId     "CommonEgg"      config key in Eggs.luau + EggId attribute on the part
PlotId    "Plot_1"         config entry in Plots.luau + Plots/<PlotId> folder
ChaserId  "Chaser_Common"  config key in Chasers.luau + ChaserId attribute on NPC
RewardId  "Creator_001"    config entry in Rewards.luau (fictional placeholder)
```

Display strings (`DisplayName`, prompt text) are art-safe renames: logic keys off
the IDs above. The placeholder world builds from these IDs; the object designer
replaces the Models later keeping the same IDs/attributes, with zero service changes.

Client/server contract (see also §6):

```text
CLIENT = REQUEST + PRESENTATION   (input, UI, prompts, effects, action requests)
SERVER = VALIDATION + GAME STATE  (ownership, state, rewards, speed, data)
```

The client must NOT decide egg/plot ownership, rewards, speed, egg state,
delivery/hatch success, currency, or inventory. If a new feature needs the client
to know something, the server broadcasts it; the client never computes it.

---

## 4. Egg state machine

```text
AVAILABLE -> CLAIMED -> CARRIED -> DELIVERED -> HATCHED
CLAIMED -> AVAILABLE  (reset / carrier left)
CARRIED -> AVAILABLE  (drop / carrier left / reset)
```

- Lives in `src/shared/EggStateMachine.luau` (pure, dependency-free, unit-tested).
- `EggService` is the only writer; every mutation goes through `AssertTransition`.
- Delivery additionally records `DeliveredByUserId`/`DeliveredPlotId` (server-side
  provenance); `ResetEgg` clears them. `HatchService` requires them to match the
  hatching player and their plot — this is what makes cross-player and double
  hatches impossible, on top of the state check.
- `HATCHED` is terminal in Beta. To respawn eggs, add an explicit `RESPAWNING`
  state + timer in `EggService` (do NOT silently reset HATCHED → AVAILABLE; keep
  the transition table honest). Test in `tests/EggStateMachine.spec.luau`.

---

## 5. Chaser targeting

The critical invariant: **`ChaserService._targets[eggId] == CarrierUserId`**.

- Set ONLY in `ServerMain` from `EggService.Claimed(player, eggId)`, and
  `SetTargetToCarrier` re-checks the egg's recorded carrier first (stale signals
  are dropped, never applied).
- Cleared on deliver / reset / carrier-leave (`EggService.Freed`, `PlayerRemoving`).
- The follow loop re-verifies `target == carrier` against `EggService` EVERY tick
  and clears on any divergence, including targets whose player left the game.
  There is deliberately NO nearest-player search anywhere in the file — if you add
  pathfinding/leash/stun later, keep reading the target from this table.
- The targeting question itself is the pure `ValidationRules.ShouldChase`, covered
  by `tests/ValidationRules.spec.luau` (nearby/other-carrier/ex-carrier all false).
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

1. Sanitize input (`ValidationRules.SanitizeEggId`; reject empties/non-strings)
2. Rate limit (per-player cooldown per action: train/take/deliver/hatch)
3. Ownership from SERVER state (plot via `PlotService`, carrier/state via `EggService`)
4. Proximity, server-measured (`PlotZones` vs own plot's pad/incubator, or egg part)
5. Mutate + broadcast (one `FireClient`/`FireAllClients` per change, not per frame)

Ownership rules (all server-derived; the client sends NO PlotId, ever):

- Deliver: egg `CARRIED` by caller + caller has a plot + caller stands at THAT
  plot's `Incubator`. No plot, wrong place, or someone else's egg → reject.
- Hatch: egg `DELIVERED` + `DeliveredByUserId == caller` + `DeliveredPlotId ==
  caller's plot`. Cross-player, early, or repeat hatch → reject.
- Train: cooldown + caller has a plot + caller stands at THAT plot's
  `TrainingPad` + below max level. Speed/XP math is server-only.
- Rejections return `false` and change nothing; malformed input never errors.

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

Lint/format/test gates (pinned versions in `aftman.toml`; `aftman install` first):

```bash
stylua --check src tests   # format gate (StyLua 2.0.2)
selene src tests           # lint gate (Selene 0.27.1, std "roblox")
rojo build default.project.json -o /tmp/eggheist.rbxlx  # project-mapping gate
```

Heads-up: the pinned StyLua predates `Table.field: Type = value` annotations, so
service state uses `= value :: Type` casts instead — same types, older syntax.
Pinned Selene ships no `testez` std, so spec files carry one adjacent
`-- selene: allow(undefined_variable)` line (must directly precede the code;
a blank line breaks its scope in 0.27.1). Do not "fix" either by upgrading
around the pins; update `aftman.toml` deliberately if you outgrow them.

---

## 8. How to test

- Unit (TestEZ in Studio): `tests/EggStateMachine.spec.luau` (happy path, resets,
  full invalid-jump matrix incl. `HATCHED → CARRIED`, unknown states) and
  `tests/ValidationRules.spec.luau` (sanitize, duplicate claims, cross-player
  delivery/hatch rejection, double-hatch rejection, train cooldown/XP math,
  carrier-only targeting).
- Headless (Linux, no Studio): the pure modules are dependency-free, so
  `lune run` executes the same expectations — 67 assertions green at last check.
  Studio TestEZ remains the gate for the in-engine suite.
- Which is which (do not confuse them):

```text
PURE LOGIC (headless OK)        STUDIO / ENGINE (Studio only)
src/shared/EggStateMachine      everything under src/server, src/client
src/shared/ValidationRules      TestEZ specs executing service behavior
```

  Headless proves the decision tables; it does NOT replace multiplayer
  playtesting (timing, replication, character physics only exist in Studio).
- Manual Beta: `docs/BETA_CHECKLIST.md` — single player, 2–4 players, edge cases
  (leave-while-carrying, double-claim, spam, far interact, hatch-with-nothing)
  plus the Security section (cross-player deliver/hatch, double hatch, stale
  chaser, train/deliver-from-afar).
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
`Init(deps)`/`Start()`, require it ONLY in `ServerMain.server.luau`, pass deps
explicitly, and use signals for cross-service events. Do not `require` another
service directly (the one exception is a read-only verifier dep like
`ChaserService → EggService`, wired in `ServerMain`). Document its ownership
in §3 above. New ownership questions go in `ValidationRules` FIRST, with specs.

---

## 10. How to contribute (GitLab)

- Branch from `main`: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
  Never develop directly on `main` for gameplay work; suggested layout:

```text
main
│
├── feature/gameplay-loop
├── feature/egg-system
├── feature/training
├── feature/hatching
└── feature/ui
```

  One branch per workstream, one focused commit per step, one MR per branch.
- One focused commit per step (see `README` history), e.g.
  `feat: add egg state model`, `test: add egg state tests`. Never one giant commit.
- Push, open a Merge Request, fill in: what loop step it touches, how you
  playtested (players count), checklist results. Keep MRs small enough to review
  in one sitting. `main` stays playable: the Beta loop must not regress.
- Run the §7 gates before pushing (`stylua --check`, `selene`, `rojo build`).
  A red gate blocks the MR the same way a failing checklist item does.

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

---

## 13. Code-first development & Studio handoff

The source repository is the source of truth. Studio is the runtime.

```text
LINUX                              WINDOWS/macOS
Edit Luau (Zed/Neovim)               │
  ↓                                  │
stylua --check / selene / lune       │
  ↓                                  │
Commit → GitLab  ───────────────────→ Pull repository
                                     Open Roblox Studio
                                     Rojo plugin → connect localhost:34872
                                     Playtest (checklist)
                                     Record bugs/results → GitLab
```

Rules:

- Permanent code changes belong in `src/` and go through Git. A temporary
  Studio-side tweak for debugging must never become an undocumented second
  version — port it back to `src/` or discard it.
- Linux needs NO Studio for: editing, formatting, linting, pure-logic tests,
  Git/GitLab, config, docs. Studio is required ONLY for sync, playtesting,
  engine debugging, and publishing.
- Studio handoff per session: pull latest `main`, `rojo serve` on Linux,
  connect plugin, run the checklist section you own, paste Output errors +
  repro steps into the GitLab issue/MR. Bugs found in Studio are fixed in
  `src/` on Linux, never patched in Studio and left there.
- First-time Studio setup: install Roblox Studio + the Rojo plugin, enable
  plugin HTTP permissions when prompted; the served DataModel mirrors
  `default.project.json` (`Shared`/`Server`/`Client`). `tests/` and `docs/`
  never sync into the game.
