# Zombie House Defense (LÖVE2D)

A small top-down zombie defense prototype built with Lua and LÖVE2D.  
Defend a house by shooting incoming zombies, repairing broken doors and windows, collecting resources, and spending scrap in a between-wave store.

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
- `B` - Open store during preparation
- `N` - Start next wave from store
- `Store keys (1-6)` - Buy upgrades/heal/boards
- `Enter` - Start or restart run
- `Esc` - Return to start menu

## Gameplay Mechanics

### Current Systems Implemented

- Top-down house defense with breakable doors/windows and repair loop.
- Multi-type zombies (`normal`, `fast`, `tank`) with directional sprite animation.
- Wave director with escalating composition and spawn pressure.
- State machine flow: `start_menu -> combat -> prep -> store -> game_over`.
- Between-wave store for healing, boards, and weapon stat upgrades.
- Combat feedback: shotgun screen shake, zombie hit flash, blood particles.
- Asset pipeline for GIF-to-spritesheet conversion using ImageMagick.

### House, Doors, and Windows

- The player starts inside a house viewed from top-down.
- Doors and windows are breakable openings on house walls.
- Each opening has durability and can be destroyed by zombies.
- Once broken, zombies can enter and attack the player inside.

### Zombies

- Zombies spawn outside the house in escalating waves.
- Zombie types:
  - **Normal** (green): baseline type (rebalanced to lower HP and plank damage)
  - **Fast** (yellow): lower HP, much faster movement
  - **Tank** (purple): high HP, high barricade damage, slower movement
- Zombies path toward the nearest door/window.
- If an opening is intact, zombies attack it until it breaks.
- Once inside, zombies chase the player and deal contact damage.
- All zombie types use the same 8-direction sprite sheet with per-frame animation.

### Repairs, Boards, and Scrap

- Killing zombies drops **scrap** and sometimes **boards**.
- Scrap is used as store currency.
- Boards are collected by walking over dropped pickups.
- Use boards to repair broken/damaged doors and windows near the player.
- Repairing restores the opening to full durability.

### Weapons and Upgrades

- **Pistol**: reliable default weapon with faster fire rate.
- **Shotgun**: slower fire rate, multi-pellet spread attack.
- Weapon upgrades are purchased in the store using scrap:
  - Damage
  - Fire rate (lower cooldown)
  - Range
  - Pellet count

### Waves and Survival

- The wave director increases zombie count and spawn pressure over time.
- Stronger zombie types appear more frequently in later waves.
- Wave 1 baseline has been increased by **+10 zombies** compared to the previous setup.
- Each round loop:
  - **Fight** a wave
  - **Prepare** (repair openings, collect leftovers)
  - **Store** (buy upgrades and supplies)
  - Start next wave

### Combat Feel and Feedback

- **Shotgun screen shake** adds impact when firing spread shots.
- **Zombie hit flash** gives clear feedback when bullets connect.
- **Blood particles on death** improve readability and combat feel.

### Game States

The game uses a simple state machine:

- **Start Menu**: title and run start prompt
- **Combat Wave**: active zombie spawning and combat
- **Preparation**: short downtime before store
- **Store**: spend scrap on upgrades/healing/boards
- **Game Over**: restart prompt after death

### Store Mechanics

Store purchases:

- `1` Upgrade fire rate (current weapon)
- `2` Upgrade damage (current weapon)
- `3` Upgrade range (current weapon)
- `4` Upgrade pellet count (current weapon)
- `5` Heal +30 HP
- `6` Buy 2 boards
- `N` Begin next wave

### HUD and Phase Display

