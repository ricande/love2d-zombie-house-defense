local AnimationController = {}
AnimationController.__index = AnimationController

local DEFAULT_DIRECTION_ORDER = {
    "north",
    "northeast",
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest",
}

local ANGLE_TO_DIRECTION_ORDER = {
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest",
    "north",
    "northeast",
}

local sharedSpriteCache = {}

local function normalizeDirectionOrder(directionOrder)
    if type(directionOrder) ~= "table" or #directionOrder == 0 then
        return DEFAULT_DIRECTION_ORDER
    end
    return directionOrder
end

local function makeStateCacheKey(stateDef, frameWidth, frameHeight, directionOrder)
    local parts = {
        stateDef.sheetPath or "",
        tostring(frameWidth),
        tostring(frameHeight),
        tostring(stateDef.frameCount or 1),
    }
    for _, direction in ipairs(directionOrder) do
        parts[#parts + 1] = direction
    end
    return table.concat(parts, "|")
end

local function buildRows(image, frameWidth, frameHeight, frameCount, directionOrder)
    local rows = {}
    local imageWidth, imageHeight = image:getWidth(), image:getHeight()
    for rowIndex, direction in ipairs(directionOrder) do
        rows[direction] = {}
        local y = (rowIndex - 1) * frameHeight
        for frameIndex = 1, frameCount do
            local x = (frameIndex - 1) * frameWidth
            rows[direction][frameIndex] = love.graphics.newQuad(x, y, frameWidth, frameHeight, imageWidth, imageHeight)
        end
    end
    return rows
end

function AnimationController.vectorToDirection(dx, dy, fallbackDirection)
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then
        return fallbackDirection or "south"
    end

    local angle = math.atan2(dy, dx)
    local octant = math.floor((angle + math.pi / 8) / (math.pi / 4)) % 8
    return ANGLE_TO_DIRECTION_ORDER[octant + 1]
end

function AnimationController.new(config)
    local states = config.states or {}
    local initialState = config.defaultState or next(states)

    local self = setmetatable({}, AnimationController)
    self.frameWidth = config.frameWidth or 48
    self.frameHeight = config.frameHeight or 48
    self.directionOrder = normalizeDirectionOrder(config.directionOrder)
    self.defaultDirection = config.defaultDirection or "south"
    self.direction = self.defaultDirection
    self.states = states
    self.baseState = initialState
    self.state = initialState
    self.frame = 1
    self.timer = 0
    self.assets = {}
    self.transientState = nil
    self.transientTimeLeft = 0
    return self
end

function AnimationController:setTimeOffset(timeOffset)
    self.timer = math.max(0, timeOffset or 0)
end

function AnimationController:setDirection(direction)
    if direction then
        self.direction = direction
    end
end

function AnimationController:setDirectionFromVector(dx, dy)
    self.direction = AnimationController.vectorToDirection(dx, dy, self.direction or self.defaultDirection)
end

function AnimationController:_switchToState(stateName, restart)
    if not self.states[stateName] then
        return false
    end

    if restart or self.state ~= stateName then
        self.state = stateName
        self.timer = 0
        self.frame = 1
    end
    return true
end

function AnimationController:setBaseState(stateName)
    if not self.states[stateName] then
        return false
    end

    self.baseState = stateName
    if not self:isTransientActive() then
        self:_switchToState(stateName, false)
    end
    return true
end

function AnimationController:playTransient(stateName, duration)
    local stateDef = self.states[stateName]
    if not stateDef then
        return false
    end

    self.transientState = stateName
    self.transientTimeLeft = duration
        or stateDef.oneShotDuration
        or 0
    self:_switchToState(stateName, true)
    return true
end

function AnimationController:isTransientActive()
    return self.transientState ~= nil and self.transientTimeLeft > 0
end

function AnimationController:getTransientState()
    if self:isTransientActive() then
        return self.transientState
    end
    return nil
end

function AnimationController:getState()
    return self.state
end

function AnimationController:_ensureStateAsset(stateName)
    if self.assets[stateName] ~= nil then
        return self.assets[stateName] ~= false
    end

    local stateDef = self.states[stateName]
    if not stateDef or not stateDef.sheetPath then
        self.assets[stateName] = false
        return false
    end

    local cacheKey = makeStateCacheKey(stateDef, self.frameWidth, self.frameHeight, self.directionOrder)
    local cachedAsset = sharedSpriteCache[cacheKey]
    if cachedAsset ~= nil then
        self.assets[stateName] = cachedAsset
        return cachedAsset ~= false
    end

    local ok, image = pcall(love.graphics.newImage, stateDef.sheetPath)
    if not ok or not image then
        sharedSpriteCache[cacheKey] = false
        self.assets[stateName] = false
        return false
    end

    image:setFilter("nearest", "nearest")
    local asset = {
        image = image,
        rows = buildRows(
            image,
            self.frameWidth,
            self.frameHeight,
            math.max(1, stateDef.frameCount or 1),
            self.directionOrder
        ),
    }

    sharedSpriteCache[cacheKey] = asset
    self.assets[stateName] = asset
    return true
end

function AnimationController:update(dt)
    if self.transientState then
        self.transientTimeLeft = self.transientTimeLeft - dt
        if self.transientTimeLeft <= 0 then
            self.transientState = nil
            self.transientTimeLeft = 0
            self:_switchToState(self.baseState, true)
        end
    end

    local stateDef = self.states[self.state]
    if not stateDef then
        return
    end

    local frameCount = math.max(1, stateDef.frameCount or 1)
    local fps = stateDef.fps or 8
    self.timer = self.timer + dt

    local frameNumber = math.floor(self.timer * fps)
    if stateDef.loop == false then
        self.frame = math.min(frameCount, frameNumber + 1)
    else
        self.frame = (frameNumber % frameCount) + 1
    end
end

function AnimationController:draw(x, y, radius, tint)
    if not self:_ensureStateAsset(self.state) then
        return false
    end

    local stateDef = self.states[self.state]
    local asset = self.assets[self.state]
    local rows = asset.rows[self.direction]
        or asset.rows[self.defaultDirection]
        or asset.rows[self.directionOrder[1]]
    local quad = rows and rows[self.frame]
    if not quad then
        return false
    end

    local color = tint or { 1, 1, 1, 1 }
    local targetSize = radius * (stateDef.scaleMultiplier or 2.5)
    local scale = targetSize / self.frameWidth

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.draw(
        asset.image,
        quad,
        x,
        y,
        0,
        scale,
        scale,
        self.frameWidth * 0.5,
        self.frameHeight * 0.5
    )
    return true
end

return AnimationController
