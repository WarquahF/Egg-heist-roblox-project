--!strict
-- Egg Heist — Egg + rarity config (PLACEHOLDER balance for Beta).
-- Human designers own final numbers. To add an egg, add one entry here
-- and place a matching placeholder egg in the world (see DEVELOPMENT.md).
-- No real-world creator identities: Creator_* are fictional placeholders.

export type EggConfig = {
	Rarity: string,
	DistanceFromPlots: number, -- studs along the runway; bigger = rarer
	HatchPoolId: string,
	ChaserId: string,
	PlaceholderColor: Color3,
}

local Eggs: { [string]: EggConfig } = {
	CommonEgg = {
		Rarity = "Common",
		DistanceFromPlots = 50,
		HatchPoolId = "CommonPool",
		ChaserId = "Chaser_Common",
		PlaceholderColor = Color3.fromRGB(255, 255, 255),
	},
	RareEgg = {
		Rarity = "Rare",
		DistanceFromPlots = 150,
		HatchPoolId = "RarePool",
		ChaserId = "Chaser_Rare",
		PlaceholderColor = Color3.fromRGB(85, 170, 255),
	},
	EpicEgg = {
		Rarity = "Epic",
		DistanceFromPlots = 300,
		HatchPoolId = "EpicPool",
		ChaserId = "Chaser_Epic",
		PlaceholderColor = Color3.fromRGB(170, 85, 255),
	},
	-- Future tiers (Legendary, Secret, God, ???) are intentionally NOT added
	-- until the Beta loop works. Add them here following the same shape.
}

return Eggs
