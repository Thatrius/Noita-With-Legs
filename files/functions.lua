--GET THE DISTANCE BETWEEN TWO SETS OF COORDS:
function Distance(x1, y1, x2, y2)
    local x1,x2,y1,y2 = x1 or 0,x2 or 0,y1 or 0,y2 or 0 --SHUT UP YA STOOPID ERRORS, ARE YA HAPPY NOW
    return math.sqrt(((x1-x2)^2) + ((y1-y2)^2))
end--> distance
function normalize(x, y)
    local mag = math.sqrt((x^2) + (y^2))
    return x/mag, y/mag
end
function dotProduct(x1, y1, x2, y2)
    return (x1*x2) + (y1*y2)
end

function DegToRads(deg)
    return deg * (math.pi/180)
end--> radians
function RadsToDeg(rads)
    return rads * (180/math.pi)
end--> radians
function VecToRads(x,y,x2,y2)
    return math.atan2(y2-y, x2-x)
end--> radians
function RadsToVec(rads)
    return math.cos(rads), math.sin(rads)
end--> vector x, y
function clamp(value, min, max)
    local max = max or -min
    if value > max then 
        return max
    elseif value < min then
        return min
    elseif math.abs(value) >= 0 then --this excludes "nan" and "-nan" values
        return value
    end
    return 0
end

function find_stupid_nans(list)
    local count = 0
    for i, val in ipairs(list) do
        if not ((val >= 0) or (val <= 0)) then
            return true
        end
    end
    return false
end

--SORT A TABLE OF TABLES BY A CERTAIN INDICE OF EACH TABLE:
function sort(list, index, follow)
    function compare(a,b)
        return a[1] < b[1]
    end
    table.sort(list, compare)
    return list
end--sorted table, new index of followed index

--ROTATE A SET OF COORDS AROUND ANOTHER SET OF COORDS:
function rotatePoint(x,y,cx,cy,rads)
    local dist = Distance(x,y,cx,cy)
    local angle = VecToRads(cx,cy,x,y) + rads
    local add_x, add_y = RadsToVec(angle)
    local new_x, new_y = cx+(add_x*dist), cy+(add_y*dist)
    return new_x, new_y
end--> rotated x, y

--GET THE FASTEST ROTATIONAL ROUTE FROM ONE ANGLE TO ANOTHER (in radians):
function rotDiff(from_angle, to_angle) 
    local end1 = math.pi
    local end2 = -end1

    if from_angle < end2 then 
        from_angle = end1 + (from_angle - end2)
    elseif from_angle > end1 then 
        from_angle = end2 + (from_angle - end1)
    end
    if to_angle < end2 then 
        to_angle = end1 + (to_angle - end2)
    elseif to_angle > end1 then 
        to_angle = end2 + (to_angle - end1)
    end


    local route1 = to_angle-from_angle
    local route2 = (end2-from_angle) + (to_angle-end1)
    local route3 = (end1-from_angle) + (to_angle-end2)

    if math.abs(route1) <= math.abs(route2) then
        if math.abs(route1) <= math.abs(route3) then
            return route1
        else
            return route3
        end
    else
        if math.abs(route2) <= math.abs(route3) then
            return route2
        else
            return route3
        end
    end
end--rotational difference

--GET CLOSEST POINT ON A LINE, TO ANOTHER POINT
function getClosestPointOnLine(x1,y1,cx,cy,x2,y2)
    local x1, y1, x2, y2 = x1-cx, y1-cy, x2-cx, y2-cy
    local scale1 = math.sqrt((x1^2) + (y1^2))
    local x1, y1 = (x1/scale1), y1/scale1

    local scale2 = math.sqrt((x2^2) + (y2^2))
    local x2, y2 = x2/scale2, y2/scale2

    local dp = (x1*x2) + (y1*y2)
    return (x1*(scale2*dp))+cx, (y1*(scale2*dp))+cy
end--> closest x, y

--MOVE A SET OF COORDS A SPECIFIC DISTANCE TOWARD ANOTHER SET OF COORDS:
function MoveCoordsAlongVector(x, y, x2, y2, dist)
    local dist2 = math.sqrt(((x-x2)^2) + ((y-y2)^2))
    local x3 = x + (((x2-x)/dist2)*dist)
    local y3 = y + (((y2-y)/dist2)*dist)
    return x3, y3
end--> moved x, y

