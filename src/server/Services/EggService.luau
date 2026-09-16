--!strict
-- Egg Heist — EggService (SERVER ONLY, authoritative egg state).
-- Owns: registration, AVAILABLE -> CLAIMED -> CARRIED -> DELIVERED -> HATCHED,
-- carrier tracking, claim/deliver/reset. Invalid transitions are rejected.
-- Emits signals so ServerMain can wire ChaserService WITHOUT a require cycle:
--   EggService.Claimed(player, eggId) / EggService.Freed(eggId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EggStateMachine = require(Shared:WaitForChild("EggStateMachine"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

export type EggRecord = {
	EggId: string,
	State: string,
	CarrierUserId: number?,
}

local EggService = {}
EggService._deps: any = nil
EggService._eggs: { [string]: EggRecord } = {}
EggService._carriedBy: { [number]: string } = {} -- UserId -> EggId (one egg at a time)
EggService._lastTakeAt: { [number]: number } = {}
EggService.Claimed: BindableEvent? = nil
EggService.Freed: BindableEvent? = nil

function EggService.Init(deps: { Remotes: any })
	EggService._deps = deps
	EggService.Claimed = Instance.new("BindableEvent")
	EggService.Freed = Instance.new("BindableEvent")
end

function EggService.RegisterEgg(eggId: string)
	if EggService._eggs[eggId] == nil then
		EggService._eggs[eggId] = { EggId = eggId, State = "AVAILABLE", CarrierUserId = nil }
	end
end

function EggService.Get(eggId: string): EggRecord?
	return EggService._eggs[eggId]
end

function EggService.GetCarriedEggId(player: Player): string?
	return EggService._carriedBy[player.UserId]
end

local function _broadcast(egg: EggRecord)
	EggService._deps.Remotes.Get(RemoteNames.EggStateChanged):FireAllClients(egg.EggId, egg.State, egg.CarrierUserId)
end

local function _setState(egg: EggRecord, to: string, carrier: number?)
	EggStateMachine.AssertTransition(egg.State :: any, to :: any)
	egg.State = to
	egg.CarrierUserId = carrier
	_broadcast(egg)
end

local function _playerRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function _eggPart(eggId: string): BasePart?
	-- PlaceholderWorld tags each egg Part with attribute EggId; humans keep the
	-- convention or replace this lookup with their own registry.
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("EggId") == eggId then
			return descendant
		end
	end
	return nil
end

local function _withinRange(player: Player, eggId: string): boolean
	-- TODO(Human): replace linear scan with a per-egg cached Part reference.
	local root = _playerRoot(player)
	local part = _eggPart(eggId)
	if root == nil or part == nil then
		return false
	end
	return (root.Position - part.Position).Magnitude <= Constants.MAX_INTERACT_DISTANCE
end

-- Validation order matters (cheap checks first, exploited checks always).
function EggService.RequestTakeEgg(player: Player, eggId: string): boolean
	if typeof(eggId) ~= "string" or eggId == "" then
		return false
	end
	local now = os.clock()
	if now - (EggService._lastTakeAt[player.UserId] or 0) < Constants.TAKE_EGG_COOLDOWN_SECONDS then
		return false
	end
	EggService._lastTakeAt[player.UserId] = now

	local egg = EggService._eggs[eggId]
	if egg == nil or egg.State ~= "AVAILABLE" then
		return false
	end
	if EggService._carriedBy[player.UserId] ~= nil then
		return false -- already carrying one egg
	end
	if not _withinRange(player, eggId) then
		return false
	end

	_setState(egg, "CLAIMED", player.UserId)
	EggService._carriedBy[player.UserId] = eggId
	-- Beta simplification: CLAIMED -> CARRIED immediately (attach visual next).
	_setState(egg, "CARRIED", player.UserId)

	local claimed = EggService.Claimed
	if claimed ~= nil then
		claimed:Fire(player, eggId)
	end
	return true
end

-- TODO(Human): verify the player is inside THEIR OWN plot incubator zone.
function EggService.RequestDeliverEgg(player: Player, eggId: string): boolean
	local egg = EggService._eggs[eggId]
	if egg == nil or egg.State ~= "CARRIED" or egg.CarrierUserId ~= player.UserId then
		return false
	end
	EggService._carriedBy[player.UserId] = nil
	_setState(egg, "DELIVERED", nil)
	local freed = EggService.Freed
	if freed ~= nil then
		freed:Fire(eggId)
	end
	return true
end

-- Returns the egg to AVAILABLE (drop / carrier left / chase reset).
function EggService.ResetEgg(eggId: string)
	local egg = EggService._eggs[eggId]
	if egg == nil or egg.State == "AVAILABLE" or egg.State == "HATCHED" then
		return
	end
	if egg.CarrierUserId ~= nil then
		EggService._carriedBy[egg.CarrierUserId] = nil
	end
	-- Route through legal transitions so the state machine stays honest.
	if egg.State == "CLAIMED" or egg.State == "CARRIED" then
		_setState(egg, "AVAILABLE", nil)
	elseif egg.State == "DELIVERED" then
		return -- delivered eggs wait for HatchService, never auto-reset
	end
	local freed = EggService.Freed
	if freed ~= nil then
		freed:Fire(eggId)
	end
end

function EggService.MarkHatched(eggId: string)
	local egg = EggService._eggs[eggId]
	if egg == nil or egg.State ~= "DELIVERED" then
		return
	end
	_setState(egg, "HATCHED", nil)
	-- TODO(Human): respawn timer that returns HATCHED -> AVAILABLE as a NEW cycle.
	-- Currently the state machine ends at HATCHED; add an explicit RESPAWNING
	-- state if eggs should reuse the same EggId (see DEVELOPMENT.md).
end

function EggService.ReleasePlayerEggs(player: Player)
	local eggId = EggService._carriedBy[player.UserId]
	if eggId ~= nil then
		EggService.ResetEgg(eggId)
	end
	EggService._lastTakeAt[player.UserId] = nil
end

function EggService.Start()
	local remotes = EggService._deps.Remotes
	remotes.Get(RemoteNames.RequestTakeEgg).OnServerEvent:Connect(function(player: Player, eggId: any)
		EggService.RequestTakeEgg(player, eggId)
	end)
	remotes.Get(RemoteNames.RequestDeliverEgg).OnServerEvent:Connect(function(player: Player, eggId: any)
		EggService.RequestDeliverEgg(player, eggId)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		EggService.ReleasePlayerEggs(player)
	end)

	-- Auto-register placeholder eggs tagged with EggId attribute (dev convenience).
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and typeof(descendant:GetAttribute("EggId")) == "string" then
			EggService.RegisterEgg(descendant:GetAttribute("EggId") :: string)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") then
			task.defer(function()
				local id = descendant:GetAttribute("EggId")
				if typeof(id) == "string" then
					EggService.RegisterEgg(id)
				end
			end)
		end
	end)
end

return EggService
