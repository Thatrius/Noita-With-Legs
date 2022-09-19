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
                local targcomp_x = EntityGetFirstComponent(leg, "VariableStorageComponent", "target_x")
                local targcomp_y = EntityGetFirstComponent(leg, "VariableStorageComponent", "target_y")
                local lengthcomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "total_length")
                local dircomp = EntityGetFirstComponent(leg, "VariableStorageComponent", "direction")

                local state = ComponentGetValue2(state_comp, "value_int")
                local length = ComponentGetValue2(lengthcomp, "value_int")
                local dir = ComponentGetValue2(dircomp, "value_int")
                local foot_x, foot_y = ComponentGetValue2(targcomp_x, "value_float"), ComponentGetValue2(targcomp_y, "value_float")
                local comps = {state=state_comp,length=lengthcomp,foot_x=targcomp_x,foot_y=targcomp_y,direction=dircomp}
                local data = {id=leg,state=state,length=length,foot_x=foot_x,foot_y=foot_y,direction=dir,toes_x=foot_x,toes_y=foot_y,comps=comps}
                if state == 1 then
                    table.insert(grounded_legs, data)
                elseif state == 0 then
                    table.insert(airborne_legs, data)
                end
            end
        end
    end
end
local mid_x, mid_y = (t1.x+t2.x)/2, (t1.y+t2.y)/2
local rot = VecToRads(t1.x, t1.y, t2.x, t2.y) + (math.pi/2)

--CONTROLS
local move_x = 0
local move_y = 0
if ComponentGetValue2(controlscomp, "mButtonDownLeft") then move_x = move_x - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownRight") then move_x = move_x + 60 end
if ComponentGetValue2(controlscomp, "mButtonDownUp") then move_y = move_y - 60 end
if ComponentGetValue2(controlscomp, "mButtonDownDown") then move_y = move_y + 60 end
move_y = move_y - grav

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

    --GET TARGET VELOCITY
    --how do we want the torso to be rotated:
    local rot_mult = mult
    local desired_rot = clamp(move_x*0.03, -0.1, 0.1)
    local torque = clamp(rotDiff(rot, desired_rot), -0.1, 0.1)
    torso.rotate_x, torso.rotate_y = rotatePoint(torso.x, torso.y, mid_x, mid_y, torque)
    torso.rotate_x, torso.rotate_y = (torso.rotate_x-torso.x)*rot_mult, (torso.rotate_y-torso.y)*rot_mult

    --add it all together
    torso.targ_vx = torso.rotate_x + move_x
    torso.targ_vy = torso.rotate_y + move_y
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
        local toedist = Distance(torso.x, torso.y, foot_x, foot_y)
        
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


        if (Distance(leg.foot_x, leg.foot_y, socket_x, socket_y) > length+2) or (step_time > 30 and stability < 0 and #airborne_legs == 0 and (not stepped_this_frame)) then
            ComponentSetValue2(leg.comps.state, "value_int", 0)
            stepped_this_frame = true
            step_time = -1
        end
        IK(leg.id)
    end
    
    if closest_CW and closest_CCW then
        local CW = grounded_legs[closest_CW]
        local CCW = grounded_legs[closest_CCW]

        local a1 = VecToRads(torso.x, torso.y, torso.force_x, torso.force_y)
        local a2 = VecToRads(torso.x, torso.y, CW.toes_x, CW.toes_y)
        local a3 = VecToRads(torso.x, torso.y, CCW.toes_x, CCW.toes_y)
        local diff1 = math.abs(rotDiff(a2,a1))
        local diff2 = math.abs(rotDiff(a1,a3))

        --GamePrint(diff1 + diff2)
        --if desired force is between foot angles:
        if diff1 + diff2 <= math.pi then
            GamePrint("1")
            torso.vx = torso.vx + torso.force_x*mult
            torso.vy = torso.vy + torso.force_y*mult
            goto skip
        end
    end
    if grounded_legs[bestFoothold] then
        GamePrint("0")
        local leg = grounded_legs[bestFoothold]
        local toedist = Distance(torso.x, torso.y, leg.toes_x, leg.toes_y)

        local fx, fy = MoveCoordsAlongVector(leg.toes_x-torso.x, leg.toes_y-torso.y, 0, 0, math.max(Distance(torso.targ_x, torso.targ_y, leg.toes_x, leg.toes_y), toedist))
        torso.vx = torso.vx + fx*mult
        torso.vy = torso.vy + fy*mult

        --local fx, fy = getClosestPointOnLine(0, 0, foot_x-torso.x, foot_y-torso.y, torso.targ_x-torso.x, torso.targ_y-torso.y)
        --if math.sqrt(fx^2 + fy^2) > footdist then
        --    torso.vx = torso.vx + fx*mult
        --    torso.vy = torso.vy + fy*mult
        --end
    end
    ::skip::
end



--CALCULATE STABILITY:
targvel_x, targvel_y = targvel_x or 0, targvel_y or -1
local vel_x, vel_y = (t1.vx+t2.vx)/2, (t1.vy+t2.vy)/2
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
    local x1, y1 = MoveCoordsAlongVector(mid2_x, mid2_y, mid2_x-targvel_x, mid2_y-targvel_y, leg.length)
    local x2, y2 = MoveCoordsAlongVector(socket_x, socket_y, x1, y1, leg.length)
    x2, y2 = rotatePoint(x2, y2, socket_x, socket_y, math.random(-10,10)*0.1)
    local did_hit, hit_x, hit_y = RaytracePlatforms(mid_x, mid_y, x2, y2)
    if not did_hit then
        x2, y2 = rotatePoint(x2, y2, socket_x, socket_y, math.random(-10,10)*0.1*DegToRads(90))
        did_hit, hit_x, hit_y = RaytracePlatforms(mid_x, mid_y, x2, y2)
    end
    if did_hit and not stepped_this_frame then
        ComponentSetValue2(leg.comps.state, "value_int", 1)
        ComponentSetValue2(leg.comps.foot_x, "value_float", hit_x)
        ComponentSetValue2(leg.comps.foot_y, "value_float", hit_y)
        stepped_this_frame = true
    else
        local foot_x2, foot_y2 = rotatePoint(socket_x, socket_y-5, socket_x, socket_y, rot+(2.6*sx))
        ComponentSetValue2(leg.comps.foot_x, "value_float", foot_x2)
        ComponentSetValue2(leg.comps.foot_y, "value_float", foot_y2)
    end
    ComponentSetValue2(leg.comps.direction, "value_int", -sx)
    IK(leg.id)
end

-------------------------------------------------------------------------------------
--KEEP TORSO TOGETHER
-------------------------------------------------------------------------------------
local dist = Distance(t1.x, t1.y, t2.x, t2.y)
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

if dist ~= 0 then
    ComponentSetValue2(t1.cdc, "mVelocity", t1.vx, t1.vy)
    ComponentSetValue2(t2.cdc, "mVelocity", t2.vx, t2.vy)
else
    ComponentSetValue2(t1.cdc, "mVelocity", 0, 70.620690902)
    ComponentSetValue2(t2.cdc, "mVelocity", 0, -70.620690902)
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
