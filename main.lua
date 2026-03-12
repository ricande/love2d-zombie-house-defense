local House = require("house")
local Player = require("player")
local Zombie = require("zombie")
local Weapon = require("weapon")
local UI = require("ui")

local game = {
    worldWidth = 1000,
    worldHeight = 700,
    bullets = {},
    zombies = {},
    pickups = {},
    wave = 0,
    waveDelay = 0,
    zombiesToSpawn = 0,
    spawnTimer = 0,
    statusText = "",
}

local function distanceSq(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

local function spawnZombie()
    local side = love.math.random(1, 4)
    local padding = 50
    local x, y
    if side == 1 then
        x = love.math.random(0, game.worldWidth)
        y = -padding
    elseif side == 2 then
        x = game.worldWidth + padding
        y = love.math.random(0, game.worldHeight)
    elseif side == 3 then
        x = love.math.random(0, game.worldWidth)
        y = game.worldHeight + padding
    else
        x = -padding
        y = love.math.random(0, game.worldHeight)
    end
    table.insert(game.zombies, Zombie.new(x, y))
end

local function startNextWave()
    game.wave = game.wave + 1
    game.zombiesToSpawn = 4 + game.wave * 2
    game.spawnTimer = 0
    game.statusText = ("Wave %d started!"):format(game.wave)
end

local function createBullet(x, y, dirX, dirY, speed, damage)
    table.insert(game.bullets, {
        x = x,
        y = y,
        vx = dirX * speed,
        vy = dirY * speed,
        radius = 3,
        damage = damage,
        life = 1.2,
    })
end

local function tryFireWeapon()
    if game.player.isDead then
        return
    end

    local weapon = Weapon.getCurrent(game.player.loadout)
    if game.player.timeSinceShot < weapon.fireCooldown then
        return
    end

    game.player.timeSinceShot = 0
    local mx, my = love.mouse.getPosition()
    local dx, dy = mx - game.player.x, my - game.player.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return
    end
    dx, dy = dx / len, dy / len

    for _ = 1, weapon.pellets do
        local spreadAngle = (love.math.random() * 2 - 1) * weapon.spread
        local cosA = math.cos(spreadAngle)
        local sinA = math.sin(spreadAngle)
        local bulletDirX = dx * cosA - dy * sinA
        local bulletDirY = dx * sinA + dy * cosA
        createBullet(game.player.x, game.player.y, bulletDirX, bulletDirY, weapon.bulletSpeed, weapon.damage)
    end
end

local function tryRepair()
    if game.player.isDead then
        return
    end

    local opening = game.house:getNearestRepairable(game.player.x, game.player.y, game.player.repairRange)
    if not opening then
        game.statusText = "No damaged opening nearby."
        return
    end
    if game.player.boards < 1 then
        game.statusText = "No boards to repair."
        return
    end

    game.player.boards = game.player.boards - 1
    game.house:repairOpening(opening)
    game.statusText = ("Repaired %s using 1 board."):format(opening.type)
end

local function tryUpgradeWeapon()
    if game.player.isDead then
        return
    end
    local ok, result = Weapon.tryUpgrade(game.player.loadout, game.player.boards)
    if ok then
        game.player.boards = game.player.boards - result
        local weapon = Weapon.getCurrent(game.player.loadout)
        game.statusText = ("%s upgraded to level %d!"):format(weapon.name, weapon.level)
    else
        game.statusText = result
    end
end

local function collectPickups()
    for i = #game.pickups, 1, -1 do
        local pickup = game.pickups[i]
        if distanceSq(game.player.x, game.player.y, pickup.x, pickup.y) < (game.player.radius + 10) ^ 2 then
            game.player.boards = game.player.boards + pickup.amount
            table.remove(game.pickups, i)
            game.statusText = ("Collected %d board."):format(pickup.amount)
        end
    end
end

local function updateBullets(dt)
    for i = #game.bullets, 1, -1 do
        local bullet = game.bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        local removeBullet = bullet.life <= 0
            or bullet.x < -20 or bullet.x > game.worldWidth + 20
            or bullet.y < -20 or bullet.y > game.worldHeight + 20

        if not removeBullet then
            for z = #game.zombies, 1, -1 do
                local zombie = game.zombies[z]
                if distanceSq(bullet.x, bullet.y, zombie.x, zombie.y) <= (bullet.radius + zombie.radius) ^ 2 then
                    removeBullet = true
                    local dead = zombie:takeDamage(bullet.damage)
                    if dead then
                        table.insert(game.pickups, { x = zombie.x, y = zombie.y, amount = 1 })
                        table.remove(game.zombies, z)
                    end
                    break
                end
            end
        end

        if removeBullet then
            table.remove(game.bullets, i)
        end
    end
end

local function updateZombies(dt)
    for _, zombie in ipairs(game.zombies) do
        zombie:update(dt, game.house, game.player)
    end
end

local function updateWaveSpawning(dt)
    if game.zombiesToSpawn > 0 then
        game.spawnTimer = game.spawnTimer + dt
        local spawnInterval = math.max(0.32, 1.15 - game.wave * 0.05)
        if game.spawnTimer >= spawnInterval then
            game.spawnTimer = 0
            game.zombiesToSpawn = game.zombiesToSpawn - 1
            spawnZombie()
        end
        return
    end

    if #game.zombies == 0 then
        game.waveDelay = game.waveDelay - dt
        if game.waveDelay <= 0 then
            game.waveDelay = 4
            startNextWave()
        else
            game.statusText = ("Next wave in %.1fs"):format(game.waveDelay)
        end
    end
end

local function resetGame()
    game.house = House.new(260, 140, 480, 420)
    game.player = Player.new(game.house.x + game.house.width * 0.5, game.house.y + game.house.height * 0.5, Weapon.createLoadout())
    game.bullets = {}
    game.zombies = {}
    game.pickups = {}
    game.wave = 0
    game.waveDelay = 0
    game.zombiesToSpawn = 0
    game.spawnTimer = 0
    game.statusText = "Survive the waves and defend the house!"
    startNextWave()
end

function love.load()
    love.window.setMode(game.worldWidth, game.worldHeight)
    love.window.setTitle("Top-Down Zombie Defense Prototype")
    love.graphics.setBackgroundColor(0.12, 0.14, 0.12)
    love.math.setRandomSeed(os.time())
    resetGame()
end

function love.update(dt)
    if game.player.isDead then
        return
    end

    game.player:update(dt, game.house, game.worldWidth, game.worldHeight)
    if love.mouse.isDown(1) then
        tryFireWeapon()
    end

    updateBullets(dt)
    updateZombies(dt)
    collectPickups()
    updateWaveSpawning(dt)
end

function love.keypressed(key)
    if key == "r" then
        tryRepair()
    elseif key == "u" then
        tryUpgradeWeapon()
    elseif key == "q" then
        Weapon.switch(game.player.loadout, -1)
    elseif key == "e" then
        Weapon.switch(game.player.loadout, 1)
    elseif key == "1" then
        game.player.loadout.current = "pistol"
    elseif key == "2" then
        game.player.loadout.current = "shotgun"
    elseif key == "return" and game.player.isDead then
        resetGame()
    end
end

function love.draw()
    -- Outside ground
    love.graphics.setColor(0.2, 0.28, 0.2)
    love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)

    game.house:draw()

    for _, pickup in ipairs(game.pickups) do
        love.graphics.setColor(0.83, 0.67, 0.32)
        love.graphics.rectangle("fill", pickup.x - 6, pickup.y - 6, 12, 12)
    end

    for _, bullet in ipairs(game.bullets) do
        love.graphics.setColor(0.98, 0.92, 0.38)
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
    end

    for _, zombie in ipairs(game.zombies) do
        zombie:draw()
    end

    game.player:draw()

    UI.draw({
        player = game.player,
        wave = game.wave,
        weapon = Weapon.getCurrent(game.player.loadout),
        statusText = game.statusText,
        worldWidth = game.worldWidth,
        worldHeight = game.worldHeight,
    })
end
