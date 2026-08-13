---@meta

---@class Unit
Unit = {

    _name = "Unit",

    POSITION_CONSTRAINT = "0",

    AIM_CONSTRAINT = "1",

    PENDULUM_CONSTRAINT = "2",

    CHAIN_CONSTRAINT = "3",

    SPRING_CONSTRAINT = "4",

    ROTATION_CONSTRAINT = "5",

    IK_CONSTRAINT = "6",

    TWOBONEIK_CONSTRAINT = "7",
}

---@param ... unknown
---@return any
function Unit.is_a(...) end

---@param ... unknown
---@return any
function Unit.level_name(...) end

---@param ... unknown
---@return any
function Unit.level_id_string(...) end

---@param ... unknown
---@return any
function Unit.play_simple_animation(...) end

---@param ... unknown
---@return any
function Unit.stop_simple_animation(...) end

---@param ... unknown
---@return any
function Unit.set_simple_animation_speed(...) end

---@param ... unknown
---@return any
function Unit.is_playing_simple_animation(...) end

---@param ... unknown
---@return any
function Unit.simple_animation_length(...) end

---@param ... unknown
---@return any
function Unit.crossfade_animation(...) end

---@param ... unknown
---@return any
function Unit.crossfade_animation_set_time(...) end

---@param ... unknown
---@return any
function Unit.crossfade_animation_set_speed(...) end

---@param ... unknown
---@return any
function Unit.is_crossfading_animation(...) end

---@param ... unknown
---@return any
function Unit.has_animation_state_machine(...) end

---@param ... unknown
---@return any
function Unit.has_animation_event(...) end

---@param ... unknown
---@return any
function Unit.animation_event(...) end

---@param ... unknown
---@return any
function Unit.animation_event_by_index(...) end

---@param ... unknown
---@return any
function Unit.animation_event_count(...) end

---@param ... unknown
---@return any
function Unit.index_by_animation_event(...) end

Unit.ANIMATION_OVERRIDE_PERCENT_SYNC = "0"

---@param ... unknown
---@return any
function Unit.animation_find_variable(...) end

---@param ... unknown
---@return any
function Unit.animation_get_variable(...) end

---@param ... unknown
---@return any
function Unit.animation_get_variable_min_max(...) end

---@param ... unknown
---@return any
function Unit.animation_set_variable(...) end

---@param ... unknown
---@return any
function Unit.animation_variable_count(...) end

---@param ... unknown
---@return any
function Unit.animation_has_constraint_target(...) end

---@param ... unknown
---@return any
function Unit.animation_find_constraint_target(...) end

---@param ... unknown
---@return any
function Unit.animation_get_constraint_target(...) end

---@param ... unknown
---@return any
function Unit.animation_set_constraint_target(...) end

---@param ... unknown
---@return any
function Unit.animation_root_mode(...) end

---@param ... unknown
---@return any
function Unit.set_animation_root_mode(...) end

---@param ... unknown
---@return any
function Unit.animation_wanted_root_pose(...) end

---@param ... unknown
---@return any
function Unit.animation_bone_mode(...) end

---@param ... unknown
---@return any
function Unit.set_animation_bone_mode(...) end

---@param ... unknown
---@return any
function Unit.disable_animation_state_machine(...) end

---@param ... unknown
---@return any
function Unit.enable_animation_state_machine(...) end

---@param ... unknown
---@return any
function Unit.set_animation_state_machine(...) end

---@param ... unknown
---@return any
function Unit.set_animation_state_machine_blend_base_layer(...) end

---@param ... unknown
---@return any
function Unit.animation_get_layer_count(...) end

---@param ... unknown
---@return any
function Unit.is_valid(...) end

---@param ... unknown
---@return any
function Unit.animation_set_state(...) end

---@param ... unknown
---@return any
function Unit.animation_get_seeds(...) end

---@param ... unknown
---@return any
function Unit.animation_set_seeds(...) end

---@param ... unknown
---@return any
function Unit.animation_get_time(...) end

---@param ... unknown
---@return any
function Unit.animation_set_time(...) end

