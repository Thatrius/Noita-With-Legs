local player = EntityGetWithTag("player_unit")[1]
local x, y = EntityGetTransform(player)
local chardatacomp = EntityGetFirstComponent(player, "CharacterDataComponent")
local invcomp = EntityGetFirstComponent(player, "Inventory2Component")
local velx, vely = ComponentGetValue2(chardatacomp, "mVelocity")
y = y - 7
local controls = EntityGetFirstComponentIncludingDisabled( player, "ControlsComponent" )
local holdcomp = EntityGetFirstComponentIncludingDisabled( player, "VariableStorageComponent", "held_object") or EntityAddComponent( player, "VariableStorageComponent", {_tags="held_object",value_int="0",})
local held_object = ComponentGetValue2(holdcomp, "value_int")
local picked_up_this_frame = false
local frames_since_pressed_e = GameGetFrameNum() - ComponentGetValue2(controls, "mButtonFrameInteract")

function clamp(value, min, max)
    local max = max or -min
    if value > max then 
        return max
    elseif value < min then
        return min
    else
        return value
    end
end

if held_object == 0 and frames_since_pressed_e == 0 then
    for i, object in ipairs(EntityGetInRadius(x, y, 20)) do
        local obj_x, obj_y = EntityGetTransform(object)
        local physcomp = EntityGetFirstComponent(object, "PhysicsBodyComponent") or EntityGetFirstComponent(object, "PhysicsBody2Component")
        local itemcomp = EntityGetFirstComponent(object, "ItemComponent")
        local goldcomp = EntityGetFirstComponent( object, "VariableStorageComponent", "gold_value")
        local name = GameTextGetTranslatedOrNot(EntityGetName(object))
        if name == "" then name = "object" end

        if goldcomp then
            local wallet = EntityGetFirstComponent(player, "WalletComponent")
            local goldcomp = EntityGetFirstComponent(object, "VariableStorageComponent", "gold_value")
            local gold_value = ComponentGetValue2(goldcomp, "value_int")
            local wallet_amount = ComponentGetValue2(wallet, "money")
            if gold_value > 500 then
            	EntityLoad("data/entities/particles/gold_pickup_huge.xml", obj_x, obj_y)
            elseif gold_value > 40 then
            	EntityLoad("data/entities/particles/gold_pickup_large.xml", obj_x, obj_y)
            else
            	EntityLoad("data/entities/particles/gold_pickup.xml", obj_x, obj_y)
            end
            local extra_money_count = GameGetGameEffectCount(player, "EXTRA_MONEY")

            if extra_money_count > 0 then
            	for i=1,extra_money_count do
            		gold_value = value * 2
            	end
            end
            ComponentSetValue2(wallet, "money", wallet_amount+gold_value)
            for i, comp in ipairs(EntityGetAllComponents(object)) do
                local comp_type = ComponentGetTypeName(comp)
                if comp_type == "VariableStorageComponent" or comp_type == "LuaComponent" or comp_type == "SpriteParticleEmitterComponent" then
                    EntityRemoveComponent(object, comp)
                end
            end
            GamePrint("Looted " .. gold_value .. " gold " .. " from " .. name)
        end

        if physcomp and not itemcomp then
            ComponentSetValue2(holdcomp, "value_int", object)
            if not EntityGetFirstComponent(object, "VariableStorageComponent", "prev_x") then
                local obj_velxcomp = EntityAddComponent(player, "VariableStorageComponent", {_tags="phys_prev_x",value_int="0",})
                local obj_velycomp = EntityAddComponent(player, "VariableStorageComponent", {_tags="phys_prev_y",value_int="0",})
                ComponentSetValue2(obj_velxcomp, "value_int", obj_x)
                ComponentSetValue2(obj_velycomp, "value_int", obj_y)
            end
            held_object = object
            picked_up_this_frame = true
            ComponentSetValue2(invcomp, "mActiveItem", -1)
            local arm = EntityGetWithTag("player_arm_r")[1]
            EntitySetComponentIsEnabled(arm, EntityGetFirstComponentIncludingDisabled(arm, "SpriteComponent", "with_item"), false)
            GamePrint("Picked up " .. name)
            break
        end
    end
