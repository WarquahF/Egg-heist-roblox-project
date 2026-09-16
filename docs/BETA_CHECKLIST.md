# Beta Test Checklist

Run these in **Studio Playtest** (Test tab → Clients and Servers). All are manual
until headless TestEZ CI exists (see `DEVELOPMENT.md` → Testing).

## Single player (must all pass)

- [ ] Join → assigned one of Plot_1..4, `PlotAssigned` fires, spawn near plot
- [ ] Train (pad prompt + UI button) → SpeedLevel/XP rises, WalkSpeed increases
- [ ] Walk to egg → Steal prompt → egg becomes CARRIED, chaser targets YOU
- [ ] Escape → return to YOUR plot Incubator → Deliver → egg DELIVERED, chaser idle
- [ ] Hatch (UI button) → reward in inventory, `InventoryUpdated` fires, egg HATCHED
- [ ] Rejoin → Coins / SpeedLevel / Inventory / EggsHatched persisted

## Multiplayer (2 players, then 4 players)

- [ ] Each player gets a DIFFERENT plot
- [ ] Player A steals Egg X → Chaser X targets A even when B stands closer
- [ ] A and B can carry different eggs simultaneously, both chased correctly
- [ ] A cannot deliver to B's incubator (server rejects or routes to own plot)
- [ ] A cannot steal the egg B is carrying (unavailable → rejected)

## Edge cases (must all be rejected safely, no errors in server Output)

- [ ] Player leaves while carrying → egg returns to AVAILABLE, chaser idle
- [ ] Player leaves while being chased → chaser target cleared
- [ ] Steal an unavailable egg (CARRIED/DELIVERED/HATCHED) → rejected
- [ ] Hatch with no DELIVERED egg → rejected
- [ ] Spam RequestTrain / RequestTakeEgg rapidly → rate-limited, no double state
- [ ] Two players claim the SAME egg at once → exactly one succeeds
- [ ] Interact from far away (>12 studs) → rejected
- [ ] HATCHED → CARRIED never happens (state machine)

## Performance sanity

- [ ] Output has no errors after a full loop with 4 clients
- [ ] No runaway RemoteEvent traffic (one fire per intent, broadcasts only on change)
- [ ] Leaving players clean up plots, eggs, chaser targets (no stuck CARRIED eggs)
