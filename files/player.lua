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
local targvel_x, targvel_y = nil, nil --the general direction in which we're trying to go, this gets defined later
local stability = GetValueNumber("stability", 0)
local stepped_this_frame = false
local step_time = GetValueNumber("steptime", 0)

local player = GetUpdatedEntityID()
local x, y, r, sx, sy = EntityGetTransform(player)
local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
local chardatacomp = EntityGetFirstComponent(player, "CharacterDataComponent")
local controlscomp = EntityGetFirstComponent(player, "ControlsComponent")

local grounded_legs = {}
local airborne_legs = {}


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
        local list = {i=child, x=cx, y=cy, vx=vx, vy=vy, cdc=cdc}
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
                local lengthcomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "total_length")
                local dircomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "direction")

                local state = ComponentGetValue2(state_comp, "value_int")
                local length = ComponentGetValue2(lengthcomp, "value_int")
                local dir = ComponentGetValue2(dircomp, "value_int")
                local foot_x, foot_y = ComponentGetValue2(footcomp_x, "value_float"), ComponentGetValue2(footcomp_y, "value_float")
                local targ_x, targ_y = ComponentGetValue2(targcomp_x, "value_float"), ComponentGetValue2(targcomp_y, "value_float")
                local comps = {state=state_comp,length=lengthcomp,foot_x=footcomp_x,foot_y=footcomp_y,targ_x=targcomp_x,targ_y=targcomp_y,direction=dircomp}
                local data = {id=leg,state=state,length=length,foot_x=foot_x,foot_y=foot_y,targ_x=targ_x,targ_y=targ_y,direction=dir,toes_x=foot_x,toes_y=foot_y,comps=comps}
                if state == 2 then
                    table.insert(grounded_legs, data)
                elseif state == 0 or state == 1 then
                    table.insert(airborne_legs, data)
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
local move_x = 0
local move_y = 0
local desired_rot = rot
local crouch = false
if ComponentGetValue2(controlscomp, "mButtonDownLeft") then move_x = move_x - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownRight") then move_x = move_x + 60 end
if ComponentGetValue2(controlscomp, "mButtonDownUp") then move_y = move_y - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownDown") then move_y = move_y + 60 end
move_y = move_y - grav
local vx, vy = normalize(move_x, move_y)
local vx2, vy2 = normalize(move_x-vel_x,move_y-vel_y)
local ground_too_close, ground_x, ground_y = RaytracePlatforms(mid_x, mid_y, mid_x, mid_y+12)

if ComponentGetValue2(controlscomp, "mButtonDownKick") then --Are we jumping?
    move_x, move_y = vx*60*2, vy*60*2
    desired_rot = VecToRads(0,0,vx,vy)+DegToRads(90)
elseif ((move_x/math.abs(move_x) ~= (vel_x/math.abs(vel_x))) and math.abs(vel_x-move_x) > 50 and move_x ~= 0) or dotProduct(rot_x,rot_y,vx,vy) <= 0 then --Are we turning around?
    --GamePrint("turning")
    if move_x ~= 0 then move_x = move_x/math.abs(move_x) end
    if ground_too_close then --are we on the ground?
        if ground_y-mid_y > 4 then move_y = (((ground_y-4)-mid_y)*5) - grav end
    else
        move_y = grav
    end
    desired_rot = VecToRads(0,0,vx,vy)+DegToRads(90)
elseif ground_too_close then --are we on the ground?
    if (move_y > 0) then --crouch
        move_x = move_x * 0.5
        move_y = 10
        desired_rot = sx
        crouch = true
    else --stand
        move_y = (((ground_y-10)-mid_y)*5) - grav
        desired_rot = clamp(move_x*0.03, -0.1, 0.1)
    end
else
    desired_rot = clamp(move_x*0.03, -0.1, 0.1)
end

local slide_x, slide_y = (vel_x-move_x)*div*2, (vel_y-move_y)*div*2
local drift = math.sqrt(slide_x^2 + slide_y^2)
local torque = clamp(rotDiff(rot, desired_rot)*0.1, -10, 10)

