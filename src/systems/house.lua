local House = {}
House.__index = House

local Settings = require("settings")
local Collision = require("src.systems.collision")

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

local function cloneOpenings(openings)
    local copied = {}
    for i, opening in ipairs(openings) do
        copied[i] = {
            id = opening.id,
            type = opening.type,
            wall = opening.wall,
            pos = opening.pos,
            size = opening.size,
            durability = opening.durability,
            maxDurability = opening.maxDurability,
        }
    end
    return copied
end

function House.new(x, y, width, height)
    local self = setmetatable({}, House)
    self.x = x or Settings.house.x
    self.y = y or Settings.house.y
    self.width = width or Settings.house.width
    self.height = height or Settings.house.height
    self.wallThickness = Settings.house.wallThickness

    -- Openings are the breakable entry points on the house perimeter.
    self.openings = cloneOpenings(Settings.house.openings)

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

function House:isPassableAtWall(wall, alongAxisCoord, entityRadius, ignoreDurability)
    local radius = entityRadius or 0
    for _, opening in ipairs(self.openings) do
        local openingPassable = ignoreDurability or opening.durability <= 0
        if opening.wall == wall and openingPassable then
            local center = 0
            if wall == "top" or wall == "bottom" then
                center = self.x + self.width * opening.pos
            else
                center = self.y + self.height * opening.pos
            end

            local usableHalfSpan = opening.size * 0.5 - radius
            if usableHalfSpan > 0
                and alongAxisCoord >= center - usableHalfSpan
                and alongAxisCoord <= center + usableHalfSpan then
                return true
            end
        end
    end
    return false
end

function House:isPlayerPassableAtWall(wall, alongAxisCoord, playerRadius)
    -- Players can pass all doorway/window openings regardless of plank durability.
    return self:isPassableAtWall(wall, alongAxisCoord, playerRadius, true)
end

function House:isZombiePassableAtWall(wall, alongAxisCoord, zombieRadius)
    -- Zombies only pass openings that are actually broken/open.
    return self:isPassableAtWall(wall, alongAxisCoord, zombieRadius, false)
end

local function getWallCenterForOpening(self, opening)
    if opening.wall == "top" or opening.wall == "bottom" then
        return self.x + self.width * opening.pos
    end
    return self.y + self.height * opening.pos
end

local function getWallLengthForOpening(self, opening)
    if opening.wall == "top" or opening.wall == "bottom" then
        return self.width
    end
    return self.height
end

local function openingIntervalForRadius(self, opening, radius)
    local wallLength = getWallLengthForOpening(self, opening)
    local centerLocal = (opening.wall == "top" or opening.wall == "bottom")
        and (self.width * opening.pos)
        or (self.height * opening.pos)
    local usableHalfSpan = opening.size * 0.5 - radius
    if usableHalfSpan <= 0 then
        return nil
    end
    local startPos = math.max(0, centerLocal - usableHalfSpan)
    local endPos = math.min(wallLength, centerLocal + usableHalfSpan)
    if endPos <= startPos then
        return nil
    end
    return { startPos = startPos, endPos = endPos }
end

local function sortByStart(a, b)
    return a.startPos < b.startPos
end

local function mergeIntervals(intervals)
    if #intervals == 0 then
        return {}
    end
    table.sort(intervals, sortByStart)

    local merged = { intervals[1] }
    for i = 2, #intervals do
        local current = intervals[i]
        local last = merged[#merged]
        if current.startPos <= last.endPos then
            last.endPos = math.max(last.endPos, current.endPos)
        else
            merged[#merged + 1] = current
        end
    end
    return merged
end

local function addWallSegments(segments, wall, baseX, baseY, solidIntervals)
    for _, interval in ipairs(solidIntervals) do
        if interval.endPos > interval.startPos then
            if wall == "top" or wall == "bottom" then
                segments[#segments + 1] = {
                    x1 = baseX + interval.startPos,
                    y1 = baseY,
                    x2 = baseX + interval.endPos,
                    y2 = baseY,
                }
            else
                segments[#segments + 1] = {
                    x1 = baseX,
                    y1 = baseY + interval.startPos,
                    x2 = baseX,
                    y2 = baseY + interval.endPos,
                }
            end
        end
    end
end

local function getSolidIntervals(wallLength, passableIntervals)
    local solids = {}
    local cursor = 0
    for _, interval in ipairs(passableIntervals) do
        if interval.startPos > cursor then
            solids[#solids + 1] = { startPos = cursor, endPos = interval.startPos }
        end
        cursor = math.max(cursor, interval.endPos)
    end
    if cursor < wallLength then
        solids[#solids + 1] = { startPos = cursor, endPos = wallLength }
    end
    return solids
end

function House:getSolidWallSegments(entityRadius, canPassAtWall)
    local radius = entityRadius or 0
    local segments = {}
    local walls = {
        top = self.width,
        bottom = self.width,
        left = self.height,
        right = self.height,
    }

    for wallName, wallLength in pairs(walls) do
        local passableIntervals = {}
        for _, opening in ipairs(self.openings) do
            if opening.wall == wallName then
                local center = getWallCenterForOpening(self, opening)
                local isPassable = canPassAtWall(wallName, center, radius)
                if isPassable then
                    local interval = openingIntervalForRadius(self, opening, radius)
                    if interval then
                        passableIntervals[#passableIntervals + 1] = interval
                    end
                end
            end
        end

        local merged = mergeIntervals(passableIntervals)
        local solids = getSolidIntervals(wallLength, merged)

        if wallName == "top" then
            addWallSegments(segments, wallName, self.x, self.y, solids)
        elseif wallName == "bottom" then
            addWallSegments(segments, wallName, self.x, self.y + self.height, solids)
        elseif wallName == "left" then
            addWallSegments(segments, wallName, self.x, self.y, solids)
        else
            addWallSegments(segments, wallName, self.x + self.width, self.y, solids)
        end
    end

    return segments
end

function House:resolveWallCollision(previousX, previousY, nextX, nextY, entityRadius, canPassAtWall)
    local segments = self:getSolidWallSegments(entityRadius, canPassAtWall)
    local resolvedX, resolvedY = Collision.resolveCircleAgainstSegments(
        nextX,
        nextY,
        entityRadius or 0,
        segments
    )
    return resolvedX, resolvedY
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
