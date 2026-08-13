---@meta

---@class World
World = {}

---@param ... unknown
---@return any
function World.update(...) end

---@param ... unknown
---@return any
function World.update_animations(...) end

---@param ... unknown
---@return any
function World.update_animations_with_callback(...) end

---@param ... unknown
---@return any
function World.update_scene(...) end

---@param ... unknown
---@return any
function World.update_scene_with_callback(...) end

---@param ... unknown
---@return any
function World.update_timer(...) end

---@param ... unknown
---@return any
function World.delta_time(...) end

---@param ... unknown
---@return any
function World.render_time(...) end

---@param ... unknown
---@return any
function World.render_delta_time(...) end

---@param ... unknown
---@return any
function World.spawn_unit(...) end

---@param ... unknown
---@return any
function World.spawn_unit_ex(...) end

---@param ... unknown
---@return any
function World.spawn_unit_table(...) end

---@param ... unknown
---@return any
function World.destroy_unit(...) end

---@param ... unknown
---@return any
function World.num_units(...) end

---@param ... unknown
---@return any
function World.units(...) end

---@param ... unknown
---@return any
function World.units_by_resource(...) end

---@param ... unknown
---@return any
function World.unit_by_name(...) end

---@param ... unknown
---@return any
function World.link_unit(...) end

---@param ... unknown
---@return any
function World.unlink_unit(...) end

---@param ... unknown
---@return any
function World.update_unit(...) end

---@param ... unknown
---@return any
function World.update_unit_and_children(...) end

---@param ... unknown
---@return any
function World.update_lod_levels(...) end

---@param ... unknown
---@return any
function World.get_dirty_units(...) end

---@param ... unknown
---@return any
function World.get_dirty_units_position(...) end

---@param ... unknown
---@return any
function World.set_out_of_bounds_aabb(...) end

---@param ... unknown
---@return any
function World.time(...) end

World.LINK_MODE_NONE = "0"

World.LINK_MODE_NODE_NAME = "1"

World.LINK_MODE_MAP_NAME = "2"

---@param ... unknown
---@return any
function World.physics_world(...) end

---@param ... unknown
---@return any
function World.create_line_object(...) end

---@param ... unknown
---@return any
function World.destroy_line_object(...) end

---@param ... unknown
---@return any
function World.create_spline_object_drawer(...) end

---@param ... unknown
---@return any
function World.destroy_spline_object_drawer(...) end

---@param ... unknown
---@return any
function World.create_particles(...) end

---@param ... unknown
---@return any
function World.destroy_particles(...) end

---@param ... unknown
---@return any
function World.create_particle_group(...) end

---@param ... unknown
---@return any
function World.set_particles_group(...) end

---@param ... unknown
---@return any
function World.destroy_particle_group(...) end

---@param ... unknown
---@return any
function World.stop_spawning_particles(...) end

---@param ... unknown
---@return any
function World.are_particles_playing(...) end

---@param ... unknown
---@return any
function World.move_particles(...) end

---@param ... unknown
---@return any
function World.link_particles(...) end

---@param ... unknown
---@return any
function World.find_particles_variable(...) end

---@param ... unknown
---@return any
function World.set_particles_variable(...) end

---@param ... unknown
---@return any
function World.set_particles_emit_rate_multiplier(...) end

---@param ... unknown
---@return any
function World.set_particles_life_time(...) end

---@param ... unknown
---@return any
function World.set_particles_use_custom_fov(...) end

---@param ... unknown
---@return any
function World.set_particles_surface_effect(...) end

---@param ... unknown
---@return any
function World.has_particles_material(...) end

---@param ... unknown
---@return any
function World.set_particles_material_scalar(...) end

---@param ... unknown
---@return any
function World.set_particles_material_vector2(...) end

---@param ... unknown
---@return any
function World.set_particles_material_vector3(...) end

---@param ... unknown
---@return any
function World.set_particles_material_vector4(...) end

---@param ... unknown
---@return any
function World.set_particles_material_matrix4x4(...) end

---@param ... unknown
---@return any
function World.set_particles_material_color(...) end

---@param ... unknown
---@return any
function World.set_particles_light_intensity(...) end

---@param ... unknown
---@return any
function World.set_particles_light_intensity_exponent(...) end

---@param ... unknown
---@return any
function World.create_gui(...) end

---@param ... unknown
---@return any
function World.create_screen_gui(...) end

---@param ... unknown
---@return any
function World.create_world_gui(...) end

---@param ... unknown
---@return any
function World.destroy_gui(...) end

---@param ... unknown
---@return any
function World.create_video_player(...) end

---@param ... unknown
---@return any
function World.destroy_video_player(...) end

---@param ... unknown
---@return any
function World.add_video_player(...) end

---@param ... unknown
---@return any
function World.remove_video_player(...) end

---@param ... unknown
---@return any
function World.set_flow_callback_object(...) end

---@param ... unknown
---@return any
function World.set_flow_callback_table(...) end

---@param ... unknown
---@return any
function World.spawn_level(...) end

---@param ... unknown
---@return any
function World.spawn_level_time_sliced(...) end

---@param ... unknown
---@return any
function World.destroy_level(...) end

---@param ... unknown
---@return any
function World.num_levels(...) end

---@param ... unknown
---@return any
function World.levels(...) end

---@param ... unknown
---@return any
function World.level_by_name(...) end

---@param ... unknown
---@return any
function World.set_ddgi_updates_enabled(...) end

---@param ... unknown
---@return any
function World.storyteller(...) end

---@param ... unknown
---@return any
function World.clear_permanent_lines(...) end

---@param ... unknown
---@return any
function World.debug_camera_pose(...) end

---@param ... unknown
---@return any
function World.create_shading_environment(...) end

---@param ... unknown
---@return any
function World.create_theme_shading_environment(...) end

---@param ... unknown
---@return any
function World.destroy_shading_environment(...) end

---@param ... unknown
---@return any
function World.create_shading_environment_resource(...) end

---@param ... unknown
---@return any
function World.destroy_shading_environment_resource(...) end

---@param ... unknown
---@return any
function World.set_shading_environment(...) end

---@param ... unknown
---@return any
function World.create_theme(...) end

---@param ... unknown
---@return any
function World.destroy_theme(...) end

---@param ... unknown
---@return any
function World.scatter_system(...) end

---@param ... unknown
---@return any
function World.vector_field(...) end

---@param ... unknown
---@return any
function World.replay(...) end

---@param ... unknown
---@return any
function World.enable_chain_constraints(...) end

---@param ... unknown
---@return any
function World.enable_constraint_collisions(...) end

---@param ... unknown
---@return any
function World.__eq(...) end

---@param ... unknown
---@return any
function World.has_data(...) end

---@param ... unknown
---@return any
function World.get_data(...) end

World._name = "World"

---@param ... unknown
---@return any
function World.set_data(...) end

---@param ... unknown
---@return any
function World.update_out_of_bounds_checker(...) end

