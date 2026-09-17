--!strict
-- Egg Heist — PlayerDataService (SERVER ONLY).
-- SOLE owner of persistence. No other Service touches DataStoreService.
-- Data shape: { Coins, SpeedLevel, SpeedXP, Inventory = {RewardRecord}, EggsHatched }

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type SaveData = {
	Coins: number,
	SpeedLevel: number,
	SpeedXP: number,
	Inventory: { any },
	EggsHatched: number,
}

local PlayerDataService = {}
PlayerDataService._data = {} :: { [number]: SaveData }
PlayerDataService._loaded = {} :: { [number]: boolean }
PlayerDataService._started = false
PlayerDataService._store = nil

function PlayerDataService.DefaultData(): SaveData
	return {
		Coins = 0,
		SpeedLevel = 1,
		SpeedXP = 0,
		Inventory = {},
		EggsHatched = 0,
	}
end

function PlayerDataService.Get(player: Player): SaveData?
	return PlayerDataService._data[player.UserId]
end

function PlayerDataService.GetOrDefault(player: Player): SaveData
	local existing = PlayerDataService._data[player.UserId]
	if existing ~= nil then
		return existing
	end
	local fresh = PlayerDataService.DefaultData()
	PlayerDataService._data[player.UserId] = fresh
	return fresh
end

-- TODO(Human): tune retry/backoff for production. Beta uses one pcall load.
-- Guarded: loading twice never overwrites newer in-memory data, so a duplicate
-- PlayerAdded (or a second Start) cannot wipe session progress.
function PlayerDataService.Load(player: Player)
	if PlayerDataService._loaded[player.UserId] then
		return
	end
	PlayerDataService._loaded[player.UserId] = true
	local store = PlayerDataService._store
	local data = PlayerDataService.DefaultData()
	if store ~= nil then
		local ok, loaded = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(loaded) == "table" then
			local l = loaded :: any
			if type(l.Coins) == "number" then
				data.Coins = math.max(0, math.floor(l.Coins))
			end
			if type(l.SpeedLevel) == "number" then
				data.SpeedLevel = math.clamp(math.floor(l.SpeedLevel), 1, Constants.MAX_SPEED_LEVEL)
			end
			if type(l.SpeedXP) == "number" then
				data.SpeedXP = math.max(0, math.floor(l.SpeedXP))
			end
			if type(l.Inventory) == "table" then
				-- Bound table size so corrupt/huge saves can't blow DataStore limits.
				local capped: { any } = {}
				for index, item in l.Inventory do
					if typeof(index) == "number" and #capped < Constants.MAX_INVENTORY_ITEMS then
						capped[#capped + 1] = item
					end
				end
				data.Inventory = capped
			end
			if type(l.EggsHatched) == "number" then
				data.EggsHatched = math.max(0, math.floor(l.EggsHatched))
			end
		end
	end
	PlayerDataService._data[player.UserId] = data
end

function PlayerDataService.Save(player: Player)
	local data = PlayerDataService._data[player.UserId]
	local store = PlayerDataService._store
	if data == nil or store == nil then
		return
	end
	pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
end

function PlayerDataService.AddReward(player: Player, reward: any)
	PlayerDataService.GetOrDefault(player).Inventory[#PlayerDataService.GetOrDefault(player).Inventory + 1] = reward
end

function PlayerDataService.Start()
	if PlayerDataService._started then
		return -- idempotent: a second Start must not spawn a second autosave loop
	end
	PlayerDataService._started = true

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
	end)
	if ok then
		PlayerDataService._store = store
	else
		warn("[PlayerDataService] DataStore unavailable (Studio offline?). Progress is session-only.")
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.Load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		PlayerDataService._data[player.UserId] = nil
		PlayerDataService._loaded[player.UserId] = nil
	end)

	-- Flush on shutdown so Stop/Update doesn't drop the last minutes of play.
	-- In Studio, BindToClose may not fire on every Stop press; autosave +
	-- PlayerRemoving saves remain the primary durability path there.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerDataService.Save(player)
		end
	end)

	-- Autosave loop. Single task; cheap for Beta scale.
	task.spawn(function()
		while true do
			task.wait(Constants.AUTOSAVE_INTERVAL_SECONDS)
			for _, player in Players:GetPlayers() do
				PlayerDataService.Save(player)
			end
		end
	end)
end

return PlayerDataService
