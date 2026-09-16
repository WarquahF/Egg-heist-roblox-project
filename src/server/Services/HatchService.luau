--!strict
-- Egg Heist — HatchService (SERVER ONLY).
-- Owns: validating DELIVERED eggs, rolling the hatch pool, writing the
-- reward into PlayerDataService inventory. Client only sends RequestHatch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local RewardPools = require(Shared:WaitForChild("Config"):WaitForChild("Rewards"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local HatchService = {}
HatchService._deps: any = nil

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
				Name = e.Name,
				HatchedAt = os.time(),
			}
		end
	end
	local fallback = pool[1] :: any
	return {
		RewardId = fallback.RewardId,
		Rarity = fallback.Rarity,
		Name = fallback.Name,
		HatchedAt = os.time(),
	}
end

function HatchService.RequestHatch(player: Player, eggId: string): boolean
	if typeof(eggId) ~= "string" or eggId == "" then
		return false
	end
	local egg = HatchService._deps.EggService.Get(eggId)
	if egg == nil or egg.State ~= "DELIVERED" then
		return false -- nothing to hatch: reject (covers "hatch without egg")
	end
	local cfg = EggConfig[eggId]
	if cfg == nil then
		return false
	end

	-- TODO(Human): verify the delivered egg sits in THIS player's plot incubator.
	local reward = _rollReward((cfg :: any).HatchPoolId)
	if reward == nil then
		return false
	end

	local data = HatchService._deps.PlayerDataService.GetOrDefault(player)
	data.Coins += 0 -- Beta: coin payout curve is a human economy decision.
	data.EggsHatched += 1
	HatchService._deps.PlayerDataService.AddReward(player, reward)
	HatchService._deps.EggService.MarkHatched(eggId)

	HatchService._deps.Remotes.Get(RemoteNames.InventoryUpdated):FireClient(player, data.Inventory)
	return true
end

function HatchService.Start()
	HatchService._deps.Remotes.Get(RemoteNames.RequestHatch).OnServerEvent:Connect(
		function(player: Player, eggId: any)
			HatchService.RequestHatch(player, eggId)
		end
	)
end

return HatchService
