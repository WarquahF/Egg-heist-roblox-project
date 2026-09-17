--!strict
-- Egg Heist — TrainingService (SERVER ONLY).
-- Owns: training requests, XP/level, WalkSpeed application.
-- The CLIENT MUST NEVER set its own speed; it only fires RequestTrain.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local TrainingConfig = require(Shared:WaitForChild("Config"):WaitForChild("Training"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local ValidationRules = require(Shared:WaitForChild("ValidationRules"))

local PlotZones = require(script.Parent:WaitForChild("PlotZones"))

local TrainingService = {}
TrainingService._deps = nil :: any
TrainingService._lastTrainAt = {} :: { [number]: number }

function TrainingService.Init(deps: { PlayerDataService: any, PlotService: any, Remotes: any })
	TrainingService._deps = deps
end

function TrainingService.SpeedForLevel(level: number): number
	return Constants.BASE_WALK_SPEED
		+ (math.clamp(level, 1, Constants.MAX_SPEED_LEVEL) - 1) * Constants.WALK_SPEED_PER_LEVEL
end

function TrainingService.ApplySpeed(player: Player)
	local data = TrainingService._deps.PlayerDataService.GetOrDefault(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid.WalkSpeed = TrainingService.SpeedForLevel(data.SpeedLevel)
	end
	TrainingService._deps.Remotes.Get(RemoteNames.SpeedChanged):FireClient(player, data.SpeedLevel, data.SpeedXP)
end

-- Phase 7: the client only knocks. The server decides: cooldown gate,
-- player has a plot, character stands at THEIR OWN plot's training pad
-- (server-measured), level below cap. XP math and WalkSpeed are server-only;
-- there is exactly one WalkSpeed writer (ApplySpeed below).
function TrainingService.RequestTrain(player: Player): boolean
	local data = TrainingService._deps.PlayerDataService.GetOrDefault(player)
	local now = os.clock()
	if
		not ValidationRules.CanTrain(
			now,
			TrainingService._lastTrainAt[player.UserId],
			Constants.TRAIN_COOLDOWN_SECONDS,
			data.SpeedLevel,
			TrainingConfig.MaxLevel
		)
	then
		return false -- rate-limited spam (Scenario G) or already maxed
	end
	TrainingService._lastTrainAt[player.UserId] = now

	local plotId = TrainingService._deps.PlotService.GetPlotForPlayer(player)
	if plotId == nil then
		return false -- no plot, no pad
	end
	if not PlotZones.IsNearOwnPlotPart(player, plotId, "TrainingPad", Constants.MAX_INTERACT_DISTANCE) then
		return false -- must train at your own pad, not from across the map
	end

	data.SpeedLevel, data.SpeedXP = ValidationRules.ApplyTrainXP(
		data.SpeedXP,
		data.SpeedLevel,
		TrainingConfig.XPPerTrain,
		TrainingConfig.XPToLevel,
		TrainingConfig.MaxLevel
	)

	TrainingService.ApplySpeed(player)
	return true
end

function TrainingService.Start()
	local requestTrain = TrainingService._deps.Remotes.Get(RemoteNames.RequestTrain)
	requestTrain.OnServerEvent:Connect(function(player: Player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		TrainingService.RequestTrain(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Small delay so Humanoid exists before we set speed.
			task.defer(function()
				TrainingService.ApplySpeed(player)
			end)
		end)
	end)

	-- Re-apply speed on respawn for players already in-game (Studio playtest).
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(function()
				TrainingService.ApplySpeed(player)
			end)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		TrainingService._lastTrainAt[player.UserId] = nil
	end)
end

return TrainingService
