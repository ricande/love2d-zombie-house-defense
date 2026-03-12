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
    love.graphics.rectangle("fill", 12, 12, 360, 120, 8, 8)

    local hpPct = player.health / player.maxHealth
    drawBar(24, 28, 220, 20, hpPct, { 0.25, 0.1, 0.1 }, { 0.88, 0.22, 0.2 })

    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print(("Health: %d / %d"):format(player.health, player.maxHealth), 24, 54)
    love.graphics.print(("Boards: %d"):format(player.boards), 24, 74)
    love.graphics.print(("Wave: %d"):format(game.wave), 24, 94)

    love.graphics.print(("Weapon: %s (Lv.%d)"):format(weapon.name, weapon.level), 190, 74)
    love.graphics.print(("Damage %.1f | Cooldown %.2fs"):format(weapon.damage, weapon.fireCooldown), 190, 94)

    love.graphics.setColor(0.1, 0.1, 0.12, 0.78)
    love.graphics.rectangle("fill", 12, game.worldHeight - 72, 640, 54, 8, 8)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print("WASD Move | LMB Shoot | 1/2 or Q/E Switch | R Repair (1 board) | U Upgrade (3 boards)", 22, game.worldHeight - 62)
    love.graphics.print(statusText, 22, game.worldHeight - 42)

    if player.isDead then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, game.worldWidth, game.worldHeight)
        love.graphics.setColor(1, 0.25, 0.25)
        love.graphics.printf("You died - Press Enter to restart", 0, game.worldHeight * 0.45, game.worldWidth, "center")
    end
end

return UI
