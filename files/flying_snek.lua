local entity = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity)

function clamp(value, min, max)
    if value > max then return max elseif value < min then return min else return value end
end
function Distance(dx, dy, dx2, dy2)
    return math.sqrt(((dx-dx2)^2) + ((dy-dy2)^2))
end
function rotatePoint(x,y,cx,cy,rads)
    --local angle = radToDeg(rads)
    local sin = math.sin(rads)
    local cos = math.cos(rads)
    x = x - cx
    y = y - cy
    local new_x = (x * cos) - (y * sin)
    local new_y = (x * sin) - (y * cos)
    x = new_x + cx
    y = new_y + cy
    return x, y
end

local prev_x, prev_y = GetValueNumber("prev_x", x), GetValueNumber("prev_y", y)
local vel_x, vel_y = x-prev_x, y-prev_y
local targ_x, targ_y = GetValueNumber("targ_x", 0), GetValueNumber("targ_y", 0)
local targ_entity = GetValueNumber("targ_entity", EntityGetWithTag("player_unit")[1])
local px, py = EntityGetTransform(targ_entity)
local state = GetValueNumber("state", 1)
local oscilation = GetValueNumber("oscilation", 0)
if not px then SetValueNumber("state", 0) end
local verlet_physics_component = EntityGetFirstComponent(entity, "VerletPhysicsComponent")
local positions = ComponentGetValue2(verlet_physics_component, "positions")
local positions_prev = ComponentGetValue2(verlet_physics_component, "positions_prev")


local number_of_segments = 20
local force_amount = 1
local upward_force_amount = 0.1
local damping = 49

--WIGGLE AROUND:
for i=(number_of_segments*2)-3,1,-2 do
    positions_prev[i+1] = ((positions_prev[i+1]*9) + (positions_prev[i+3])) / 10
    positions_prev[i] = (((positions_prev[i]*9) + (positions_prev[i+2])) / 10) + upward_force_amount
end

ComponentSetValue2(verlet_physics_component, "positions_prev", positions_prev)
ComponentSetValue2(verlet_physics_component, "positions", positions)


if state == 0 then -- Fly around seeking prey:
    local path_obstructed, block_x, block_y = RaytracePlatforms(x, y, targ_x, targ_y)
    local targ_dist = Distance(x, y, targ_x, targ_y)
    
    if not path_obstructed and targ_dist < 20 and math.random(20) == 1 then
        SetValueNumber("targ_x", targ_x+math.random(-70,70))
        SetValueNumber("targ_y", targ_y+math.random(-70,70))
    elseif math.random(20) == 1 then
        SetValueNumber("targ_x", targ_x+math.random(-5,5))
        SetValueNumber("targ_y", targ_y+math.random(-5,5))
    end

    --find prey within line of sight:
    local newtarg = nil
    for i, creature in ipairs(EntityGetInRadiusWithTag(x,y,100, "hittable")) do
        local px, py = EntityGetTransform(creature)
        local dmc2 = EntityGetFirstComponent(creature, "DamageModelComponent")
        local path_obstructed = RaytracePlatforms(x, y, px, py)
        if not path_obstructed and dmc2 and creature ~= entity then
            SetValueNumber("targ_entity", creature)
            SetValueNumber("state", 1)
            GamePrint("inspecting " .. GameTextGetTranslatedOrNot(EntityGetName(creature)))
            break
        end
    end
    --if nothing living, find a random object to inspect instead:
    if not newtarg then
        for i, creature in ipairs(EntityGetInRadius(x,y,100)) do
            local px, py = EntityGetTransform(creature)
            local path_obstructed = RaytracePlatforms(x, y, px, py)
            if not path_obstructed and creature ~= entity then
                SetValueNumber("targ_entity", creature)
                SetValueNumber("state", 1)
                GamePrint("inspecting " .. GameTextGetTranslatedOrNot((EntityGetName(creature) or "object")))
                break
            end
        end
    end
elseif state == 1 then --Stalk potential prey:
    --what direction can we move the farthest in, that gest us closest to the target entity?
    local ray1, rx1, ry1 = RaytracePlatforms(x, y, targ_x, targ_y)
    local raydist1 = Distance(x, y, rx1, ry1)
    local targdist1 = Distance(rx1, ry1, px, py)
    --GamePrint(raydist1 - (targdist1/10))
    for i=1,3 do
        local rotx, roty = rotatePoint(targ_x, targ_y, x, y, math.random(-20,20)/20)
        local ray2, rx2, ry2 = RaytracePlatforms(x, y, rotx, roty)
        local raydist2 = Distance(x, y, rx2, ry2)
        local targdist2 = Distance(rx2, ry2, px, py)
        local score1 = raydist1 - (targdist1/10)
        local score2 = raydist2 - (targdist2/10)
        --local dbg = EntityGetWithTag("debug")[1]
        --EntitySetTransform(dbg, rx2, ry2)
        if score2 > score1 then
            SetValueNumber("targ_x", rx2)
            SetValueNumber("targ_y", ry2)
            raydist1 = raydist2
            targdist1 = targdist2
            targ_x, targ_y = rx2, ry2
        end
    end
elseif state == 2 then --Strike prey:
    path_obstructed, block_x, block_y = RaytracePlatforms(x, y, px, py)
    if not path_obstructed then
        SetValueNumber("targ_x", px+math.random(-30,30))
        SetValueNumber("targ_y", py+math.random(-30,30))
    else
        SetValueNumber("state", 0)
        GamePrint("lost" .. GameTextGetTranslatedOrNot(EntityGetName(creature)))
    end
end


local vel_mag = Distance(x,y,x+vel_x,y+vel_y)+0.01
local x2 = (((x+vel_x)-x)/vel_mag)*100 
local y2 = (((y+vel_y)-y)/vel_mag)*100 
local did_hit, hit_x, hit_y = RaytracePlatforms(x, y, x+(vel_x*10), y+(vel_y*10))
local dist_to_wall = Distance(x, y, hit_x, hit_y)+0.01
local dist = Distance(x, y, targ_x, targ_y)+0.1


local move_x = targ_x-x
local move_y = targ_y-y
if Distance(0,0,move_x,move_y) > 0.1 then
    move_x = ((targ_x-x)/dist)*0.1
    move_y = ((targ_y-y)/dist)*0.1
end
if did_hit then
    move_x = move_x - ((hit_x-x)/dist_to_wall)*10*(math.abs(vel_x)/dist_to_wall)
    move_y = move_y - ((hit_y-y)/dist_to_wall)*10*(math.abs(vel_y)/dist_to_wall)
end

local prev_x = (((x*damping)+x+vel_x)/(damping+1))--damps velocity
local prev_y = (((y*damping)+y+vel_y)/(damping+1))

SetValueNumber("prev_x", prev_x - move_x)
SetValueNumber("prev_y", prev_y - move_y)
EntitySetTransform(entity, 0, 0)--x+vel_x, y+vel_y)