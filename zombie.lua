local Zombie = {}
Zombie.__index = Zombie

function Zombie.new(x, y)
    local self = setmetatable({}, Zombie)
    self.x = x
    self.y = y
    self.radius = 12
    self.speed = 58 + love.math.random() * 18
    self.health = 52
    self.attackCooldown = 0.8
    self.attackTimer = love.math.random() * 0.4
    self.contactDamage = 8
    self.wallDamage = 14
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
    return self.health <= 0
end

function Zombie:update(dt, house, player)
    self.attackTimer = self.attackTimer + dt
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
    love.graphics.setColor(0.67, 0.8, 0.31)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(0.18, 0.22, 0.1)
    love.graphics.circle("fill", self.x - 4, self.y - 2, 2)
    love.graphics.circle("fill", self.x + 4, self.y - 2, 2)
end

return Zombie