---@param ... unknown
---@return any
function Unit.animation_get_animation(...) end

---@param ... unknown
---@return any
function Unit.animation_set_animation(...) end

---@param ... unknown
---@return any
function Unit.set_animation_merge_options(...) end

---@param ... unknown
---@return any
function Unit.set_bones_lod(...) end

---@param ... unknown
---@return any
function Unit.animation_layer_info(...) end

---@param ... unknown
---@return any
function Unit.disable_physics(...) end

---@param ... unknown
---@return any
function Unit.enable_physics(...) end

---@param ... unknown
---@return any
function Unit.apply_initial_actor_velocities(...) end

---@param ... unknown
---@return any
function Unit.has_visibility_group(...) end

---@param ... unknown
---@return any
function Unit.get_visibility_group_mesh_count(...) end

---@param ... unknown
---@return any
function Unit.get_mesh_in_visibility_group(...) end

---@param ... unknown
---@return any
function Unit.set_visibility(...) end

---@param ... unknown
---@return any
function Unit.set_mesh_visibility(...) end

---@param ... unknown
---@return any
function Unit.set_mesh_ssm_visibility(...) end

---@param ... unknown
---@return any
function Unit.set_unit_objects_visibility(...) end

---@param ... unknown
---@return any
function Unit.set_unit_visibility(...) end

---@param ... unknown
---@return any
function Unit.take_visibility_snapshot(...) end

---@param ... unknown
---@return any
function Unit.restore_visibility_snapshot(...) end

---@param ... unknown
---@return any
function Unit.set_unit_culling(...) end

---@param ... unknown
---@return any
function Unit.set_texture_streamer_force_highest_mip(...) end

---@param ... unknown
---@return any
function Unit.force_stream_textures(...) end

---@param ... unknown
---@return any
function Unit.force_stream_meshes(...) end

---@param ... unknown
---@return any
function Unit.box(...) end

---@param ... unknown
---@return any
function Unit.flow_script_node_event(...) end

---@param ... unknown
---@return any
function Unit.flow_event(...) end

---@param ... unknown
---@return any
function Unit.trigger_flow_unit_spawned(...) end

---@param ... unknown
---@return any
function Unit.reload_flow(...) end

---@param ... unknown
---@return any
function Unit.query_material(...) end

---@param ... unknown
---@return any
function Unit.material_id(...) end

---@param ... unknown
---@return any
function Unit.set_property(...) end

---@param ... unknown
---@return any
function Unit.get_property(...) end

---@param ... unknown
---@return any
function Unit.set_scalar_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_vector2_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_vector3_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_vector4_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_matrix4x4_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_texture_for_material(...) end

---@param ... unknown
---@return any
function Unit.set_scalar_for_material_table(...) end

---@param ... unknown
---@return any
function Unit.set_vector2_for_material_table(...) end

---@param ... unknown
---@return any
function Unit.set_vector3_for_material_table(...) end

---@param ... unknown
---@return any
function Unit.set_vector4_for_material_table(...) end

---@param ... unknown
---@return any
function Unit.set_matrix4x4_for_material_table(...) end

---@param ... unknown
---@return any
function Unit.set_permutation_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_scalar_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_vector2_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_vector3_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_vector4_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_matrix4x4_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_color_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_texture_for_materials(...) end

---@param ... unknown
---@return any
function Unit.set_shader_pass_flag_for_meshes(...) end

---@param ... unknown
---@return any
function Unit.set_permutation_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_scalar_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_vector2_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_vector3_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_vector4_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_matrix4x4_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_color_for_materials_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_shader_pass_flag_for_meshes_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_flow_particle_effects_highlight_in_unit_and_childs(...) end

---@param ... unknown
---@return any
function Unit.set_animation_constraint_enable(...) end

---@param ... unknown
---@return any
function Unit.flow_variable(...) end

---@param ... unknown
---@return any
function Unit.set_flow_variable(...) end

---@param ... unknown
---@return any
function Unit.is_point_inside_volume(...) end

---@param ... unknown
---@return any
function Unit.distance_to_volume(...) end

