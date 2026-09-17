--!strict
-- Egg Heist — ValidationRules (PURE logic, no Roblox APIs).
-- Single decision point for every server-authoritative ownership question.
-- Services call these; tests cover these. Client input NEVER reaches past them
-- unchecked: each function takes only server-derived facts (plot from
-- PlotService, carrier/state from EggService) plus the sanitized request.
-- Intentionally dependency-free so it runs in plain Luau/Lua for fast tests.

local ValidationRules = {}

-- RemoteEvent payloads are `any`. Reject non-strings, empties, absurd lengths.
-- Returns the usable id or nil (caller rejects on nil, changing no state).
function ValidationRules.SanitizeEggId(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if value == "" or #value > 64 then
		return nil
	end
	return value
end

-- Scenario A: exactly one claimant wins because EggService checks this while
-- the egg is still AVAILABLE; the loser's identical request then sees CARRIED.
function ValidationRules.CanClaim(eggState: string?, alreadyCarrying: boolean): boolean
	return eggState == "AVAILABLE" and not alreadyCarrying
end

-- Scenario B + Phase 2/11: delivery requires ALL of:
--   egg CARRIED by THIS player, player HAS a plot, player is near THEIR OWN
--   plot's incubator (server-measured, never client-claimed).
-- There is no PlotId parameter: the destination is derived, not requested.
function ValidationRules.CanDeliver(
	playerUserId: number,
	carrierUserId: number?,
	eggState: string?,
	playerPlotId: string?,
	nearOwnIncubator: boolean
): boolean
	if eggState ~= "CARRIED" then
		return false
	end
	if carrierUserId ~= playerUserId then
		return false
	end
	if playerPlotId == nil then
		return false
	end
	return nearOwnIncubator
end

-- Scenario C/D + Phase 3: hatching requires ALL of:
--   egg DELIVERED by THIS player, to THIS player's plot.
-- Double hatch is rejected by the state check (second call sees HATCHED).
function ValidationRules.CanHatch(
	playerUserId: number,
	eggState: string?,
	deliveredByUserId: number?,
	deliveredPlotId: string?,
	playerPlotId: string?
): boolean
	if eggState ~= "DELIVERED" then
		return false
	end
	if deliveredByUserId ~= playerUserId then
		return false
	end
	if playerPlotId == nil or deliveredPlotId == nil then
		return false
	end
	return deliveredPlotId == playerPlotId
end

-- Scenario G + Phase 7: one shared cooldown gate for train/take/deliver/hatch.
-- `lastAt` nil means "never", which always passes (unless maxed out).
function ValidationRules.CanTrain(
	nowSeconds: number,
	lastAtSeconds: number?,
	cooldownSeconds: number,
	level: number,
	maxLevel: number
): boolean
	if level >= maxLevel then
		return false
	end
	return (nowSeconds - (lastAtSeconds or 0)) >= cooldownSeconds
end

-- Pure XP/level math so level-ups are unit-testable. Returns newLevel, newXP.
function ValidationRules.ApplyTrainXP(
	xp: number,
	level: number,
	xpPerTrain: number,
	xpToLevel: number,
	maxLevel: number
): (number, number)
	xp += xpPerTrain
	while xp >= xpToLevel and level < maxLevel do
		xp -= xpToLevel
		level += 1
	end
	return level, xp
end

-- Phase 5: the ONLY targeting question. A chaser with EggId E chases user U
-- iff U is E's current carrier. Nearby players, other carriers, and ex-carriers
-- all answer false here — there is no proximity input to this function at all.
function ValidationRules.ShouldChase(targetUserId: number?, carrierUserId: number?): boolean
	return targetUserId ~= nil and targetUserId == carrierUserId
end

return ValidationRules
