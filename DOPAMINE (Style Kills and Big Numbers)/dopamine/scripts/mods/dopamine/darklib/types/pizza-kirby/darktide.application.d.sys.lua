---@meta

---@class Application
Application = {
    ENABLE_RAY_TRACING = "5",

    ERROR_NO_FILE_IN_SETTINGS = "1",

    ERROR_NO_APPDATA_FOLDER = "2",

    ERROR_CAN_NOT_OPEN_FILE = "3",

    ERROR_NO_PLS_FOLDER = "4",

    WIN32 = "win32",

    PS4 = "ps4",

    PS5 = "ps5",

    XB1 = "xb1",

    DISABLE_PHYSICS = "0",

    _name = "Application",

    ENABLE_REPLAY = "2",

    ENABLE_VOLUMETRICS = "3",
}

---@param ... unknown
---@return any
function Application.new_world(...) end

---@param ... unknown
---@return any
function Application.render_world(...) end

---@param ... unknown
---@return any
function Application.reset_dlss(...) end

---@param ... unknown
---@return any
function Application.release_world(...) end

---@param ... unknown
---@return any
function Application.worlds(...) end

---@param ... unknown
---@return any
function Application.main_world(...) end

---@param ... unknown
---@return any
function Application.debug_world(...) end

---@param ... unknown
---@return any
function Application.bundled(...) end

---@param ... unknown
---@return any
function Application.resource_package(...) end

---@param ... unknown
---@return any
function Application.release_resource_package(...) end

---@param ... unknown
---@return any
function Application.set_resource_property_preference_order(...) end

---@param ... unknown
---@return any
function Application.get_unit_resource_bounding_volume(...) end

---@param ... unknown
---@return any
function Application.all_plugin_names(...) end

---@param ... unknown
---@return any
function Application.get_filelog_local(...) end

---@param ... unknown
---@return any
function Application.back_buffer_size(...) end

---@param ... unknown
---@return any
function Application.flow_callback_context_level(...) end

Application.ENABLE_MOC = "4"

---@param ... unknown
---@return any
function Application.memory_telemetry(...) end

---@param ... unknown
---@return any
function Application.memory_tree(...) end

---@param ... unknown
---@return any
function Application.get_strip_tags_hash(...) end

---@param ... unknown
---@return any
function Application.is_fullscreen(...) end

---@param ... unknown
---@return any
function Application.set_in_menu(...) end

---@param ... unknown
---@return any
function Application.get_feature_flags_hash(...) end

---@param ... unknown
---@return any
function Application.get_strip_tags_table(...) end

---@param ... unknown
---@return any
function Application.get_feature_flags_table(...) end

---@param ... unknown
---@return any
function Application.print_strip_tags(...) end

---@param ... unknown
---@return any
function Application.print_feature_flags(...) end

---@param ... unknown
---@return any
function Application.is_plugin_active(...) end

---@param ... unknown
---@return any
function Application.activate_plugin(...) end

---@param ... unknown
---@return any
function Application.set_contribution_cull_limit(...) end

---@param ... unknown
---@return any
function Application.hex64_to_dec(...) end

---@param ... unknown
---@return any
function Application.dec64_to_hex(...) end

---@param ... unknown
---@return any
function Application.flow_callback_context(...) end

---@param ... unknown
---@return any
function Application.enum_display_modes(...) end

---@param ... unknown
---@return any
function Application.export_mesh_geometry(...) end

---@param ... unknown
---@return any
function Application.set_max_frame_stacking(...) end

---@param ... unknown
---@return any
function Application.query_performance_counter(...) end

---@param ... unknown
---@return any
function Application.time_since_query(...) end

---@param ... unknown
---@return any
function Application.restart_file_log(...) end

---@param ... unknown
---@return any
function Application.open_url_in_browser(...) end

---@param ... unknown
---@return any
function Application.save_render_target(...) end

---@param ... unknown
---@return any
function Application.create_viewport(...) end

