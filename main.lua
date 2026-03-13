local House = require("src.systems.house")
local Player = require("src.entities.player")
local Zombie = require("src.entities.zombie")
local Weapon = require("src.systems.weapon")
local UI = require("src.ui.ui")
local Settings = require("settings")
local Collision = require("src.systems.collision")

local STATES = {
    START_MENU = "start_menu",
    COMBAT = "combat",
    PREP = "prep",
    STORE = "store",
    GAME_OVER = "game_over",
}

local game = {
    worldWidth = Settings.window.width,
    worldHeight = Settings.window.height,
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
    for _ = 1, Settings.effects.blood.count do
        local angle = love.math.random() * math.pi * 2
        local speed = Settings.effects.blood.speedMin + love.math.random() * (Settings.effects.blood.speedMax - Settings.effects.blood.speedMin)
        table.insert(game.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = Settings.effects.blood.lifeMin + love.math.random() * (Settings.effects.blood.lifeMax - Settings.effects.blood.lifeMin),
            maxLife = Settings.effects.blood.lifeMax,
            radius = Settings.effects.blood.radiusMin + love.math.random() * (Settings.effects.blood.radiusMax - Settings.effects.blood.radiusMin),
        })
    end
end

local function chooseZombieType()
    -- Wave director: unlock stronger types gradually with configured weights.
    local roll = love.math.random()
    local selectedTier = Settings.waveDirector.typeChances[#Settings.waveDirector.typeChances]
    for _, tier in ipairs(Settings.waveDirector.typeChances) do
        if game.wave <= tier.maxWave then
            selectedTier = tier
            break
        end
    end

    local cumulative = 0
    for _, zombieType in ipairs(Settings.waveDirector.typeRollOrder) do
        cumulative = cumulative + (selectedTier.chances[zombieType] or 0)
        if roll <= cumulative then
            return zombieType
        end
    end

    return "normal"
end

local function spawnZombie()
    local side = love.math.random(1, 4)
    local padding = Settings.world.spawnPadding
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
    game.director.toSpawn = Settings.waveDirector.baseCount
        + game.wave * Settings.waveDirector.growthPerWave
        + math.floor(game.wave * Settings.waveDirector.growthBonusFactor)
    game.director.spawnTimer = 0
    game.director.spawnInterval = math.max(
        Settings.waveDirector.spawnIntervalMin,
        Settings.waveDirector.spawnIntervalBase - game.wave * Settings.waveDirector.spawnIntervalPerWave
    )
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
    game.player:triggerShootAnim()

    if game.player.loadout.current == "shotgun" then
        game.shakeTimer = Settings.effects.shotgunShake.duration
        game.shakeStrength = Settings.effects.shotgunShake.strength
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
    local collectedCount = 0
    for i = #game.pickups, 1, -1 do
        local pickup = game.pickups[i]
        if distanceSq(game.player.x, game.player.y, pickup.x, pickup.y) < (game.player.radius + Settings.pickups.collectRadius) ^ 2 then
            if pickup.kind == "scrap" then
                game.player.scrap = game.player.scrap + pickup.amount
                game.statusText = ("Collected %d scrap."):format(pickup.amount)
            else
                game.player.boards = game.player.boards + pickup.amount
                game.statusText = ("Collected %d board."):format(pickup.amount)
            end
            table.remove(game.pickups, i)
            collectedCount = collectedCount + 1
        end
    end
    return collectedCount
end

local function addZombieDrops(zombie)
    local scrap = Settings.economy.drops.scrapByType[zombie.kind] or 1
    table.insert(game.pickups, { x = zombie.x, y = zombie.y, amount = scrap, kind = "scrap" })

    local boardChance = Settings.economy.drops.boardChanceByType[zombie.kind] or Settings.economy.drops.boardChanceByType.normal
    if love.math.random() < boardChance then
        table.insert(game.pickups, {
            x = zombie.x + Settings.economy.drops.boardDropOffset.x,
            y = zombie.y + Settings.economy.drops.boardDropOffset.y,
            amount = 1,
            kind = "board"
        })
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

local function resolveDynamicCollisions()
    if game.player.isDead or #game.zombies == 0 then
        return
    end

    local playerPassRule = function(wall, alongAxisCoord, radius)
        return game.house:isPlayerPassableAtWall(wall, alongAxisCoord, radius)
    end
    local zombiePassRule = function(wall, alongAxisCoord, radius)
        return game.house:isZombiePassableAtWall(wall, alongAxisCoord, radius)
    end

    for _ = 1, 3 do
        local hadOverlap = false
        for _, zombie in ipairs(game.zombies) do
            local hit, nx, ny, depth = Collision.circleCirclePenetration(
                game.player.x,
                game.player.y,
                game.player.radius,
                zombie.x,
                zombie.y,
                zombie.radius
            )
            if hit and depth > 0 then
                local halfPush = (depth + 0.001) * 0.5
                game.player.x = game.player.x - nx * halfPush
                game.player.y = game.player.y - ny * halfPush
                zombie.x = zombie.x + nx * halfPush
                zombie.y = zombie.y + ny * halfPush

                game.player.x, game.player.y = game.house:resolveWallCollision(
                    game.player.x,
                    game.player.y,
                    game.player.x,
                    game.player.y,
                    game.player.radius,
                    playerPassRule
                )
                zombie.x, zombie.y = game.house:resolveWallCollision(
                    zombie.x,
                    zombie.y,
                    zombie.x,
                    zombie.y,
                    zombie.radius,
                    zombiePassRule
                )
                hadOverlap = true
            end
        end
        if not hadOverlap then
            break
        end
    end
end

local function updateParticles(dt)
    for i = #game.particles, 1, -1 do
        local particle = game.particles[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vx = particle.vx * Settings.effects.blood.drag
        particle.vy = particle.vy * Settings.effects.blood.drag
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
        local cost = Settings.economy.store.healCost
        if game.player.scrap >= cost then
            game.player.scrap = game.player.scrap - cost
            game.player:heal(Settings.economy.store.healAmount)
            game.statusText = ("Healed +%d HP."):format(Settings.economy.store.healAmount)
        else
            game.statusText = ("Need %d scrap."):format(cost)
        end
    elseif option == "boards" then
        local cost = Settings.economy.store.boardPackCost
        if game.player.scrap >= cost then
            game.player.scrap = game.player.scrap - cost
            game.player.boards = game.player.boards + Settings.economy.store.boardPackAmount
            game.statusText = ("Bought %d boards."):format(Settings.economy.store.boardPackAmount)
        else
            game.statusText = ("Need %d scrap."):format(cost)
        end
    end
end

local function resetRun()
    game.house = House.new(Settings.house.x, Settings.house.y, Settings.house.width, Settings.house.height)
    game.player = Player.new(game.house.x + game.house.width * 0.5, game.house.y + game.house.height * 0.5, Weapon.createLoadout())
    game.player.scrap = Settings.player.startingScrap
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
    game.prepTimer = Settings.states.prepDuration
    game.statusText = "Preparation: repair openings or press B for store."
end

local function updateCombat(dt)
    game.player:update(dt, game.house, game.worldWidth, game.worldHeight)
    if love.mouse.isDown(1) then
        tryFireWeapon()
    end

    updateBullets(dt)
    updateZombies(dt)
    resolveDynamicCollisions()
    if collectPickups() > 0 then
        game.player:triggerPickupAnim()
    end

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
    if collectPickups() > 0 then
        game.player:triggerPickupAnim()
    end
    game.prepTimer = game.prepTimer - dt
    if game.prepTimer <= 0 then
        setState(STATES.STORE)
        game.statusText = "Store is open. Buy upgrades and press N for next wave."
    end
end

function love.load()
    love.window.setMode(game.worldWidth, game.worldHeight)
    love.window.setTitle(Settings.window.title)
    love.graphics.setBackgroundColor(Settings.window.backgroundColor)
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
