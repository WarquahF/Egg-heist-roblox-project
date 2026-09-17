--!strict
-- Egg Heist — PlotZones (SERVER ONLY, no state).
-- Single copy of "find a part inside a player's plot + measure distance".
-- Used by EggService (own-incubator delivery check) and TrainingService
-- (own-pad training check). PlotId always comes from PlotService, never
-- from the client, so a player can only ever validate against their own plot.

local PlotZones = {}

-- Resolves workspace.Plots[<plotId>]/<partName> ("Incubator" | "TrainingPad").
-- Falls back to an attribute scan so hand-built maps keep working as long as
-- parts carry PlotId attributes and the expected names.
function PlotZones.GetPlotPart(plotId: string, partName: string): BasePart?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder ~= nil then
		local plotFolder = plotsFolder:FindFirstChild(plotId)
		if plotFolder ~= nil then
			local direct = plotFolder:FindFirstChild(partName)
			if direct ~= nil and direct:IsA("BasePart") then
				return direct
			end
		end
	end
	for _, descendant in workspace:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant.Name == partName
			and descendant:GetAttribute("PlotId") == plotId
		then
			return descendant
		end
	end
	return nil
end

local function _playerRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Server-measured proximity. Missing character/part/plot answers false
-- (reject), never true. `maxDistance` comes from Constants.
function PlotZones.IsNearOwnPlotPart(player: Player, plotId: string, partName: string, maxDistance: number): boolean
	local root = _playerRoot(player)
	local part = PlotZones.GetPlotPart(plotId, partName)
	if root == nil or part == nil then
		return false
	end
	return (root.Position - part.Position).Magnitude <= maxDistance
end

return PlotZones
