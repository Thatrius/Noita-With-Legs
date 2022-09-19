dofile_once("data/scripts/lib/utilities.lua")

local entity_id = GetUpdatedEntityID()

local physics_body_component = EntityGetFirstComponentIncludingDisabled(entity_id, "PhysicsBodyComponent")
-- local physics_ai_component = EntityGetFirstComponentIncludingDisabled(entity_id, "PhysicsAIComponent")

EntitySetComponentIsEnabled( entity_id, physics_body_component, true )
-- EntitySetComponentIsEnabled( entity_id, physics_ai_component, true )