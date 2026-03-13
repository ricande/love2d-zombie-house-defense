local Player = {}
Player.__index = Player

local Settings = require("settings")
local AnimationController = require("src.systems.animation_controller")
local AnimationProfile = require("src.systems.animation_profile")

local TRANSIENT_PRIORITY = {
    shoot = 1,
    pickup = 2,
}

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

    local profile = Settings.animations.player
    local animationControllerConfig = AnimationProfile.toControllerConfig(profile, Settings.animations.directionOrder)
    self.animation = AnimationController.new(animationControllerConfig)
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
    if length > 0 then
        moveX = moveX / length
        moveY = moveY / length
        self.x = self.x + moveX * self.speed * dt
        self.y = self.y + moveY * self.speed * dt
    end

    -- Keep the player inside the house interior for this prototype.
    self.x = math.max(house.x + self.radius, math.min(house.x + house.width - self.radius, self.x))
    self.y = math.max(house.y + self.radius, math.min(house.y + house.height - self.radius, self.y))

    self.x = math.max(self.radius, math.min(worldWidth - self.radius, self.x))
    self.y = math.max(self.radius, math.min(worldHeight - self.radius, self.y))

    self.timeSinceShot = self.timeSinceShot + dt

    if length > 0 then
        self.animation:setDirectionFromVector(moveX, moveY)
    else
        local mx, my = love.mouse.getPosition()
        self.animation:setDirectionFromVector(mx - self.x, my - self.y)
    end

    local baseState = length > 0 and "walk" or "idle"
    self.animation:setBaseState(baseState)
    self.animation:update(dt)
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

    local currentTransient = self.animation:getTransientState()
    if currentTransient then
        local currentPriority = TRANSIENT_PRIORITY[currentTransient] or 0
        local requestedPriority = TRANSIENT_PRIORITY[stateName] or 0
        if requestedPriority < currentPriority then
            return
        end
    end

    self.animation:playTransient(stateName)
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
        drewSprite = self.animation:draw(self.x, self.y, self.radius, { 1, 1, 1, 1 })
        if not drewSprite then
            love.graphics.setColor(0.2, 0.82, 0.35)
            love.graphics.circle("fill", self.x, self.y, self.radius)
        end
    end

    local mx, my = love.mouse.getPosition()
    local dx, dy = mx - self.x, my - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx = dx / len
        dy = dy / len
        love.graphics.setColor(0.92, 0.92, 0.95)
        love.graphics.setLineWidth(3)
        love.graphics.line(self.x, self.y, self.x + dx * 20, self.y + dy * 20)
    end
end

return Player
