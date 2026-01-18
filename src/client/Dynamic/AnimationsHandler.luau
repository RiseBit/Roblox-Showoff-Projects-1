--!strict
local Players = game:GetService("Players")

--[[
    =========  TYPES  =========
]]
type AnimationConfig = {
	[string]: string | { [string]: string }
}

--[[
    =========  VARIABLES  =========
]]
local player = Players.LocalPlayer
local customAnimations: AnimationConfig = {}
local characterConnection: RBXScriptConnection? = nil

--[[
    =========  HELPER FUNCTIONS  =========
]]
local function applyAnimations(character: Model)
	local animate = character:WaitForChild("Animate", 5)
	if not animate then return end

	for animName, animData in customAnimations do
		local animFolder = animate:FindFirstChild(animName)
		if not animFolder then continue end

		if type(animData) == "string" then
			local anim = animFolder:FindFirstChildOfClass("Animation") :: Animation?
			if anim then
				anim.AnimationId = animData
			end
		elseif type(animData) == "table" then
			for subName, subId in animData do
				local anim = animFolder:FindFirstChild(subName) :: Animation?
				if anim then
					anim.AnimationId = subId
				end
			end
		end
	end
end

--[[
    =========  MODULE  =========
]]
local AnimationsHandler = {}

function AnimationsHandler.SetAnimations(config: AnimationConfig)
	customAnimations = config

	if characterConnection then
		characterConnection:Disconnect()
	end

	characterConnection = player.CharacterAdded:Connect(applyAnimations)

	if player.Character then
		applyAnimations(player.Character)
	end
end

function AnimationsHandler.ClearAnimations()
	customAnimations = {}

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
end

function AnimationsHandler.loadAnimations(player: Player, animationsList: { Animation }): { [string]: AnimationTrack }
	local character = player.Character
	if not character then
		return {}
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return {}
	end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid
		animator = newAnimator
	end
	
	local validAnimator = animator :: Animator
	
	local loadedTracks: { [string]: AnimationTrack } = {}
	
	for _, animation in ipairs(animationsList) do
		if animation:IsA("Animation") then
			loadedTracks[animation.Name] = validAnimator:LoadAnimation(animation)
		end
	end
	
	return loadedTracks
end

return AnimationsHandler