--!strict
-- Egg Heist — Hatch pools + reward catalog (PLACEHOLDER content).
-- IDs like Creator_001 are FICTIONAL placeholders, not real people.
-- Art team can replace models later; HatchService only stores these records.

export type RewardDef = {
	RewardId: string,
	Rarity: string,
	-- Collectible kind. Beta knows one kind ("Collectible"); the art/content
	-- team adds kinds here later without touching HatchService.
	RewardType: string,
	Name: string,
	CoinValue: number,
	Weight: number, -- relative roll weight inside its pool
}

local Rewards: { [string]: { RewardDef } } = {
	CommonPool = {
		{
			RewardId = "Creator_001",
			Rarity = "Common",
			RewardType = "Collectible",
			Name = "Placeholder Chick 1",
			CoinValue = 10,
			Weight = 70,
		},
		{
			RewardId = "Creator_002",
			Rarity = "Common",
			RewardType = "Collectible",
			Name = "Placeholder Chick 2",
			CoinValue = 15,
			Weight = 30,
		},
	},
	RarePool = {
		{
			RewardId = "Creator_003",
			Rarity = "Rare",
			RewardType = "Collectible",
			Name = "Placeholder Chick 3",
			CoinValue = 40,
			Weight = 70,
		},
		{
			RewardId = "Creator_004",
			Rarity = "Rare",
			RewardType = "Collectible",
			Name = "Placeholder Chick 4",
			CoinValue = 60,
			Weight = 30,
		},
	},
	EpicPool = {
		{
			RewardId = "Creator_005",
			Rarity = "Epic",
			RewardType = "Collectible",
			Name = "Placeholder Chick 5",
			CoinValue = 150,
			Weight = 100,
		},
	},
}

return Rewards
