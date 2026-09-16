--!strict
-- Egg Heist — Training / speed progression config (PLACEHOLDER values).
-- Only TrainingService (server) may apply these. Client must never set speed.

local Training = {
	XPPerTrain = 1,
	XPToLevel = 5, -- XP needed per SpeedLevel (flat for Beta; humans can curve later)
	MaxLevel = 20, -- mirrors Constants.MAX_SPEED_LEVEL
	CoinsPerTrain = 0, -- Beta: training gives speed only, no coins
}

return Training
