local House = {}
House.__index = House

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

function House.new(x, y, width, height)
    local self = setmetatable({}, House)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.wallThickness = 16

    -- Openings are the breakable entry points on the house perimeter.
    self.openings = {
        { id = 1, type = "door", wall = "top", pos = 0.25, size = 80, durability = 140, maxDurability = 140 },
        { id = 2, type = "window", wall = "top", pos = 0.70, size = 60, durability = 90, maxDurability = 90 },
        { id = 3, type = "window", wall = "left", pos = 0.30, size = 60, durability = 90, maxDurability = 90 },
        { id = 4, type = "door", wall = "left", pos = 0.74, size = 78, durability = 140, maxDurability = 140 },
        { id = 5, type = "window", wall = "right", pos = 0.28, size = 60, durability = 90, maxDurability = 90 },
        { id = 6, type = "door", wall = "right", pos = 0.68, size = 82, durability = 140, maxDurability = 140 },
        { id = 7, type = "window", wall = "bottom", pos = 0.34, size = 62, durability = 90, maxDurability = 90 },
        { id = 8, type = "window", wall = "bottom", pos = 0.78, size = 62, durability = 90, maxDurability = 90 },
    }

    return self
end

function House:isInside(px, py)
    return px >= self.x and px <= self.x + self.width
        and py >= self.y and py <= self.y + self.height
end

function House:getOpeningWorldPosition(opening)
    if opening.wall == "top" then
        return self.x + self.width * opening.pos, self.y
    elseif opening.wall == "bottom" then
        return self.x + self.width * opening.pos, self.y + self.height
    elseif opening.wall == "left" then
        return self.x, self.y + self.height * opening.pos
    else
        return self.x + self.width, self.y + self.height * opening.pos
    end
end

function House:getNearestOpening(px, py)
    local nearest, bestDistSq
    for _, opening in ipairs(self.openings) do
        local ox, oy = self:getOpeningWorldPosition(opening)
        local dx = ox - px
        local dy = oy - py
        local distSq = dx * dx + dy * dy
        if not bestDistSq or distSq < bestDistSq then
            bestDistSq = distSq
            nearest = opening
        end
    end
    return nearest, math.sqrt(bestDistSq or 0)
end

function House:getNearestRepairable(px, py, range)
    local nearest, bestDist
    for _, opening in ipairs(self.openings) do
        local ox, oy = self:getOpeningWorldPosition(opening)
        local dist = ((ox - px) ^ 2 + (oy - py) ^ 2) ^ 0.5
        if dist <= range and opening.durability < opening.maxDurability then
            if not bestDist or dist < bestDist then
                bestDist = dist
                nearest = opening
            end
        end
    end
    return nearest, bestDist
end

function House:damageOpening(openingId, amount)
    for _, opening in ipairs(self.openings) do
        if opening.id == openingId then
            opening.durability = clamp(opening.durability - amount, 0, opening.maxDurability)
            return opening.durability <= 0
        end
    end
    return false
end

function House:repairOpening(opening)
    opening.durability = opening.maxDurability
end

function House:draw()
    local wallColor = { 0.62, 0.62, 0.66 }
    local floorColor = { 0.17, 0.17, 0.18 }

    love.graphics.setColor(floorColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    love.graphics.setColor(wallColor)
    love.graphics.rectangle("fill", self.x - self.wallThickness, self.y - self.wallThickness, self.width + self.wallThickness * 2, self.wallThickness)
    love.graphics.rectangle("fill", self.x - self.wallThickness, self.y + self.height, self.width + self.wallThickness * 2, self.wallThickness)
    love.graphics.rectangle("fill", self.x - self.wallThickness, self.y, self.wallThickness, self.height)
    love.graphics.rectangle("fill", self.x + self.width, self.y, self.wallThickness, self.height)

    for _, opening in ipairs(self.openings) do
        local ox, oy = self:getOpeningWorldPosition(opening)
        local isBroken = opening.durability <= 0
        local healthPct = opening.durability / opening.maxDurability

        if isBroken then
            love.graphics.setColor(0.06, 0.06, 0.07)
        elseif opening.type == "door" then
            love.graphics.setColor(0.56, 0.32, 0.15)
        else
            love.graphics.setColor(0.35, 0.64, 0.87)
        end

        if opening.wall == "top" or opening.wall == "bottom" then
            love.graphics.rectangle("fill", ox - opening.size * 0.5, oy - 8, opening.size, 16)
            if not isBroken then
                -- Board overlays visually represent repaired durability.
                local boardCount = math.max(1, math.floor(healthPct * 3))
                love.graphics.setColor(0.78, 0.63, 0.34)
                for i = 1, boardCount do
                    local yOffset = -6 + (i - 1) * 6
                    love.graphics.rectangle("fill", ox - opening.size * 0.45, oy + yOffset, opening.size * 0.9, 3)
                end
            end
        else
            love.graphics.rectangle("fill", ox - 8, oy - opening.size * 0.5, 16, opening.size)
            if not isBroken then
                local boardCount = math.max(1, math.floor(healthPct * 3))
                love.graphics.setColor(0.78, 0.63, 0.34)
                for i = 1, boardCount do
                    local xOffset = -6 + (i - 1) * 6
                    love.graphics.rectangle("fill", ox + xOffset, oy - opening.size * 0.45, 3, opening.size * 0.9)
                end
            end
        end
    end
end

return House
