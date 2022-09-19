function teleported()

	dofile_once("data/scripts/lib/utilities.lua")
	
	local entity_id = GetUpdatedEntityID()

	local physics_body_component = EntityGetFirstComponentIncludingDisabled(entity_id, "PhysicsBodyComponent")
	-- local physics_ai_component = EntityGetFirstComponentIncludingDisabled(entity_id, "PhysicsAIComponent")

	-- EntitySetComponentIsEnabled( entity_id, physics_ai_component, false )
	EntitySetComponentIsEnabled( entity_id, physics_body_component, false )

	EntityAddComponent(entity_id, "LuaComponent", {
		script_source_file="mods/more_physic/teleport_end.lua",
		execute_every_n_frame=1,
		remove_after_executed=1
	}) 

end