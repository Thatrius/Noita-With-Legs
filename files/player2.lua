-----------------------------------------------------------------------------------------
--SETUP
-----------------------------------------------------------------------------------------
dofile_once("mods/more_physic/files/functions.lua")

local player = GetUpdatedEntityID()
local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
local chardatacomp = EntityGetFirstComponent(player, "CharacterDataComponent")
local controlscomp = EntityGetFirstComponent(player, "ControlsComponent")

local mx, my = ComponentGetValue2(controlscomp, "mMousePosition")
local x, y, rot, sx, sy = EntityGetTransform(player)
local pelvis_x, pelvis_y = x+(math.cos(rot+DegToRads(90))*3), y+(math.sin(rot+DegToRads(90))*3)
local chest_x, chest_y = x+(math.cos(rot+DegToRads(90))*-3), y+(math.sin(rot+DegToRads(90))*-3)
local vel_x, vel_y = PhysicsGetComponentVelocity(player, EntityGetFirstComponent(player, "PhysicsBodyComponent"))
local prev_vel_x, prev_vel_y = GetValueNumber("vel_x", 0), GetValueNumber("vel_y", 0)
local jumping = GetValueNumber("jump", 0)
local step_time = GetValueNumber("steptime", 0)
local time_since_RMB = GetValueNumber("RMB", 21)
local itemrot = GetValueNumber("itemrot", 0)
local accel_x, accel_y = vel_x-prev_vel_x, vel_y-prev_vel_y
local vel_rot = PhysicsGetComponentAngularVelocity(player, EntityGetFirstComponent(player, "PhysicsBodyComponent"))
local liquids = ComponentGetValue2(dmc, "mLiquidCount")

local prev_pelvis_x, prev_pelvis_y = GetValueNumber("pel_x", pelvis_x), GetValueNumber("pel_y", pelvis_y)
local prev_chest_x, prev_chest_y = GetValueNumber("chest_x", pelvis_x), GetValueNumber("chest_y", pelvis_y)
local pel_vel_x, pel_vel_y = pelvis_x-prev_pelvis_x, pelvis_y-prev_pelvis_y
local chest_vel_x, chest_vel_y = chest_x-prev_chest_x, chest_y-prev_chest_y

local desired_vel_x = 0
local desired_vel_y = -0.01
local still = true

if ComponentGetValue2(controlscomp, "mButtonDownUp") then
    desired_vel_y = desired_vel_y - 10
    still = false
elseif ComponentGetValue2(controlscomp, "mButtonDownDown") then
    desired_vel_y = desired_vel_y + 10
    still = false
end
if ComponentGetValue2(controlscomp, "mButtonDownLeft") then
    desired_vel_x = desired_vel_x - 10
    still = false
elseif ComponentGetValue2(controlscomp, "mButtonDownRight") then
    desired_vel_x = desired_vel_x + 10
    still = false
end
local fx, fy = x+(vel_x/10), y+(vel_y/10)

local height = 11--(10/(math.abs(desired_vel_x/20)+1))*1.2
local leg_length = 10.5
local ground_too_close, ground_x, ground_y = RaytracePlatforms(x, y, x, y+height+3)

local legs = {}
local anchors={}
local attached_one = false

