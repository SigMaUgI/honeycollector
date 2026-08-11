-- honeycollector.lua
-- Auto-collect + pathfinding

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TARGET_NAMES = {
	["Collectible"] = true,
	["Pickup"] = true,
	["Item"] = true,
	["Food"] = true,
	["Sandwich"] = true,
}

local SEARCH_DELAY = 0.15
local REPATH_DELAY = 0.35
local REACH_DISTANCE = 5

local AGENT_RADIUS = 2
local AGENT_HEIGHT = 5
local AGENT_CAN_JUMP = true
local AGENT_CAN_CLIMB = true

local character
local humanoid
local root

local function getCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
end

getCharacter()

player.CharacterAdded:Connect(function()
	task.wait(1)
	getCharacter()
end)

local function getPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end

	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart.Position
		end

		local part = object:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	return nil
end

local function isTarget(object)
	if not object then
		return false
	end

	if TARGET_NAMES[object.Name] then
		return true
	end

	if object:GetAttribute("Collectible") == true then
		return true
	end

	if object:GetAttribute("Pickup") == true then
		return true
	end

	local collectibleValue = object:FindFirstChild("Collectible")
	if collectibleValue and collectibleValue:IsA("BoolValue") and collectibleValue.Value == true then
		return true
	end

	return false
end

local function findNearestTarget()
	if not root then
		return nil
	end

	local nearest
	local nearestDistance = math.huge

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object ~= character and isTarget(object) then
			local position = getPosition(object)

			if position then
				local distance = (root.Position - position).Magnitude

				if distance < nearestDistance then
					nearestDistance = distance
					nearest = object
				end
			end
		end
	end

	return nearest
end

local function createPath()
	return PathfindingService:CreatePath({
		AgentRadius = AGENT_RADIUS,
		AgentHeight = AGENT_HEIGHT,
		AgentCanJump = AGENT_CAN_JUMP,
		AgentCanClimb = AGENT_CAN_CLIMB,
		Costs = {
			Water = 20
		}
	})
end

local function targetStillExists(target)
	return target
		and target.Parent
		and target:IsDescendantOf(Workspace)
		and getPosition(target) ~= nil
end

local function walkToTarget(target)
	if not humanoid or not root then
		return
	end

	while targetStillExists(target) do
		local targetPosition = getPosition(target)
		if not targetPosition then
			return
		end

		if (root.Position - targetPosition).Magnitude <= REACH_DISTANCE then
			humanoid:MoveTo(root.Position)

			while targetStillExists(target) do
				task.wait(0.05)
			end

			return
		end

		local path = createPath()

		local success = pcall(function()
			path:ComputeAsync(root.Position, targetPosition)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			for _, waypoint in ipairs(path:GetWaypoints()) do
				if not targetStillExists(target) then
					return
				end

				local currentTargetPosition = getPosition(target)
				if not currentTargetPosition then
					return
				end

				if (root.Position - currentTargetPosition).Magnitude <= REACH_DISTANCE then
					break
				end

				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end

				humanoid:MoveTo(waypoint.Position)

				local reached = false
				local connection = humanoid.MoveToFinished:Connect(function()
					reached = true
				end)

				local startTime = tick()

				while not reached do
					if not targetStillExists(target) then
						connection:Disconnect()
						return
					end

					if tick() - startTime > 2 then
						break
					end

					local newestPosition = getPosition(target)
					if newestPosition and (newestPosition - targetPosition).Magnitude > 7 then
						break
					end

					task.wait(0.05)
				end

				connection:Disconnect()
			end
		else
			humanoid:MoveTo(targetPosition)
		end

		task.wait(REPATH_DELAY)
	end
end

task.spawn(function()
	while true do
		if not character
			or not character.Parent
			or not humanoid
			or humanoid.Health <= 0
			or not root then
			getCharacter()
		end

		local target = findNearestTarget()

		if target then
			walkToTarget(target)
		else
			task.wait(SEARCH_DELAY)
		end
	end
end)
