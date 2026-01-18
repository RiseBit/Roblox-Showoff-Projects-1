local SoccerSystem = {}

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local SoccerPhysics = require(SharedFolder:WaitForChild("SoccerPhysics"))

local LocalPlayer = Players.LocalPlayer

local character, humanoid, rootPart
local AlignPosition, AlignOrientation, BallAttachment, PlayerAttachment
local CurrentBall, CurrentCylinder
local CylinderRotation = 0
local CylinderSpinConnection

local RunAnimationTrack
local SlideAnimationTrack
local ShootChargeAnimationTrack
local ShootReleaseAnimationTrack

local RUNNING_SPEED = 30
local WALK_SPEED = 8

local isRunning = false
local isShiftHeld = false
local moveConnection: RBXScriptConnection? = nil
local walkSpeedConnection: RBXScriptConnection? = nil

local IsSlide = false
local LastSlideTime = os.clock()
local SlideBodyVelocity

local IsCharge = false
local ChargePower = 0

local LastStealTime = 0
local STEAL_COOLDOWN = 0.5

local IsDribble = false
local LastDribbleTime = os.clock()
local DRIBBLE_COOLDOWN = 0.35

local IsLocalOwner = false

local SoccerEvents = ReplicatedStorage:WaitForChild("SoccerEvents")

local function updateRunState()
	if not humanoid or not RunAnimationTrack then return end
	if IsCharge then return end
	
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	local shouldRun = isShiftHeld and isMoving

	if shouldRun and not isRunning then
		isRunning = true
		
		local speedRatio = humanoid.WalkSpeed / RUNNING_SPEED
		local startAnimSpeed = math.pow(speedRatio, 2) 
		RunAnimationTrack:Play(0.2, 1, startAnimSpeed)
		
		TweenService:Create(humanoid, TweenInfo.new(1, Enum.EasingStyle.Exponential), {WalkSpeed = RUNNING_SPEED}):Play()
		
	elseif not shouldRun and isRunning then
		isRunning = false
		TweenService:Create(humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {WalkSpeed = WALK_SPEED}):Play()
		RunAnimationTrack:Stop(0.2)
	end
end

local function onWalkSpeedChanged()
	if isRunning and RunAnimationTrack and humanoid then
		local speedRatio = humanoid.WalkSpeed / RUNNING_SPEED
		RunAnimationTrack:AdjustSpeed(math.pow(speedRatio, 2))
	end
end

local function createCylinder(player)
	if not player or not player:IsA("Player") then return end

	local playerCharacter = player.Character
	if not playerCharacter then return end

	local HumanoidRootPart = playerCharacter:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	if CylinderSpinConnection then
		CylinderSpinConnection:Disconnect()
		CylinderSpinConnection = nil
	end
	if CurrentCylinder then CurrentCylinder:Destroy() end

	CurrentCylinder = Instance.new("Part")
	CurrentCylinder.Shape = Enum.PartType.Cylinder
	CurrentCylinder.Size = Vector3.new(.1, 6, 6)
	CurrentCylinder.Color = Color3.new(0.133333, 0.337255, 1)
	CurrentCylinder.Anchored = false
	CurrentCylinder.CanCollide = false
	CurrentCylinder.CastShadow = false
	CurrentCylinder.Parent = playerCharacter

	local weld = Instance.new("Weld")
	weld.Part0 = HumanoidRootPart
	weld.Part1 = CurrentCylinder
	weld.C0 = CFrame.new(0, -3, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld.C1 = CFrame.new()
	weld.Parent = HumanoidRootPart

	CylinderRotation = 0
	CylinderSpinConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not CurrentCylinder or not CurrentCylinder.Parent then
			CylinderSpinConnection:Disconnect()
			CylinderSpinConnection = nil
			return
		end

		CylinderRotation = CylinderRotation + math.rad(180) * deltaTime
		weld.C0 = CFrame.new(0, -3, 0) * CFrame.Angles(0, CylinderRotation, math.rad(90))
	end)
end

local function weldBallToPlayer(ballModel)
	CurrentBall = ballModel

	BallAttachment = Instance.new("Attachment")
	BallAttachment.Parent = ballModel.PrimaryPart

	PlayerAttachment = Instance.new("Attachment")
	PlayerAttachment.Position = Vector3.new(0, -2, -3)
	PlayerAttachment.Parent = LocalPlayer.Character.HumanoidRootPart

	AlignPosition = Instance.new("AlignPosition")
	AlignPosition.MaxForce = math.huge
	AlignPosition.Responsiveness = 50
	AlignPosition.Attachment0 = BallAttachment
	AlignPosition.Attachment1 = PlayerAttachment
	AlignPosition.Parent = ballModel.PrimaryPart

	AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientation.MaxTorque = math.huge
	AlignOrientation.Responsiveness = 50
	AlignOrientation.Attachment0 = BallAttachment
	AlignOrientation.Attachment1 = PlayerAttachment
	AlignOrientation.Parent = ballModel.PrimaryPart
end

local function releaseBall()
	if CurrentBall then
		CurrentBall = nil
	end
	if AlignPosition then
		AlignPosition:Destroy()
		AlignPosition = nil
	end
	if AlignOrientation then
		AlignOrientation:Destroy()
		AlignOrientation = nil
	end
	if BallAttachment then
		BallAttachment:Destroy()
		BallAttachment = nil
	end
	if PlayerAttachment then
		PlayerAttachment:Destroy()
		PlayerAttachment = nil
	end
	if CurrentCylinder then
		CurrentCylinder:Destroy()
	end
end

local function doSteal()
	if (os.clock() - LastStealTime) < STEAL_COOLDOWN then return end
	LastStealTime = os.clock()
	SoccerEvents:FireServer("RequestSteal")
end

