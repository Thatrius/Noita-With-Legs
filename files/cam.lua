local entityId = GetUpdatedEntityID()
local x, y = EntityGetTransform(entityId)
local platformShooterPlayerComponent = EntityGetFirstComponentIncludingDisabled(entityId, "PlatformShooterPlayerComponent")
local x2, y2 = ComponentGetValue2(EntityGetFirstComponentIncludingDisabled(entityId, "ControlsComponent"),"mMousePosition")
local x3, y3 = ComponentGetValue2(EntityGetFirstComponentIncludingDisabled(entityId, "ControlsComponent"),"mMouseDelta")


local camX, CamY = GameGetCameraPos()
local entity_last_x, entity_last_y = GetValueNumber("px", 0), GetValueNumber("py", 0)
local entity_vel_x, entity_vel_y = x-entity_last_x, y-entity_last_y
vel_x = GetValueNumber("x", 0)
vel_y = GetValueNumber("y", 0)
aim_x = GetValueNumber("x1", 1)
aim_y = GetValueNumber("y1", 0)
speed = math.sqrt(x3^2 + y3^2)

aim_x, aim_y = aim_x + (x3), aim_y + (y3)
local d = math.sqrt(aim_x^2 + aim_y^2)
x3 = (aim_x/d)*20
y3 = (aim_y/d)*20
if d > 20 then
    aim_x = x3
    aim_y = y3
end
--GameCreateParticle("plasma_fading", x+(x3), (y-8)+(y3), 1, 0, 0, true, false)


smooth = 20
cam_weight = 50 --how long it takes for the camera to catch up to the player's speed

local dist = math.sqrt((x-x2)^2 + (y-y2)^2)
if dist > 150 then
    x2 = x + ((x2-x)/dist)*150
    y2 = y + ((y2-y)/dist)*150
end

if GameIsInventoryOpen() then
    x2 = x + GetValueNumber("last_mx", 0)
    y2 = y + GetValueNumber("last_my", 0)
else
    SetValueNumber("last_mx", x2-x)
    SetValueNumber("last_my", y2-y)
end

--define the midpoint as a line between the player and the mouse
local midpointX = ((camX+vel_x)*smooth + (x+x2)/2) / (smooth+1)
local midpointY = ((CamY+vel_y)*smooth + (y+y2)/2) / (smooth+1)
--set the desired vector to the midpoint
ComponentSetValue2(platformShooterPlayerComponent, "mDesiredCameraPos", midpointX, midpointY)


SetValueNumber("x", ((vel_x*cam_weight)+(entity_vel_x*1.1))/(cam_weight+1))
SetValueNumber("y", ((vel_y*cam_weight)+(entity_vel_y*1.1))/(cam_weight+1))
SetValueNumber("x1", aim_x)
SetValueNumber("y1", aim_y)
SetValueNumber("px", x)
SetValueNumber("py", y)