--FIND ALL THE LEG:
local arm_side = 1
local is_first_arm = true
for i, child in pairs(EntityGetAllChildren( player )) do
    if EntityGetName(child) == "leg" then
        local state_comp = EntityGetFirstComponent(child, "VariableStorageComponent", "state")
        local targ_x_comp, targ_y_comp = EntityGetFirstComponent(child, "VariableStorageComponent", "target_x"), EntityGetFirstComponent(child, "VariableStorageComponent", "target_y")
        local targ_x, targ_y = ComponentGetValue2(targ_x_comp, "value_int"), ComponentGetValue2(targ_y_comp, "value_int")
        local state = ComponentGetValue2(state_comp, "value_int")
        local coords = {targ_x, targ_y}
        if state == 1 then table.insert(anchors, coords) end
        table.insert(legs, child)
    elseif EntityGetName(child) == "head" then
        local head_x, head_y, head_rot, head_sx, head_sy = EntityGetTransform(child)
        local prevcomp_x, prevcomp_y = EntityGetFirstComponent(child, "VariableStorageComponent", "prev_x"), EntityGetFirstComponent(child, "VariableStorageComponent", "prev_y")
        local head_prev_x, head_prev_y = ComponentGetValue2(prevcomp_x, "value_int"), ComponentGetValue2(prevcomp_y, "value_int")
        local head_targ_x, head_targ_y = x+(math.cos(rot-1.57)*3), y+(math.sin(rot-1.57)*3)
        local head_vel_x, head_vel_y = head_x-head_prev_x, head_y-head_prev_y
        --rotate head toward mouse:
        local head_targ_rot = VecToRads(x,y,mx,my)
        local head_dir = rotDiff(VecToRads(x,y,chest_x,chest_y),VecToRads(x,y,mx,my))
        if head_dir <= 0 then
            head_sy = -1
        elseif head_dir > 0 then
            head_sy = 1
        end
        --apply force+damping to head:
        local head_vel_x = (vel_x*0.15) + ((head_targ_x-head_x))
        local head_vel_y = (vel_y*0.15) + ((head_targ_y-head_y))
        local head_x, head_y = head_x+head_vel_x, head_y+head_vel_y
        local head_dist = Distance(head_targ_x, head_targ_y, head_x, head_y)
        if head_dist > 3 then
            head_x, head_y = MoveCoordsAlongVector(head_targ_x, head_targ_y, head_x+head_vel_x, head_y+head_vel_y,3)
        end
        --apply changes:
        EntitySetTransform(child, head_x, head_y, head_targ_rot, head_sx, head_sy)
        --reset previous positions:
        ComponentSetValue2(prevcomp_x, "value_int", head_x)
        ComponentSetValue2(prevcomp_y, "value_int", head_y)
    elseif EntityGetName(child) == "ik_arm" then
        local arm_x, arm_y = EntityGetTransform(child)
        local ik_comp = EntityGetFirstComponent(child, "IKLimbComponent")
        local state_comp = EntityGetFirstComponent(child, "VariableStorageComponent", "state")
        local targ_x_comp, targ_y_comp = EntityGetFirstComponent(child, "VariableStorageComponent", "target_x"), EntityGetFirstComponent(child, "VariableStorageComponent", "target_y")
        local targ_x, targ_y = ComponentGetValue2(targ_x_comp, "value_int"), ComponentGetValue2(targ_y_comp, "value_int")
        local hand_x, hand_y = ComponentGetValue2(ik_comp, "end_position")
        local state = ComponentGetValue2(state_comp, "value_int")
        local hotspot_component = EntityGetFirstComponent(player, "HotspotComponent", "right_arm_root")
        local held_item = ComponentGetValue2(EntityGetFirstComponent(player, "Inventory2Component"), "mActiveItem")
        if not is_first_arm then held_item = 0 end
        local transformcomp = EntityGetFirstComponent(held_item, "InheritTransformComponent")
        if transformcomp then EntityRemoveComponent(held_item, transformcomp) end

        local prevcomp_x, prevcomp_y = EntityGetFirstComponent(child, "VariableStorageComponent", "prev_x"), EntityGetFirstComponent(child, "VariableStorageComponent", "prev_y")
        local hand_prev_x, hand_prev_y = ComponentGetValue2(prevcomp_x, "value_int"), ComponentGetValue2(prevcomp_y, "value_int")
        local arm_vel_x, arm_vel_y = hand_x-hand_prev_x, hand_y-hand_prev_y

        --figure out if arm should be rendered in front or back:
        local ideal_z = 0.5
        if ((not is_first_arm) and sx == 1) or (is_first_arm and sx == -1) then 
            ideal_z = 0
        elseif ((not is_first_arm) and sx == -1) or (is_first_arm and sx == 1) then
            ideal_z = 1.2
        end
        for i, sprite in ipairs(EntityGetComponent(child, "SpriteComponent")) do
            local sprite_z = ComponentGetValue2(sprite, "z_index")
            if ideal_z ~= sprite_z then
                ComponentSetValue2(sprite, "z_index", ideal_z)
                EntityRefreshSprite(child, sprite)
            else
                break
            end
        end

        --rotate arm toward mouse:
        if (ComponentGetValue2(controlscomp, "mButtonDownLeftClick") or time_since_RMB < 20) and held_item ~= 0 then
            hand_targ_x, hand_targ_y = MoveCoordsAlongVector(arm_x, arm_y, mx, my, 7)
            itemrot = itemrot + (rotDiff(itemrot, VecToRads(x, y, mx, my))/2)
            if ComponentGetValue2(controlscomp, "mButtonDownLeftClick") then 
                SetValueNumber("RMB", 0)
            else
                SetValueNumber("RMB", time_since_RMB + 1)
            end
        else
            if held_item ~= 0 then
                hand_targ_x, hand_targ_y = rotatePoint(chest_x, chest_y, x, y, 1.57*sx)
                itemrot = itemrot + (rotDiff(itemrot, VecToRads(hand_x, hand_y, chest_x, chest_y) + DegToRads(90*sx))/2)
            else
                hand_targ_x, hand_targ_y = rotatePoint(pelvis_x+pel_vel_x, pelvis_y+pel_vel_y, chest_x+chest_vel_x, chest_y+chest_vel_y, 0.3*sx*arm_side)
                hand_targ_x, hand_targ_y = hand_targ_x+(vel_x/2), hand_targ_y+(vel_y/2)
                arm_side = -1
            end
            table.insert(legs, child)
            local coords = {targ_x, targ_y}
            if state == 1 then table.insert(anchors, coords) end
        end
        local hand_x, hand_y = (hand_targ_x+(hand_x*3))/4, (hand_targ_y+(hand_y*3))/4
        local hand_dist = Distance(arm_x, arm_y, hand_x, hand_y)
        if hand_dist > 7 then
            hand_x, hand_y = MoveCoordsAlongVector(arm_x, arm_y, hand_x, hand_y,7)
        end

        --apply changes:
        if held_item ~= 0 then
            local itemspritecomp = EntityGetFirstComponent(held_item, "SpriteComponent")
            local item_z = ComponentGetValue2(itemspritecomp, "z_index")
            local item_sprite = ComponentGetValue2(itemspritecomp, "image_file")
            ComponentSetValue2(EntityGetFirstComponent(player, "HotspotComponent", "shoot_pos"), "offset", math.abs((hand_x) - x), (hand_y) - y)
            EntitySetTransform(held_item, hand_x, hand_y, itemrot)
            if ideal_z ~= item_z then
                if ideal_z > 0.5 then ideal_z = 1.1 else ideal_z = 0.1 end
                ComponentSetValue2(itemspritecomp, "z_index", ideal_z)
                EntityRefreshSprite(held_item, itemspritecomp)
            end
        end
        ComponentSetValue2(ik_comp, "end_position", hand_x, hand_y)

        local shoulder_x, shoulder_y = chest_x, chest_y
        if ideal_z < 0.5 then
            shoulder_x, shoulder_y = MoveCoordsAlongVector(x, y, chest_x, chest_y, 2)
        end
        EntitySetTransform(child, shoulder_x+chest_vel_x, shoulder_y+chest_vel_y)
        --reset previous positions:
        ComponentSetValue2(prevcomp_x, "value_int", hand_x)
        ComponentSetValue2(prevcomp_y, "value_int", hand_y)
        is_first_arm = false
    end