local function doSlide()
	if CurrentBall then return end
	if IsSlide then
		SlideAnimationTrack:Stop()
		if SlideBodyVelocity then SlideBodyVelocity:Destroy() end
		return
	end
	if (os.clock() - LastSlideTime) < SoccerPhysics.Slide.Cooldown then return end

	IsSlide = true
	LastSlideTime = os.clock()

	SlideBodyVelocity = SoccerPhysics.applySlide(rootPart)

	SlideAnimationTrack:Play()

	doSteal()

	task.delay(SoccerPhysics.Slide.Duration, function()
		SlideAnimationTrack:Stop()
		if SlideBodyVelocity then SlideBodyVelocity:Destroy() end
	end)

	task.delay(SoccerPhysics.Slide.Cooldown, function()
		IsSlide = false
	end)
end

local function doShoot()
	if not IsCharge then return end
	if not CurrentBall then return end
	IsCharge = false
	humanoid.WalkSpeed = WALK_SPEED
    updateRunState()

	if ShootChargeAnimationTrack then ShootChargeAnimationTrack:Stop() end
	if ShootReleaseAnimationTrack then ShootReleaseAnimationTrack:Play() end
    
	local shootPower = ChargePower
	local ballPart = CurrentBall.PrimaryPart
	
	SoccerPhysics.applyShoot(ballPart, rootPart.CFrame.LookVector, shootPower)

	releaseBall()
	SoccerEvents:FireServer("Shoot", shootPower)
	ChargePower = 0
end

local function chargeShoot()
	if not rootPart or not ShootChargeAnimationTrack then return end
	if not CurrentBall then return end
	if IsCharge then return end
	IsCharge = true
    
    if isRunning then
        isRunning = false
        RunAnimationTrack:Stop(0.2)
    end

	local config = SoccerPhysics.Shoot
	local chargeTime = (config.ChargeMax / config.ChargeIncrement) * config.ChargeTick
	local animLength = ShootChargeAnimationTrack.Length - .1
	local animSpeed = animLength / chargeTime * 0.95

	ShootChargeAnimationTrack:Play()
	ShootChargeAnimationTrack:AdjustSpeed(animSpeed)

	humanoid.WalkSpeed = 2
	SoccerEvents:FireServer("StartShootCharge")

	task.spawn(function()
		while IsCharge and ChargePower < config.ChargeMax do
			ChargePower = math.min(ChargePower + config.ChargeIncrement, config.ChargeMax)
			task.wait(config.ChargeTick)
		end

		if IsCharge and ChargePower >= config.ChargeMax then
			ShootChargeAnimationTrack:AdjustSpeed(0)
			task.wait(config.ChargeFullDuration)
			if IsCharge then
				doShoot()
			end
		end
	end)
end

local function doDribble()
	if IsDribble then return end
	if not CurrentBall or not rootPart then return end
	if not PlayerAttachment or not AlignPosition then return end
	if (os.clock() - LastDribbleTime) < DRIBBLE_COOLDOWN then return end

	IsDribble = true
	LastDribbleTime = os.clock()

	local originalResponsiveness = AlignPosition.Responsiveness
	AlignPosition.Responsiveness = 15

	local dribbleRatio = humanoid.MoveDirection.Magnitude
	local kickDistance = -3 - (3 * dribbleRatio)

	local kickTween = TweenService:Create(
		PlayerAttachment,
		TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Position = Vector3.new(0, -2, kickDistance) }
	)
	kickTween:Play()

    SoccerEvents:FireServer("Dribble")

	task.delay(0.2, function()
		if not PlayerAttachment or not AlignPosition then return end

		local returnTween = TweenService:Create(
			PlayerAttachment,
			TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Position = Vector3.new(0, -2, -3) }
		)
		returnTween:Play()

		returnTween.Completed:Once(function()
			if AlignPosition then
				AlignPosition.Responsiveness = originalResponsiveness
			end
			IsDribble = false
		end)
	end)
end

function SoccerSystem.GlobalInit()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if not rootPart then return end

		if input.KeyCode == Enum.KeyCode.F then
			doSlide()
		elseif input.KeyCode == Enum.KeyCode.R then
			doDribble()
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            isShiftHeld = true
            if not IsCharge then updateRunState() end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			chargeShoot()
		end
	end)
    
    UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
        if input.KeyCode == Enum.KeyCode.LeftShift then
            isShiftHeld = false
            updateRunState()
        end
        
        if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			doShoot()
		end
    end)


	SoccerEvents.OnClientEvent:Connect(function(action, ...)
		if action == "BallOwnerChanged" then
			local arg = { ... }
			local ballOwner = arg[1]
			local ball = arg[2]

			IsLocalOwner = (LocalPlayer == ballOwner)

			createCylinder(ballOwner)
			
			if IsLocalOwner then
				weldBallToPlayer(ball)
			else
				releaseBall()
				IsCharge = false
				ChargePower = 0
				if humanoid then
					humanoid.WalkSpeed = WALK_SPEED
                    updateRunState()
				end
			end
		elseif action == "Goal" then
			releaseBall()
			IsCharge = false
			ChargePower = 0
			IsLocalOwner = false
		end
	end)
end

function SoccerSystem.Update(_character, _runTrack, _slideTrack, _shootChargeTrack, _shootReleaseTrack)
	character = _character
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

    RunAnimationTrack = _runTrack
	SlideAnimationTrack = _slideTrack
	ShootChargeAnimationTrack = _shootChargeTrack
	ShootReleaseAnimationTrack = _shootReleaseTrack
    
    if moveConnection then moveConnection:Disconnect() end
    if walkSpeedConnection then walkSpeedConnection:Disconnect() end
    
    moveConnection = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(updateRunState)
    walkSpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(onWalkSpeedChanged)
end

return SoccerSystem