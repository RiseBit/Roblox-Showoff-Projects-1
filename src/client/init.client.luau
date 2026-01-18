--[[
    =========  SERVICES  =========
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--[[
    =========  MODULE  =========
]]
local DynamicFolder = script:WaitForChild("Dynamic")
local SoccerSystem = require(script.Static.SoccerSystem)
local AnimationsHandler = require(DynamicFolder:WaitForChild("AnimationsHandler"))



--[[
    =========  CONSTANT  =========
]]
local LocalPlayer = Players.LocalPlayer

--[[
    =========  VARIABLE  =========
]]
--[[
    =========  ASSETS  =========
]]
local Animations = ReplicatedStorage:WaitForChild("Animations")

--[[
    =========  HELPER FUNCTION  =========
]]

--[[
    =========  PUBLIC FUNCTION  =========
]]

--[[
    =========  MAIN  =========
]]
local WALK_ANIMATION_ID = "rbxassetid://132616616794173"
local RUN_ANIMATION = Animations:WaitForChild("Running")
local SLIDE_ANIMATION = Animations:WaitForChild("Slide")
local SHOOT_CHARGE_ANIMATION = Animations:WaitForChild("Shoot Charge")
local SHOOT_RELEASE_ANIMATION = Animations:WaitForChild("Shoot Release")

AnimationsHandler.SetAnimations({
	walk = WALK_ANIMATION_ID,
})

local function OnCharAdded(character)
	local animationTrackTable = AnimationsHandler.loadAnimations(LocalPlayer, {RUN_ANIMATION, SLIDE_ANIMATION, SHOOT_CHARGE_ANIMATION, SHOOT_RELEASE_ANIMATION})
    SoccerSystem.Update(character, animationTrackTable.Running, animationTrackTable.Slide, animationTrackTable["Shoot Charge"], animationTrackTable["Shoot Release"])
end

if LocalPlayer.Character then
    OnCharAdded(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(OnCharAdded)

SoccerSystem.GlobalInit()