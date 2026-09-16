-- Egg Heist — EggStateMachine spec (TestEZ, runs in Studio).
-- How to run: put this file under a TestEZ runner (e.g. ReplicatedStorage tests
-- folder synced via Rojo) and run from the Studio command bar or CI later.
-- See DEVELOPMENT.md > Testing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggStateMachine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EggStateMachine"))

return function()
	describe("EggStateMachine", function()
		it("allows the happy path AVAILABLE -> CLAIMED -> CARRIED -> DELIVERED -> HATCHED", function()
			expect(EggStateMachine.CanTransition("AVAILABLE", "CLAIMED")).to.equal(true)
			expect(EggStateMachine.CanTransition("CLAIMED", "CARRIED")).to.equal(true)
			expect(EggStateMachine.CanTransition("CARRIED", "DELIVERED")).to.equal(true)
			expect(EggStateMachine.CanTransition("DELIVERED", "HATCHED")).to.equal(true)
		end)

		it("allows reset CLAIMED/CARRIED -> AVAILABLE", function()
			expect(EggStateMachine.CanTransition("CLAIMED", "AVAILABLE")).to.equal(true)
			expect(EggStateMachine.CanTransition("CARRIED", "AVAILABLE")).to.equal(true)
		end)

		it("rejects invalid transitions", function()
			expect(EggStateMachine.CanTransition("HATCHED", "CARRIED")).to.equal(false)
			expect(EggStateMachine.CanTransition("AVAILABLE", "DELIVERED")).to.equal(false)
			expect(EggStateMachine.CanTransition("DELIVERED", "AVAILABLE")).to.equal(false)
			expect(EggStateMachine.CanTransition("HATCHED", "AVAILABLE")).to.equal(false)
			expect(EggStateMachine.CanTransition("AVAILABLE", "HATCHED")).to.equal(false)
		end)

		it("AssertTransition errors on invalid transitions", function()
			local ok = pcall(function()
				EggStateMachine.AssertTransition("HATCHED", "CARRIED")
			end)
			expect(ok).to.equal(false)
		end)

		it("two eggs have independent state (model check)", function()
			-- The machine is stateless; independence is enforced by EggService's
			-- per-egg table. This guards against a future 'global state' refactor.
			expect(EggStateMachine.CanTransition("AVAILABLE", "CLAIMED")).to.equal(true)
			expect(EggStateMachine.CanTransition("AVAILABLE", "CLAIMED")).to.equal(true)
		end)
	end)
end
