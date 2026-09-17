--!strict
-- Egg Heist — HatchService (SERVER ONLY).
-- Owns: validating DELIVERED eggs, rolling the hatch pool, writing the
-- reward into PlayerDataService inventory. Client only sends RequestHatch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EggConfig = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local RewardPools = require(Shared:WaitForChild("Config"):WaitForChild("Rewards"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local ValidationRules = require(Shared:WaitForChild("ValidationRules"))

local HatchService = {}
HatchService._deps = nil :: any
HatchService._lastHatchAt = {} :: { [number]: number }

function HatchService.Init(deps: {
	PlayerDataService: any,
	EggService: any,
	PlotService: any,
	Remotes: any,
})
	HatchService._deps = deps
end

local function _rollReward(poolId: string): any?
	local pool = RewardPools[poolId]
	if pool == nil or #pool == 0 then
		return nil
	end
	local total = 0
	for _, entry in pool do
		total += (entry :: any).Weight
	end
	local roll = Random.new():NextNumber(0, total)
	for _, entry in pool do
		roll -= (entry :: any).Weight
		if roll <= 0 then
			local e = entry :: any
			return {
				RewardId = e.RewardId,
				Rarity = e.Rarity,
				RewardType = e.RewardType,
				Name = e.Name,
				HatchedAt = os.time(),
			}
		end
	end
	local fallback = pool[1] :: any
	return {
		RewardId = fallback.RewardId,
		Rarity = fallback.Rarity,
		RewardType = fallback.RewardType,
		Name = fallback.Name,
		HatchedAt = os.time(),
	}
end

-- Phase 3: hatching is valid ONLY for the player who delivered the egg,
-- to their own plot. The reward is rolled server-side; the client sends
-- nothing but the egg id. Every rejection leaves state untouched.
function HatchService.RequestHatch(player: Player, eggId: any): boolean
	local id = ValidationRules.SanitizeEggId(eggId)
	if id == nil then
		return false
	end
	local now = os.clock()
	if now - (HatchService._lastHatchAt[player.UserId] or 0) < Constants.HATCH_COOLDOWN_SECONDS then
		return false -- Scenario G: spam collapses to one attempt per cooldown
	end
	HatchService._lastHatchAt[player.UserId] = now

	local egg = HatchService._deps.EggService.Get(id)
	local state = if egg then egg.State else nil
	local deliveredBy = if egg then egg.DeliveredByUserId else nil
	local deliveredPlot = if egg then egg.DeliveredPlotId else nil
	local playerPlot = HatchService._deps.PlotService.GetPlotForPlayer(player)
	if egg == nil or not ValidationRules.CanHatch(player.UserId, state, deliveredBy, deliveredPlot, playerPlot) then
		-- Covers: nonexistent egg, hatch-before-delivery, cross-player hatch
		-- (Scenario C), already-HATCHED / double hatch (Scenario D).
		return false
	end
	local cfg = EggConfig[id]
	if cfg == nil then
		return false
	end

	local reward = _rollReward((cfg :: any).HatchPoolId)
	if reward == nil then
		return false
	end

	-- NOTE: coin payout curve is a human economy decision; Beta grants the
	-- collectible only. Do not invent currency here.
	local data = HatchService._deps.PlayerDataService.GetOrDefault(player)
	data.EggsHatched += 1
	HatchService._deps.PlayerDataService.AddReward(player, reward)
	HatchService._deps.EggService.MarkHatched(id)

	HatchService._deps.Remotes.Get(RemoteNames.InventoryUpdated):FireClient(player, data.Inventory)
	return true
end

function HatchService.Start()
	HatchService._deps.Remotes.Get(RemoteNames.RequestHatch).OnServerEvent:Connect(function(player: Player, eggId: any)
		HatchService.RequestHatch(player, eggId)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		HatchService._lastHatchAt[player.UserId] = nil
	end)
end

return HatchService
