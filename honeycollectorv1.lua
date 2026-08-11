-- honeycollectorv1.lua
-- Finds the nearest object named "HoneyJar", pathfinds to it,
-- waits for it to disappear/get collected, then finds the next one.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TARGET_NAME = "HoneyJar"
local SEARCH_DELAY = 0.15
local REPATH_DELAY = 0.25
local REACH_DISTANCE = 4

local character
local humanoid
local root

local function refreshCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
end

refreshCharacter()

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	refreshCharacter()
end)

local function getTargetPart(obj)
	if not obj then
		return nil
	end

	if obj:IsA("BasePart") then
		return obj
	end

	if obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart
		end
		return obj:FindFirstChildWhichIsA("BasePart", true)
	end

	if obj:IsA("Tool") or obj:IsA("Folder") then
		local handle = obj:FindFirstChild("Handle", true)
		if handle and handle:IsA("BasePart") then
			return handle
		end
		return obj:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function isValidTarget(obj)
	if not obj or not obj.Parent then
		return false
	end

	if obj.Name ~= TARGET_NAME then
		return false
	end

	if character and obj:IsDescendantOf(character) then
		return false
	end

	return getTargetPart(obj) ~= nil
end

local function findNearestHoneyJar()
	if not root then
		return nil
	end

	local nearest = nil
	local nearestDistance = math.huge

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == TARGET_NAME and isValidTarget(obj) then
			local part = getTargetPart(obj)
			if part then
				local distance = (root.Position - part.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = obj
				end
			end
		end
	end

	return nearest
end

local function targetStillExists(target)
	return target
		and target.Parent
		and target:IsDescendantOf(Workspace)
		and getTargetPart(target) ~= nil
end

local function makePath()
	return PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 3
	})
end

local function moveToWaypoint(position, timeout)
	if not humanoid or not root then
		return false
	end

	humanoid:MoveTo(position)

	local finished = false
	local reached = false

	local connection
	connection = humanoid.MoveToFinished:Connect(function(success)
		reached = success
		finished = true
	end)

	local started = os.clock()

	while not finished and os.clock() - started < timeout do
		if not humanoid or humanoid.Health <= 0 then
			break
		end
		task.wait(0.03)
	end

	if connection then
		connection:Disconnect()
	end

	return reached
end

local function walkToHoneyJar(target)
	while targetStillExists(target) do
		if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root then
			refreshCharacter()
			return
		end

		local targetPart = getTargetPart(target)
		if not targetPart then
			return
		end

		local targetPosition = targetPart.Position
		local distance = (root.Position - targetPosition).Magnitude

		if distance <= REACH_DISTANCE then
			humanoid:MoveTo(targetPosition)

			while targetStillExists(target) do
				local p = getTargetPart(target)
				if p then
					humanoid:MoveTo(p.Position)
				end
				task.wait(0.08)
			end

			return
		end

		local path = makePath()

		local success = pcall(function()
			path:ComputeAsync(root.Position, targetPosition)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			for _, waypoint in ipairs(path:GetWaypoints()) do
				if not targetStillExists(target) then
					return
				end

				local currentPart = getTargetPart(target)
				if not currentPart then
					return
				end

				if (root.Position - currentPart.Position).Magnitude <= REACH_DISTANCE then
					break
				end

				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end

				local reached = moveToWaypoint(waypoint.Position, 1.5)

				if not reached then
					break
				end
			end
		else
			humanoid:MoveTo(targetPosition)
		end

		task.wait(REPATH_DELAY)
	end
end

task.spawn(function()
	while true do
		if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root then
			refreshCharacter()
		end

		local honeyJar = findNearestHoneyJar()

		if honeyJar then
			walkToHoneyJar(honeyJar)
		else
			task.wait(SEARCH_DELAY)
		end
	end
end)