end
local anchor_count = #anchors

--DO THA SWIM:
if liquids > 0 then
    PhysicsApplyForce(player, -vel_x*liquids*0.002, (-liquids/13) - (vel_y*liquids*0.002))
    PhysicsApplyTorque(player, -vel_rot*liquids*0.0001)
    if anchor_count < 2 then
        local swim_x, swim_y = desired_vel_x*liquids*0.01, desired_vel_y*liquids*0.01
        ApplyForceAtPoint(player, chest_x, chest_y, swim_x, swim_y, 0)
    end
end

--GET FORCE REQUIRED TO MAINTAIN DESIRED PLAYER VELOCITY:
local butt_x,butt_y = pelvis_x,pelvis_y
local head_x,head_y = chest_x,chest_y
local butt_to_head = Distance(butt_x, butt_y, head_x, head_y)

--where do we want the torso to be:
local butt2_x, butt2_y = butt_x,butt_y
local head2_x, head2_y = head_x,head_y
local butt_to_head = Distance(butt_x, butt_y, head_x, head_y)

--how do we want the torso to be rotated:
local desired_rot = clamp(desired_vel_x*0.03, -1, 1)
local torque = clamp(rotDiff(rot, desired_rot)-(vel_rot/10), -0.1, 0.1)
local head2_x, head2_y = rotatePoint(head2_x, head2_y, x, y, torque)
local butt2_x, butt2_y = rotatePoint(butt2_x, butt2_y, x, y, torque)

