--[[
    =========  SERVICES  =========
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

--[[
    =========  MODULE  =========
]]
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local SoccerPhysics = require(SharedFolder:WaitForChild("SoccerPhysics"))

--[[
    =========  CONSTANT  =========
]]
local BALL_TAG_NAME = "ball"
local BALL_SPAWN_TAG_NAME = "ball_Spawn"
local GOAL_TAG_NAME = "goal"
local STEAL_RANGE = 6
local PICKUP_RADIUS = 4

local BALL_COLLISION_GROUP = "Ball"
local PLAYERS_COLLISION_GROUP = "Players"

--[[
    =========  VARIABLE  =========
]]
local ball = nil
local currentOwner = nil

--[[
    =========  ASSETS  =========
]]
local SoccerBall = ReplicatedStorage:WaitForChild("SoccerBall")

local SoccerEvents = Instance.new("RemoteEvent")
SoccerEvents.Name = "SoccerEvents"
SoccerEvents.Parent = ReplicatedStorage

--[[
    =========  HELPER FUNCTION  =========
]]
local function setBallOwner(newOwner)
    if newOwner then
        currentOwner = newOwner.Character
    else
        currentOwner = nil
    end

    if not ball then return end
    ball.PrimaryPart:SetNetworkOwner(newOwner)
	SoccerEvents:FireAllClients("BallOwnerChanged", newOwner, ball)
end

local function onRequestSteal(player)
	if not ball then return end

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local distance = (rootPart.Position - ball.PrimaryPart.Position).Magnitude
	if distance > STEAL_RANGE then return end

	if currentOwner == character then return end

	setBallOwner(player)
end

local function checkBallPickup()
	if not ball then return end

	if currentOwner then
		local humanoid = currentOwner:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			setBallOwner(nil)
		else
			return
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		local distance = (rootPart.Position - ball.PrimaryPart.Position).Magnitude
		if distance <= PICKUP_RADIUS then
			setBallOwner(player)
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
            print("YE GOOAL")
            setBallOwner(nil)
            ball.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            ball:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 3, 0)))
        end
    end)
end

local function initBall()
    spawnBall()

	CollectionService:GetInstanceAddedSignal(BALL_TAG_NAME):Connect(function(instance)
		ball = instance
	end)

	RunService.Heartbeat:Connect(checkBallPickup)
end

--[[
    =========  MAIN  =========
]]
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
SoccerEvents.OnServerEvent:Connect(function(player, action)
    if action == "RequestSteal" then
        onRequestSteal(player)
    end
end)