---@param ... unknown
---@return any
function Unit.closest_point_on_volume(...) end

---@param ... unknown
---@return any
function Unit.random_point_inside_volume(...) end

---@param ... unknown
---@return any
function Unit.next_random_point_inside_volume(...) end

---@param ... unknown
---@return any
function Unit.is_volumes_overlapping(...) end

---@param ... unknown
---@return any
function Unit._set_mover(...) end

---@param ... unknown
---@return any
function Unit.volume_height(...) end

---@param ... unknown
---@return any
function Unit.volume_points(...) end

---@param ... unknown
---@return any
function Unit.has_volume(...) end

---@param ... unknown
---@return any
function Unit.animation_get_state(...) end

---@param ... unknown
---@return any
function Unit.id_string(...) end

---@param ... unknown
---@return any
function Unit.world(...) end

---@param ... unknown
---@return any
function Unit.lod_object(...) end

---@param ... unknown
---@return any
function Unit.num_lod_groups(...) end

---@param ... unknown
---@return any
function Unit.has_lod_group(...) end

---@param ... unknown
---@return any
function Unit.has_node(...) end

---@param ... unknown
---@return any
function Unit.node(...) end

---@param ... unknown
---@return any
function Unit.scene_graph_children(...) end

---@param ... unknown
---@return any
function Unit.get_node_actors(...) end

---@param ... unknown
---@return any
function Unit.get_node_meshes(...) end

---@param ... unknown
---@return any
function Unit.get_node_lights(...) end

---@param ... unknown
---@return any
function Unit.get_node_cameras(...) end

---@param ... unknown
---@return any
function Unit.local_position(...) end

---@param ... unknown
---@return any
function Unit.local_rotation(...) end

---@param ... unknown
---@return any
function Unit.local_scale(...) end

---@param ... unknown
---@return any
function Unit.local_pose(...) end

---@param ... unknown
---@return any
function Unit.set_local_position(...) end

---@param ... unknown
---@return any
function Unit.set_local_rotation(...) end

---@param ... unknown
---@return any
function Unit.set_local_scale(...) end

---@param ... unknown
---@return any
function Unit.set_local_pose(...) end

---@param ... unknown
---@return any
function Unit.teleport_local_position(...) end

---@param ... unknown
---@return any
function Unit.teleport_local_rotation(...) end

---@param ... unknown
---@return any
function Unit.teleport_local_scale(...) end

---@param ... unknown
---@return any
function Unit.teleport_local_pose(...) end

---@param ... unknown
---@return any
function Unit.level(...) end

---@param ... unknown
---@return any
function Unit.world_position(...) end

---@param ... unknown
---@return any
function Unit.world_rotation(...) end

---@param ... unknown
---@return any
function Unit.world_scale(...) end

---@param ... unknown
---@return any
function Unit.world_pose(...) end

---@param ... unknown
---@return any
function Unit.delta_position(...) end

---@param ... unknown
---@return any
function Unit.delta_rotation(...) end

---@param ... unknown
---@return any
function Unit.delta_pose(...) end

---@param ... unknown
---@return any
function Unit.num_scene_graph_items(...) end

---@param ... unknown
---@return any
function Unit.scene_graph_parent(...) end

---@param ... unknown
---@return any
function Unit.scene_graph_link(...) end

---@param ... unknown
---@return any
function Unit.bones(...) end

---@param ... unknown
---@return any
function Unit.copy_scene_graph_local_from(...) end

---@param ... unknown
---@return any
function Unit.get_child_units(...) end

---@param ... unknown
---@return any
function Unit.num_cameras(...) end

---@param ... unknown
---@return any
function Unit.has_camera(...) end

---@param ... unknown
---@return any
function Unit.camera(...) end

---@param ... unknown
---@return any
function Unit.num_meshes(...) end

---@param ... unknown
---@return any
function Unit.has_mesh(...) end

---@param ... unknown
---@return any
function Unit.mesh(...) end

---@param ... unknown
---@return any
function Unit.num_lod_objects(...) end

