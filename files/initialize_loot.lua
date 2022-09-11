local entity = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity)

local gold = EntityGetClosestWithTag(x, y, "gold_value")

if not gold then
    for i, comp in ipairs(EntityGetAllComponents(entity)) do
        local comp_type = ComponentGetTypeName(comp)
        if comp_type == "VariableStorageComponent" or comp_type == "LuaComponent" or comp_type == "SpriteParticleEmitterComponent" then
            EntityRemoveComponent(entity, comp)
        end
    end
else
    own_goldcomp = EntityGetFirstComponent(entity, "VariableStorageComponent", "gold_value")
    goldcomp = EntityGetFirstComponent(gold, "VariableStorageComponent", "gold_value")
    gold_value = ComponentGetValue2(goldcomp, "value_int")
    ComponentSetValue2(own_goldcomp, "value_int", gold_value)
    EntitySetName(entity, EntityGetName(gold))


    EntityAddComponent( entity, "UIInfoComponent", {
		_tags="enabled_in_world",
		name=EntityGetName(gold),
    })

    EntityKill(gold)
end