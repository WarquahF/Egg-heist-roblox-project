--!strict
-- Egg Heist — Remote names (single source of truth).
-- The server creates these RemoteEvents under ReplicatedStorage/<REMOTES_FOLDER>.
-- Client and Server must require THIS module; never hardcode the strings elsewhere.
-- Keep remotes meaningful (player intents + server broadcasts), not per-function.

local RemoteNames = {
	-- Client -> Server intents (all validated + rate-limited on the server).
	RequestTrain = "RequestTrain",
	RequestTakeEgg = "RequestTakeEgg",
	RequestDeliverEgg = "RequestDeliverEgg",
	RequestHatch = "RequestHatch",

	-- Server -> Client broadcasts.
	InventoryUpdated = "InventoryUpdated",
	PlotAssigned = "PlotAssigned",
	EggStateChanged = "EggStateChanged",
	SpeedChanged = "SpeedChanged",
}

return RemoteNames
