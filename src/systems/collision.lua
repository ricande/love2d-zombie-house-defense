local Collision = {}

local EPSILON = 0.0001

local function length(x, y)
    return math.sqrt(x * x + y * y)
end

function Collision.closestPointOnSegment(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local abLenSq = abx * abx + aby * aby
    if abLenSq <= EPSILON then
        return ax, ay
    end

    local apx = px - ax
    local apy = py - ay
    local t = (apx * abx + apy * aby) / abLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end
    return ax + abx * t, ay + aby * t
end

function Collision.circleSegmentPenetration(cx, cy, radius, ax, ay, bx, by)
    local closestX, closestY = Collision.closestPointOnSegment(cx, cy, ax, ay, bx, by)
    local dx = cx - closestX
    local dy = cy - closestY
    local distSq = dx * dx + dy * dy
    local radiusSq = radius * radius
    if distSq >= radiusSq then
        return false, 0, 0, 0
    end

    local dist = math.sqrt(math.max(0, distSq))
    local nx, ny = 1, 0
    if dist > EPSILON then
        nx = dx / dist
        ny = dy / dist
    else
        -- Degenerate center-on-segment case: use segment normal as fallback.
        local sx = bx - ax
        local sy = by - ay
        local segLen = length(sx, sy)
        if segLen > EPSILON then
            nx = -sy / segLen
            ny = sx / segLen
            local mx = (ax + bx) * 0.5
            local my = (ay + by) * 0.5
            local toCenterX = cx - mx
            local toCenterY = cy - my
            if toCenterX * nx + toCenterY * ny < 0 then
                nx = -nx
                ny = -ny
            end
        end
    end

    local depth = radius - dist
    return true, nx, ny, depth
end

function Collision.resolveCircleAgainstSegments(targetX, targetY, radius, segments, maxIterations)
    local x, y = targetX, targetY
    local iterations = maxIterations or 6

    for _ = 1, iterations do
        local hadPenetration = false
        for _, segment in ipairs(segments) do
            local hit, nx, ny, depth = Collision.circleSegmentPenetration(
                x,
                y,
                radius,
                segment.x1,
                segment.y1,
                segment.x2,
                segment.y2
            )
            if hit and depth > 0 then
                x = x + nx * (depth + EPSILON)
                y = y + ny * (depth + EPSILON)
                hadPenetration = true
            end
        end
        if not hadPenetration then
            break
        end
    end

    return x, y
end

function Collision.circleCirclePenetration(ax, ay, ar, bx, by, br)
    local dx = bx - ax
    local dy = by - ay
    local distance = length(dx, dy)
    local minDistance = ar + br
    if distance >= minDistance then
        return false, 0, 0, 0
    end

    local nx, ny = 1, 0
    if distance > EPSILON then
        nx = dx / distance
        ny = dy / distance
    end

    local depth = minDistance - distance
    return true, nx, ny, depth
end

return Collision
