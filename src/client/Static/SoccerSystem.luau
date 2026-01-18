local SoccerSystem = {}
--[[
    =========  SERVICES  =========
]]
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--[[
    =========  MODULE  =========
]]
local SharedFolder = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoccerPhysics = require(SharedFolder:WaitForChild("SoccerPhysics"))
--[[
    =========  CONSTANT  =========
]]
local LocalPlayer = Players.LocalPlayer

--[[
    =========  VARIABLE  =========
]]
local character, humanoid, rootPart
local AlignPosition, AlignOrientation, BallAttachment, PlayerAttachment
local CurrentBall

local SlideAnimationTrack
local ShootChargeAnimationTrack
local ShootReleaseAnimationTrack

local IsSlide = false
local LastSlideTime = os.clock()
local SlideBodyVelocity

local IsCharge = false
local ChargePower = 0

--[[
    =========  ASSETS  =========
]]
local SoccerEvents = ReplicatedStorage:WaitForChild("SoccerEvents")

--[[
    =========  HELPER FUNCTION  =========
]]
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
end

local function doSlide()
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
    humanoid.WalkSpeed = 8

    if ShootChargeAnimationTrack then ShootChargeAnimationTrack:Stop() end
    if ShootReleaseAnimationTrack then ShootReleaseAnimationTrack:Play() end

    releaseBall()

    local shootPower = ChargePower
    ChargePower = 0

    SoccerPhysics.applyShoot(CurrentBall.PrimaryPart, rootPart.CFrame.LookVector, shootPower)
    CurrentBall = nil

    SoccerEvents:FireServer("Shoot")
end

local function chargeShoot()
    if not rootPart or not ShootChargeAnimationTrack then return end
    if not CurrentBall then return end
    if IsCharge then return end
    IsCharge = true

    ShootChargeAnimationTrack:Play()
    ShootChargeAnimationTrack.Stopped:Once(function()
        if IsCharge then
            ShootChargeAnimationTrack:Play()
            ShootChargeAnimationTrack:AdjustSpeed(0)
        end
    end)

    humanoid.WalkSpeed = 2

    task.spawn(function()
        local config = SoccerPhysics.Shoot
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

--[[
    =========  PUBLIC FUNCTION  =========
]]
function SoccerSystem.GlobalInit()
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean) 
        if gameProcessed then return end
        if not rootPart then return end
        
        if input.KeyCode == Enum.KeyCode.F then
		    doSlide()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		    chargeShoot()
	    end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean) 
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

            if LocalPlayer == ballOwner then
                weldBallToPlayer(ball)
            elseif AlignPosition then
                AlignPosition:Destroy()
                AlignPosition = nil
            end
		end
	end)
end

function SoccerSystem.Update(_character, _slideTrack, _shootChargeTrack, _shootReleaseTrack)
	character = _character
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	SlideAnimationTrack = _slideTrack
    ShootChargeAnimationTrack = _shootChargeTrack
    ShootReleaseAnimationTrack = _shootReleaseTrack
end

return SoccerSystem
