local Zombie = {}
Zombie.__index = Zombie

Zombie.types = {
    normal = {
        name = "Normal",
        radius = 12,
        speedMin = 58,
        speedMax = 76,
        health = 55,
        contactDamage = 8,
        wallDamage = 14,
        color = { 0.67, 0.8, 0.31 },
    },
    fast = {
        name = "Fast",
        radius = 10,
        speedMin = 95,
        speedMax = 125,
        health = 38,
        contactDamage = 7,
        wallDamage = 12,
        color = { 0.95, 0.73, 0.28 },
    },
    tank = {
        name = "Tank",
        radius = 16,
        speedMin = 38,
        speedMax = 50,
        health = 130,
        contactDamage = 14,
        wallDamage = 24,
        color = { 0.56, 0.38, 0.72 },
    },
}

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
    self.attackCooldown = 0.8
    self.attackTimer = love.math.random() * 0.4
    self.contactDamage = profile.contactDamage
    self.wallDamage = profile.wallDamage
    self.color = profile.color
    self.hitFlashTimer = 0
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
    self.hitFlashTimer = 0.11
    return self.health <= 0
end

function Zombie:update(dt, house, player)
    self.attackTimer = self.attackTimer + dt
    self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
    if house:isInside(self.x, self.y) then
        self.inside = true
    end

    if self.inside then
        local ndx, ndy, distance = normalize(player.x - self.x, player.y - self.y)
        self.x = self.x + ndx * self.speed * dt
        self.y = self.y + ndy * self.speed * dt

        if distance <= self.radius + player.radius + 4 and self.attackTimer >= self.attackCooldown then
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

    if distance > self.radius + 6 then
        self.x = self.x + ndx * self.speed * dt
        self.y = self.y + ndy * self.speed * dt
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
