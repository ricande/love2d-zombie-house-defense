local Player = {}
Player.__index = Player

local Settings = require("settings")

local TRANSIENT_PRIORITY = {
    idle = 1,
    walk = 2,
    shoot = 3,
    pickup = 4,
}

local playerSpriteRuntime = nil

local function toDirectionName(dx, dy)
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then
        return nil
    end

    -- 8-way octant mapping, aligned to configured sheet row order.
    local angle = math.atan(dy, dx)
    local octant = math.floor((angle / (math.pi / 4)) + 0.5) % 8
    local directionByOctant = {
        "east",
        "southeast",
        "south",
        "southwest",
        "west",
        "northwest",
        "north",
        "northeast",
    }
    return directionByOctant[octant + 1]
end

local function buildStateQuads(image, stateConfig, frameWidth, frameHeight, directionOrder)
    local quads = {}
    for directionIndex, directionName in ipairs(directionOrder) do
        local directionQuads = {}
        for frameIndex = 1, stateConfig.frameCount do
            directionQuads[frameIndex] = love.graphics.newQuad(
                (frameIndex - 1) * frameWidth,
                (directionIndex - 1) * frameHeight,
                frameWidth,
                frameHeight,
                image:getDimensions()
            )
        end
        quads[directionName] = directionQuads
    end
    return quads
end

local function buildPlayerSpriteRuntime()
    local animationConfig = Settings.animations.player
    if not animationConfig then
        return {
            loaded = false,
            states = {},
            frameWidth = 1,
            frameHeight = 1,
        }
    end

    local runtime = {
        loaded = true,
        states = {},
        frameWidth = animationConfig.frameWidth,
        frameHeight = animationConfig.frameHeight,
        defaultDirection = animationConfig.defaultDirection or "south",
        defaultState = animationConfig.defaultState or "idle",
        directionOrder = Settings.animations.directionOrder or {
            "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest",
        },
    }

    for stateName, stateConfig in pairs(animationConfig.states or {}) do
        local ok, imageOrError = pcall(love.graphics.newImage, stateConfig.sheetPath)
        if not ok then
            runtime.loaded = false
            runtime.states[stateName] = {
                image = nil,
                quadsByDirection = {},
                frameCount = stateConfig.frameCount or 1,
                fps = stateConfig.fps or 1,
                scaleMultiplier = stateConfig.scaleMultiplier or 1,
                oneShotDuration = stateConfig.oneShotDuration,
            }
        else
            runtime.states[stateName] = {
                image = imageOrError,
                quadsByDirection = buildStateQuads(
                    imageOrError,
                    stateConfig,
                    animationConfig.frameWidth,
                    animationConfig.frameHeight,
                    runtime.directionOrder
                ),
                frameCount = stateConfig.frameCount or 1,
                fps = stateConfig.fps or 1,
                scaleMultiplier = stateConfig.scaleMultiplier or 1,
                oneShotDuration = stateConfig.oneShotDuration,
            }
        end
    end

    return runtime
end

local function ensurePlayerSpriteRuntime()
    if playerSpriteRuntime == nil then
        playerSpriteRuntime = buildPlayerSpriteRuntime()
    end
    return playerSpriteRuntime
end

local function updateAnimationFrame(self, dt)
    local stateRuntime = self.spriteRuntime.states[self.animState]
    if not stateRuntime then
        return
    end

    local fps = math.max(0.001, stateRuntime.fps or 1)
    local frameCount = math.max(1, stateRuntime.frameCount or 1)
    local frameDuration = 1 / fps

    self.animTimer = self.animTimer + dt
    while self.animTimer >= frameDuration do
        self.animTimer = self.animTimer - frameDuration
        self.animFrame = self.animFrame + 1
        if self.animFrame > frameCount then
            self.animFrame = 1
        end
    end
end

local function setAnimState(self, stateName)
    if self.animState == stateName then
        return
    end
    self.animState = stateName
    self.animFrame = 1
    self.animTimer = 0
end

local function resolveAnimState(self, baseState)
    if self.pickupTimer > 0 then
        return "pickup"
    end
    if self.shootTimer > 0 then
        return "shoot"
    end
    return baseState
end

function Player.new(x, y, loadout)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.radius = Settings.player.radius
    self.speed = Settings.player.speed
    self.health = Settings.player.maxHealth
    self.maxHealth = Settings.player.maxHealth
    self.repairRange = Settings.player.repairRange
    self.boards = Settings.player.startingBoards
    self.loadout = loadout
    self.timeSinceShot = 0
    self.isDead = false

    self.spriteRuntime = ensurePlayerSpriteRuntime()
    self.direction = self.spriteRuntime.defaultDirection or "south"
    self.animState = self.spriteRuntime.defaultState or "idle"
    self.animFrame = 1
    self.animTimer = 0
    self.shootTimer = 0
    self.pickupTimer = 0
    return self
