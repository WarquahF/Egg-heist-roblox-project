--!strict
-- Egg Heist — Placeholder world builder (DEV ONLY, server).
-- Creates simple Parts/Models so the Beta loop is playable without final art:
--   4 plots (platform + spawn + training pad + incubator), runway, 3 eggs, 3 chasers.
-- Safe to DELETE once the art team builds the real map: Services only depend on
-- attributes (EggId / ChaserId / PlotId), ProximityPrompts, and folders, not on looks.
-- Toggle via DEV_BUILD_PLACEHOLDERS in ServerMain.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local PlotConfig = require(Shared:WaitForChild("Config"):WaitForChild("Plots"))

local PlaceholderWorld = {}

local function _part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value;
		end
	end
	p.Anchored = true
	p.Parent = parent
	return p
end

function PlaceholderWorld.Build()
	if workspace:FindFirstChild("Plots") ~= nil and workspace:FindFirstChild("Eggs") ~= nil then
		return -- real map (or previous build) already exists; don't overwrite
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	local plotSpacing = 40
	for index, plotId in PlotConfig.PlotIds do
		local origin = Vector3.new((index - 1) * plotSpacing - 60, 1, 0)

		local plotFolder = Instance.new("Folder")
		plotFolder.Name = plotId
		plotFolder:SetAttribute("PlotId", plotId)
		plotFolder.Parent = plotsFolder

		_part({
			Name = "Base",
			Size = Vector3.new(24, 2, 24),
			Position = origin,
			Color = Color3.fromRGB(120, 120, 120),
		}, plotFolder)

		local spawn = _part({
			Name = "Spawn",
			Size = Vector3.new(6, 1, 6),
			Position = origin + Vector3.new(0, 2, -6),
			Color = Color3.fromRGB(100, 200, 100),
		}, plotFolder)
		spawn:SetAttribute("PlotId", plotId)

		local pad = _part({
			Name = "TrainingPad",
			Size = Vector3.new(6, 1, 6),
			Position = origin + Vector3.new(-6, 2, 6),
			Color = Color3.fromRGB(255, 200, 80),
		}, plotFolder)
		pad:SetAttribute("PlotId", plotId)
		local trainPrompt = Instance.new("ProximityPrompt")
		trainPrompt.ActionText = "Train"
		trainPrompt.ObjectText = "Training Pad"
		trainPrompt.HoldDuration = 0
		trainPrompt.MaxActivationDistance = 12
		trainPrompt.Name = "TrainPrompt"
		trainPrompt.Parent = pad

		local incubator = _part({
			Name = "Incubator",
			Size = Vector3.new(6, 4, 6),
			Position = origin + Vector3.new(6, 3, 6),
			Color = Color3.fromRGB(150, 220, 255),
		}, plotFolder)
		incubator:SetAttribute("PlotId", plotId)
		local deliverPrompt = Instance.new("ProximityPrompt")
		deliverPrompt.ActionText = "Deliver"
		deliverPrompt.ObjectText = "Incubator"
		deliverPrompt.HoldDuration = 0
		deliverPrompt.MaxActivationDistance = 12
		deliverPrompt.Name = "DeliverPrompt"
		deliverPrompt.Parent = incubator
	end

	-- Runway extending away from plots (+Z), eggs placed by config distance.
	_part({
		Name = "Runway",
		Size = Vector3.new(20, 1, 700),
		Position = Vector3.new(0, 0, 350),
		Color = Color3.fromRGB(90, 90, 90),
	}, workspace)

	local eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = workspace

	local chasersFolder = Instance.new("Folder")
	chasersFolder.Name = "Chasers"
	chasersFolder.Parent = workspace

	local laneX = 0
	for eggId, cfg in pairs(EggsConfig) do
		laneX += 5
		local c = cfg :: any
		local egg = _part({
			Name = eggId,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Position = Vector3.new(laneX - 7, 4, c.DistanceFromPlots),
			Color = c.PlaceholderColor,
		}, eggsFolder)
		egg:SetAttribute("EggId", eggId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = eggId
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.Name = "TakePrompt"
		prompt.Parent = egg

		-- Placeholder chaser NPC: simple R15-ish block rig.
		local npc = Instance.new("Model")
		npc.Name = "Chaser_" .. eggId
		npc:SetAttribute("EggId", eggId)
		npc:SetAttribute("ChaserId", c.ChaserId)
		npc:SetAttribute("HomePosition", Vector3.new(laneX - 7, 4, c.DistanceFromPlots + 8))
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Position = Vector3.new(laneX - 7, 4, c.DistanceFromPlots + 8)
		root.Color = Color3.fromRGB(200, 60, 60)
		root.Anchored = false
		root.CanCollide = false
		root.Parent = npc
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = npc
		npc.PrimaryPart = root
		npc.Parent = chasersFolder
	end
end

return PlaceholderWorld
