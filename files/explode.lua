dofile_once("mods/more_physic/files/functions.lua")

local entity = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity)
local luacomp = EntityGetFirstComponent(entity, "LuaComponent")
local radcomp = EntityGetFirstComponent(entity, "VariableStorageComponent")
local frames = ComponentGetValue2(luacomp, "mTimesExecuted")
local power = ComponentGetValue2(radcomp, "value_int")
local expansion_rate = (power/5)*frames
local radius = power + expansion_rate --bomb is 50+(10*frames)

function force(body_entity, body_mass, body_x, body_y, body_vel_x, body_vel_y, body_vel_angular)
    local fx, fy = 0, 0
    local dist = Distance(x, y, body_x, body_y)
    if dist < radius then
        local force = 500+(power*10)
        if frames > 1 then 
            force = force/10
            inner_radius = (power-10)+(expansion_rate/2)
            if (dist > inner_radius) then force = force/frames else force = 0 end
        end
        fx, fy = MoveCoordsAlongVector(0, 0, body_x-x, body_y-y, force)
    end
    return x,y,fx,fy,0
end
--> force_world_pos_x:number,force_world_pos_y:number,force_x:number,force_y:number,force_angular:number

if frames == 0 then
    local tiers = math.max(math.floor(power / 10), 1)
    --chunk_count = math.min(3+math.floor((power+10)/10), 20)
    local chunks_added = 0
    local bounds = {x,x,y,y}
    for tier=1,tiers do
        local size = 1
        if tier > 4 then
            size = 7
        elseif tier > 2 then
            size = 4
        end
        for i=1,3 do
            local size = math.random(size,size+2)
            path = "mods/more_physic/files/collapse_shapes/" .. size .. ".png"

            local offset = -5
            local rand = (tier*10)
            if i > 3 then offset = -12.5 elseif i > 6 then offset = -25 end

            local x2, y2 = x+offset+math.random(-rand,rand), y+offset+math.random(-rand,rand)
            --if x2 > x
            if tier == 1 and tiers < 3 then 
                local hit, hit_x, hit_y = RaytraceSurfaces(x,y,x2,y2)
                if hit then x2, y2 = hit_x, hit_y end
            end
            LooseChunk(x2, y2, path, 100)
        end
        chunks_added = chunks_added + 3
        if chunks_added > 25 then break end
    end
    --GamePrint(chunks_added .. "chunks created")
else
    PhysicsApplyForceOnArea(force, 0, x-radius, y-radius, x+radius, y+radius)
end