--GET THE INTERSECTION OF 2 LINE SEGMENTS:
function intersection(s1, e1, s2, e2)
    local d = (s1.x - e1.x) * (s2.y - e2.y) - (s1.y - e1.y) * (s2.x - e2.x)
    if d == 0 then return end
    local a = s1.x * e1.y - s1.y * e1.x
    local b = s2.x * e2.y - s2.y * e2.x
    local x = (a * (s2.x - e2.x) - (s1.x - e1.x) * b) / d
    local y = (a * (s2.y - e2.y) - (s1.y - e1.y) * b) / d
    return x, y
end

--FIND WHERE TWO CIRCLES INTERSECT:
function CircleIntersections(p1, p2, r1, r2)
    local d = Distance(p1.x, p1.y, p2.x, p2.y)--distance between circles
    if d == 0 then --if circles share same position
        return nil, nil
    elseif d > r1 + r2 then --if circles too far away
        local diff = (d - (r1+r2)) / 2
        r1, r2 = r1+diff, r2+diff
    elseif d < math.abs(r1 - r2) then --if one circle is inside the other
        local diff = (math.abs(r1 - r2) - d) / 2
        if r1 < r2 then
            r1, r2 = r1+diff, r2-diff
        else
            r1, r2 = r1-diff, r2+diff
        end
    end

    local a = (r1^2 -r2^2 + d^2) / (d*2)--distance from p1, to p3(see below)
    local h = math.sqrt(r1^2 - a^2)--distance from p3 to either intersection

    local v1 = {x = ((p2.x-p1.x)/d),--normalized vector from p1 to p2
                y = ((p2.y-p1.y)/d)}
    local v2 = {x = -v1.y,--same vector but inverted
                y =  v1.x}

    local p3 = {x = p1.x + v1.x*a,--the closest point to either intersection, on the line between circles
                y = p1.y + v1.y*a}

    local p4 = {x = p3.x + v2.x*h,--first intersection
                y = p3.y + v2.y*h}
    local p5 = {x = p3.x - v2.x*h,--second intersection
                y = p3.y - v2.y*h}
    return p4, p5
end


--APPLY FORCE TO AN ENTITY:
function EntityApplyForce(entity, force_x, force_y)
    local x, y = EntityGetTransform(entity)
    local chardatacomp = EntityGetFirstComponent(entity, "CharacterDataComponent")
    local projcomp = EntityGetFirstComponent(entity, "VelocityComponent")
    local physcomp = EntityGetFirstComponent(entity, "PhysicsBodyComponent") or EntityGetFirstComponent(entity, "PhysicsBody2Component") or EntityGetFirstComponent(entity, "SimplePhysicsComponent")
    local vel_x, vel_y = ComponentGetValue2(chardatacomp, "mVelocity")
    local proj_vel_x, proj_vel_y = ComponentGetValue2(projcomp, "mVelocity")

    if physcomp or not proj_vel_x then
        PhysicsApplyForce(entity, force_x, force_y)
    end
    if vel_x then 
        ComponentSetValue2(chardatacomp, "mVelocity", vel_x+force_x, vel_y+force_y)
    elseif proj_vel_x then
        ComponentSetValue2(projcomp, "mVelocity", proj_vel_x+force_x, proj_vel_y+force_y)
    end
end



--GET THE FIRST PROJECTILE THAT'S GOING TO HIT US ON ITS CURRENT TRAJECTORY:
function GetIncomingProjectile(x, y, radius, projectiles_to_ignore)
    local projectiles_to_ignore = projectiles_to_ignore or {}
    local projectiles = EntityGetInRadiusWithTag(x, y, radius, "projectile")
    for i, projectile in ipairs(projectiles) do
        local proj_comp = EntityGetFirstComponent(projectile, "VelocityComponent")
        local px, py = EntityGetTransform(projectile)
        if px and not get_index(projectiles_to_ignore, projectile) then
            local currentdist = math.sqrt(((px-x)^2) + ((py-(y-4))^2))
            local vel_px, vel_py = ComponentGetValue2(proj_comp, "mVelocity")
            local vel_px = vel_px
            local vel_py = vel_py
            local mag = math.sqrt(((vel_px)^2) + ((vel_py)^2))
            local future_x = px + ((vel_px/mag)*currentdist)
            local future_y = py + ((vel_py/mag)*currentdist)
            local futuredist = math.sqrt(((x-future_x)^2) + (((y-4)-future_y)^2))
            local projectile_view_obstructed = RaytraceSurfaces(x,y-4,px,py)
            if futuredist < 10 and futuredist < currentdist and not projectile_view_obstructed then 
                return projectile
            end
        end
    end
end--> projectile_id

