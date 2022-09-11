local explosive = GetUpdatedEntityID()
local x, y = EntityGetTransform(explosive)
local explosion = EntityLoad("data/entities/misc/explode.xml", x, y)

local projcomp = EntityGetFirstComponent(explosive, "ProjectileComponent") or EntityGetFirstComponent(explosive, "ExplodeOnDamageComponent") or EntityGetFirstComponent(explosive, "ExplosionComponent")
local radius = ComponentObjectGetValue2(projcomp, "config_explosion", "explosion_radius")

local powercomp = EntityGetFirstComponent(explosion, "VariableStorageComponent", "power")
ComponentSetValue2(powercomp, "value_int", radius-10)
local sizecomp = EntityGetFirstComponent(explosion, "VariableStorageComponent", "displacement")
ComponentSetValue2(sizecomp, "value_int", 0)