local bfx, bfy = butt2_x-butt_x, butt2_y-butt_y
local hfx, hfy = head2_x-head_x, head2_y-head_y
local butt2_x, butt2_y = butt_x+(bfx*70), butt_y+(bfy*70)
local head2_x, head2_y = head_x+(hfx*70), head_y+(hfy*70)
--if too close to ground, move up:
if ground_too_close then
    if desired_vel_y > 0 or (desired_vel_x/math.abs(desired_vel_x) ~= vel_x/math.abs(vel_x) and math.abs(desired_vel_x-vel_x) > 5) then
        butt2_y = butt2_y + (((ground_y-4)-y)*5)
        head2_y = head2_y + (((ground_y-4)-y)*5)
        desired_vel_x = 0
        desired_vel_y = 0
    else
        butt2_y = butt2_y + (((ground_y-height)-y)*5)
        head2_y = head2_y + (((ground_y-height)-y)*5)
    end
    local is_close, surf_x, surf_y = GetSurfaceNormal(ground_x, ground_y, 6, 10)
    local surf_x_out, surf_y_out = -surf_x, -surf_y
    local surf_x, surf_y = rotatePoint(surf_x, surf_y, 0, 0, DegToRads(90))
    --desired_vel_x, desired_vel_y = getClosestPointOnLine(0,0,surf_x,surf_y,desired_vel_x,desired_vel_y)
    if desired_vel_x ~= 0 then desired_vel_x, desired_vel_y = desired_vel_x+surf_x_out, desired_vel_y+surf_y_out end
elseif rotDiff(rot, desired_rot) > 1.57 then
    desired_vel_x = desired_vel_x/4
    desired_vel_y = desired_vel_y/4
end

--move torso toward wherever controls are pointed:
local butt2_x = butt2_x + (desired_vel_x*10)
local butt2_y = butt2_y + (desired_vel_y*10)
local head2_x = head2_x + (desired_vel_x*10)
local head2_y = head2_y + (desired_vel_y*10)


--apply damping by accounting for the current velocities, subtracting them:
local butt2_x = butt2_x - (pel_vel_x*70)
local butt2_y = butt2_y - (pel_vel_y*70)
local head2_x = head2_x - (chest_vel_x*70)
local head2_y = head2_y - (chest_vel_y*70)


--cap velocity:
if Distance(butt_x, butt_y, butt2_x,butt2_y) > 20 then
    butt2_x, butt2_y = MoveCoordsAlongVector(butt_x, butt_y, butt2_x, butt2_y, 20)
end
if Distance(head_x, head_y, head2_x, head2_y) > 20 then
    head2_x, head2_y = MoveCoordsAlongVector(head_x, head_y, head2_x, head2_y, 20)
end


local cx, cy = (butt2_x+head2_x)/2, (butt2_y+head2_y)/2
local fx, fy = cx-x, cy-y



local corrective_x = ((butt2_x-butt_x) + (head2_x-(head_x))) / 2
local corrective_y = ((butt2_y-butt_y) + (head2_y-(head_y))) / 2



