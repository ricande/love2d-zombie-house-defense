local Zombie = {}
Zombie.__index = Zombie

local Settings = require("settings")
local AnimationController = require("src.systems.animation_controller")
local AnimationProfile = require("src.systems.animation_profile")

Zombie.types = Settings.zombies.types

function Zombie.new(x, y, zombieType)
    local self = setmetatable({}, Zombie)
    local profile = Zombie.types[zombieType] or Zombie.types.normal
    self.kind = zombieType or "normal"
    self.x = x
    self.y = y
    self.radius = profile.radius
    self.speed = profile.speedMin + love.math.random() * (profile.speedMax - profile.speedMin)
    self.health = profile.health
    self.maxHealth = profile.health
    self.attackCooldown = Settings.zombies.attackCooldown
    self.attackTimer = love.math.random() * Settings.zombies.attackTimerJitter
    self.contactDamage = profile.contactDamage
    self.wallDamage = profile.wallDamage
    self.color = profile.color
    self.hitFlashTimer = 0
    local profile = Settings.animations.zombie
    local animationControllerConfig = AnimationProfile.toControllerConfig(profile, Settings.animations.directionOrder)
    self.animation = AnimationController.new(animationControllerConfig)
    self.animation:setTimeOffset(love.math.random() * 0.5)
    self.targetOpeningId = nil
    self.inside = false
    return self
end

local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

function Zombie:takeDamage(amount)
    self.health = self.health - amount
    self.hitFlashTimer = Settings.zombies.hitFlashDuration
    return self.health <= 0
end

function Zombie:update(dt, house, player)
    self.attackTimer = self.attackTimer + dt
    self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
    self.animation:update(dt)
    if house:isInside(self.x, self.y) then
        self.inside = true
    end

    if self.inside then
        local ndx, ndy, distance = normalize(player.x - self.x, player.y - self.y)
        self.animation:setDirectionFromVector(ndx, ndy)
        local nextX = self.x + ndx * self.speed * dt
        local nextY = self.y + ndy * self.speed * dt
        self.x, self.y = house:resolveWallCollision(
            self.x,
            self.y,
            nextX,
            nextY,
            self.radius,
            function(wall, alongAxisCoord, radius)
                return house:isZombiePassableAtWall(wall, alongAxisCoord, radius)
            end
        )

        if distance <= self.radius + player.radius and self.attackTimer >= self.attackCooldown then
            self.attackTimer = 0
            player:takeDamage(self.contactDamage)
        end
        return
    end

    local targetOpening = nil
    if self.targetOpeningId then
        for _, opening in ipairs(house.openings) do
            if opening.id == self.targetOpeningId then
                targetOpening = opening
                break
            end
        end
    end

    if not targetOpening then
        targetOpening = house:getNearestOpening(self.x, self.y)
        if targetOpening then
            self.targetOpeningId = targetOpening.id
        end
    end

    if not targetOpening then
        return
    end

    local ox, oy = house:getOpeningWorldPosition(targetOpening)
    local ndx, ndy, distance = normalize(ox - self.x, oy - self.y)
    self.animation:setDirectionFromVector(ndx, ndy)

    if distance > self.radius + Settings.zombies.openingAttackDistance then
        local nextX = self.x + ndx * self.speed * dt
        local nextY = self.y + ndy * self.speed * dt
        self.x, self.y = house:resolveWallCollision(
            self.x,
            self.y,
            nextX,
            nextY,
            self.radius,
            function(wall, alongAxisCoord, radius)
                return house:isZombiePassableAtWall(wall, alongAxisCoord, radius)
            end
        )
    else
        if targetOpening.durability <= 0 then
            self.inside = true
        elseif self.attackTimer >= self.attackCooldown then
            self.attackTimer = 0
            house:damageOpening(targetOpening.id, self.wallDamage)
        end
    end
end

function Zombie:draw()
    local tint = { 1, 1, 1, 1 }
    if self.hitFlashTimer > 0 then
        local flash = math.min(1, self.hitFlashTimer / Settings.zombies.hitFlashDuration)
        tint[2] = tint[2] + (1 - tint[2]) * flash
        tint[3] = tint[3] + (1 - tint[3]) * flash
    end
    if self.animation:draw(self.x, self.y, self.radius, tint) then
        return
    end

    -- Fallback placeholder draw if sprite sheet is unavailable.
    if self.hitFlashTimer > 0 then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(self.color)
    end
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(0.18, 0.22, 0.1)
    love.graphics.circle("fill", self.x - self.radius * 0.3, self.y - self.radius * 0.15, 2)
    love.graphics.circle("fill", self.x + self.radius * 0.3, self.y - self.radius * 0.15, 2)
end

return Zombie
