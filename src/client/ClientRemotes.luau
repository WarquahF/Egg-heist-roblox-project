--!strict
-- Egg Heist — Client remotes helper (presentation side only).
-- Waits for the server-created folder; never creates RemoteEvents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ClientRemotes = {}
local _cache: { [string]: RemoteEvent } = {}

function ClientRemotes.Get(name: string): RemoteEvent
	local cached = _cache[name]
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Constants.REMOTES_FOLDER_NAME)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	_cache[name] = remote
	return remote
end

return ClientRemotes
