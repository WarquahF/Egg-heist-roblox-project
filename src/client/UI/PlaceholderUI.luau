--!strict
-- Egg Heist — Placeholder UI (CLIENT, dev only).
-- Minimal code-built ScreenGui so the Beta loop is testable without final UI:
-- Train button, Hatch button, state label. Replace with real UI later;
-- Services never depend on this file.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local ClientRemotes = require(script.Parent.Parent:WaitForChild("ClientRemotes"))

local PlaceholderUI = {}

function PlaceholderUI.Start(interaction: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggHeistBetaUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(220, 170)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundTransparency = 0.3
	frame.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -16, 0, 60)
	status.Position = UDim2.fromOffset(8, 8)
	status.BackgroundTransparency = 1
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "Egg Heist Beta\nWaiting for server..."
	status.Parent = frame

	local trainButton = Instance.new("TextButton")
	trainButton.Size = UDim2.new(1, -16, 0, 36)
	trainButton.Position = UDim2.fromOffset(8, 76)
	trainButton.Text = "Train (+Speed XP)"
	trainButton.Parent = frame
	trainButton.MouseButton1Click:Connect(function()
		ClientRemotes.Get(RemoteNames.RequestTrain):FireServer()
	end)

	local hatchButton = Instance.new("TextButton")
	hatchButton.Size = UDim2.new(1, -16, 0, 36)
	hatchButton.Position = UDim2.fromOffset(8, 120)
	hatchButton.Text = "Hatch Delivered Egg"
	hatchButton.Parent = frame
	hatchButton.MouseButton1Click:Connect(function()
		interaction.RequestHatch()
	end)

	ClientRemotes.Get(RemoteNames.PlotAssigned).OnClientEvent:Connect(function(plotId: string)
		status.Text = ("Egg Heist Beta\nPlot: %s\nSteal an egg, return to your Incubator."):format(plotId)
	end)
	ClientRemotes.Get(RemoteNames.SpeedChanged).OnClientEvent:Connect(function(level: number, xp: number)
		status.Text = ("Egg Heist Beta\nSpeed Lv.%d (XP %d)\nSteal, escape, deliver, hatch."):format(level, xp)
	end)
	ClientRemotes.Get(RemoteNames.InventoryUpdated).OnClientEvent:Connect(function(inventory: any)
		local count = if type(inventory) == "table" then #inventory else 0
		status.Text = ("Egg Heist Beta\nHatched! Rewards: %d\nKeep going."):format(count)
	end)
end

return PlaceholderUI
