dofile_once("mods/more_physic/files/functions.lua")
dofile_once("mods/more_physic/files/IK_function.lua")

-------------------------------------------------------------------------------------
--DEFINE THINGS
-------------------------------------------------------------------------------------
local mult = 70.620690902 --the velocity required to move an entity 1 pixel per frame
local div = 0.014160156 --1 divided by the previous number
local drag = 0.99 --the air drag we actually want, on both axes
local drag_negate = 1.176470605 --multiply to negate drag on the x axis
local grav = 5.8332982063293 --velocity that the game adds each frame to the y axis
local stability = GetValueNumber("stability", 0)
local stepped_this_frame = false
local step_cooldown = GetValueNumber("steptime", 0)
local turn_cooldown = GetValueNumber("turntime", 0)

local player = GetUpdatedEntityID()
local x, y, r, sx, sy = EntityGetTransform(player)
local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
local chardatacomp = EntityGetFirstComponent(player, "CharacterDataComponent")
local controlscomp = EntityGetFirstComponent(player, "ControlsComponent")

local grounded_legs = {}
local stepping_legs = {}
local airborne_legs = {}
local alignments = {}
local bestFoothold = 1
local worstFoothold = 1
local closest_CW = nil
local closest_CCW = nil

local log = ""

-------------------------------------------------------------------------------------
--CATEGORIZE AND INDEX ALL THE LEG
-------------------------------------------------------------------------------------
local t1, t2 = nil, nil
for i,child in ipairs(EntityGetAllChildren(player)) do
    if EntityGetName(child) == "torso" then
        local cx, cy = EntityGetTransform(child)
        if cx == 0 and cy == 0 then EntitySetTransform(child, x, y); cx=x; cy=y end
        local cdc = EntityGetFirstComponentIncludingDisabled( child, "CharacterDataComponent")
        local vx, vy = ComponentGetValue2(cdc, "mVelocity")
        local list = {i=child, x=cx, y=cy, vx=vx, vy=vy, cdc=cdc, ground=ground}
        if t1 then t2 = list else t1 = list end

        --ADD STARTING LEGS
        local leginfo = EntityGetFirstComponent(child, "VariableStorageComponent", "legs")
        if leginfo then
            local file = ComponentGetValue2(leginfo, "value_string")
            local num = ComponentGetValue2(leginfo, "value_int")
            for i=1,num do
                local leg = EntityLoad(file)
		        EntityAddChild(child, leg)
            end
            EntityRemoveComponent(child, leginfo)
        end
        for i,leg in ipairs((EntityGetAllChildren(child) or {})) do
            if EntityGetName(leg) == "leg" then 
                local state_comp = EntityGetFirstComponent(leg, "VariableStorageComponent", "state")
                local footcomp_x = EntityGetFirstComponent(leg, "VariableStorageComponent", "foot_x")
                local footcomp_y = EntityGetFirstComponent(leg, "VariableStorageComponent", "foot_y")
                local targcomp_x = EntityGetFirstComponent(leg, "VariableStorageComponent", "target_x")
                local targcomp_y = EntityGetFirstComponent(leg, "VariableStorageComponent", "target_y")
                local relcomp_x = EntityGetFirstComponent(leg, "VariableStorageComponent", "relative_x")
                local relcomp_y = EntityGetFirstComponent(leg, "VariableStorageComponent", "relative_y")
                local lengthcomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "total_length")
                local dircomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "direction")

                local state = ComponentGetValue2(state_comp, "value_int")
                local length = ComponentGetValue2(lengthcomp, "value_int")
                local dir = ComponentGetValue2(dircomp, "value_float")
                local foot_x, foot_y = ComponentGetValue2(footcomp_x, "value_float"), ComponentGetValue2(footcomp_y, "value_float")
                local targ_x, targ_y = ComponentGetValue2(targcomp_x, "value_float"), ComponentGetValue2(targcomp_y, "value_float")
                local rel_x, rel_y = ComponentGetValue2(relcomp_x, "value_float"), ComponentGetValue2(relcomp_y, "value_float")
                local comps = {state=state_comp,length=lengthcomp,foot_x=footcomp_x,foot_y=footcomp_y,targ_x=targcomp_x,targ_y=targcomp_y,rel_x=relcomp_x,rel_y=relcomp_y,direction=dircomp}
                local data = {id=leg,state=state,length=length,foot_x=foot_x,foot_y=foot_y,targ_x=targ_x,targ_y=targ_y,rel_x=rel_x,rel_y=rel_y,direction=dir,toes_x=foot_x,toes_y=foot_y,comps=comps}
                if state == 2 then
                    table.insert(grounded_legs, data)
                else
                    table.insert(airborne_legs, data)
                    if state == 1 then table.insert(stepping_legs, data) end
                end
            end
        end
    end