--FIND WHERE SUPPORT IS NEEDED MOST IN ORDER TO CREATE SAID FORCE:
local x2, y2 = MoveCoordsAlongVector(x, y, (x+(vel_x*2))-corrective_x, (y+(vel_y*2))-corrective_y,leg_length)
local did_hit, hit_x, hit_y = RaytracePlatforms(x, y, x2, y2)
local raydist = Distance(x, y, hit_x, hit_y)

if hit_x == x then 
    did_hit = false 
    --GamePrint(math.floor(raydist))
end
if not did_hit then
    x2, y2 = MoveCoordsAlongVector(x, y, x2+math.random(-5,5), y2+math.random(-5,5), leg_length)
    did_hit, hit_x, hit_y = RaytracePlatforms(x, y, x2, y2)
end
if hit_x == x then 
    did_hit = false 
    --GamePrint(math.floor(raydist))
end

--CHECK IF PLAYER IS APTLY SUPPORTED ALREADY:
local lacking_support = true
local strongest_foothold = nil
local weakest_foothold = nil
local avg_x = nil
local avg_y = nil
for i, anchor in ipairs(anchors) do
    strongest_foothold = strongest_foothold or anchors[1]
    weakest_foothold = weakest_foothold or anchors[1]
    local ax, ay = anchor[1], anchor[2]
    avg_x, avg_y = avg_x or ax, avg_y or ay
    avg_x, avg_y = (avg_x+ax)/2, (avg_y+ay)/2

    local accuracy = math.abs(rotDiff(VecToRads(x,y, hit_x, hit_y), VecToRads(x, y, ax, ay)))
    anchors[i][3] = accuracy
    if accuracy < 0.3 or not did_hit then
        lacking_support = false
    end
    if i ~= 1 then
        if strongest_foothold[3] > accuracy then strongest_foothold = anchors[i] end
        if weakest_foothold[3] < accuracy then weakest_foothold = anchors[i] end
    else
        strongest_foothold = anchors[1]
        weakest_foothold = anchors[1]
        avg_x, avg_y = ax, ay
    end
end


--is the average foot position enough to balance?
if did_hit and anchor_count > 0 then
    local accuracy = math.abs(rotDiff(VecToRads(x,y, hit_x, hit_y), VecToRads(x, y, avg_x, avg_y)))
    if accuracy < 0.3 then
        lacking_support = false
    end
    if still then
        local cx2, cy2 = (avg_x-x)/10, (avg_y-y)/10
        butt2_x, butt2_y = butt2_x+cx2, butt2_y+cy2
        head2_x, head2_y = head2_x+cx2, head2_y+cy2
        --EntitySetTransform(EntityGetWithTag("debug")[3], cx+cx2, cy)
    end
else
    lacking_support = false
end

