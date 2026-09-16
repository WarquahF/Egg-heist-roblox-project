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

local TrainingService = {}
TrainingService._deps: any = nil
TrainingService._lastTrainAt: { [number]: number } = {}

function TrainingService.Init(deps: { PlayerDataService: any, Remotes: any })
	TrainingService._deps = deps
end

function TrainingService.SpeedForLevel(level: number): number
	return Constants.BASE_WALK_SPEED + (math.clamp(level, 1, Constants.MAX_SPEED_LEVEL) - 1) * Constants.WALK_SPEED_PER_LEVEL
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

-- TODO(Human): add "near training pad" distance check using PlotService plot lookup.
function TrainingService.RequestTrain(player: Player): boolean
	local now = os.clock()
	local last = TrainingService._lastTrainAt[player.UserId] or 0
	if now - last < Constants.TRAIN_COOLDOWN_SECONDS then
		return false -- rate-limited: repeated remote spam is dropped
	end
	TrainingService._lastTrainAt[player.UserId] = now

	local data = TrainingService._deps.PlayerDataService.GetOrDefault(player)
	if data.SpeedLevel >= TrainingConfig.MaxLevel then
		return false
	end

	data.SpeedXP += TrainingConfig.XPPerTrain
	while data.SpeedXP >= TrainingConfig.XPToLevel and data.SpeedLevel < TrainingConfig.MaxLevel do
		data.SpeedXP -= TrainingConfig.XPToLevel
		data.SpeedLevel += 1
	end

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
end

return TrainingService
