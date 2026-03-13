local AnimationProfile = {}

local DEFAULT_DIRECTION_ORDER = {
    "north",
    "northeast",
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest",
}

function AnimationProfile.toControllerConfig(profile, sharedDirectionOrder)
    local states = {}
    local profileStates = profile and profile.states or {}
    for stateName, stateDef in pairs(profileStates) do
        states[stateName] = {
            sheetPath = stateDef.sheetPath,
            frameCount = stateDef.frameCount,
            fps = stateDef.fps,
            scaleMultiplier = stateDef.scaleMultiplier,
            oneShotDuration = stateDef.oneShotDuration,
            loop = stateDef.loop,
        }
    end

    return {
        frameWidth = (profile and profile.frameWidth) or 48,
        frameHeight = (profile and profile.frameHeight) or 48,
        directionOrder = (profile and profile.directionOrder) or sharedDirectionOrder or DEFAULT_DIRECTION_ORDER,
        defaultDirection = (profile and profile.defaultDirection) or "south",
        defaultState = (profile and profile.defaultState) or "idle",
        states = states,
    }
end

return AnimationProfile