-------------------------------------------------------------------------------------
--LEGZ 
-------------------------------------------------------------------------------------
--legs that are touching ground:
for i, torso in ipairs({t1, t2}) do
    local alignments = {}
    local bestFoothold = 1
    local worstFoothold = 1
    local closest_CW = nil
    local closest_CCW = nil
    local x2, y2 = torso.x, torso.y
    
    --GET TARGET VELOCITY
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
    targvel_x = ((targvel_x or torso.targ_vx) + torso.targ_vx)/2
    targvel_y = ((targvel_y or torso.targ_vy) + torso.targ_vy)/2

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

        local length = leg.length
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
            if alignment > (alignments[closest_CW] or -1) then
                closest_CW = j
            end
        end
        if whichside <= 0 then--if closest in Counter-Clockwise direction
            if alignment > (alignments[closest_CCW] or -1) then
                closest_CCW = j
            end
        end
        --also update the overall best and worst footholds so far:
        if alignment > (alignments[bestFoothold] or -1) then 
            bestFoothold = j 
        elseif alignment < (alignments[worstFoothold] or -1) then 
            worstFoothold = j
        end
        table.insert(alignments, alignment or -1)

        --backup method in case we need it later:
        local toedist2 = Distance(x2, y2, leg.toes_x, leg.toes_y)
        x2, y2 = MoveCoordsAlongVector(leg.toes_x, leg.toes_y, x2, y2, math.max(Distance(torso.targ_x, torso.targ_y, leg.toes_x, leg.toes_y), toedist2))--getClosestPointOnLine(leg.toes_x, leg.toes_y, x2, y2, torso.targ_x, torso.targ_y)
        --if Distance(x3, y3, leg.toes_x, leg.toes_y) > toedist2 then
        --    x2, y2 = x3, y3
        --end
        
        --retract feet if overextended, or needed elsewhere
        if (Distance(leg.foot_x, leg.foot_y, socket_x, socket_y) > length+1) or (step_time > 10 and stability < 0 and #airborne_legs == 0 and (not stepped_this_frame)) then
            ComponentSetValue2(leg.comps.state, "value_int", 0)
            stepped_this_frame = true
            step_time = -1
        end
        --slide:
        if i == 2 then
            local foot_x2, foot_y2 = MoveCoordsAlongVector(socket_x, socket_y, leg.foot_x+slide_x, leg.foot_y+slide_y, length+10)
            local hit, hit_x, hit_y = RaytracePlatforms(socket_x, socket_y, foot_x2, foot_y2)
            local hitdist = Distance(socket_x, socket_y, hit_x, hit_y)
            local score1 = Distance(leg.foot_x, leg.foot_y, leg.foot_x+slide_x, leg.foot_y+slide_y)
            local score2 = Distance(hit_x, hit_y, leg.foot_x+slide_x, leg.foot_y+slide_y)
            if hit and hitdist >= Distance(socket_x, socket_y, leg.foot_x, leg.foot_y) and hitdist < length+1 and score2 < score1 then
                ComponentSetValue2(leg.comps.foot_x, "value_float", hit_x)
                ComponentSetValue2(leg.comps.foot_y, "value_float", hit_y)
            end
        end
        IK(leg.id)
    end
    
    local CW = grounded_legs[closest_CW]
    local CCW = grounded_legs[closest_CCW]
    if closest_CW and closest_CCW then
        local a1 = VecToRads(torso.x, torso.y, torso.force_x, torso.force_y)
        local a2 = VecToRads(torso.x, torso.y, CW.toes_x, CW.toes_y)
        local a3 = VecToRads(torso.x, torso.y, CCW.toes_x, CCW.toes_y)
        local diff1 = math.abs(rotDiff(a2,a1))
        local diff2 = math.abs(rotDiff(a1,a3))

        --if desired force is between foot angles:
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
    --if grounded_legs[bestFoothold] then
    --    local leg = grounded_legs[bestFoothold]
    --    local toedist = Distance(torso.x, torso.y, leg.toes_x, leg.toes_y)
    --    local fx, fy = MoveCoordsAlongVector(leg.toes_x-torso.x, leg.toes_y-torso.y, 0, 0, math.max(Distance(torso.targ_x, torso.targ_y, leg.toes_x, leg.toes_y), toedist))
    --    torso.vx = torso.vx + fx*mult
    --    torso.vy = torso.vy + fy*mult
    --end
    ::skip::
end



--CALCULATE STABILITY:
targvel_x, targvel_y = targvel_x or 0, targvel_y or -1
vel_x, vel_y = (t1.vx+t2.vx)/2, (t1.vy+t2.vy)/2
local targvel_mag = math.sqrt(targvel_x^2 + targvel_y^2)
local vmag = math.sqrt(vel_x^2 + vel_y^2)

local mid2_x, mid2_y = (mid_x+(vel_x*mult)), (mid_y+(vel_y*mult))

local stability = dotProduct(vel_x/vmag, vel_y/vmag, targvel_x/targvel_mag, targvel_y/targvel_mag)
if not (stability >= 0 or stability < 0) then stability = -1 end
SetValueNumber("stability", stability)

--legs that aren't touching ground:
for i,leg in ipairs(airborne_legs) do
    local socket = EntityGetParent(leg.id)
    local socket_x, socket_y = EntityGetTransform(socket)
    EntitySetTransform(leg.id, socket_x, socket_y)

    --FIND WHERE SUPPORT IS NEEDED MOST IN ORDER TO CREATE DESIRED FORCE:
    --make this overshoot somehow
    local x1, y1 = MoveCoordsAlongVector(mid2_x, mid2_y, mid2_x-targvel_x, mid2_y-targvel_y, leg.length)
    local x2, y2 = MoveCoordsAlongVector(socket_x, socket_y, x1, y1, leg.length)
    x2, y2 = rotatePoint(x2, y2, socket_x, socket_y, math.random(-10,10)*0.1)
    local did_hit, hit_x, hit_y = RaytracePlatforms(mid_x, mid_y, x2, y2)
    if not did_hit then
        x2, y2 = rotatePoint(x2, y2, socket_x, socket_y, math.random(-10,10)*0.1*DegToRads(90))
        did_hit, hit_x, hit_y = RaytracePlatforms(mid_x, mid_y, x2, y2)
    end
    if did_hit and not stepped_this_frame then
        ComponentSetValue2(leg.comps.state, "value_int", 2)
        ComponentSetValue2(leg.comps.foot_x, "value_float", hit_x)
        ComponentSetValue2(leg.comps.foot_y, "value_float", hit_y)
        stepped_this_frame = true
    else
        local foot_x2, foot_y2 = rotatePoint(socket_x, socket_y-5, socket_x, socket_y, rot+(2.6*sx))
        ComponentSetValue2(leg.comps.foot_x, "value_float", ((leg.foot_x*3 + foot_x2)*0.25)+(vel_x*div))
        ComponentSetValue2(leg.comps.foot_y, "value_float", ((leg.foot_y*3 + foot_y2)*0.25)+(vel_y*div))
    end
    ComponentSetValue2(leg.comps.direction, "value_int", -sx)
    IK(leg.id)
end

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
    if ComponentGetValue2(controlscomp, "mButtonDownLeft") then t1.vx = -40; t2.vx = -40 end
    if ComponentGetValue2(controlscomp, "mButtonDownRight") then t1.vx = 40; t2.vx = 40 end
    if ComponentGetValue2(controlscomp, "mButtonDownUp") then t1.vy = -40; t2.vy = -40 end
    if ComponentGetValue2(controlscomp, "mButtonDownDown") then t1.vy = 40; t2.vy = 40 end
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
EntitySetTransform(player, mid_x, mid_y, rot)
SetValueNumber("steptime", step_time + 1)

if (vmag >= 0) or (vmag < 0) then
    GameEntityPlaySoundLoop( player, "sound_whoosh", vmag*0.005 )
end


--dbg = EntityGetWithTag("debug")
--EntitySetTransform(dbg[1], t1.x, t1.y)
--EntitySetTransform(dbg[2], t2.x, t2.y, rot)
if ComponentGetValue2(controlscomp, "mButtonDownInteract") then EntityKill(player) end

