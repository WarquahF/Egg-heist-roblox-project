-- Egg Heist — ValidationRules spec (TestEZ, runs in Studio).
-- Covers the multiplayer ownership/race scenarios A–G against the SAME pure
-- functions the server Services call, so a passing suite means the live
-- validation answers these cases identically. See DEVELOPMENT.md > Testing.
-- `describe/it/expect` are TestEZ globals, provided by the runner at runtime
-- (pinned selene ships no testez std).
-- selene: allow(undefined_variable)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ValidationRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ValidationRules"))

local A_USER = 101 -- Player A
local B_USER = 202 -- Player B
local A_PLOT = "Plot_1"
local B_PLOT = "Plot_2"

-- selene: allow(undefined_variable)
return function()
	describe("ValidationRules.SanitizeEggId", function()
		it("accepts well-formed ids", function()
			expect(ValidationRules.SanitizeEggId("CommonEgg")).to.equal("CommonEgg")
		end)

		it("rejects malformed remote payloads without erroring", function()
			expect(ValidationRules.SanitizeEggId(nil)).to.equal(nil)
			expect(ValidationRules.SanitizeEggId(123)).to.equal(nil)
			expect(ValidationRules.SanitizeEggId("")).to.equal(nil)
			expect(ValidationRules.SanitizeEggId({})).to.equal(nil)
			expect(ValidationRules.SanitizeEggId(string.rep("x", 65))).to.equal(nil)
		end)
	end)

	describe("ValidationRules.CanClaim (Scenario A: duplicate claims)", function()
		it("allows claiming an available egg while empty-handed", function()
			expect(ValidationRules.CanClaim("AVAILABLE", false)).to.equal(true)
		end)

		it("rejects the loser's duplicate claim once the egg is taken", function()
			expect(ValidationRules.CanClaim("CARRIED", false)).to.equal(false)
			expect(ValidationRules.CanClaim("CLAIMED", false)).to.equal(false)
			expect(ValidationRules.CanClaim("DELIVERED", false)).to.equal(false)
			expect(ValidationRules.CanClaim("HATCHED", false)).to.equal(false)
		end)

		it("rejects claiming while already carrying, and nonexistent eggs", function()
			expect(ValidationRules.CanClaim("AVAILABLE", true)).to.equal(false)
			expect(ValidationRules.CanClaim(nil, false)).to.equal(false)
		end)
	end)

	describe("ValidationRules.CanDeliver (Scenario B: cross-player delivery)", function()
		it("allows delivery by the carrier at their own incubator", function()
			expect(ValidationRules.CanDeliver(A_USER, A_USER, "CARRIED", A_PLOT, true)).to.equal(true)
		end)

		it("rejects delivery of another player's egg", function()
			expect(ValidationRules.CanDeliver(B_USER, A_USER, "CARRIED", B_PLOT, true)).to.equal(false)
		end)

		it("rejects delivery with no plot, away from the incubator, or wrong state", function()
			expect(ValidationRules.CanDeliver(A_USER, A_USER, "CARRIED", nil, true)).to.equal(false)
			expect(ValidationRules.CanDeliver(A_USER, A_USER, "CARRIED", A_PLOT, false)).to.equal(false)
			expect(ValidationRules.CanDeliver(A_USER, A_USER, "AVAILABLE", A_PLOT, true)).to.equal(false)
			expect(ValidationRules.CanDeliver(A_USER, nil, "DELIVERED", A_PLOT, true)).to.equal(false)
		end)
	end)

	describe("ValidationRules.CanHatch (Scenarios C/D: cross-player + double hatch)", function()
		it("allows hatching your own delivered egg at your own plot", function()
			expect(ValidationRules.CanHatch(A_USER, "DELIVERED", A_USER, A_PLOT, A_PLOT)).to.equal(true)
		end)

		it("rejects hatching another player's delivered egg", function()
			expect(ValidationRules.CanHatch(B_USER, "DELIVERED", A_USER, A_PLOT, B_PLOT)).to.equal(false)
		end)

		it("rejects hatch-before-delivery, double hatch, and nonexistent eggs", function()
			expect(ValidationRules.CanHatch(A_USER, "CARRIED", A_USER, A_PLOT, A_PLOT)).to.equal(false)
			expect(ValidationRules.CanHatch(A_USER, "AVAILABLE", nil, nil, A_PLOT)).to.equal(false)
			expect(ValidationRules.CanHatch(A_USER, "HATCHED", A_USER, A_PLOT, A_PLOT)).to.equal(false)
			expect(ValidationRules.CanHatch(A_USER, nil, nil, nil, A_PLOT)).to.equal(false)
		end)

		it("rejects hatching with no plot on either side", function()
			expect(ValidationRules.CanHatch(A_USER, "DELIVERED", A_USER, A_PLOT, nil)).to.equal(false)
			expect(ValidationRules.CanHatch(A_USER, "DELIVERED", A_USER, nil, A_PLOT)).to.equal(false)
		end)
	end)

	describe("ValidationRules.CanTrain + ApplyTrainXP (Scenario G: spam)", function()
		it("rate-limits rapid repeat requests", function()
			expect(ValidationRules.CanTrain(10.0, 9.5, 1.0, 1, 20)).to.equal(false)
			expect(ValidationRules.CanTrain(10.0, 9.0, 1.0, 1, 20)).to.equal(true)
			expect(ValidationRules.CanTrain(10.0, nil, 1.0, 1, 20)).to.equal(true)
		end)

		it("blocks training past max level", function()
			expect(ValidationRules.CanTrain(10.0, nil, 1.0, 20, 20)).to.equal(false)
		end)

		it("levels up exactly at the XP threshold", function()
			local level, xp = ValidationRules.ApplyTrainXP(4, 1, 1, 5, 20)
			expect(level).to.equal(2)
			expect(xp).to.equal(0)
		end)

		it("accumulates XP below threshold and caps at max level", function()
			local level, xp = ValidationRules.ApplyTrainXP(0, 1, 1, 5, 20)
			expect(level).to.equal(1)
			expect(xp).to.equal(1)
			local maxed, maxedXp = ValidationRules.ApplyTrainXP(4, 20, 1, 5, 20)
			expect(maxed).to.equal(20)
			expect(maxedXp).to.equal(5)
		end)
	end)

	describe("ValidationRules.ShouldChase (carrier-only targeting)", function()
		it("chases the current carrier", function()
			expect(ValidationRules.ShouldChase(A_USER, A_USER)).to.equal(true)
		end)

		it("ignores nearby players, other carriers, and ex-carriers", function()
			expect(ValidationRules.ShouldChase(B_USER, A_USER)).to.equal(false)
		end)

		it("goes idle when the egg has no carrier (delivered/reset/left)", function()
			expect(ValidationRules.ShouldChase(A_USER, nil)).to.equal(false)
			expect(ValidationRules.ShouldChase(nil, nil)).to.equal(false)
		end)
	end)
end
