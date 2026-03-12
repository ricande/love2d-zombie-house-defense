local House = require("src.systems.house")
local Player = require("src.entities.player")
local Zombie = require("src.entities.zombie")
local Weapon = require("src.systems.weapon")
local UI = require("src.ui.ui")

local STATES = {
    START_MENU = "start_menu",
    COMBAT = "combat",
    PREP = "prep",
    STORE = "store",
    GAME_OVER = "game_over",
}

local game = {
    worldWidth = 1000,
    worldHeight = 700,
    bullets = {},
    zombies = {},
    pickups = {},
    particles = {},
    wave = 0,
    statusText = "",
    state = STATES.START_MENU,
    phaseLabel = "Start Menu",
    prepTimer = 0,
    director = {
        toSpawn = 0,
        spawnTimer = 0,
        spawnInterval = 1,
    },
    shakeTimer = 0,
    shakeStrength = 0,
}

local function distanceSq(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

local function setState(state)
    game.state = state
    if state == STATES.COMBAT then
        game.phaseLabel = "Combat"
    elseif state == STATES.PREP then
        game.phaseLabel = "Preparation"
    elseif state == STATES.STORE then
        game.phaseLabel = "Store"
    elseif state == STATES.GAME_OVER then
        game.phaseLabel = "Game Over"
    else
        game.phaseLabel = "Start Menu"
    end
end

local function spawnBlood(x, y)
    -- Lightweight blood burst for death feedback.
    for _ = 1, 12 do
        local angle = love.math.random() * math.pi * 2
        local speed = 40 + love.math.random() * 150
        table.insert(game.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.55 + love.math.random() * 0.35,
            maxLife = 0.9,
            radius = 2 + love.math.random() * 2,
        })
    end
end

local function chooseZombieType()
    -- Wave director: unlock stronger types gradually.
    local roll = love.math.random()
    if game.wave < 3 then
        return "normal"
    elseif game.wave < 6 then
        if roll < 0.2 then return "fast" end
        return "normal"
    else
        if roll < 0.15 then return "tank" end
        if roll < 0.45 then return "fast" end
        return "normal"
    end
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
    table.insert(game.zombies, Zombie.new(x, y, chooseZombieType()))
end

local function beginWave()
    game.wave = game.wave + 1
    game.director.toSpawn = 4 + game.wave * 2 + math.floor(game.wave * 0.8)
    game.director.spawnTimer = 0
    game.director.spawnInterval = math.max(0.24, 1.08 - game.wave * 0.045)
    game.statusText = ("Wave %d begins. Defend the house!"):format(game.wave)
    setState(STATES.COMBAT)
end

local function createBullet(x, y, dirX, dirY, speed, damage, lifetime)
    table.insert(game.bullets, {
        x = x,
        y = y,
        vx = dirX * speed,
        vy = dirY * speed,
        radius = 3,
        damage = damage,
        life = lifetime,
    })
end

local function tryFireWeapon()
    if game.player.isDead or game.state ~= STATES.COMBAT then
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
        createBullet(game.player.x, game.player.y, bulletDirX, bulletDirY, weapon.bulletSpeed, weapon.damage, weapon.range)
    end

    if game.player.loadout.current == "shotgun" then
        game.shakeTimer = 0.16
        game.shakeStrength = 5
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

local function collectPickups()
    for i = #game.pickups, 1, -1 do
        local pickup = game.pickups[i]
        if distanceSq(game.player.x, game.player.y, pickup.x, pickup.y) < (game.player.radius + 10) ^ 2 then
            if pickup.kind == "scrap" then
                game.player.scrap = game.player.scrap + pickup.amount
                game.statusText = ("Collected %d scrap."):format(pickup.amount)
            else
                game.player.boards = game.player.boards + pickup.amount
                game.statusText = ("Collected %d board."):format(pickup.amount)
            end
            table.remove(game.pickups, i)
        end
    end
end

