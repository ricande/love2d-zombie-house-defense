local Settings = {}

Settings.window = {
    width = 1000,
    height = 700,
    title = "Top-Down Zombie Defense Prototype",
    backgroundColor = { 0.12, 0.14, 0.12 },
}

Settings.world = {
    spawnPadding = 50,
}

Settings.states = {
    prepDuration = 8,
}

Settings.waveDirector = {
    -- Previous baseline yielded 6 zombies on wave 1.
    -- New baseline is shifted by +10, so wave 1 now starts at 16.
    baseCount = 14,
    growthPerWave = 2,
    growthBonusFactor = 0.8,
    spawnIntervalBase = 1.08,
    spawnIntervalPerWave = 0.045,
    spawnIntervalMin = 0.24,
    typeRollOrder = { "normal", "fast", "tank" },
    typeChances = {
        { maxWave = 2, chances = { normal = 1.0 } },
        { maxWave = 5, chances = { normal = 0.8, fast = 0.2 } },
        { maxWave = math.huge, chances = { normal = 0.55, fast = 0.30, tank = 0.15 } },
    },
}

Settings.animations = {
    directionOrder = {
        "north",
        "northeast",
        "east",
        "southeast",
        "south",
        "southwest",
        "west",
        "northwest",
    },
    player = {
        frameWidth = 48,
        frameHeight = 48,
        defaultDirection = "south",
        defaultState = "idle",
        states = {
            idle = {
                sheetPath = "assets/graphics/player/idle.png",
                frameCount = 4,
                fps = 6,
                scaleMultiplier = 2.9,
            },
            walk = {
                sheetPath = "assets/graphics/player/walk.png",
                frameCount = 6,
                fps = 10,
                scaleMultiplier = 2.9,
            },
            shoot = {
                sheetPath = "assets/graphics/player/shoot.png",
                frameCount = 16,
                fps = 22,
                scaleMultiplier = 2.9,
                oneShotDuration = 0.35,
            },
            pickup = {
                sheetPath = "assets/graphics/player/pickup.png",
                frameCount = 5,
                fps = 12,
                scaleMultiplier = 2.9,
                oneShotDuration = 0.42,
            },
        },
    },
    zombie = {
        frameWidth = 48,
        frameHeight = 48,
        defaultDirection = "south",
        defaultState = "walk",
        states = {
            walk = {
                sheetPath = "assets/graphics/enemies/zombie/zombie_sheet.png",
                frameCount = 8,
                fps = 10,
                scaleMultiplier = 2.9,
            },
        },
    },
}

Settings.player = {
    radius = 26,
    speed = 185,
    maxHealth = 100,
    repairRange = 70,
    startingBoards = 2,
    startingScrap = 0,
}

Settings.house = {
    x = 260,
    y = 140,
    width = 480,
    height = 420,
    wallThickness = 16,
    openings = {
        { id = 1, type = "door", wall = "top", pos = 0.25, size = 80, durability = 140, maxDurability = 140 },
        { id = 2, type = "window", wall = "top", pos = 0.70, size = 60, durability = 90, maxDurability = 90 },
        { id = 3, type = "window", wall = "left", pos = 0.30, size = 60, durability = 90, maxDurability = 90 },
        { id = 4, type = "door", wall = "left", pos = 0.74, size = 78, durability = 140, maxDurability = 140 },
        { id = 5, type = "window", wall = "right", pos = 0.28, size = 60, durability = 90, maxDurability = 90 },
        { id = 6, type = "door", wall = "right", pos = 0.68, size = 82, durability = 140, maxDurability = 140 },
        { id = 7, type = "window", wall = "bottom", pos = 0.34, size = 62, durability = 90, maxDurability = 90 },
        { id = 8, type = "window", wall = "bottom", pos = 0.78, size = 62, durability = 90, maxDurability = 90 },
    },
}

Settings.weapons = {
    definitions = {
        pistol = {
            name = "Pistol",
            fireCooldown = 0.28,
            damage = 24,
            bulletSpeed = 640,
            pellets = 1,
            spread = 0.02,
            range = 1.2,
        },
        shotgun = {
            name = "Shotgun",
            fireCooldown = 0.9,
            damage = 12,
            bulletSpeed = 520,
            pellets = 6,
            spread = 0.32,
            range = 1.0,
        },
    },
    upgrades = {
        baseCost = 3,
        costStep = 2,
        maxLevel = 5,
        fireRateMultiplier = 0.9,
        damageMultiplier = 1.18,
        rangeMultiplier = 1.12,
        pelletStep = 1,
    },
}

Settings.zombies = {
    types = {
        normal = {
            name = "Normal",
            radius = 24,
            speedMin = 58,
            speedMax = 76,
            health = 45, -- reduced by 10
            contactDamage = 8,
            wallDamage = 8, -- reduced by 6
            color = { 0.67, 0.8, 0.31 },
        },
        fast = {
            name = "Fast",
            radius = 20,
            speedMin = 95,
            speedMax = 125,
            health = 38,
            contactDamage = 7,
            wallDamage = 12,
            color = { 0.95, 0.73, 0.28 },
        },
        tank = {
            name = "Tank",
            radius = 32,
            speedMin = 38,
            speedMax = 50,
            health = 130,
            contactDamage = 14,
            wallDamage = 24,
            color = { 0.56, 0.38, 0.72 },
        },
    },
    attackCooldown = 0.8,
    attackTimerJitter = 0.4,
    openingAttackDistance = 6,
    playerAttackOffset = 4,
    hitFlashDuration = 0.11,
}

Settings.economy = {
    drops = {
        scrapByType = {
            normal = 1,
            fast = 1,
            tank = 3,
        },
        boardChanceByType = {
            normal = 0.35,
            fast = 0.2,
            tank = 0.7,
        },
        boardDropOffset = { x = 5, y = -5 },
    },
    store = {
        healCost = 5,
        healAmount = 30,
        boardPackCost = 4,
        boardPackAmount = 2,
    },
}

Settings.effects = {
    shotgunShake = {
        duration = 0.16,
        strength = 5,
    },
    blood = {
        count = 12,
        speedMin = 40,
        speedMax = 150,
        lifeMin = 0.55,
        lifeMax = 0.9,
        radiusMin = 2,
        radiusMax = 4,
        drag = 0.93,
    },
}

Settings.pickups = {
    collectRadius = 10,
}

return Settings
