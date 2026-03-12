local UI = {}

local function drawBar(x, y, width, height, percent, backColor, fillColor)
    love.graphics.setColor(backColor)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x + 2, y + 2, (width - 4) * percent, height - 4, 3, 3)
end

function UI.draw(game)
    local player = game.player
    local weapon = game.weapon
    local statusText = game.statusText

    love.graphics.setColor(0.08, 0.08, 0.1, 0.75)
    love.graphics.rectangle("fill", 12, 12, 460, 154, 8, 8)

    local hpPct = player.health / player.maxHealth
    drawBar(24, 28, 220, 20, hpPct, { 0.25, 0.1, 0.1 }, { 0.88, 0.22, 0.2 })

    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print(("Health: %d / %d"):format(player.health, player.maxHealth), 24, 54)
    love.graphics.print(("Boards: %d"):format(player.boards), 24, 74)
    love.graphics.print(("Scrap: %d"):format(player.scrap or 0), 24, 94)
    love.graphics.print(("Wave: %d"):format(game.wave), 24, 114)
    love.graphics.print(("Phase: %s"):format(game.phaseLabel or "Combat"), 24, 134)

    love.graphics.print(("Weapon: %s (Lv.%d)"):format(weapon.name, weapon.level), 190, 74)
    love.graphics.print(("Damage %.1f | Cooldown %.2fs"):format(weapon.damage, weapon.fireCooldown), 190, 94)
    love.graphics.print(("Range %.2f | Pellets %d"):format(weapon.range, weapon.pellets), 190, 114)
    love.graphics.print(("Alive: %d | Left to spawn: %d"):format(game.aliveZombies or 0, game.toSpawn or 0), 190, 134)

    love.graphics.setColor(0.1, 0.1, 0.12, 0.78)
    love.graphics.rectangle("fill", 12, game.worldHeight - 72, 920, 54, 8, 8)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print("WASD Move | LMB Shoot | 1/2 or Q/E Switch | R Repair (1 board) | Esc: Menu", 22, game.worldHeight - 62)
    love.graphics.print(statusText, 22, game.worldHeight - 42)
end

function UI.drawOverlay(game)
    if game.state == "start_menu" then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.printf("Zombie House Defense", 0, game.worldHeight * 0.34, game.worldWidth, "center")
        love.graphics.printf("Press Enter to Start", 0, game.worldHeight * 0.40, game.worldWidth, "center")
        love.graphics.printf("Defend openings, collect scrap, shop between waves.", 0, game.worldHeight * 0.46, game.worldWidth, "center")
    elseif game.state == "prep" then
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
        love.graphics.setColor(0.8, 0.93, 1)
        love.graphics.printf(("Preparation: %.1fs"):format(game.prepTimer or 0), 0, 28, game.worldWidth, "center")
        love.graphics.printf("Repair now, then press B to enter store", 0, 48, game.worldWidth, "center")
    elseif game.state == "store" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.printf("Store - Spend Scrap", 0, 150, game.worldWidth, "center")
        love.graphics.printf("1) Upgrade Fire Rate  |  2) Upgrade Damage", 0, 210, game.worldWidth, "center")
        love.graphics.printf("3) Upgrade Range      |  4) Upgrade Pellet Count", 0, 236, game.worldWidth, "center")
        love.graphics.printf("5) Heal +30 HP (5 scrap) | 6) Buy 2 Boards (4 scrap)", 0, 262, game.worldWidth, "center")
        love.graphics.printf("Current weapon upgrades apply only to selected gun.", 0, 304, game.worldWidth, "center")
        love.graphics.printf("Press N to start next wave", 0, 338, game.worldWidth, "center")
    elseif game.state == "game_over" then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
        love.graphics.setColor(1, 0.25, 0.25)
        love.graphics.printf("You died - Press Enter to restart", 0, game.worldHeight * 0.45, game.worldWidth, "center")
    end
end

return UI
