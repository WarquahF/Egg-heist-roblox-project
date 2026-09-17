--!strict
-- Egg Heist — Shared constants.
-- Magic numbers live here, not scattered in Services.

local Constants = {}

-- Beta supports ~4 plots. Raise later without touching PlotService logic.
Constants.MAX_PLOTS = 4

-- Anti-spam / validation guardrails (placeholder values for Beta).
Constants.MAX_INTERACT_DISTANCE = 12 -- studs: egg claim / deliver / train
Constants.TRAIN_COOLDOWN_SECONDS = 1.0
Constants.TAKE_EGG_COOLDOWN_SECONDS = 1.0
Constants.DELIVER_EGG_COOLDOWN_SECONDS = 1.0
Constants.HATCH_COOLDOWN_SECONDS = 1.0

-- Movement. Only the SERVER applies these (see TrainingService).
Constants.BASE_WALK_SPEED = 16
Constants.WALK_SPEED_PER_LEVEL = 2
Constants.MAX_SPEED_LEVEL = 20

-- Chaser follow-loop tick (server). Tunable here, not hardcoded in the service.
Constants.CHASER_TICK_SECONDS = 0.25

-- Data.
Constants.DATASTORE_NAME = "EggHeist_Beta_001"
Constants.AUTOSAVE_INTERVAL_SECONDS = 120
Constants.MAX_INVENTORY_ITEMS = 500 -- safety cap for corrupt/huge saves

-- Remotes folder name created under ReplicatedStorage by the server.
Constants.REMOTES_FOLDER_NAME = "EggHeistRemotes"

return Constants
