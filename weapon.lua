local Weapon = {}

Weapon.definitions = {
    pistol = {
        name = "Pistol",
        fireCooldown = 0.28,
        damage = 24,
        bulletSpeed = 640,
        pellets = 1,
        spread = 0.02,
    },
    shotgun = {
        name = "Shotgun",
        fireCooldown = 0.9,
        damage = 12,
        bulletSpeed = 520,
        pellets = 6,
        spread = 0.32,
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

function Weapon.tryUpgrade(loadout, boards)
    local weapon = Weapon.getCurrent(loadout)
    local upgradeCost = 3
    if boards < upgradeCost then
        return false, "Need 3 boards"
    end
    if weapon.level >= 6 then
        return false, "Max level reached"
    end

    weapon.level = weapon.level + 1
    weapon.damage = weapon.damage * 1.15
    weapon.fireCooldown = weapon.fireCooldown * 0.92
    return true, upgradeCost
end

return Weapon
