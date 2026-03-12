# Zombie House Defense (LÖVE2D)

A small top-down zombie defense prototype built with Lua and LÖVE2D.  
Defend a house by shooting incoming zombies, repairing broken doors and windows, and managing wooden boards dropped by enemies.

## Screenshot

Screenshot placeholder:

![Gameplay screenshot placeholder](docs/screenshot-placeholder.png)

_(Add a real screenshot later in `docs/`.)_

## Controls

- `W A S D` - Move player
- `Mouse` - Aim
- `Left Click` - Shoot
- `1` / `2` - Select pistol / shotgun
- `Q` / `E` - Cycle weapons
- `R` - Repair nearby damaged opening (costs 1 board)
- `U` - Upgrade current weapon (costs 3 boards)
- `Enter` - Restart after death

## Gameplay Mechanics

### House, Doors, and Windows

- The player starts inside a house viewed from top-down.
- Doors and windows are breakable openings on house walls.
- Each opening has durability and can be destroyed by zombies.
- Once broken, zombies can enter and attack the player inside.

### Zombies

- Zombies spawn outside the house in waves.
- Each zombie moves toward the nearest door/window.
- If the opening is intact, zombies attack it until it breaks.
- Once inside, zombies chase the player and deal contact damage.

### Repairs and Boards

- Killing zombies drops wooden boards.
- Boards are collected by walking over dropped pickups.
- Use boards to repair broken/damaged doors and windows near the player.
- Repairing restores the opening to full durability.

### Weapons and Upgrades

- **Pistol**: reliable default weapon with faster fire rate.
- **Shotgun**: slower fire rate, multi-pellet spread attack.
- Current weapon can be upgraded using boards to improve:
  - Damage
  - Fire rate (lower cooldown)

### Waves and Survival

- The game progresses through increasingly difficult waves.
- More zombies spawn as wave number increases.
- Survive as long as possible by balancing offense and repairs.

## Installation (LÖVE2D)

1. Download LÖVE2D from the official site: [https://love2d.org/](https://love2d.org/)
2. Install it for your OS.
3. Verify `love` is available in your system path (optional, but useful for CLI launch).

## How To Run

From the project folder:

- **Option A (CLI):**
  ```bash
  love .
  ```
- **Option B (GUI):**
  - Drag the project folder onto `love.exe` (Windows) or the LÖVE app (macOS/Linux).

## Project Structure

```text
.
├── main.lua      # Game loop, input routing, waves, bullets, state setup
├── player.lua    # Player movement, health, aiming direction, death state
├── zombie.lua    # Zombie AI, wall attacking, player contact damage
├── weapon.lua    # Weapon definitions, switching, upgrades
├── house.lua     # House bounds, breakable openings, repair/damage logic
├── ui.lua        # HUD and game status rendering
└── README.md
```

## Future Improvements

- Better pathfinding and zombie crowd behavior
- More weapon types and unique upgrade trees
- Barricade placement anywhere on walls
- Audio effects and background music
- Menu, pause screen, and game over flow improvements
- Save/load progression between sessions
- Sprite art, animations, and polish effects
- Co-op or local multiplayer support
