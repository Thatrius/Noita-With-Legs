
--if the entity is set up right, this function will arrange all children into an IK chain, 
--connecting the entity to its "targ_x", "targ_y" variables.


function IK(leg_entity)
    function distance(x1, y1, x2, y2)
        return math.sqrt(((x1-x2)^2) + ((y1-y2)^2))
    end--> distance
    function dotProduct(x1, y1, x2, y2)
        return (x1*x2) + (y1*y2)
    end
    ---------------------------------------------------------------------------------
    --General Setup
    ---------------------------------------------------------------------------------
    local ex, ey, er = EntityGetTransform(leg_entity)
    local targcomp_x = EntityGetFirstComponent(leg_entity, "VariableStorageComponent", "target_x")
    local targcomp_y = EntityGetFirstComponent(leg_entity, "VariableStorageComponent", "target_y")
    local directioncomp = EntityGetFirstComponent(leg_entity, "VariableStorageComponent", "direction")
    local target = {ComponentGetValue2(targcomp_x, "value_float"), ComponentGetValue2(targcomp_y, "value_float")}
    local direction = ComponentGetValue2(directioncomp, "value_int")
    local children = EntityGetAllChildren(leg_entity)
    local reach = math.sqrt((target[1]-ex)^2 + (target[2]-ey)^2)
    local vec_x, vec_y = (target[1]-ex)/reach, (target[2]-ey)/reach
    local invec_x, invec_y = -vec_y, vec_x
    --EntitySetTransform(leg_entity, ex, ey, er, -direction)

    ---------------------------------------------------------------------------------
    --Inverse Kinematics
    ---------------------------------------------------------------------------------
    local legments = {} --"leg" + "segments"... haha funny word combo do you get
    local joints = {}
    local knees = {}
    for i, child in ipairs(children) do
        if not EntityHasTag(child, "knee") then
            local x, y = EntityGetTransform(child)
            --make knees bend right way:
            local dist = math.sqrt(((x-ex)^2) + ((y-ey)^2))
            local vec2_x, vec2_y = (x-ex)/dist, (y-ey)/dist
            local dp = dotProduct(invec_x, invec_y, vec2_x, vec2_y)
            if dp/math.abs(dp) ~= direction then--are knees bend wrong way?
                local cpol_x, cpol_y = ex + (-vec_y*dp), ey + (vec_x*dp)
                local move_x, move_y = (cpol_x-x), (cpol_y-y)
                move_x, move_y = move_x+(invec_x*direction),move_y+(invec_y*direction)
                x, y = x + move_x, y + move_y
            end
            if x == 0 then x = 1 end --safeguards against stupid "nan"s by making sure the code can never divide 0/0. Lost a piece of my soul in the frustration brought about by trying to track down a bug cause by this. Why does 0/0 have to equal "nan" in lua anyways and not just 0 or something, it serves no purpose except to create frustration, this is utterly retarted
            if y == 0 then y = 1 end
            table.insert(legments, child)
            if i == 1 then table.insert(joints, {ex, ey}) else table.insert(joints, {x, y}) end
        else
            table.insert(knees, child)
        end
    end
    table.insert(joints, target)
    
    --First pass, starting at end of chain:
    for i = #joints, 1, -1 do
        if i == #joints then
            --move joint directly to the target coords:
            joints[i] = target
        elseif i ~= 1 then
            local lengthcomp = EntityGetFirstComponent(children[i], "VariableStorageComponent", "length")
            local length = ComponentGetValue2(lengthcomp, "value_int")
            --move joint within range of the previous one iterated:
            local jx, jy = joints[i][1], joints[i][2]
            local jx2, jy2 = joints[i+1][1], joints[i+1][2]
            if jx == jx2 or jy == jy2 then jx, jx = jx+1, jy+1 end --more nan-avoiding bullcrap
            local joint_dist = distance(jx, jy, jx2, jy2)
            local jx = jx2 + (((jx-jx2) / joint_dist) * length)
            local jy = jy2 + (((jy-jy2) / joint_dist) * length)
            joints[i] = {jx, jy}
        end
    end
    
    --Second pass, starting at beginning of chain:
    for i, joint in ipairs(joints) do
        if i ~= 1 then
            local lengthcomp = EntityGetFirstComponent(children[i-1], "VariableStorageComponent", "length")
            local length = ComponentGetValue2(lengthcomp, "value_int")
            --move joint within range of the previous one iterated:
            local jx, jy = joints[i][1], joints[i][2]
            local jx2, jy2 = joints[i-1][1], joints[i-1][2]
            if jx == jx2 or jy == jy2 then jx, jx = jx+1, jy+1 end
            local joint_dist = distance(jx, jy, jx2, jy2)
            local jx = jx2 + (((jx-jx2) / joint_dist) * length)
            local jy = jy2 + (((jy-jy2) / joint_dist) * length)
            joints[i] = {jx, jy}
        end
    end

    --make sure foot doesn't go past target cause it looks weird
    local targdist = distance(joints[#joints-1][1], joints[#joints-1][2], target[1], target[2])
    local lengthcomp = EntityGetFirstComponent(children[#joints-1], "VariableStorageComponent", "length")
    local length = ComponentGetValue2(lengthcomp, "value_int")
    if targdist < length then 
        joints[#joints-1][1] = target[1] + ((joints[#joints-1][1]-target[1])/targdist)*length
        joints[#joints-1][2] = target[2] + ((joints[#joints-1][2]-target[2])/targdist)*length
    end
    
    --Arrange all the legments to connect in between the joints:
    for i, legment in ipairs(legments) do
        local jx, jy = joints[i][1], joints[i][2]
        local jx2, jy2 = joints[i+1][1], joints[i+1][2]
        if jx == jx2 or jy == jy2 then jx, jx = jx+1, jy+1 end
        local vec_x, vec_y = jx2-jx, jy2-jy
        local targ_rot = math.atan2(vec_y, vec_x)
        local leg_x, leg_y, legrot, leg_sx, leg_sy = EntityGetTransform(legment)
        EntitySetTransform(legment, jx, jy, targ_rot, leg_sx, math.abs(leg_sy)*-direction)
        if knees[i] then EntitySetTransform(knees[i], jx2, jy2) end
    end
end