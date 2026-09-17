--!strict
-- Egg Heist — Shared types.
-- Single source of truth for shapes passed between Services and Client.
-- Keep this file small: add a type only when 2+ modules need it.

export type EggState = "AVAILABLE" | "CLAIMED" | "CARRIED" | "DELIVERED" | "HATCHED"

export type EggRecord = {
	EggId: string,
	State: EggState,
	-- UserId of the carrier while CLAIMED/CARRIED, nil otherwise.
	CarrierUserId: number?,
	-- Set on delivery (server-derived, never client-provided). HatchService
	-- requires these to match the hatching player and their plot.
	DeliveredByUserId: number?,
	DeliveredPlotId: string?,
	PlotId: string?,
}

export type RewardRecord = {
	RewardId: string,
	Rarity: string,
	Name: string,
	HatchedAt: number,
}

export type PlayerSaveData = {
	Coins: number,
	SpeedLevel: number,
	SpeedXP: number,
	Inventory: { RewardRecord },
	EggsHatched: number,
}

export type PlotRecord = {
	PlotId: string,
	OwnerUserId: number?,
}

return nil
