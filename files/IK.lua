---------------------------------------------------------------------------------
--Define Functions
---------------------------------------------------------------------------------
function distance(x1,y1,x2,y2)
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

function approx_rolling_average(avg, target, n)
    avg = avg - avg / n;
    avg = avg + target / n;
    return avg
end
local smoothness_factor = 6

---------------------------------------------------------------------------------
--General Setup
---------------------------------------------------------------------------------
local entity = GetUpdatedEntityID()
local ex, ey = EntityGetTransform(entity)

local parent = EntityGetParent(entity)
local vel_x, vel_y = GameGetVelocityCompVelocity(parent)
local vel_mag = math.sqrt((vel_x)^2 + (vel_y)^2)
local futurex, futurey = ex+(vel_x*60), ey+(vel_y*60)

local lengthcomp = EntityGetFirstComponent(entity, "VariableStorageComponent", "length")
local target = {GetValueNumber("targ_x", ex), GetValueNumber("targ_y", ey)}
local length = ComponentGetValue2(lengthcomp, "value_int")
local time = GetValueNumber("time", 0)

---------------------------------------------------------------------------------
--Inverse Kinematics
---------------------------------------------------------------------------------
--organize the segments and joints into neat little tables:
local legments = {} --"leg" + "segments"... haha funny word combo do you get
local joints = {}
local knees = {}
for i, child in ipairs(EntityGetAllChildren(entity)) do
    if not EntityHasTag(child, "knee") then
        local x, y = EntityGetTransform(child)
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

--Arrange all the legments to connect in between the joints:
for i, legment in ipairs(legments) do
    local jx, jy = math.floor(joints[i][1]), math.floor(joints[i][2])
    local jx2, jy2 = joints[i+1][1], joints[i+1][2]
    if jx == jx2 or jy == jy2 then jx, jx = jx+1, jy+1 end
    local vec_x, vec_y = jx2-jx, jy2-jy
    local targ_rot = math.atan2(vec_y, vec_x)
    EntitySetTransform(legment, jx, jy, targ_rot)
    if knees[i] then EntitySetTransform(knees[i], jx2, jy2) end
end

---------------------------------------------------------------------------------
--AI:
---------------------------------------------------------------------------------
local total_leglength = length*#legments --combined length of all the segments in the leg
local length_tolerance = total_leglength--how far to let the end of the leg get before re-positioning it

--what the leg needs to point at:
local tx = GetValueNumber("tx", target[1])
local ty = GetValueNumber("ty", target[2])
local distance_to_target = distance(tx, ty, target[1], target[2])


--mix target position between ex, ey and tx, ty, based on time (picks up feet slightly when stepping):
local mult = smoothness_factor * (1+(2/3))
local inv = mult-time
local mix_x = (ex/mult)*time + (tx/mult)*inv
local mix_y = (ey/mult)*time + (ty/mult)*inv

--move feet toward target, unless already within range of it, in which case snap to the coordinates:
if distance_to_target > 10 then
    target[1] = approx_rolling_average(target[1], mix_x, smoothness_factor)
    target[2] = approx_rolling_average(target[2], mix_y, smoothness_factor)
elseif target[1] ~= tx and target[2] ~= ty then
    target[1] = tx
    target[2] = ty
    --[a stepping noise could go here]
end

--if the leg stretches too far, find a new target:
if (distance(tx, ty, ex, ey) > total_leglength and distance(tx, ty, futurex, futurey) > total_leglength) or distance(tx, ty, ex, ey) == 0 then 
    local surfaces_found = false
    --try to find nearby surfaces up to 3 times before resorting to stepping on air:
    for i=1,3 do
        potential_x, potential_y = (vel_x*60)+math.random(-total_leglength, total_leglength), (vel_y*60)+math.random(-total_leglength, total_leglength)
        mag = math.sqrt(((ex+potential_x)-ex)^2 + ((ey+potential_y)-ey)^2)
        potential_x, potential_y = ex + ((potential_x/mag)*total_leglength), ey + ((potential_y/mag)*total_leglength)
        did_hit, hit_x, hit_y = RaytracePlatforms(ex, ey, potential_x, potential_y)
        if did_hit then
            tx = hit_x
            ty = hit_y
            surfaces_found = true
            break
        end
    end
    --step on air:
    if not surfaces_found then
        tx = potential_x
        ty = potential_y
    end
    time = mult
end

--apply changes:
SetValueNumber("tx", tx)
SetValueNumber("ty", ty)
SetValueNumber("targ_x", target[1])
SetValueNumber("targ_y", target[2])
SetValueNumber("time", math.max(0,time-1))