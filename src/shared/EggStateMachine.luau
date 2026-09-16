--!strict
-- Egg Heist — Egg state machine (PURE logic, no Roblox APIs).
-- Server owns the authoritative state; this module only answers:
--   "is From -> To a legal transition?"
-- Used by EggService and by tests/. Intentionally dependency-free so it
-- runs in plain Luau/Lua for fast tests (see tests/ and DEVELOPMENT.md).

export type EggState = "AVAILABLE" | "CLAIMED" | "CARRIED" | "DELIVERED" | "HATCHED"

-- Legal transitions for the Beta loop:
--   AVAILABLE -> CLAIMED -> CARRIED -> DELIVERED -> HATCHED
-- + CLAIMED/CARRIED -> AVAILABLE (drop / reset / carrier left).
local ALLOWED: { [string]: { string } } = {
	AVAILABLE = { "CLAIMED" },
	CLAIMED = { "CARRIED", "AVAILABLE" },
	CARRIED = { "DELIVERED", "AVAILABLE" },
	DELIVERED = { "HATCHED" },
	HATCHED = {},
}

local EggStateMachine = {}

function EggStateMachine.CanTransition(from: EggState, to: EggState): boolean
	local targets = ALLOWED[from]
	if targets == nil then
		return false
	end
	for _, allowed in targets do
		if allowed == to then
			return true
		end
	end
	return false
end

function EggStateMachine.AssertTransition(from: EggState, to: EggState)
	if not EggStateMachine.CanTransition(from, to) then
		error(("Invalid egg transition: %s -> %s"):format(from, to), 2)
	end
end

return EggStateMachine