local function addZombieDrops(zombie)
    local scrap = (zombie.kind == "tank") and 3 or 1
    table.insert(game.pickups, { x = zombie.x, y = zombie.y, amount = scrap, kind = "scrap" })

    local boardChance = 0.35
    if zombie.kind == "fast" then boardChance = 0.2 end
    if zombie.kind == "tank" then boardChance = 0.7 end
    if love.math.random() < boardChance then
        table.insert(game.pickups, { x = zombie.x + 5, y = zombie.y - 5, amount = 1, kind = "board" })
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
                        spawnBlood(zombie.x, zombie.y)
                        addZombieDrops(zombie)
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

local function updateParticles(dt)
    for i = #game.particles, 1, -1 do
        local particle = game.particles[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vx = particle.vx * 0.93
        particle.vy = particle.vy * 0.93
        if particle.life <= 0 then
            table.remove(game.particles, i)
        end
    end
end

local function tryStorePurchase(option)
    local weapon = Weapon.getCurrent(game.player.loadout)
    if option == "fireRate" or option == "damage" or option == "range" or option == "pellets" then
        local ok, result = Weapon.tryUpgrade(game.player.loadout, game.player.scrap, option)
        if ok then
            game.player.scrap = game.player.scrap - result
            game.statusText = ("%s upgraded (%s)."):format(weapon.name, option)
        else
            game.statusText = result
        end
    elseif option == "heal" then
        local cost = 5
        if game.player.scrap >= cost then
            game.player.scrap = game.player.scrap - cost
            game.player:heal(30)
            game.statusText = "Healed +30 HP."
        else
            game.statusText = "Need 5 scrap."
        end
    elseif option == "boards" then
        local cost = 4
        if game.player.scrap >= cost then
            game.player.scrap = game.player.scrap - cost
            game.player.boards = game.player.boards + 2
            game.statusText = "Bought 2 boards."
        else
            game.statusText = "Need 4 scrap."
        end
    end
end

local function resetRun()
    game.house = House.new(260, 140, 480, 420)
    game.player = Player.new(game.house.x + game.house.width * 0.5, game.house.y + game.house.height * 0.5, Weapon.createLoadout())
    game.player.scrap = 0
    game.bullets = {}
    game.zombies = {}
    game.pickups = {}
    game.particles = {}
    game.wave = 0
    game.prepTimer = 0
    game.director.toSpawn = 0
    game.director.spawnTimer = 0
    game.statusText = "Press Enter to start."
    setState(STATES.START_MENU)
end

local function enterPrepPhase()
    setState(STATES.PREP)
    game.prepTimer = 8
    game.statusText = "Preparation: repair openings or press B for store."
end

local function updateCombat(dt)
    game.player:update(dt, game.house, game.worldWidth, game.worldHeight)
    if love.mouse.isDown(1) then
        tryFireWeapon()
    end

    updateBullets(dt)
    updateZombies(dt)
    collectPickups()

    if game.director.toSpawn > 0 then
        game.director.spawnTimer = game.director.spawnTimer + dt
        if game.director.spawnTimer >= game.director.spawnInterval then
            game.director.spawnTimer = 0
            game.director.toSpawn = game.director.toSpawn - 1
            spawnZombie()
        end
    elseif #game.zombies == 0 then
        enterPrepPhase()
    end
end

local function updatePrep(dt)
    game.player:update(dt, game.house, game.worldWidth, game.worldHeight)
    collectPickups()
    game.prepTimer = game.prepTimer - dt
    if game.prepTimer <= 0 then
        setState(STATES.STORE)
        game.statusText = "Store is open. Buy upgrades and press N for next wave."
    end
end

function love.load()
    love.window.setMode(game.worldWidth, game.worldHeight)
    love.window.setTitle("Top-Down Zombie Defense Prototype")
    love.graphics.setBackgroundColor(0.12, 0.14, 0.12)
    love.math.setRandomSeed(os.time())
    resetRun()
end

function love.update(dt)
    game.shakeTimer = math.max(0, game.shakeTimer - dt)
    updateParticles(dt)

    if game.state == STATES.COMBAT then
        updateCombat(dt)
    elseif game.state == STATES.PREP then
        updatePrep(dt)
    elseif game.state == STATES.GAME_OVER then
        -- Keep particles alive, but freeze gameplay state.
    end

    if game.player and game.player.isDead and game.state ~= STATES.GAME_OVER then
        setState(STATES.GAME_OVER)
        game.statusText = "You were overrun."
    end
end

function love.keypressed(key)
    if key == "escape" then
        setState(STATES.START_MENU)
        game.statusText = "Paused to menu. Press Enter to resume from a new run."
        return
    end

    if game.state == STATES.START_MENU then
        if key == "return" then
            resetRun()
            beginWave()
        end
        return
    end

    if game.state == STATES.GAME_OVER then
        if key == "return" then
            resetRun()
            beginWave()
        end
        return
    end

    if game.state == STATES.STORE then
        if key == "1" then tryStorePurchase("fireRate")
        elseif key == "2" then tryStorePurchase("damage")
        elseif key == "3" then tryStorePurchase("range")
        elseif key == "4" then tryStorePurchase("pellets")
        elseif key == "5" then tryStorePurchase("heal")
        elseif key == "6" then tryStorePurchase("boards")
        elseif key == "n" then beginWave()
        end
        return
    end

    if key == "q" then
        Weapon.switch(game.player.loadout, -1)
    elseif key == "e" then
        Weapon.switch(game.player.loadout, 1)
    elseif key == "1" then
        game.player.loadout.current = "pistol"
    elseif key == "2" then
        game.player.loadout.current = "shotgun"
    elseif key == "r" and (game.state == STATES.COMBAT or game.state == STATES.PREP) then
        tryRepair()
    end

    if game.state == STATES.PREP and key == "b" then
        setState(STATES.STORE)
        game.statusText = "Store opened early."
        return
    end
end

local function drawWorld()
    love.graphics.setColor(0.2, 0.28, 0.2)
    love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
    game.house:draw()

    for _, pickup in ipairs(game.pickups) do
        if pickup.kind == "scrap" then
            love.graphics.setColor(0.72, 0.72, 0.76)
        else
            love.graphics.setColor(0.83, 0.67, 0.32)
        end
        love.graphics.rectangle("fill", pickup.x - 6, pickup.y - 6, 12, 12)
    end

    for _, particle in ipairs(game.particles) do
        local alpha = math.max(0, particle.life / particle.maxLife)
        love.graphics.setColor(0.82, 0.12, 0.12, alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.radius)
    end

    for _, bullet in ipairs(game.bullets) do
        love.graphics.setColor(0.98, 0.92, 0.38)
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
    end

    for _, zombie in ipairs(game.zombies) do
        zombie:draw()
    end

    game.player:draw()
end

function love.draw()
    love.graphics.push()
    if game.shakeTimer > 0 then
        local magnitude = game.shakeStrength * (game.shakeTimer / 0.16)
        local offsetX = (love.math.random() * 2 - 1) * magnitude
        local offsetY = (love.math.random() * 2 - 1) * magnitude
        love.graphics.translate(offsetX, offsetY)
    end
    drawWorld()
    love.graphics.pop()

    UI.draw({
        player = game.player,
        wave = game.wave,
        weapon = Weapon.getCurrent(game.player.loadout),
        statusText = game.statusText,
        phaseLabel = game.phaseLabel,
        aliveZombies = #game.zombies,
        toSpawn = game.director.toSpawn,
        worldWidth = game.worldWidth,
        worldHeight = game.worldHeight,
    })

    UI.drawOverlay({
        state = game.state,
        prepTimer = game.prepTimer,
        worldWidth = game.worldWidth,
        worldHeight = game.worldHeight,
    })
end