end

local obj_x, obj_y = EntityGetTransform(held_object)
if obj_x then 
    local physcomp = EntityGetFirstComponent(held_object, "PhysicsBodyComponent") or EntityGetFirstComponent(held_object, "PhysicsBody2Component")
    local mass = ComponentGetValue2(physcomp, "mPixelCount")*0.1
    if mass == 0 then mass = 1 end
    local obj_velxcomp = EntityGetFirstComponent(player, "VariableStorageComponent", "phys_prev_x")
    local obj_velycomp = EntityGetFirstComponent(player, "VariableStorageComponent", "phys_prev_y")
    local obj_velx, obj_vely = obj_x-ComponentGetValue2(obj_velxcomp, "value_int"), obj_y-ComponentGetValue2(obj_velycomp, "value_int")
    local mx, my = ComponentGetValue2(controls, "mMousePosition")
    local mousedist = math.sqrt(((x-mx)^2) + ((y-my)^2))/mass
    local playerdist = math.sqrt(((x-obj_x)^2) + ((y-obj_y)^2))
    x, y = x+((mx-x)/mousedist), y+((my-y)/mousedist)
    local velx_diff = obj_velx - (velx/10)
    local vely_diff = obj_vely - (vely/10)
    local damp_x, damp_y = velx_diff*mass*-2, vely_diff*mass*-2 --force required to keep the held object going at the same velocity as the player
    local force_x, force_y = (x-obj_x)*mass*5, (y-obj_y)*mass*5
    local final_x, final_y = clamp(force_x+damp_x, -frames_since_pressed_e), clamp(force_y+damp_y, -frames_since_pressed_e)
    PhysicsApplyForce(held_object, final_x, final_y+mass) 
    ComponentSetValue2(chardatacomp, "mVelocity", velx - final_x, vely - (final_y-mass))
    if ComponentGetValue2(controls, "mButtonDownThrow") then
        local mag = math.sqrt(((obj_x-mx)^2)+((obj_y-my)^2))
        local throw_x = ((mx-obj_x)/mag)*200
        local throw_y = ((my-obj_y)/mag)*200
        PhysicsApplyForce(held_object, throw_x, throw_y)
        ComponentSetValue2(holdcomp, "value_int", 0)
        ComponentSetValue2(invcomp, "mActiveItem", 0)
        local arm = EntityGetWithTag("player_arm_r")[1]
        EntitySetComponentIsEnabled(arm, EntityGetFirstComponentIncludingDisabled(arm, "SpriteComponent", "with_item"), true)
    elseif (frames_since_pressed_e == 0 and not picked_up_this_frame) or playerdist > 20 or ComponentGetValue2(invcomp, "mActiveItem") ~= -1 then
        ComponentSetValue2(holdcomp, "value_int", 0) 
        if ComponentGetValue2(invcomp, "mActiveItem") == -1 then ComponentSetValue2(invcomp, "mActiveItem", 0) end
        local arm = EntityGetWithTag("player_arm_r")[1]
        EntitySetComponentIsEnabled(arm, EntityGetFirstComponentIncludingDisabled(arm, "SpriteComponent", "with_item"), true)
    end
    ComponentSetValue2(obj_velxcomp, "value_int", obj_x)
    ComponentSetValue2(obj_velycomp, "value_int", obj_y)
elseif held_object ~= 0 then
    ComponentSetValue2(holdcomp, "value_int", 0) 
    local arm = EntityGetWithTag("player_arm_r")[1]
    EntitySetComponentIsEnabled(arm, EntityGetFirstComponentIncludingDisabled(arm, "SpriteComponent", "with_item"), true)
end
