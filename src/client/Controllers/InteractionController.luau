--!strict
-- Egg Heist — InteractionController (CLIENT, presentation only).
-- Forwards ProximityPrompt triggers to the server. No authority here:
-- the server re-validates distance, state, ownership, and rate limits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local ClientRemotes = require(script.Parent.Parent:WaitForChild("ClientRemotes"))

local InteractionController = {}

-- Tracks the egg the local player is carrying (for Deliver prompt routing).
local _carriedEggId: string? = nil

function InteractionController.Start()
	local requestTake = ClientRemotes.Get(RemoteNames.RequestTakeEgg)
	local requestDeliver = ClientRemotes.Get(RemoteNames.RequestDeliverEgg)
	local requestHatch = ClientRemotes.Get(RemoteNames.RequestHatch)
	local eggChanged = ClientRemotes.Get(RemoteNames.EggStateChanged)

	eggChanged.OnClientEvent:Connect(function(eggId: string, state: string, carrierUserId: any)
		local localUserId = game:GetService("Players").LocalPlayer.UserId
		if carrierUserId == localUserId and (state == "CLAIMED" or state == "CARRIED") then
			_carriedEggId = eggId
		elseif state == "DELIVERED" or state == "HATCHED" or state == "AVAILABLE" then
			if _carriedEggId == eggId then
				_carriedEggId = nil
			end
		end
	end)

	-- Wire any prompt already in the world + future ones (placeholder map streams in).
	local function _wirePrompt(prompt: ProximityPrompt)
		if prompt.Name == "TakePrompt" then
			prompt.Triggered:Connect(function()
				local eggPart = prompt.Parent
				local eggId = if eggPart then eggPart:GetAttribute("EggId") else nil
				if typeof(eggId) == "string" then
					requestTake:FireServer(eggId)
				end
			end)
		elseif prompt.Name == "DeliverPrompt" then
			prompt.Triggered:Connect(function()
				-- Deliver the egg we carry; server verifies plot + state.
				if _carriedEggId ~= nil then
					requestDeliver:FireServer(_carriedEggId)
				end
			end)
		elseif prompt.Name == "TrainPrompt" then
			prompt.Triggered:Connect(function()
				ClientRemotes.Get(RemoteNames.RequestTrain):FireServer()
			end)
		end
	end

	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			_wirePrompt(descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("ProximityPrompt") then
			_wirePrompt(descendant)
		end
	end)

	-- Expose hatch for the placeholder UI button (see UI/PlaceholderUI).
	InteractionController.RequestHatch = function()
		if _carriedEggId ~= nil then
			-- Already carried: nothing to hatch yet.
			return
		end
		-- The server rejects hatches with no DELIVERED egg; UI passes last delivered id.
		local lastDelivered = InteractionController._lastDelivered
		if typeof(lastDelivered) == "string" then
			requestHatch:FireServer(lastDelivered)
		end
	end

	eggChanged.OnClientEvent:Connect(function(eggId: string, state: string)
		if state == "DELIVERED" then
			InteractionController._lastDelivered = eggId
		elseif state == "HATCHED" then
			InteractionController._lastDelivered = nil
		end
	end)
end

InteractionController._lastDelivered = nil :: string?

return InteractionController