--ITERATE ALL THE LEG:
for i, leg in pairs(legs) do
    local socket_x, socket_y = chest_x, chest_y
    local limb_length = 8
    local is_arm = true
    if EntityGetName(leg) == "leg" then 
        EntitySetTransform(leg, pelvis_x, pelvis_y) 
        socket_x, socket_y = pelvis_x, pelvis_y
        limb_length = leg_length
        is_arm = false
    end
    local ik_comp = EntityGetFirstComponent(leg, "IKLimbComponent")
    local state_comp = EntityGetFirstComponent(leg, "VariableStorageComponent", "state")
    local targ_x_comp, targ_y_comp = EntityGetFirstComponent(leg, "VariableStorageComponent", "target_x"), EntityGetFirstComponent(leg, "VariableStorageComponent", "target_y")
    local time_comp = EntityGetFirstComponent(leg, "VariableStorageComponent", "time")
    local time = ComponentGetValue2(time_comp, "value_int")
    local end_x, end_y = ComponentGetValue2(ik_comp, "end_position")
    local end_x_prev, end_y_prev = ComponentGetValue2(ik_comp, "end_position")
    local state = ComponentGetValue2(state_comp, "value_int")
    local targ_x, targ_y = ComponentGetValue2(targ_x_comp, "value_int"), ComponentGetValue2(targ_y_comp, "value_int")


    --FIND SURFACES TO ATTACH TO:
    if state == 0 and not attached_one then
        if is_arm then
            local x3, y3 = MoveCoordsAlongVector(head_x, head_y, head2_x, head2_y,8)
            local did_hit2, hit_x2, hit_y2 = RaytracePlatforms(head_x, head_y, x3, y3)
            local raydist2 = Distance(head_x, head_y, hit_x2, hit_y2)
            if math.abs(head_x-hit_x2) < 0.1 then did_hit2 = false end
            if not did_hit2 then
                x3, y3 = MoveCoordsAlongVector(head_x, head_y, head2_x, head2_y,-8)
                did_hit2, hit_x2, hit_y2 = RaytracePlatforms(head_x, head_y, x3, y3)
            end
            if math.abs(head_x-hit_x2) < 0.1 then did_hit2 = false end
            if not did_hit2 then
                x3, y3 = MoveCoordsAlongVector(head_x, head_y, head_x+math.random(-5,5), head_y+math.random(-5,5),-8)
                did_hit2, hit_x2, hit_y2 = RaytracePlatforms(head_x, head_y, x3, y3)
            end
            if math.abs(head_x-hit_x2) < 0.1 then did_hit2 = false end
            if did_hit2 then
                ComponentSetValue2(targ_x_comp, "value_int", hit_x2)
                ComponentSetValue2(targ_y_comp, "value_int", hit_y2)
                targ_x = hit_x2
                targ_y = hit_y2
                GamePlaySound( "data/audio/Desktop/player.bank", "player/step_rock", hit_x2, hit_y2 )
                state = 1
                time = -1
            else
                state = 0
            end
        else
            if not did_hit then
                x2, y2 = MoveCoordsAlongVector(pelvis_x, pelvis_y, x2+math.random(-5,5), y2+math.random(-5,5), leg_length) 
                did_hit, hit_x, hit_y = RaytracePlatforms(pelvis_x, pelvis_y, x2, y2)
                if hit_x == x then did_hit = false end
            end

            if did_hit then
                attached_one = true
                lacking_support = false
                ComponentSetValue2(targ_x_comp, "value_int", hit_x)
                ComponentSetValue2(targ_y_comp, "value_int", hit_y)
                targ_x = hit_x
                targ_y = hit_y
                GamePlaySound( "data/audio/Desktop/player.bank", "player/step_rock", hit_x, hit_y )
                state = 1
                time = -1
                --GamePrint("leg " .. i .. " gained foothold")
            else
                end_x, end_y = rotatePoint(butt_x, butt_y-5, butt_x, butt_y, rot+(2.6*sx))
                --end_x, end_y = (targ_end_x+(end_x*2))/3, (targ_end_y+(end_y*2))/3
            end
        end
    end
    --MOVE PLAYER:
    if state == 1 then
        if step_time < 10 then
            targ_end_x, targ_end_y = rotatePoint(butt_x, butt_y-5, butt_x, butt_y, rot+(2.6*sx))
            end_x, end_y = (end_x+targ_x)/2, (end_y+targ_y)/2
        else
            end_x = targ_x
            end_y = targ_y
        end
        local force_diff = rotDiff(VecToRads(x, y, x-fx, y-fy), VecToRads(x, y, targ_x, targ_y))
        local foot_x, foot_y = rotatePoint(targ_x, targ_y, x, y, clamp(-force_diff, -0.3, 0.3))
        local butt_to_foot = Distance(butt_x, butt_y, foot_x, foot_y)
        local head_to_foot = Distance(head_x, head_y, foot_x, foot_y)

        --best way to assume desired position with only forces from the legs:
        local butt3_x, butt3_y = getClosestPointOnLine(foot_x, foot_y, butt_x, butt_y, butt2_x, butt2_y)
        local head3_x, head3_y = getClosestPointOnLine(foot_x, foot_y, head_x, head_y, head2_x, head2_y)
        local cx, cy = (butt3_x+head3_x)/2, (butt3_y+head3_y)/2
        local butt3_x, butt3_y = MoveCoordsAlongVector(cx,cy,butt3_x,butt3_y,butt_to_head/2)
        local head3_x, head3_y = MoveCoordsAlongVector(cx,cy,head3_x,head3_y,butt_to_head/2)



        local buttforce_x = (butt3_x-butt_x)
        local buttforce_y = (butt3_y-butt_y)
        local headforce_x = (head3_x-head_x)
        local headforce_y = (head3_y-head_y)

        local butt2_to_foot = Distance(butt3_x, butt3_y, foot_x, foot_y)
        local head2_to_foot = Distance(head3_x, head3_y, foot_x, foot_y)

        --does foot have traction?
        local is_norm, norm_x, norm_y = GetSurfaceNormal( targ_x, targ_y, 4, 6 )
        local norm_x, norm_y = -norm_x, -norm_y
        local surfnorm = VecToRads(0, 0, norm_x, norm_y)
        local buttnorm = VecToRads(0, 0, buttforce_x, buttforce_y)
        local headnorm = VecToRads(0, 0, headforce_x, headforce_y)

        local req = 2
        --*if is_arm then req = 2.5 end
        local butt_traction = 1
        local head_traction = 1
        local buttforce_alignment = math.abs(rotDiff(surfnorm, buttnorm))
        local headforce_alignment = math.abs(rotDiff(surfnorm, headnorm))

        if buttforce_alignment < req or Distance(foot_x, foot_y, butt3_x, butt3_y) > Distance(foot_x, foot_y, butt_x, butt_y) then
            ApplyForceAtPoint(player, butt_x, butt_y, buttforce_x*butt_traction, buttforce_y / anchor_count, 0)
        end
        if headforce_alignment < req or Distance(foot_x, foot_y, head3_x, head3_y) > Distance(foot_x, foot_y, head_x, head_y) then
            ApplyForceAtPoint(player, head_x, head_y, headforce_x*head_traction, headforce_y / anchor_count, 0)
        end
        --if is_arm then GamePrint(headforce_x .. ", " .. headforce_y) end

        --EntitySetTransform(EntityGetWithTag("debug")[i], foot_x, foot_y)
        if (not anchors[i]) or (not weakest_foothold) then
            anchors[i] = {1,2,3}
            weakest_foothold = {3,2,1}
        end
        if Distance(socket_x, socket_y, targ_x, targ_y) > limb_length+0.5 or (step_time > 10 and lacking_support and anchors[i][3] == weakest_foothold[3]) then
            if not did_hit then
                x2, y2 = MoveCoordsAlongVector(pelvis_x, pelvis_y, x2+math.random(-5,5), y2+math.random(-5,5), leg_length) 
                did_hit, hit_x, hit_y = RaytracePlatforms(pelvis_x, pelvis_y, x2, y2)
                if hit_x == pelvis_x then did_hit = false end
            end

            if did_hit and (not is_arm) then
                ComponentSetValue2(targ_x_comp, "value_int", hit_x)
                ComponentSetValue2(targ_y_comp, "value_int", hit_y)
                attached_one = true
                lacking_support = false
                GamePlaySound( "data/audio/Desktop/player.bank", "player/step_rock", hit_x, hit_y )
                --GamePrint("repositioning leg " .. i)
            else
                state = 0
                --PhysicsApplyTorque(player, clamp(-vel_rot, -1))
                --GamePrint("leg " .. i .. " lost foothold due to distance")
            end
            step_time = -1
        end
    end

    if (not is_arm) or state == 1 then ComponentSetValue2(ik_comp, "end_position", end_x, end_y) end
    ComponentSetValue2(state_comp, "value_int", state)
    ComponentSetValue2(time_comp, "value_int", time)
end
PhysicsApplyForce(player, 0, 3)
SetValueNumber("vel_x", vel_x)
SetValueNumber("vel_y", vel_y)
SetValueNumber("pel_x", pelvis_x)
SetValueNumber("pel_y", pelvis_y)
SetValueNumber("chest_x", chest_x)
SetValueNumber("chest_y", chest_y)
SetValueNumber("itemrot", itemrot)
SetValueNumber("jump", jumping)
SetValueNumber("steptime", step_time + 1)