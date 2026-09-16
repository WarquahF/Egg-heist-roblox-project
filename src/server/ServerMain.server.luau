--!strict
-- Egg Heist — Server entry point (ServerScriptService.Server.ServerMain).
-- Wires Services in dependency order. Server-to-server uses DIRECT calls,
-- never RemoteEvents. Remotes are client<->server only.
--
-- Order: Remotes -> PlayerData -> Plot -> Egg -> Chaser -> Training -> Hatch.
-- Egg/Chaser are linked via SIGNALS (Claimed/Freed) to avoid require cycles.

local DEV_BUILD_PLACEHOLDERS = true -- set false once the real map exists

local Server = script.Parent
local Services = Server:WaitForChild("Services")
local Remotes = require(Server:WaitForChild("Remotes"))

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local EggService = require(Services:WaitForChild("EggService"))
local ChaserService = require(Services:WaitForChild("ChaserService"))
local TrainingService = require(Services:WaitForChild("TrainingService"))
local HatchService = require(Services:WaitForChild("HatchService"))

-- Dev world must exist BEFORE services scan workspace for EggId tags.
if DEV_BUILD_PLACEHOLDERS then
	local PlaceholderWorld =
		require(Server:WaitForChild("Bootstrap"):WaitForChild("PlaceholderWorld"))
	PlaceholderWorld.Build()
end

Remotes.EnsureAll()

PlayerDataService.Start()
PlotService.Init()
PlotService.Start()

-- Broadcast plot assignment to the joining client (client teleports to plot).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteNames"))
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
	local plotId = PlotService.GetPlotForPlayer(player)
	-- PlotService.Start already claimed; this is a safety net for load order.
	if plotId == nil then
		plotId = PlotService.ClaimFreePlot(player)
	end
	if plotId ~= nil then
		Remotes.Get(RemoteNames.PlotAssigned):FireClient(player, plotId)
	else
		warn(("[ServerMain] No free plot for %s (server full, Beta max 4)"):format(player.Name))
	end
end)

EggService.Init({ Remotes = Remotes })
ChaserService.Init()

-- THE critical wiring: carrier -> target. Never nearest-player.
local claimed = EggService.Claimed
if claimed ~= nil then
	claimed.Event:Connect(function(player: Player, eggId: string)
		ChaserService.SetTargetToCarrier(player, eggId)
	end)
end
local freed = EggService.Freed
if freed ~= nil then
	freed.Event:Connect(function(eggId: string)
		ChaserService.ClearTarget(eggId)
	end)
end

EggService.Start()
ChaserService.Start()

TrainingService.Init({ PlayerDataService = PlayerDataService, Remotes = Remotes })
TrainingService.Start()

HatchService.Init({
	PlayerDataService = PlayerDataService,
	EggService = EggService,
	PlotService = PlotService,
	Remotes = Remotes,
})
HatchService.Start()

print("[EggHeist] ServerMain ready — Beta foundation online.")
