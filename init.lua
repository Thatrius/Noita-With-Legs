---@diagnostic disable: trailing-space

function OnWorldPostUpdate()
	local entities = EntityGetWithTag("mortal")
	local entity = entities[math.random(#entities)]

	local explodecomp = EntityGetFirstComponent(entity, "ExplodeOnDamageComponent") 
	if explodecomp and (not EntityHasTag(entity, "explodey")) then
		local radius = ComponentObjectGetValue2(explodecomp, "config_explosion", "explosion_radius") or 0
		local makes_hole = ComponentObjectGetValue2(explodecomp, "config_explosion", "hole_enabled")
		if radius > 20 and makes_hole then
			ComponentObjectSetValue2(explodecomp, "config_explosion", "hole_enabled", false)
			EntityAddComponent(entity, "LuaComponent", {
				script_source_file="mods/more_physic/files/explode_init.lua",
				execute_every_n_frame="-1",
				execute_on_removed="1",
			})
			EntityAddTag(entity, "explodey")
			--GamePrint("adding much physic to " .. (EntityGetName(entity) or EntityGetFilename(entity)))
		end
	end
end

function OnPlayerSpawned(player)
	if not GameHasFlagRun( "more_physic_started" ) then
		local x, y = EntityGetTransform(player)
		--EntityLoad( "data/entities/animals/flying_snek.xml", x-10, y ) 

		lst = {"blood","radioactive_liquid","plasma_fading_green","spark_white_bright"}
		for i=1,4 do
			local dbg = EntityCreateNew()
			EntityAddTag(dbg, "debug")
			local particles = EntityAddComponent( dbg, "ParticleEmitterComponent", {
				_tags="",
				_enabled="1",
				emitted_material_name=lst[i],
				emission_interval_max_frames="0",
				emission_interval_min_frames="0",
				lifetime_min="0.1",
				lifetime_max="0.1",
				fade_based_on_lifetime="1",
				emit_real_particles="0",
				create_real_particles="0",
				emit_cosmetic_particles="1",
				cosmetic_force_create="1",
				render_on_grid="1",
				draw_as_long="0",
				render_back="0",
				friction="1",
				airflow_force="2",
				airflow_time="1",
				airflow_scale="0.1",
				b2_force="0.6",
				x_pos_offset_max="0",
				x_pos_offset_min="0",
				y_pos_offset_max="0",
				y_pos_offset_min="0",
				x_vel_max="0",
				x_vel_min="-30",
				y_vel_max="0",
				y_vel_min="0",
				})
			ComponentSetValue2(particles, "gravity", 0, -60)
			ComponentSetValue2(particles, "count_min", 10)
			ComponentSetValue2(particles, "count_max", 10)
		end
		local dbg = EntityCreateNew()
		EntityAddTag(dbg, "dbg_effect")
		local particles = EntityAddComponent( dbg, "ParticleEmitterComponent", {
			_tags="",
			_enabled="1",
			emitted_material_name=lst[i],
			emission_interval_max_frames="0",
			emission_interval_min_frames="0",
			lifetime_min="10",
			lifetime_max="30",
			fade_based_on_lifetime="1",
			emit_real_particles="0",
			create_real_particles="0",
			emit_cosmetic_particles="1",
			cosmetic_force_create="1",
			render_on_grid="1",
			draw_as_long="0",
			render_back="0",
			friction="1",
			airflow_force="2",
			airflow_time="1",
			airflow_scale="0.1",
			b2_force="0.6",
			x_pos_offset_max="0",
			x_pos_offset_min="0",
			y_pos_offset_max="0",
			y_pos_offset_min="0",
			x_vel_max="0",
			x_vel_min="-30",
			y_vel_max="0",
			y_vel_min="0",
			})
		ComponentSetValue2(particles, "gravity", 0, -60)
		ComponentSetValue2(particles, "count_min", 10)
		ComponentSetValue2(particles, "count_max", 10)
		--local torso1 = EntityLoad("data/entities/torso.xml", x+0.01, y-100)
		--local torso2 = EntityLoad("data/entities/torso.xml", x, y-112)
		--EntitySetName(torso1, "torso1")
		--EntitySetName(torso2, "torso2")
		--EntityAddChild(player, torso1)
		--EntityAddChild(player, torso2)
		--local leg1 = EntityLoad("mods/more_physic/files/leg/ik_leg.xml")
		--local leg2 = EntityLoad("mods/more_physic/files/leg/ik_leg.xml")
		--EntityAddChild(player, leg1)
		--EntityAddChild(player, leg2)
		GameAddFlagRun("more_physic_started")

	end
end

ModMaterialsFileAdd( "mods/more_physic/files/material_appends.xml" ) 


dofile_once("data/scripts/gun/gun_actions.lua")
local nxml = dofile_once("mods/more_physic/lib/nxml.lua")
for i, projectile in ipairs(actions) do
	if projectile.related_projectiles then
		local filename = projectile.related_projectiles[1]
		local filename2 = (projectile.related_projectiles[1]):gsub("/deck", "")
		local name = (((projectile.related_projectiles[1]):gsub("data/entities/projectiles/", "")):gsub(".xml", "")):gsub("deck/", "")
		local variants = {filename, filename2}
		for j, file in ipairs(variants) do
			local projectile = ModTextFileGetContent(file)
			if projectile then
				local Entity = (nxml.parse(projectile))
				local Base = Entity:first_of("Base")
				local ProjectileComponent = Entity:first_of("ProjectileComponent")
				local ExplosionComponent = Entity:first_of("ExplosionComponent")
				local ExplodeOnDamageComponent = Entity:first_of("ExplodeOnDamageComponent")
				

				local default_hole = 0
				local default_damage = 0
				if Base then
					if Base.attr then
						if Base.attr.file == "data/entities/base_projectile_physics.xml" then
							default_hole = 1
							default_damage = 2
						end
					end
					if (not ProjectileComponent) then
						ProjectileComponent = Base:first_of("ProjectileComponent")
					end
				end

				local explodes = false
				for k, component in ipairs(({ProjectileComponent, ExplosionComponent, ExplodeOnDamageComponent})) do
					if component then
						local config = component:first_of("config_explosion")
						if config then
							if config.attr then
								local hole = tonumber(config.attr.hole_enabled) or default_hole
								local damage = tonumber(config.attr.damage) or default_damage
								--print(component.name or "no name")
								--print("destroys terrain: " .. tostring(hole))
								--print("power: " .. tostring(damage))
								if hole == 1 and damage > 0 then
									config.attr.hole_enabled = "0"
									config.attr.max_durability_to_destroy = "1"
									explodes = true
								end
							end
						end
					end
				end

				if explodes then
					Entity.attr = Entity.attr or {}
					Entity.attr._tags = (Entity.attr._tags or "") .. ",explodey"
					Entity:add_child(nxml.new_element("LuaComponent", {script_source_file="mods/more_physic/files/explode_init.lua",execute_every_n_frame="-1",execute_on_removed="1"}))
					--print("adding earth-shattering properties to " .. name .. "(" .. tostring(j) .. ")")
					local xml = nxml.tostring(Entity)
					--print(xml)
					ModTextFileSetContent(file, xml)
				end
			end
		end
	end
end