end
local mid_x, mid_y = (t1.x+t2.x)/2, (t1.y+t2.y)/2
local vel_x, vel_y = (t1.vx+t2.vx)/2, (t1.vy+t2.vy)/2
local rot = VecToRads(t1.x, t1.y, t2.x, t2.y) + (math.pi/2)
local rot_x, rot_y = normalize(t2.x-t1.x, t2.y-t1.y)
local prev_rot = GetValueNumber("prot", rot)
local rot_vel = rotDiff(prev_rot, rot)
SetValueNumber("prot", rot)

--CONTROLS
local move_x, move_y = 0, -grav
local desired_rot = rot
local crouch = false
if ComponentGetValue2(controlscomp, "mButtonDownLeft") then move_x = move_x - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownRight") then move_x = move_x + 60 end
if ComponentGetValue2(controlscomp, "mButtonDownUp") then move_y = move_y - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownDown") then move_y = move_y + 60 end
local move2_x, move2_y = normalize(move_x, move_y+grav)
local vx, vy = normalize(move_x, move_y)
local vx2, vy2 = normalize(move_x-vel_x,move_y-vel_y)
local ground_too_close, ground_x, ground_y = RaytracePlatforms(mid_x, mid_y, mid_x, mid_y+10)

if ComponentGetValue2(controlscomp, "mButtonDownKick") then --Are we jumping?
    move_x, move_y = vx*60*2, vy*60*2
    desired_rot = VecToRads(0,0,vx,vy)+DegToRads(90)
elseif (Distance(move_x,move_y,vel_x,vel_y) > 50) or dotProduct(rot_x,rot_y,vx,vy) <= 0 then --Are we changing trajectory?
    --GamePrint("turning")
    --if move_x ~= 0 then move_x = move_x + ((vel_x-move_x)*50) end
    move_x,move_y = MoveCoordsAlongVector(move_x,move_y,vel_x,vel_y,50)
    if ground_too_close then --are we on the ground?
        if ground_y-mid_y > 4 then move_y = (((ground_y-4)-mid_y)*5) - grav end
    else
        --move_y = grav
    end
    desired_rot = VecToRads(0,0,vx,vy)+DegToRads(90)
elseif ground_too_close then --are we on the ground?
    if (move_y > 0) then --crouch
        move_x = move_x * 0.5
        move_y = vel_y
        desired_rot = sx
        crouch = true
    else --stand
        move_y = (((ground_y-10)-mid_y)*5) - grav
        desired_rot = clamp(move_x*0.03, -0.3, 0.3)
    end
else
    desired_rot = clamp(move_x*0.03, -0.3, 0.3)
end


local slide_x, slide_y = (vel_x-move_x)*div*2, (vel_y-move_y)*div*2
local drift = math.sqrt(slide_x^2 + slide_y^2)
local torque = clamp(rotDiff(rot, desired_rot)*0.1, -10, 10)

--try to make the torso face the direction we want to go:
local face_x, face_y = RadsToVec(rot)
if dotProduct(face_x*sx, face_y*sx, move2_x, move2_y) < 0 and turn_cooldown > 20 then
    sx = -sx
    turn_cooldown = -1
end

