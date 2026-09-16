--!strict
-- Egg Heist — Chaser config (PLACEHOLDER values).
-- Critical rule (enforced in ChaserService): a chaser targets ONLY the
-- player carrying its egg. Never nearest-player. See DEVELOPMENT.md.

export type ChaserConfig = {
	WalkSpeed: number,
	LoseDistance: number, -- distance that ends chase after deliver/reset (informational)
	ResetDelaySeconds: number,
}

local Chasers: { [string]: ChaserConfig } = {
	Chaser_Common = {
		WalkSpeed = 18,
		LoseDistance = 200,
		ResetDelaySeconds = 5,
	},
	Chaser_Rare = {
		WalkSpeed = 20,
		LoseDistance = 250,
		ResetDelaySeconds = 5,
	},
	Chaser_Epic = {
		WalkSpeed = 22,
		LoseDistance = 300,
		ResetDelaySeconds = 5,
	},
}

return Chasers
