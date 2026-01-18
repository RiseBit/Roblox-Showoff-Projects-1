local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local SoccerPhysics = require(SharedFolder:WaitForChild("SoccerPhysics"))

local BALL_TAG_NAME = "ball"
local BALL_SPAWN_TAG_NAME = "ball_Spawn"
local BALL_INVINCIBLE_ATTRIBUTE = "Invincible"
local GOAL_TAG_NAME = "goal"
local STEAL_RANGE = 6
local PICKUP_RADIUS = 4

local BALL_COLLISION_GROUP = "Ball"
local PLAYERS_COLLISION_GROUP = "Players"

local STEAL_COOLDOWN = 1
local DRIBBLE_INVICIBLE_TIME = 1

local STEAL_DISTANCE_BUFFER = 4
local CHARGE_TIMEOUT_BUFFER = 1
local CHARGE_POWER_TOLERANCE = 10

local ball = nil
local currentOwner = nil
local currentOwnerPlayer = nil
local lastStealTime = os.clock()
local lastDribbleTime = 0
local shootChargeData = {}

local SoccerBall = ReplicatedStorage:WaitForChild("SoccerBall")

local SoccerEvents = Instance.new("RemoteEvent")
SoccerEvents.Name = "SoccerEvents"
SoccerEvents.Parent = ReplicatedStorage

local function setBallOwner(newOwner)
	if newOwner then
		currentOwner = newOwner.Character
		currentOwnerPlayer = newOwner
	else
		currentOwner = nil
		currentOwnerPlayer = nil
	end

	if not ball then return end
	
	ball.PrimaryPart:SetNetworkOwner(newOwner)
	ball:SetAttribute(BALL_INVINCIBLE_ATTRIBUTE, false)
	
	SoccerEvents:FireAllClients("BallOwnerChanged", newOwner, ball)
end

local function onRequestSteal(player)
	if not ball then return end
	if ball:GetAttribute(BALL_INVINCIBLE_ATTRIBUTE) then return end

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local distance = (rootPart.Position - ball.PrimaryPart.Position).Magnitude
	if distance > STEAL_RANGE + STEAL_DISTANCE_BUFFER then return end
	if os.clock() - lastStealTime < STEAL_COOLDOWN then return end
    
    if os.clock() - lastDribbleTime < DRIBBLE_INVICIBLE_TIME then return end

	if currentOwner == character then return end

	setBallOwner(player)
	lastStealTime = os.clock()
end

local function onStartShootCharge(player)
	if not ball then return end

	local character = player.Character
	if not character then return end

	if currentOwner ~= character then return end

	if shootChargeData[player] then return end

	local maxChargeTime = SoccerPhysics.Shoot.ChargeFullDuration + CHARGE_TIMEOUT_BUFFER

	shootChargeData[player] = {
		startTime = os.clock(),
		timeout = task.delay(maxChargeTime, function()
			if shootChargeData[player] then
				shootChargeData[player] = nil
				if currentOwnerPlayer == player then
					setBallOwner(nil)
				end
			end
		end)
	}
end

local function onRequestShoot(player, chargePower)
	if not ball then return end

	local character = player.Character
	if not character then return end

	if currentOwner ~= character then return end

	local chargeData = shootChargeData[player]
	if not chargeData then return end

	task.cancel(chargeData.timeout)
	shootChargeData[player] = nil

	if type(chargePower) ~= "number" then return end

	local config = SoccerPhysics.Shoot
	local chargeTime = os.clock() - chargeData.startTime
	local maxPossibleCharge = math.min(
		(chargeTime / config.ChargeTick) * config.ChargeIncrement,
		config.ChargeMax
	)

	chargePower = math.clamp(chargePower, 0, config.ChargeMax)

	if chargePower > maxPossibleCharge + CHARGE_POWER_TOLERANCE then
		chargePower = maxPossibleCharge
	end

	ball:SetAttribute(BALL_INVINCIBLE_ATTRIBUTE, true)

	task.delay(0.5, function()
		if currentOwnerPlayer == player then
			setBallOwner(nil)
		end
	end)
end

local function onDribble(player)
    if not ball then return end

    local character = player.Character
    if not character then return end

    if currentOwner ~= character then return end

    lastDribbleTime = os.clock()
end

local function checkBallPickup()
	if not ball then return end
    if ball:GetAttribute(BALL_INVINCIBLE_ATTRIBUTE) == true then return end
    
    if os.clock() - lastDribbleTime < DRIBBLE_INVICIBLE_TIME then return end

	if currentOwner then
		local humanoid = currentOwner:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			setBallOwner(nil)
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		local distance = (rootPart.Position - ball.PrimaryPart.Position).Magnitude
		if distance <= PICKUP_RADIUS and currentOwnerPlayer ~= player then
	        if os.clock() - lastStealTime < STEAL_COOLDOWN then return end
			setBallOwner(player)
			lastStealTime = os.clock()
			break
		end
	end
end

local function spawnBall()
	local spawnPoints = CollectionService:GetTagged(BALL_SPAWN_TAG_NAME)
	if #spawnPoints == 0 then return end

	local spawnPoint = spawnPoints[1]
	local newBall = SoccerBall:Clone()
	newBall:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 3, 0)))
	newBall.Parent = workspace
	CollectionService:AddTag(newBall, BALL_TAG_NAME)

	ball = newBall
	ball.PrimaryPart.CollisionGroup = BALL_COLLISION_GROUP

	ball.PrimaryPart.Touched:Connect(function(hit)
		if hit.Parent == currentOwner then return end
		if hit:HasTag(GOAL_TAG_NAME) then
			setBallOwner(nil)

			ball:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 3, 0)))
			SoccerEvents:FireAllClients("Goal")
            ball.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            ball.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function initBall()
	spawnBall()

	CollectionService:GetInstanceAddedSignal(BALL_TAG_NAME):Connect(function(instance)
		ball = instance
	end)

	RunService.Heartbeat:Connect(function(dt)
		checkBallPickup()
	end)
end

PhysicsService:RegisterCollisionGroup(BALL_COLLISION_GROUP)
PhysicsService:RegisterCollisionGroup(PLAYERS_COLLISION_GROUP)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION_GROUP, PLAYERS_COLLISION_GROUP, false)

local function setCharacterCollisionGroup(character)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYERS_COLLISION_GROUP
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYERS_COLLISION_GROUP
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setCharacterCollisionGroup)
	if player.Character then
		setCharacterCollisionGroup(player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		setCharacterCollisionGroup(player.Character)
	end
	player.CharacterAdded:Connect(setCharacterCollisionGroup)
end

initBall()

Players.PlayerRemoving:Connect(function(player)
	local chargeData = shootChargeData[player]
	if chargeData then
		task.cancel(chargeData.timeout)
		shootChargeData[player] = nil
	end
	
	if currentOwnerPlayer == player then
		setBallOwner(nil)
	end
end)

SoccerEvents.OnServerEvent:Connect(function(player, action, ...)
	if action == "RequestSteal" then
		onRequestSteal(player)
	elseif action == "StartShootCharge" then
		onStartShootCharge(player)
	elseif action == "Shoot" then
		onRequestShoot(player, ...)
    elseif action == "Dribble" then
        onDribble(player)
	end
end)