-------------------------------------------------------------------------------------
--LEGS THAT ARE TOUCHING GROUND
-------------------------------------------------------------------------------------
for i, torso in ipairs({t1, t2}) do
    local x2, y2 = torso.x, torso.y
    torso.alignments = {}
    torso.closest_CW = nil
    torso.closest_CCW = nil
    
    --how do we want the torso to be rotated:
    torso.rotate_x, torso.rotate_y = rotatePoint(torso.x, torso.y, mid_x, mid_y, torque - clamp(rot_vel*0.1, -10, 10))
    torso.rotate_x, torso.rotate_y = (torso.rotate_x-torso.x)*mult, (torso.rotate_y-torso.y)*mult

    --add it all together
    if crouch and ground_too_close then 
        torso.targ_vx, torso.targ_vy = move_x, torso.vy
    else
        torso.targ_vx = torso.rotate_x + move_x
        torso.targ_vy = torso.rotate_y + move_y
    end

    --correct velocity to match target velocity
    torso.force_x, torso.force_y = (torso.targ_vx-torso.vx)*div, (torso.targ_vy-torso.vy)*div
    torso.force_mag = math.sqrt(torso.force_x^2 + torso.force_y^2)
    torso.targ_x = torso.x + torso.force_x
    torso.targ_y = torso.y + torso.force_y
    local targvec_x, targvec_y = torso.force_x/torso.force_mag, torso.force_y/torso.force_mag
    local perpvec_x, perpvec_y = -targvec_y, targvec_x

    for j,leg in ipairs(grounded_legs) do
        local socket = EntityGetParent(leg.id)
        local socket_x, socket_y = EntityGetTransform(socket)
        EntitySetTransform(leg.id, socket_x, socket_y)

        local footdist = Distance(torso.x, torso.y, leg.foot_x, leg.foot_y)
        --toes:
        local idealfoot_x, idealfoot_y = torso.x - ((torso.force_x/torso.force_mag)*footdist), torso.y - ((torso.force_y/torso.force_mag)*footdist)
        local d = Distance(idealfoot_x, idealfoot_y, leg.foot_x, leg.foot_y)
        leg.toes_x, leg.toes_y = MoveCoordsAlongVector(leg.foot_x, leg.foot_y, idealfoot_x, idealfoot_y, math.min(d,2))
        local toedist = Distance(torso.x, torso.y, leg.toes_x, leg.toes_y)
        
        local footvec_x, footvec_y = (leg.toes_x-torso.x)/toedist, (leg.toes_y-torso.y)/toedist
        local alignment = -dotProduct(footvec_x, footvec_y, targvec_x, targvec_y)
        local whichside = dotProduct(footvec_x, footvec_y, perpvec_x, perpvec_y)

        --ultimately we're looking for the closest 2 vectors to the force vector, 1 on either side:
        if whichside >= 0 then--if closest in Clockwise direction
            if alignment > (torso.alignments[torso.closest_CW] or -1) then torso.closest_CW = j end
        end
        if whichside <= 0 then--if closest in Counter-Clockwise direction
            if alignment > (torso.alignments[torso.closest_CCW] or -1) then torso.closest_CCW = j end
        end
        --tbh I actually have no idea which one is CW or CCW, I just needed variable names ok, theres a 50% chance it's correct so just roll with it 
        table.insert(torso.alignments, alignment or -1)
        

        --calculate the same thing but for the center of mass instead of just the head or butt
        if i == 1 then
            local toedist = Distance(mid_x, mid_y, leg.toes_x, leg.toes_y)
            local footvec_x, footvec_y = (leg.toes_x-mid_x)/toedist, (leg.toes_y-mid_y)/toedist
            local perpvec_x, perpvec_y = -slide_y/drift, slide_x/drift
            local alignment = dotProduct(footvec_x, footvec_y, slide_x/drift, slide_y/drift)
            local whichside = dotProduct(footvec_x, footvec_y, perpvec_x, perpvec_y)
            --how good is foothold?
            if alignment > (alignments[bestFoothold] or -1) then bestFoothold = j end
            if alignment < (alignments[worstFoothold] or -1) then worstFoothold = j end
            if whichside >= 0 then--if closest in Clockwise direction
                if alignment > (alignments[closest_CW] or -1) then closest_CW = j end
            end
            if whichside <= 0 then--if closest in Counter-Clockwise direction
                if alignment > (alignments[closest_CCW] or -1) then closest_CCW = j end
            end
            table.insert(alignments, alignment or -1)
        end

        --slide:
        if i == 2 then
            local foot_x2, foot_y2 = MoveCoordsAlongVector(socket_x, socket_y, leg.foot_x+slide_x, leg.foot_y+slide_y, leg.length+10)
            local hit, hit_x, hit_y = RaytracePlatforms(socket_x, socket_y, foot_x2, foot_y2)
            local hitdist = Distance(socket_x, socket_y, hit_x, hit_y)
            local score1 = Distance(leg.foot_x, leg.foot_y, leg.foot_x+slide_x, leg.foot_y+slide_y)
            local score2 = Distance(hit_x, hit_y, leg.foot_x+slide_x, leg.foot_y+slide_y)
            if hit and hitdist >= Distance(socket_x, socket_y, leg.foot_x, leg.foot_y) and hitdist < leg.length+1 and score2 < score1 then
                leg.foot_x = hit_x
                leg.foot_y = hit_y
            end --weeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        end

        --backup method in case we need it later:
        local toedist2 = Distance(x2, y2, leg.toes_x, leg.toes_y)
        x3, y3 = getClosestPointOnLine(leg.toes_x, leg.toes_y, x2, y2, torso.targ_x, torso.targ_y)
        if Distance(x3, y3, leg.toes_x, leg.toes_y) > toedist2 then
            x2, y2 = x3, y3
        end
        
        
        --retract foot if overextended:
        if Distance(leg.foot_x, leg.foot_y, socket_x, socket_y) > leg.length+1 then
            ComponentSetValue2(leg.comps.state, "value_int", 0)
            ComponentSetValue2(leg.comps.foot_x, "value_float", leg.foot_x-mid_x)
            ComponentSetValue2(leg.comps.foot_y, "value_float", leg.foot_y-mid_y)
            stepped_this_frame = true
            IK(leg.id, mid_x, mid_y, vel_x*div, vel_y*div)
            log = log .. "foot " .. leg.id .. " retracts (too far), "
        else--apply varibles normally:
            ComponentSetValue2(leg.comps.foot_x, "value_float", leg.foot_x)
            ComponentSetValue2(leg.comps.foot_y, "value_float", leg.foot_y)
            IK(leg.id, 0, 0, vel_x*div, vel_y*div)
        end
    end
    
    local CW = grounded_legs[torso.closest_CW]
    local CCW = grounded_legs[torso.closest_CCW]
    if torso.closest_CW and torso.closest_CCW then
        local a1 = VecToRads(torso.x, torso.y, torso.force_x, torso.force_y)
        local a2 = VecToRads(torso.x, torso.y, CW.toes_x, CW.toes_y)
        local a3 = VecToRads(torso.x, torso.y, CCW.toes_x, CCW.toes_y)
        local diff1 = math.abs(rotDiff(a2,a1))
        local diff2 = math.abs(rotDiff(a1,a3))

        --if desired force is between foot angles (GOOD GOOD VER GUD YES):
        if diff1 + diff2 <= math.pi then
            torso.vx = torso.vx + torso.force_x*mult
            torso.vy = torso.vy + torso.force_y*mult
            goto skip
        end
    end
    --backup method:
    if #grounded_legs > 0 then
        local fx, fy = (x2-torso.x)*mult, (y2-torso.y)*mult
        torso.vx = torso.vx + fx
        torso.vy = torso.vy + fy
    end
    ::skip::
