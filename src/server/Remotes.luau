--!strict
-- Egg Heist — Server Remotes helper.
-- Creates each RemoteEvent in RemoteNames ONCE (server authority),
-- then hands out references. Client waits for the folder + events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local Remotes = {}
local _cache: { [string]: RemoteEvent } = {}

function Remotes.EnsureAll(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Constants.REMOTES_FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Constants.REMOTES_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in pairs(RemoteNames) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	local cached = _cache[name]
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Constants.REMOTES_FOLDER_NAME)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	_cache[name] = remote
	return remote
end

return Remotes
