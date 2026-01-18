local RunSystem = {}
--[[
    =========  SERVICES  =========
]]
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

--[[
    =========  MODULE  =========
]]


--[[
    =========  CONSTANT  =========
]]
local RUNNING_SPEED = 24
local WALK_SPEED = 8

--[[
    =========  VARIABLE  =========
]]
local RunAnimationTrack, Humanoid
local isRunning = false
local isShiftHeld = false
local moveConnection: RBXScriptConnection? = nil
local walkSpeedConnection: RBXScriptConnection? = nil

local function updateRunState()
	if not Humanoid or not RunAnimationTrack then return end
	
	local isMoving = Humanoid.MoveDirection.Magnitude > 0
	local shouldRun = isShiftHeld and isMoving

	if shouldRun and not isRunning then
		isRunning = true
		
		local speedRatio = Humanoid.WalkSpeed / RUNNING_SPEED
		local startAnimSpeed = math.pow(speedRatio, 2) 
		RunAnimationTrack:Play(0.2, 1, startAnimSpeed)
		
		TweenService:Create(Humanoid, TweenInfo.new(1, Enum.EasingStyle.Exponential), {WalkSpeed = RUNNING_SPEED}):Play()
		
	elseif not shouldRun and isRunning then
		isRunning = false
		TweenService:Create(Humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {WalkSpeed = WALK_SPEED}):Play()
		RunAnimationTrack:Stop(0.2)
	end
end

local function onWalkSpeedChanged()
	if isRunning and RunAnimationTrack and Humanoid then
		local speedRatio = Humanoid.WalkSpeed / RUNNING_SPEED
		RunAnimationTrack:AdjustSpeed(math.pow(speedRatio, 2))
	end
end

function RunSystem.GlobalInit()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isShiftHeld = true
			updateRunState()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isShiftHeld = false
			updateRunState()
		end
	end)
end

function RunSystem.UpdateTrack(newHumanoid, newRunAnimationTrack)
	Humanoid = newHumanoid
	RunAnimationTrack = newRunAnimationTrack
	
	if moveConnection then
		moveConnection:Disconnect()
		moveConnection = nil
	end
	
	if walkSpeedConnection then
		walkSpeedConnection:Disconnect()
		walkSpeedConnection = nil
	end
	
	if Humanoid then
		moveConnection = Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(updateRunState)
		walkSpeedConnection = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(onWalkSpeedChanged)
	end
end

return RunSystem