dofile_once("mods/more_physic/files/functions.lua")

entity = GetUpdatedEntityID()
x, y, rot, sx, sy = EntityGetTransform(entity)

ctrl1_offset = {x=0, y=-3} --usually the head
ctrl2_offset = {x=0, y=3} --usually the butt
ctrl1.x, ctrl1.y = rotatePoint(ctrl1_offset.x,ctrl1_offset.y,rot)
ctrl2.x, ctrl2.y = rotatePoint(ctrl2_offset.x,ctrl2_offset.y,rot)

targ_vel = {x=0, y=0}

--calculate desired position:

--dampen current movements
damp_mult = 1
ctrl1_damp = {-ctrl1_vel.x*damp_mult, -ctrl1_vel.y*damp_mult}
ctrl2_damp = {-ctrl2_vel.x*damp_mult, -ctrl2_vel.y*damp_mult}

--rotate torso away from gravity
rotate_mult = 1
targ_angle = VecToRads(0, 0, 0, 10)

--push a distance away from gravity
--move toward controls

ctrl1.targ_x = ctrl1_damp.x + ctrl1_rotate.x + ctrl1_move.x
ctrl1.targ_y = ctrl1_damp.y + ctrl1_rotate.y + ctrl1_move.y
ctrl2.targ_x = ctrl2_damp.x + ctrl2_rotate.x + ctrl2_move.x
ctrl2.targ_y = ctrl2_damp.y + ctrl2_rotate.y + ctrl2_move.y
--clamp new movements



closestOnLeft = 100
closestOnRight = -100
bestFoothold = 100
worstFoothold = 0
--get foot data
for i, limb in ipairs(EntityGetAllChildren(entity)) do
    targ_x, targ_y = ComponentGetValue2(targ_x_comp, "value_int"), ComponentGetValue2(targ_y_comp, "value_int")
    grip = ComponentGetValue2(grip_comp, "value_string")
    if grip == "any" or grip == "push" then can_push = true end
    if grip == "any" or grip == "pull" then can_pull = true end
    
    footangle = VecToRads(targ_x, targ_y, x, y)
    diff = rotDiff(footangle, forceangle)

    --find closest 2 vectors to the force vector
    if diff > 0 and diff < closestOnLeft then--if closest on left
        closestOnLeft = diff
    elseif diff < 0 and diff > closestOnRight then--if closest on right
        closestOnRight = diff
    end
end
bestFoothold = math.min(bestFoothold, closestOnLeft, closestOnRight)



--move torso


--decide next foot position for worst-placed foot