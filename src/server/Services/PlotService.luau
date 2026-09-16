--!strict
-- Egg Heist — PlotService (SERVER ONLY).
-- Owns: plot assignment, release, owner lookup. Nothing else.
-- Egg logic, hatching, and rewards are explicitly OUT of scope here.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared:WaitForChild("Config"):WaitForChild("Plots"))

local PlotService = {}
-- PlotId -> UserId (nil = free)
PlotService._owners: { [string]: number? } = {}

function PlotService.Init()
	for _, plotId in PlotConfig.PlotIds do
		PlotService._owners[plotId] = nil
	end
end

-- First free plot wins. Returns nil when the server is full (Beta: 4 plots).
function PlotService.ClaimFreePlot(player: Player): string?
	for _, plotId in PlotConfig.PlotIds do
		if PlotService._owners[plotId] == nil then
			PlotService._owners[plotId] = player.UserId
			return plotId
		end
	end
	return nil
end

function PlotService.ReleasePlayerPlot(player: Player)
	for plotId, ownerId in PlotService._owners do
		if ownerId == player.UserId then
			PlotService._owners[plotId] = nil
		end
	end
end

function PlotService.GetPlotForPlayer(player: Player): string?
	for plotId, ownerId in PlotService._owners do
		if ownerId == player.UserId then
			return plotId
		end
	end
	return nil
end

function PlotService.GetOwner(plotId: string): number?
	return PlotService._owners[plotId]
end

function PlotService.Start()
	Players.PlayerAdded:Connect(function(player)
		PlotService.ClaimFreePlot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlotService.ReleasePlayerPlot(player)
	end)
end

return PlotService