end

--CALCULATE STABILITY:
vel_x, vel_y = (t1.vx+t2.vx)/2, ((t1.vy+t2.vy)/2)+grav
local vmag = math.sqrt(vel_x^2 + vel_y^2)
local move_mag = math.sqrt(move_x^2 + move_y^2)

local slide_x, slide_y = (vel_x-move_x), (vel_y-move_y)
local drift = math.sqrt(slide_x^2 + slide_y^2)

local mid2_x, mid2_y = (mid_x+(vel_x*div)), (mid_y+(vel_y*div))

local stability = dotProduct(vel_x/vmag, vel_y/vmag, move_x/move_mag, move_y/move_mag)
if not (stability >= 0 or stability < 0) then stability = -1 end
SetValueNumber("stability", stability)


--DEAL WITH LEAST HELPFUL LEG:
if #grounded_legs > 0 then
    local leg = grounded_legs[worstFoothold]

    --point knee toward where we're facing:
    ComponentSetValue2(leg.comps.direction, "value_float", ((leg.direction*3) - sx)/4)

    --retract foot if unstable:
    if #airborne_legs == 0 and #stepping_legs == 0 and stability < 0 and step_cooldown > -10 and (not stepped_this_frame) then
        ComponentSetValue2(leg.comps.state, "value_int", 0)
        ComponentSetValue2(leg.comps.foot_x, "value_float", leg.foot_x-mid_x)
        ComponentSetValue2(leg.comps.foot_y, "value_float", leg.foot_y-mid_y)
        log = log .. "foot " .. leg.id .. " retracts (unstable), "
    end