end

function Player:update(dt, house, worldWidth, worldHeight)
    if self.isDead then
        return
    end

    local moveX, moveY = 0, 0
    if love.keyboard.isDown("w") then moveY = moveY - 1 end
    if love.keyboard.isDown("s") then moveY = moveY + 1 end
    if love.keyboard.isDown("a") then moveX = moveX - 1 end
    if love.keyboard.isDown("d") then moveX = moveX + 1 end

    local length = math.sqrt(moveX * moveX + moveY * moveY)
    local previousX, previousY = self.x, self.y
    local nextX, nextY = self.x, self.y
    if length > 0 then
        moveX = moveX / length
        moveY = moveY / length
        nextX = self.x + moveX * self.speed * dt
        nextY = self.y + moveY * self.speed * dt
    end

    nextX, nextY = house:resolveWallCollision(
        previousX,
        previousY,
        nextX,
        nextY,
        self.radius,
        function(wall, alongAxisCoord, radius)
            return house:isPlayerPassableAtWall(wall, alongAxisCoord, radius)
        end
    )

    self.x = nextX
    self.y = nextY

    self.timeSinceShot = self.timeSinceShot + dt
    self.shootTimer = math.max(0, self.shootTimer - dt)
    self.pickupTimer = math.max(0, self.pickupTimer - dt)

    if length > 0 then
        self.direction = toDirectionName(moveX, moveY) or self.direction
    else
        local mx, my = love.mouse.getPosition()
        self.direction = toDirectionName(mx - self.x, my - self.y) or self.direction
    end

    local baseState = length > 0 and "walk" or "idle"
    setAnimState(self, resolveAnimState(self, baseState))
    updateAnimationFrame(self, dt)
end

function Player:takeDamage(amount)
    if self.isDead then
        return
    end
    self.health = self.health - amount
    if self.health <= 0 then
        self.health = 0
        self.isDead = true
    end
end

function Player:heal(amount)
    self.health = math.min(self.maxHealth, self.health + amount)
end

local function tryPlayTransient(self, stateName)
    if self.isDead then
        return
    end

    local currentState = resolveAnimState(self, "idle")
    local currentPriority = TRANSIENT_PRIORITY[currentState] or 0
    local requestedPriority = TRANSIENT_PRIORITY[stateName] or 0
    if requestedPriority < currentPriority then
        return
    end

    local stateRuntime = self.spriteRuntime.states[stateName]
    if not stateRuntime then
        return
    end

    local duration = stateRuntime.oneShotDuration
    if not duration or duration <= 0 then
        duration = math.max(0.05, stateRuntime.frameCount / math.max(0.001, stateRuntime.fps))
    end

    if stateName == "shoot" then
        self.shootTimer = duration
    elseif stateName == "pickup" then
        self.pickupTimer = duration
    end

    setAnimState(self, stateName)
end

function Player:triggerShootAnim()
    tryPlayTransient(self, "shoot")
end

function Player:triggerPickupAnim()
    tryPlayTransient(self, "pickup")
end

function Player:draw()
    local drewSprite = false
    if self.isDead then
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.circle("fill", self.x, self.y, self.radius)
    else
        local stateRuntime = self.spriteRuntime.states[self.animState]
        if stateRuntime and stateRuntime.image then
            local directionName = self.direction or self.spriteRuntime.defaultDirection or "south"
            local directionQuads = stateRuntime.quadsByDirection[directionName]
            local quad = directionQuads and directionQuads[self.animFrame]
            if quad then
                local frameWidth = self.spriteRuntime.frameWidth
                local frameHeight = self.spriteRuntime.frameHeight
                local targetSize = self.radius * (stateRuntime.scaleMultiplier or 2.5)
                local scale = targetSize / math.max(1, frameWidth)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    stateRuntime.image,
                    quad,
                    self.x,
                    self.y,
                    0,
                    scale,
                    scale,
                    frameWidth * 0.5,
                    frameHeight * 0.5
                )
                drewSprite = true
            end
        end

        if not drewSprite then
            love.graphics.setColor(0.2, 0.82, 0.35)
            love.graphics.circle("fill", self.x, self.y, self.radius)
        end
    end

end

return Player
