function do_money_drop( amount_multiplier, trick_kill )

	local entity = GetUpdatedEntityID()
	local name = GameTextGetTranslatedOrNot(EntityGetName(entity))
    local x, y = EntityGetTransform(entity)
	local amount = 1
	local dmc = EntityGetFirstComponent(entity, "DamageModelComponent")
	local health = tonumber(ComponentGetValue2(dmc, "max_hp"))
    if health > 1.0 then
		amount = math.floor(health)
	end
	if GameHasFlagRun( "greed_curse" ) and ( GameHasFlagRun( "greed_curse_gone" ) == false ) then
		amount = amount * 3.0
	end
	amount = amount * amount_multiplier
	local money = 10 * amount
	
	local gold = EntityCreateNew(x, y)
	local goldcomp = EntityAddComponent( gold, "VariableStorageComponent", {_tags="gold_value",value_int="0",})
	ComponentSetValue2(goldcomp, "value_int", money)
	EntitySetName(gold, name)
	EntityAddTag(gold, "gold_value")
end

function death( damage_type_bit_field, damage_message, entity_thats_responsible, drop_items )
    do_money_drop(1, false)
    local entity = GetUpdatedEntityID()
	local effect = LoadGameEffectEntityTo(entity, "data/entities/misc/effect_ragdoll_entitify.xml")
end