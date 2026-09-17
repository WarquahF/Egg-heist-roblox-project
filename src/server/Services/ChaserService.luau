--!strict
-- Egg Heist — ChaserService (SERVER ONLY).
-- CRITICAL RULE: a chaser targets ONLY the carrier of its egg.
--   Egg X carried by Player A  =>  Chaser X target = Player A, even if B is closer.
-- On deliver / reset / carrier-leave: target = nil, chaser goes idle.
-- Movement below is a minimal placeholder (Humanoid:MoveTo); humans own real AI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local ChaserConfig = require(Shared:WaitForChild("Config"):WaitForChild("Chasers"))
local ValidationRules = require(Shared:WaitForChild("ValidationRules"))

local ChaserService = {}
-- EggId -> UserId (nil = idle). Keyed by EGG so the relation stays obvious.
ChaserService._targets = {} :: { [string]: number? }
ChaserService._npcs = {} :: { [string]: Model }
ChaserService._deps = nil :: any

-- Read-only link to EggService (Chaser never mutates eggs; Egg never requires
-- Chaser). Lets the follow loop re-verify target == carrier every tick.
function ChaserService.Init(deps: { EggService: any }?)
	ChaserService._deps = deps
end

-- Called ONLY from ServerMain wiring of EggService.Claimed. Never from proximity.
-- Trust-but-verify: the egg's recorded carrier must equal the claimed player,
-- otherwise the signal is stale and the target is NOT set.
function ChaserService.SetTargetToCarrier(player: Player, eggId: string)
	local deps = ChaserService._deps
	if deps ~= nil and deps.EggService ~= nil then
		local egg = deps.EggService.Get(eggId)
		local carrier = if egg then egg.CarrierUserId else nil
		if carrier ~= player.UserId then
			return
		end
	end
	ChaserService._targets[eggId] = player.UserId
end

function ChaserService.ClearTarget(eggId: string)
	ChaserService._targets[eggId] = nil
	local npc = ChaserService._npcs[eggId]
	if npc ~= nil then
		ChaserService._returnHome(npc)
	end
end

function ChaserService.ClearTargetsForPlayer(player: Player)
	for eggId, userId in pairs(ChaserService._targets) do
		if userId == player.UserId then
			ChaserService.ClearTarget(eggId)
		end
	end
end

function ChaserService.GetTarget(eggId: string): number?
	return ChaserService._targets[eggId]
end

-- Binds a world NPC (Model with Humanoid + HumanoidRootPart) to an egg.
function ChaserService.BindNpc(eggId: string, npc: Model)
	ChaserService._npcs[eggId] = npc
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local cfg = ChaserConfig[npc:GetAttribute("ChaserId") :: string]
	if humanoid ~= nil and cfg ~= nil then
		humanoid.WalkSpeed = (cfg :: any).WalkSpeed
	end
end

-- Current carrier per EggService, or nil. Single read path for the sweep.
-- Falls back to the stored target when no verifier is wired (e.g. unit tests
-- calling Init() with no deps), preserving the previous behavior exactly.
function ChaserService._carrierOf(eggId: string): number?
	local deps = ChaserService._deps
	if deps == nil or deps.EggService == nil then
		return ChaserService._targets[eggId]
	end
	local egg = deps.EggService.Get(eggId)
	if egg == nil then
		return nil
	end
	return egg.CarrierUserId
end

function ChaserService._returnHome(npc: Model)
	-- TODO(Human): store per-chaser home CFrame and path back to it.
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid ~= nil and root ~= nil and npc:GetAttribute("HomePosition") ~= nil then
		humanoid:MoveTo(npc:GetAttribute("HomePosition") :: Vector3)
	end
end

function ChaserService.Start()
	-- Auto-bind placeholder chasers tagged with EggId attribute.
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and typeof(descendant:GetAttribute("EggId")) == "string" then
			ChaserService.BindNpc(descendant:GetAttribute("EggId") :: string, descendant)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		ChaserService.ClearTargetsForPlayer(player)
	end)

	-- Minimal follow loop: 4 Hz server tick, carrier ONLY. No nearest-player logic.
	-- Every tick re-verifies target == egg carrier (Scenario E/F sweep): any
	-- divergence clears the target instead of chasing a stale player.
	-- TODO(Human): replace with pathfinding + leash + stun/escape rules.
	task.spawn(function()
		while true do
			task.wait(Constants.CHASER_TICK_SECONDS)
			for eggId, userId in pairs(ChaserService._targets) do
				if not ValidationRules.ShouldChase(userId, ChaserService._carrierOf(eggId)) then
					-- Covers: deliver/reset already cleared the carrier, carrier
					-- left (Scenario E/F), or a stale/exploited target value.
					ChaserService.ClearTarget(eggId)
					continue
				end
				assert(userId ~= nil, "ShouldChase passed so a target exists")
				local npc = ChaserService._npcs[eggId]
				local targetPlayer = Players:GetPlayerByUserId(userId)
				if targetPlayer == nil then
					ChaserService.ClearTarget(eggId)
					continue
				end
				local humanoid = if npc then npc:FindFirstChildOfClass("Humanoid") else nil
				local root = if npc then npc:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				local targetRoot = if targetPlayer and targetPlayer.Character
					then targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					else nil
				if humanoid ~= nil and root ~= nil and targetRoot ~= nil then
					-- RunService check keeps Studio edit-mode safe if loop outlives playtest.
					if RunService:IsRunning() then
						humanoid:MoveTo(targetRoot.Position)
					end
				end
			end
		end
	end)
end

return ChaserService
