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
local ValidationRules = require(Shared:WaitForChild("ValidationRules"))

local PlotZones = require(script.Parent:WaitForChild("PlotZones"))

export type EggRecord = {
	EggId: string,
	State: string,
	CarrierUserId: number?,
	-- Server-recorded delivery provenance (never client-provided).
	DeliveredByUserId: number?,
	DeliveredPlotId: string?,
}

local EggService = {}
EggService._deps = nil :: any
EggService._eggs = {} :: { [string]: EggRecord }
EggService._carriedBy = {} :: { [number]: string } -- UserId -> EggId (one egg at a time)
EggService._parts = {} :: { [string]: BasePart } -- EggId -> world part (cached at registration)
EggService._lastTakeAt = {} :: { [number]: number }
EggService._lastDeliverAt = {} :: { [number]: number }
EggService.Claimed = nil :: BindableEvent?
EggService.Freed = nil :: BindableEvent?

function EggService.Init(deps: { Remotes: any, PlotService: any })
	EggService._deps = deps
	EggService.Claimed = Instance.new("BindableEvent")
	EggService.Freed = Instance.new("BindableEvent")
end

function EggService.RegisterEgg(eggId: string, part: BasePart?)
	if EggService._eggs[eggId] == nil then
		EggService._eggs[eggId] = {
			EggId = eggId,
			State = "AVAILABLE",
			CarrierUserId = nil,
			DeliveredByUserId = nil,
			DeliveredPlotId = nil,
		}
	end
	if part ~= nil then
		EggService._parts[eggId] = part
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
	-- Cached at registration; the scan below is a fallback for parts added
	-- without a reference (e.g. hand-built maps), and it re-caches on hit.
	-- One part per EggId: duplicate EggId tags are a map bug, surfaced by the
	-- first-registered part winning here.
	local cached = EggService._parts[eggId]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("EggId") == eggId then
			EggService._parts[eggId] = descendant
			return descendant
		end
	end
	return nil
end

local function _withinRange(player: Player, eggId: string): boolean
	local root = _playerRoot(player)
	local part = _eggPart(eggId)
	if root == nil or part == nil then
		return false
	end
	return (root.Position - part.Position).Magnitude <= Constants.MAX_INTERACT_DISTANCE
end

-- Server-measured "standing at my own incubator". PlotId comes from
-- PlotService state; distance is measured server-side. The client is never
-- asked where it is or which plot it means.
local function _atOwnIncubator(player: Player): (boolean, string?)
	local plotId = EggService._deps.PlotService.GetPlotForPlayer(player)
	if plotId == nil then
		return false, nil
	end
	local near = PlotZones.IsNearOwnPlotPart(player, plotId, "Incubator", Constants.MAX_INTERACT_DISTANCE)
	return near, plotId
end

-- Validation order matters (cheap checks first, exploited checks always).
-- Every rejection returns false WITHOUT changing state.
function EggService.RequestTakeEgg(player: Player, eggId: any): boolean
	local id = ValidationRules.SanitizeEggId(eggId)
	if id == nil then
		return false
	end
	local now = os.clock()
	if now - (EggService._lastTakeAt[player.UserId] or 0) < Constants.TAKE_EGG_COOLDOWN_SECONDS then
		return false
	end
	EggService._lastTakeAt[player.UserId] = now

	local egg = EggService._eggs[id]
	local state = if egg then egg.State else nil
	if not ValidationRules.CanClaim(state, EggService._carriedBy[player.UserId] ~= nil) then
		return false -- nonexistent, not AVAILABLE (Scenario A loser), or already carrying
	end
	if not _withinRange(player, id) then
		return false
	end
	assert(egg ~= nil, "CanClaim passed so the egg exists")

	_setState(egg, "CLAIMED", player.UserId)
	EggService._carriedBy[player.UserId] = id
	-- Beta simplification: CLAIMED -> CARRIED immediately (attach visual next).
	_setState(egg, "CARRIED", player.UserId)

	local claimed = EggService.Claimed
	if claimed ~= nil then
		claimed:Fire(player, id)
	end
	return true
end

-- Phase 2/11: delivery is valid ONLY at the carrier's OWN plot incubator.
-- Required chain: sanitized id -> deliver cooldown -> CARRIED-by-caller ->
-- caller owns a plot -> caller stands at that plot's incubator (server-measured).
function EggService.RequestDeliverEgg(player: Player, eggId: any): boolean
	local id = ValidationRules.SanitizeEggId(eggId)
	if id == nil then
		return false
	end
	local now = os.clock()
	if now - (EggService._lastDeliverAt[player.UserId] or 0) < Constants.DELIVER_EGG_COOLDOWN_SECONDS then
		return false
	end
	EggService._lastDeliverAt[player.UserId] = now

	local egg = EggService._eggs[id]
	local state = if egg then egg.State else nil
	local carrier = if egg then egg.CarrierUserId else nil
	local nearIncubator, plotId = _atOwnIncubator(player) -- nil plot or far away -> both answers reject below
	if egg == nil or not ValidationRules.CanDeliver(player.UserId, carrier, state, plotId, nearIncubator) then
		return false -- covers Scenario B (another player's egg), no plot, wrong location
	end

	EggService._carriedBy[player.UserId] = nil
	egg.DeliveredByUserId = player.UserId
	egg.DeliveredPlotId = plotId
	_setState(egg, "DELIVERED", nil)
	local freed = EggService.Freed
	if freed ~= nil then
		freed:Fire(id)
	end
	return true
end

-- Returns the egg to AVAILABLE (drop / carrier left / chase reset).
-- Clears carrier AND delivery provenance so no stale ownership survives.
function EggService.ResetEgg(eggId: string)
	local egg = EggService._eggs[eggId]
	if egg == nil or egg.State == "AVAILABLE" or egg.State == "HATCHED" then
		return
	end
	if egg.CarrierUserId ~= nil then
		EggService._carriedBy[egg.CarrierUserId] = nil
	end
	egg.CarrierUserId = nil
	egg.DeliveredByUserId = nil
	egg.DeliveredPlotId = nil
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
	EggService._lastDeliverAt[player.UserId] = nil
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
			EggService.RegisterEgg(descendant:GetAttribute("EggId") :: string, descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") then
			task.defer(function()
				local id = descendant:GetAttribute("EggId")
				if typeof(id) == "string" then
					EggService.RegisterEgg(id, descendant)
				end
			end)
		end
	end)
end

return EggService
