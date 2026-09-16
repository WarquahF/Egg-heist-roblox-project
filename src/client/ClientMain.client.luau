--!strict
-- Egg Heist — Client entry point (StarterPlayerScripts.Client.ClientMain).
-- Presentation only: input, prompts, placeholder UI. No authority here.

local Client = script.Parent
local Controllers = Client:WaitForChild("Controllers")

local InteractionController = require(Controllers:WaitForChild("InteractionController"))
local PlaceholderUI = require(Client:WaitForChild("UI"):WaitForChild("PlaceholderUI"))

InteractionController.Start()
PlaceholderUI.Start(InteractionController)

print("[EggHeist] ClientMain ready.")