---@param ... unknown
---@return any
function Unit.has_lod_object(...) end

---@param ... unknown
---@return any
function Unit.set_data(...) end

---@alias UnitData string

---@param name UnitData
---@return any
function Unit:get_data(name) end

---@param ... unknown
---@return any
function Unit.has_data(...) end

---@param ... unknown
---@return any
function Unit.lod_group(...) end

---@param ... unknown
---@return any
function Unit.num_lights(...) end

---@param ... unknown
---@return any
function Unit.has_light(...) end

---@param ... unknown
---@return any
function Unit.light(...) end

---@param ... unknown
---@return any
function Unit.num_terrains(...) end

---@param ... unknown
---@return any
function Unit.has_terrain(...) end

---@param ... unknown
---@return any
function Unit.terrain(...) end

---@param ... unknown
---@return any
function Unit.terrain_update_height_field(...) end

---@param ... unknown
---@return any
function Unit.num_large_terrains(...) end

---@param ... unknown
---@return any
function Unit.has_large_terrain(...) end

---@param ... unknown
---@return any
function Unit.large_terrain(...) end

---@param ... unknown
---@return any
function Unit.data_table_size(...) end

---@param ... unknown
---@return any
function Unit.num_actors(...) end

---@param ... unknown
---@return any
function Unit.find_actor(...) end

---@param ... unknown
---@return any
function Unit.actor(...) end

---@param ... unknown
---@return any
function Unit.num_movers(...) end

---@param ... unknown
---@return any
function Unit.find_mover(...) end

---@return any
function Unit.set_mover() end

---@param ... unknown
---@return any
function Unit.mover_fits_at(...) end

---@param ... unknown
---@return any
function Unit.mover(...) end

---@param ... unknown
---@return any
function Unit.create_actor(...) end

---@param ... unknown
---@return any
function Unit.destroy_actor(...) end

---@param ... unknown
---@return any
function Unit.create_custom_joint(...) end

---@param ... unknown
---@return any
function Unit.create_joint(...) end

---@param ... unknown
---@return any
function Unit.destroy_joint(...) end

---@param ... unknown
---@return any
function Unit.create_vehicle(...) end

---@param ... unknown
---@return any
function Unit.destroy_vehicle(...) end

---@param ... unknown
---@return any
function Unit.vehicle(...) end

---@param ... unknown
---@return any
function Unit.set_moving(...) end

---@param ... unknown
---@return any
function Unit.draw_tree(...) end

---@param ... unknown
---@return any
function Unit.debug_name(...) end

---@param ... unknown
---@return any
function Unit.debug_name_hash(...) end

---@param ... unknown
---@return any
function Unit.name_hash(...) end

---@param ... unknown
---@return any
function Unit.alive(...) end

---@param ... unknown
---@return any
function Unit.set_frozen(...) end

---@param ... unknown
---@return any
function Unit.is_frozen(...) end

---@param ... unknown
---@return any
function Unit.is_static(...) end

---@param ... unknown
---@return any
function Unit.create_new_reference(...) end

---@param ... unknown
---@return any
function Unit.remove_reference(...) end

---@param ... unknown
---@return any
function Unit.assign_reference(...) end

---@param ... unknown
---@return any
function Unit.validate_material_slot_compatibility(...) end

---@param ... unknown
---@return any
function Unit.set_material(...) end

---@param ... unknown
---@return any
function Unit.set_all_materials(...) end

---@param ... unknown
---@return any
function Unit.set_light_material(...) end

---@param ... unknown
---@return any
function Unit.set_material_from_id(...) end

---@param ... unknown
---@return any
function Unit.get_material_resource_id(...) end

---@param ... unknown
---@return any
function Unit.set_material_layer(...) end

---@param ... unknown
---@return any
function Unit.add_material_layer(...) end

---@param ... unknown
---@return any
function Unit.remove_material_layer(...) end

---@param ... unknown
---@return any
function Unit.get_material_layer_materials(...) end

---@param ... unknown
---@return any
function Unit.set_sort_order(...) end

---@param ... unknown
---@return any
function Unit.id32(...) end
