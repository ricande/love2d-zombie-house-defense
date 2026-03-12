@{
    SchemaVersion = 1

    # Shared defaults that profiles can override.
    Defaults = @{
        FrameWidth    = 48
        FrameHeight   = 48
        FrameCount    = 8
        PaletteColors = 16
        DirectionOrder = @(
            "north"
            "northeast"
            "east"
            "southeast"
            "south"
            "southwest"
            "west"
            "northwest"
        )
    }

    # Profile schema (reference for script validation and maintenance).
    ProfileSchema = @{
        Required = @(
            "SourceDir"       # Directory containing source GIF files.
            "OutputPath"      # Final sprite sheet destination.
            "DirectionOrder"  # Row order for final sheet.
            "SourceMap"       # direction -> source filename.
            "MirrorMap"       # targetDirection -> sourceDirection.
        )
        Optional = @(
            "FrameWidth"
            "FrameHeight"
            "FrameCount"
            "PaletteColors"
        )
    }

    Profiles = @{
        zombie = @{
            SourceDir  = "assets/graphics/enemies/zombie/source"
            OutputPath = "assets/graphics/enemies/zombie/zombie_sheet.png"

            FrameWidth    = 48
            FrameHeight   = 48
            FrameCount    = 8
            PaletteColors = 16

            DirectionOrder = @(
                "north"
                "northeast"
                "east"
                "southeast"
                "south"
                "southwest"
                "west"
                "northwest"
            )

            SourceMap = @{
                north     = "north.gif"
                east      = "east.gif"
                northwest = "north-west.gif"
                south     = "south.gif"
                southeast = "south-east.gif"
            }

            MirrorMap = @{
                west      = "east"
                northeast = "northwest"
                southwest = "southeast"
            }
        }

        player_idle_a = @{
            SourceDir  = "assets/graphics/player/player/source/idle"
            OutputPath = "assets/graphics/player/player/sheets/idle_a_sheet.png"

            FrameWidth    = 48
            FrameHeight   = 48
            FrameCount    = 8
            PaletteColors = 16

            DirectionOrder = @(
                "north"
                "northeast"
                "east"
                "southeast"
                "south"
                "southwest"
                "west"
                "northwest"
            )

            # Update filenames as player source coverage expands.
            SourceMap = @{
                south = "idle_south.gif"
            }

            MirrorMap = @{
                # Example mirror rules for this profile.
                west = "east"
            }
        }
    }
}