---@param ... unknown
---@return any
function Application.destroy_viewport(...) end

---@param ... unknown
---@return any
function Application.set_render_setting(...) end

---@param ... unknown
---@return any
function Application.render_config(...) end

---@param ... unknown
---@return any
function Application.rendering_enabled(...) end

---@param ... unknown
---@return any
function Application.argv(...) end

---@param ... unknown
---@return any
function Application.quit(...) end

---@param ... unknown
---@return any
function Application.can_get_resource(...) end

---@param ... unknown
---@return any
function Application.can_get_resource_id(...) end

---@param ... unknown
---@return any
function Application.resource_reference_info(...) end

---@param ... unknown
---@return any
function Application.guid(...) end

---@param ... unknown
---@return any
function Application.set_data(...) end

---@param ... unknown
---@return any
function Application.get_data(...) end

---@param ... unknown
---@return any
function Application.has_data(...) end

Application.DISABLE_RENDERING = "1"

---@param ... unknown
---@return any
function Application.error(...) end

---@param ... unknown
---@return any
function Application.warning(...) end

---@param ... unknown
---@return any
function Application.set_win32_user_setting(...) end

---@param ... unknown
---@return any
function Application.win32_user_setting(...) end

---@param ... unknown
---@return any
function Application.save_win32_user_settings(...) end

---@param ... unknown
---@return any
function Application.apply_win32_user_settings(...) end

---@param ... unknown
---@return any
function Application.process_id(...) end

---@param ... unknown
---@return any
function Application.set_process_priority(...) end

---@param ... unknown
---@return any
function Application.force_silent_exit_policy(...) end

---@param ... unknown
---@return any
function Application.set_exit_code(...) end

---@param ... unknown
---@return any
function Application.save_user_settings(...) end

---@param ... unknown
---@return any
function Application.user_settings_load_error(...) end

---@param ... unknown
---@return any
function Application.apply_user_settings(...) end

---@param ... unknown
---@return any
function Application.set_user_setting(...) end

---@param ... unknown
---@return any
function Application.user_setting(...) end

---@param ... unknown
---@return any
function Application.has_steam_appid(...) end

---@param ... unknown
---@return any
function Application.add_crash_property(...) end

---@param ... unknown
---@return any
function Application.get_crash_properties(...) end

---@param ... unknown
---@return any
function Application.set_vsync(...) end

---@param ... unknown
---@return any
function Application.render_caps(...) end

---@param ... unknown
---@return any
function Application.print_render_settings(...) end

---@param ... unknown
---@return any
function Application.create_render_fence(...) end

---@param ... unknown
---@return any
function Application.poll_render_fence(...) end

---@param ... unknown
---@return any
function Application.time_since_launch(...) end

---@param ... unknown
---@return any
function Application.resource_id(...) end

---@param ... unknown
---@return any
function Application.make_hash(...) end

---@param ... unknown
---@return any
function Application.set_time_step_policy(...) end

---@param ... unknown
---@return any
function Application.session_id(...) end

---@param ... unknown
---@return any
function Application.remove_crash_property(...) end

---@param ... unknown
---@return any
function Application.quit_with_message(...) end

---@param ... unknown
---@return any
function Application.flow_callback_context_world(...) end

---@param ... unknown
---@return any
function Application.flow_callback_context_unit(...) end

---@return any
function Application.platform() end

---@param ... unknown
---@return any
function Application.source_platform(...) end

---@return any
function Application.build() end

---@return any
function Application.build_identifier() end

---@return any
function Application.settings() end

---@param ... unknown
---@return any
function Application.sysinfo(...) end

---@param ... unknown
---@return any
function Application.is_dedicated_server(...) end

---@param ... unknown
---@return any
function Application.file_client(...) end

---@param ... unknown
---@return any
function Application.is_virtual_machine(...) end

---@param ... unknown
---@return any
function Application.wine_version(...) end

---@param ... unknown
---@return any
function Application.machine_id(...) end