end

-------------------------------------------------------------------------------------
--LEGS THAT ARE IN THE AIR
-------------------------------------------------------------------------------------
local reach = false
for i,leg in ipairs(airborne_legs) do
    --GamePrint(leg.state)
    local socket = EntityGetParent(leg.id)
    local socket_x, socket_y = EntityGetTransform(socket)
    EntitySetTransform(leg.id, socket_x, socket_y)

    --Find where to step next:
    local did_hit4, x1, y1 = getNextAvailableFoothold({x=mid_x,y=mid_y}, {x=socket_x,y=socket_y}, {x=vel_x*div,y=vel_y*div}, {x=move_x*div,y=move_y*div}, leg.length, grav*div)
    if did_hit4 then 
        --x1, y1 = x1+mid_x, y1+mid_y 
    else
        x1, y1 = MoveCoordsAlongVector(mid_x, mid_y, mid_x+slide_x, mid_y+slide_y, leg.length*2)
        if not (drift > 0) then x1, y1 = leg.foot_x+mid_x, leg.foot_y+mid_y end
        x1, y1 = CircleLineIntersection({x=mid_x, y=mid_y}, {x=x1, y=y1}, {x=socket_x, y=socket_y}, leg.length, {x=x1,y=y1})
    end

    local did_hit3, hit_x3, hit_y3 = RaytraceSurfaces(mid_x, mid_y, x1, y1)
    if did_hit3 then x1, y1 = hit_x3, hit_y3 end

    --Calculate leg mid-air rest position:
    local rest_x, rest_y = rotatePoint(socket_x, socket_y-5, socket_x, socket_y, rot+(2.6*sx))
    local rest2_x, rest2_y = rotatePoint(socket_x, socket_y-5, socket_x, socket_y, rot+(2.6*-sx))
    local dp = dotProduct((rest_x-socket_x)/5, (rest_y-socket_y)/5, (x1-socket_x)/leg.length, (y1-socket_y)/leg.length)
    local dp2 = dotProduct((rest2_x-socket_x)/5, (rest2_y-socket_y)/5, (x1-socket_x)/leg.length, (y1-socket_y)/leg.length)

    --Aim foot toward direction of undesired motion:
    if ((leg.state == 1) or (#stepping_legs == 0 and not reach)) then 
        if leg.state == 0 then log = log .. "foot " .. leg.id .. " extends, " end
        leg.state = 1
        if dp > -10.5 then
            rest_x, rest_y = x1, y1
        elseif dp2 > -0.5 and turn_cooldown > 20 then
            sx = -sx
            rest_x, rest_y = x1, y1
            turn_cooldown = -1
        else
            state = 0
        end
        
        local targdist = Distance(leg.foot_x+mid_x, leg.foot_y+mid_y, x1, y1)
        if targdist < 2 then
            leg.foot_x, leg.foot_y = rest_x-mid_x, rest_y-mid_y
            if did_hit3 and not stepped_this_frame then
                leg.state = 2
                leg.targ_x, leg.targ_y = hit_x3, hit_y3
                leg.foot_x, leg.foot_y = hit_x3, hit_y3
                step_cooldown = -1
                stepped_this_frame = true
                log = log .. "foot " .. leg.id .. " reaches target, "
            end
        else
            leg.foot_x, leg.foot_y = MoveCoordsAlongVector(leg.foot_x, leg.foot_y, rest_x-mid_x, rest_y-mid_y, 1)
        end
        reach = true
    else --Curl up:
        if leg.state == 1 then log = log .. "foot " .. leg.id .. " curls, " end
        leg.state = 0
        rest_x, rest_y = rotatePoint(socket_x, socket_y-5, socket_x, socket_y, rot+(2.6*sx))
        if i == 2 then rest_x, rest_y = rotatePoint(socket_x, socket_y-3, socket_x, socket_y, rot+(3*sx)) end
        leg.foot_x = ((leg.foot_x*3) + (rest_x-mid_x))/4
        leg.foot_y = ((leg.foot_y*3) + (rest_y-mid_y))/4
        --leg.foot_x, leg.foot_y = rotatePoint(leg.foot_x, leg.foot_y, socket_x-mid_x, socket_y-mid_y, torque - clamp(rot_vel*0.1, -10, 10))
        --EntitySetTransform(EntityGetWithTag("debug")[4], leg.foot_x+mid_x, leg.foot_y+mid_y)
    end

    --apply variables
    ComponentSetValue2(leg.comps.state, "value_int", leg.state)
    ComponentSetValue2(leg.comps.foot_x, "value_float", leg.foot_x)
    ComponentSetValue2(leg.comps.foot_y, "value_float", leg.foot_y)
    ComponentSetValue2(leg.comps.targ_x, "value_float", leg.targ_x)
    ComponentSetValue2(leg.comps.targ_y, "value_float", leg.targ_y)
    ComponentSetValue2(leg.comps.direction, "value_float", ((leg.direction*3) - sx)/4)
    if leg.state ~= 2 then
        IK(leg.id, mid_x, mid_y, vel_x*div, vel_y*div)
    else
        IK(leg.id, 0, 0, vel_x*div, vel_y*div)
    end
end
if log ~= "" then print(log) end

-------------------------------------------------------------------------------------
--KEEP TORSO TOGETHER
-------------------------------------------------------------------------------------
local dist = (Distance(t1.x, t1.y, t2.x, t2.y))
local futuredist = Distance(t1.x+(t1.vx*div), t1.y+(t1.vy*div), t2.x+(t2.vx*div), t2.y+(t2.vy*div))
local offset = ((futuredist-dist))/2
local vec_x = ((t1.x-t2.x)/dist)*((3-offset))
local vec_y = ((t1.y-t2.y)/dist)*((3-offset))

t1.x2, t1.y2 = mid_x+vec_x, mid_y+vec_y
t2.x2, t2.y2 = mid_x-vec_x, mid_y-vec_y


t1.fx, t1.fy = (t1.x2-t1.x)*mult, (t1.y2-t1.y)*mult
t2.fx, t2.fy = (t2.x2-t2.x)*mult, (t2.y2-t2.y)*mult


t1.vx = (t1.vx*drag_negate*drag) + t1.fx
t2.vx = (t2.vx*drag_negate*drag) + t2.fx
t1.vy = (t1.vy*drag) + t1.fy
t2.vy = (t2.vy*drag) + t2.fy

-------------------------------------------------------------------------------------
--APPLY TORSO SEGMENT POSITIONS
-------------------------------------------------------------------------------------
if ComponentGetValue2(controlscomp, "mButtonDownThrow") then 
    t1.vx = 0; t1.vy = -grav; t2.vx = 0; t2.vy = -grav;
    if ComponentGetValue2(controlscomp, "mButtonDownLeft") then t1.vx = -60; t2.vx = -60 end
    if ComponentGetValue2(controlscomp, "mButtonDownRight") then t1.vx = 60; t2.vx = 60 end
    if ComponentGetValue2(controlscomp, "mButtonDownUp") then t1.vy = -60; t2.vy = -60 end
    if ComponentGetValue2(controlscomp, "mButtonDownDown") then t1.vy = 60; t2.vy = 60 end
end


if dist ~= 0 and (not find_stupid_nans({t1.vx,t1.vy,t2.vx,t2.vy})) then
    ComponentSetValue2(t1.cdc, "mVelocity", t1.vx, t1.vy)
    ComponentSetValue2(t2.cdc, "mVelocity", t2.vx, t2.vy)
else
    ComponentSetValue2(t1.cdc, "mVelocity", 0, 70.620690902)
    ComponentSetValue2(t2.cdc, "mVelocity", 0, -70.620690902)
    GamePrint("reset")
end
EntitySetTransform(t1.i, t1.x, t1.y, rot)
EntitySetTransform(t2.i, t2.x, t2.y, rot)
EntitySetTransform(player, mid_x, mid_y, rot, sx)
SetValueNumber("steptime", step_cooldown + 1)
SetValueNumber("turntime", turn_cooldown + 1)

if (vmag >= 0) or (vmag < 0) then
    GameEntityPlaySoundLoop( player, "sound_whoosh", vmag*0.005 )
end




--EntitySetTransform(EntityGetWithTag("debug")[1], t1.x, t1.y)
--EntitySetTransform(EntityGetWithTag("debug")[2], t2.x, t2.y, rot)
if ComponentGetValue2(controlscomp, "mButtonDownInteract") then EntityKill(player) end

