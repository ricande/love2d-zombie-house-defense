local Weapon = {}

Weapon.definitions = {
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
}

local function copyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function Weapon.createLoadout()
    local loadout = {
        current = "pistol",
        weaponData = {},
    }
    for key, definition in pairs(Weapon.definitions) do
        local weapon = copyTable(definition)
        weapon.level = 1
        weapon.upgradeLevels = {
            fireRate = 0,
            damage = 0,
            range = 0,
            pellets = 0,
        }
        loadout.weaponData[key] = weapon
    end
    return loadout
end

function Weapon.switch(loadout, direction)
    if direction > 0 then
        loadout.current = (loadout.current == "pistol") and "shotgun" or "pistol"
    else
        loadout.current = (loadout.current == "shotgun") and "pistol" or "shotgun"
    end
end

function Weapon.getCurrent(loadout)
    return loadout.weaponData[loadout.current]
end

function Weapon.getUpgradeCost(weapon, upgradeType)
    local level = weapon.upgradeLevels[upgradeType] or 0
    return 3 + level * 2
end

function Weapon.tryUpgrade(loadout, resources, upgradeType)
    local weapon = Weapon.getCurrent(loadout)
    if not weapon.upgradeLevels[upgradeType] then
        return false, "Invalid upgrade type"
    end

    local currentLevel = weapon.upgradeLevels[upgradeType]
    local maxLevel = 5
    if currentLevel >= maxLevel then
        return false, "Upgrade maxed"
    end

    local upgradeCost = Weapon.getUpgradeCost(weapon, upgradeType)
    if resources < upgradeCost then
        return false, ("Need %d scrap"):format(upgradeCost)
    end

    weapon.upgradeLevels[upgradeType] = currentLevel + 1
    if upgradeType == "fireRate" then
        weapon.fireCooldown = weapon.fireCooldown * 0.9
    elseif upgradeType == "damage" then
        weapon.damage = weapon.damage * 1.18
    elseif upgradeType == "range" then
        weapon.range = weapon.range * 1.12
    elseif upgradeType == "pellets" then
        weapon.pellets = weapon.pellets + 1
    end

    weapon.level = weapon.level + 1
    return true, upgradeCost, upgradeType
end

return Weapon