--FIND A VISIBLE ENEMY WITHIN RANGE AND LINE OF SIGHT:
function GetAttackableEnemy(x,y,radius,genome,entities_to_ignore)
    local entities_to_ignore = entities_to_ignore or {}
    local newtargs = EntityGetInRadiusWithTag(x, y, radius, "mortal")
    for i, newtarg in ipairs(newtargs) do
        local x2, y2 = EntityGetTransform(newtarg)
        local target_view_obstructed = RaytracePlatforms(x,y,x2,y2)
        local targ_genome = ComponentGetValue2(EntityGetFirstComponent(newtarg, "GenomeDataComponent"), "herd_id")
        if targ_genome and genome ~= targ_genome and not target_view_obstructed and not get_index(entities_to_ignore, newtarg) then
            return newtarg
        end
    end
end--> entity_id

--TAKE MONEY FROM A CORPSE:
function loot_corpse( entity_item, entity_who_picked)
    dofile_once( "data/scripts/game_helpers.lua" )
    dofile_once("data/scripts/lib/utilities.lua")
    dofile_once( "data/scripts/game_helpers.lua" )
	local pos_x, pos_y = EntityGetTransform( entity_item )
	local money = 0
	local value = 10
	local hp_value = 0
	edit_component( entity_who_picked, "WalletComponent", function(comp,vars)
		money = ComponentGetValueInt( comp, "money")
	end)
	-- load the gold_value from VariableStorageComponent
	local components = EntityGetComponent( entity_item, "VariableStorageComponent" )
	if ( components ~= nil ) then
		for key,comp_id in pairs(components) do 
			local var_name = ComponentGetValue( comp_id, "name" )
			if( var_name == "gold_value") then
				value = ComponentGetValueInt( comp_id, "value_int" )
			end
			if( var_name == "hp_value" ) then
				hp_value = ComponentGetValueFloat( comp_id, "value_float" )
			end
		end
	end
	-- Different FX based on value
	if value > 500 then
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup_huge.xml", pos_x, pos_y, 0, 0 )
	elseif value > 40 then
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup_large.xml", pos_x, pos_y, 0, 0 )
	else
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup.xml", pos_x, pos_y, 0, 0 )
    end
	local extra_money_count = GameGetGameEffectCount( entity_who_picked, "EXTRA_MONEY" )
	if extra_money_count > 0 then
		for i=1,extra_money_count do
			value = value * 2
		end
	end
	money = money + value
	edit_component( entity_who_picked, "WalletComponent", function(comp,vars)
		vars.money = money
	end)
	if( hp_value > 0 ) then
		hp_value = hp_value * 0.5
		heal_entity( entity_who_picked, hp_value )
	end
    GamePrint("Looted " .. money .. " gold from " ..EntityGetName(entity_item))
	for i, comp in ipairs(EntityGetAllComponents(entity_item)) do
        local comp_type = ComponentGetTypeName(comp)
        if comp_type == "VariableStorageComponent" or comp_type == "SpriteParticleEmitterComponent" then
            EntityRemoveComponent(entity_item, comp)
        end
    end
end

--Below functions were written by Not An Apple, A Stone. 
--I slightly modified ApplyForceAtPoint() so that it applies the torque around the given point, rather than around the center of mass.  
--This change is a bit more realistic, but comes at the cost of reduced versatility - if the center of mass of the entity isn't equal to the entity's x, y transform, the object flips out. 

function Cross(x1, y1, x2, y2)
	return (x1*y2) - (y1*x2)
end

--Applies force as if it was given on a sertain point on the entity
function ApplyForceAtPoint(entity, point_x, point_y, force_x, force_y, angular_drag)
    local x, y, rot = EntityGetTransform(entity)
    local original_dist = Distance(point_x, point_y, x, y)
    local future_point_x, future_point_y = point_x+force_x, point_y+force_y
    local future_x, future_y = MoveCoordsAlongVector(future_point_x, future_point_y, x, y, original_dist)
    if not string.find(tostring(future_x-x), "nan") and not string.find(tostring(future_x-x), "inf") then
	    PhysicsApplyForce(entity, future_x-x, future_y-y)
    end
    local speed = Distance(0,0,force_x,force_y)
    --PhysicsApplyTorque(entity, angular_drag*speed*0.01)
	ApplyTorqueFromPoint(entity, point_x, point_y, force_x/2, force_y/2, angular_drag)
end
--Applies angular force as if a force was given on a sertain point on the entity
function ApplyTorqueFromPoint(entity, point_x, point_y, force_x, force_y, drag)
	local x, y, rot = EntityGetTransform(entity)
	
	local torque = -Cross(x - point_x, y - point_y, force_x, force_y)

	if not string.find(tostring(torque), "nan") and torque ~= 0 and not string.find(tostring(torque), "inf") then
		PhysicsApplyTorque(entity, clamp((torque / 50), -20, 20))
	end
end