- HUD shows player health, boards, scrap, current weapon stats, and wave number.
- The current phase (`Start Menu`, `Combat`, `Preparation`, `Store`, `Game Over`) is always visible.
- Combat info includes current enemies alive and enemies left to spawn.

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
├── main.lua
├── settings.lua
├── assets/
│   ├── graphics/
│   │   ├── player/      # Runtime sprites for player
│   │   ├── enemies/     # Runtime sprites for enemies
│   │   └── ui/          # Runtime sprites for UI
│   ├── audio/
│   │   ├── player/      # Player SFX
│   │   ├── enemies/     # Enemy SFX
│   │   └── ui/          # UI/menu SFX
│   └── source/
│       └── animation/
│           ├── player/  # Source GIFs/frames before conversion
│           ├── enemies/ # Source GIFs/frames before conversion
│           ├── ui/      # Source GIFs/frames before conversion
│           └── README.md
├── assets/scripts/
│   ├── sheet_maker.ps1         # Generic ImageMagick sheet pipeline
│   └── sheet_profiles.psd1     # Profile config for source/output/mirror rules
├── src/
│   ├── entities/
│   │   ├── player.lua    # Player movement, health, aiming direction
│   │   └── zombie.lua    # Zombie AI and type profiles
│   ├── systems/
│   │   ├── house.lua     # House layout and breakable openings
│   │   └── weapon.lua    # Weapon definitions and upgrade logic
│   └── ui/
│       └── ui.lua        # HUD and state overlays
├── docs/
│   └── README.md
├── README.md
└── LICENSE
```

`main.lua` stays at the root because LÖVE2D uses it as the project entrypoint.  
Gameplay modules live in `src/` to keep the codebase easy to grow over time.
Gameplay and balance knobs are centralized in `settings.lua`.

### Asset Pipeline Notes

- Put raw animation sources (such as GIF files) into `assets/source/animation/...`.
- Convert source animations into sprite sheets later using ImageMagick.
- Save generated sprite sheets into `assets/graphics/...` for in-game use.
- Keep audio assets organized by domain in `assets/audio/player`, `assets/audio/enemies`, and `assets/audio/ui`.
- Generic sprite sheet pipeline scripts:
  - `assets/scripts/sheet_maker.ps1`
  - `assets/scripts/sheet_profiles.psd1`

### Sprite Sheet Profiles (`sheet_profiles.psd1`)

`assets/scripts/sheet_profiles.psd1` defines reusable profile settings for sprite sheet generation.

Each profile supports:

- `SourceDir`: folder containing source GIF files.
- `OutputPath`: final sprite sheet destination.
- `DirectionOrder`: row order in the generated sheet.
- `SourceMap`: direction to source filename map.
- `MirrorMap`: target direction from source direction (`target <- source`).
- Optional overrides: `FrameWidth`, `FrameHeight`, `FrameCount`, `PaletteColors`.

Example profile names:

- `zombie` (backward-compatible zombie source/output layout).
- `player_idle_a` (sample player idle profile).

Usage examples:

```powershell
pwsh ./assets/scripts/sheet_maker.ps1 -Profile zombie
pwsh ./assets/scripts/sheet_maker.ps1 -Profile player_idle_a
```

Troubleshooting:

- Missing file: verify each `SourceMap` filename exists in `SourceDir`.
- Wrong frame count: verify GIF frame count or adjust `FrameCount`.
- Alpha or palette issues: inspect output with `magick identify` and adjust `PaletteColors`.

## Game Configuration (`settings.lua`)

`settings.lua` is the single place for core gameplay tuning. Main groups:

- `window`: resolution, title, background color.
- `world`: spawn padding and world-level bounds helpers.
- `states`: prep timer and phase timings.
- `waveDirector`: base wave count, per-wave growth, spawn interval curve, zombie mix weights.
- `player`: speed, health, repair range, and starting resources.
- `house`: house dimensions, wall thickness, and all opening durability definitions.
- `weapons`: base stats plus upgrade costs/multipliers.
- `zombies`: per-type stats, attack behavior, and animation settings.
- `economy`: drop tables and store prices/rewards.
- `effects`: blood particle and screen-shake tuning.
- `pickups`: resource pickup radius.

### Latest Balance Tuning

- Wave baseline increased so the first combat wave starts with significantly more zombies.
- **Normal** zombie HP reduced by `10`.
- **Normal** zombie plank damage reduced by `6`.
- Later waves keep the same growth formula but now scale from the new higher baseline.

## Future Improvements

- Better pathfinding around crowded openings
- More weapon types and unique upgrade trees
- Barricade placement anywhere on walls
- Audio effects and background music
- Better store UX with selectable cursor/shop cards
- Save/load progression between sessions
- Sprite art, animations, and polish effects
- Co-op or local multiplayer support

## Repository

- **Repository name:** `love2d-zombie-house-defense`
- **Repository description:** A top-down LÖVE2D zombie defense prototype with multi-type zombies, wave director progression, a between-round store, barricade repairs, and weapon stat upgrades.
- **GitHub URL:** `https://github.com/ricande/love2d-zombie-house-defense`

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository and create a feature branch:
   ```bash
   git checkout -b feature/my-change
   ```
2. Keep changes focused and update docs when behavior changes.
3. Run the game locally with LÖVE2D and verify no regressions.
4. Commit with clear messages and open a pull request describing:
   - What changed
   - Why it changed
   - How it was tested

### Contributor Setup

```bash
git clone https://github.com/ricande/love2d-zombie-house-defense.git
cd love2d-zombie-house-defense
love .
```

## License

This project is released under the **MIT License**.
