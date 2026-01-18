local SoccerPhysics = {}

--[[
    =========  SLIDE CONFIG  =========
]]
SoccerPhysics.Slide = {
    Cooldown = 2,
    Duration = 0.35,
    Speed = 60,
    MaxForce = Vector3.new(5e6, 0, 5e6),
}

--[[
    =========  SHOOT CONFIG  =========
]]
SoccerPhysics.Shoot = {
    BaseSpeed = 50,
    MaxSpeed = 150,
    ChargeMax = 75,
    ChargeIncrement = 10,
    ChargeTick = 0.1,
    ChargeFullDuration = 1,
    ArcMultiplier = .5,
}

--[[
    =========  PHYSICS FUNCTIONS  =========
]]
function SoccerPhysics.calculateSlideVelocity(lookVector: Vector3): Vector3
    return lookVector * SoccerPhysics.Slide.Speed
end

function SoccerPhysics.calculateShootVelocity(lookVector: Vector3, chargePower: number): Vector3
    local config = SoccerPhysics.Shoot
    local shootSpeed = config.BaseSpeed + (chargePower / config.ChargeMax) * (config.MaxSpeed - config.BaseSpeed)
    local direction = lookVector
    return direction * shootSpeed + Vector3.new(0, shootSpeed * config.ArcMultiplier, 0)
end

function SoccerPhysics.applySlide(rootPart: BasePart): BodyVelocity
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = SoccerPhysics.Slide.MaxForce
    bodyVelocity.Velocity = SoccerPhysics.calculateSlideVelocity(rootPart.CFrame.LookVector)
    bodyVelocity.Parent = rootPart
    return bodyVelocity
end

function SoccerPhysics.applyShoot(ballPart: BasePart, lookVector: Vector3, chargePower: number)
    ballPart.AssemblyLinearVelocity = SoccerPhysics.calculateShootVelocity(lookVector, chargePower)
end

return SoccerPhysics
