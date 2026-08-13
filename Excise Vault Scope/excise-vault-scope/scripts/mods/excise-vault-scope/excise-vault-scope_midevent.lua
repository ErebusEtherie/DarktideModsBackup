-- excise-vault-scope_midevent.lua
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

return function(core, manager)
    local OBJECTIVES = core.objectives
    local MARKER_TYPE = core.marker_types.midevent
    local MARKER_TEXT = ""
    local PENDING_MARKER = core.pending_marker

    local tracked_units = {}
    local marker_ids = {}
    local marker_pending_frames = {}
    local marker_colours = {}
    local clear_marker_units = {}
    local refresh_marker_units = {}
    local update_tracked_units = {}
    local door_unit = nil
    local door_search_active = false
    local complete = false

    local function get_decoder_device_extension(unit)
        if not core.is_valid_unit(unit) then
            return nil
        end

        return ScriptUnit.has_extension(unit, "decoder_device_system")
    end

    local function call_decoder_extension_boolean(extension, method_name)
        if not extension then
            return false
        end

        local method = extension[method_name]

        if type(method) ~= "function" then
            return false
        end

        local ok, value = pcall(method, extension)

        return ok and value == true
    end

    local function call_decoder_boolean(unit, method_name)
        return call_decoder_extension_boolean(get_decoder_device_extension(unit), method_name)
    end

    local function decoder_is_finished(unit)
        return call_decoder_boolean(unit, "is_finished")
    end

    local function decoder_is_enabled(unit)
        return call_decoder_boolean(unit, "unit_is_enabled")
    end

    local function has_tracked_units()
        return next(tracked_units) ~= nil
    end

    local function current_marker_state(unit)
        if complete or not tracked_units[unit] then
            return nil
        end

        local extension = get_decoder_device_extension(unit)

        if not extension or not call_decoder_extension_boolean(extension, "unit_is_enabled") or call_decoder_extension_boolean(extension, "is_finished") then
            return nil
        end

        if call_decoder_extension_boolean(extension, "wait_for_setup") then
            return "setup"
        elseif call_decoder_extension_boolean(extension, "wait_for_restart") then
            return "restart"
        end

        return nil
    end

    local function current_marker_colour(unit)
        return unit and marker_colours[unit] or core.colours.button
    end

    local function remove_marker(unit)
        core.remove_live_markers(MARKER_TYPE, unit)
        marker_ids[unit] = nil
        marker_pending_frames[unit] = nil
        marker_colours[unit] = nil
    end

    local function untrack_unit(unit)
        tracked_units[unit] = nil
        remove_marker(unit)

        if door_unit == unit then
            door_unit = nil
            door_search_active = has_tracked_units()
        end
    end

    local function clear_state(keep_complete)
        table.clear(clear_marker_units)

        for unit, _ in pairs(marker_ids) do
            clear_marker_units[#clear_marker_units + 1] = unit
        end

        for i = 1, #clear_marker_units do
            remove_marker(clear_marker_units[i])
        end

        table.clear(tracked_units)
        table.clear(marker_ids)
        table.clear(marker_pending_frames)
        table.clear(marker_colours)
        door_unit = nil
        door_search_active = false

        if not keep_complete then
            complete = false
        end
    end

    local function finish()
        complete = true
        clear_state(true)
        core.request_refresh()
    end

    local function track_unit(unit)
        if not core.is_target() or complete or not core.is_valid_unit(unit) or tracked_units[unit] then
            return
        end

        tracked_units[unit] = true
        core.request_refresh()
    end

    local function create_marker_template()
        local font_settings = UIFontSettings.hud_body
        local template = {}

        template.name = MARKER_TYPE
        template.size = { 64, 64 }
        template.unit_node = "ui_interaction_marker"
        template.position_offset = { 0, 0, 0 }
        template.max_distance = core.button_max_distance()
        template.screen_clamp = true
        template.screen_margins = {
            down = 0.23148148148148148,
            left = 0.234375,
            right = 0.234375,
            up = 0.23148148148148148,
        }
        template.check_line_of_sight = false
        template.using_smart_tag_system = false
        template.scale_settings = {
            distance_min = 0,
            distance_max = core.distance_values.Far,
            scale_from = 1,
            scale_to = 1,
        }
        template.fade_settings = nil

        template.create_widget_defintion = function(_, scenegraph_id)
            return UIWidget.create_definition({
                {
                    pass_type = "text",
                    style_id = "marker_shadow",
                    value = MARKER_TEXT,
                    value_id = "marker_text",
                    style = {
                        font_type = font_settings.font_type,
                        font_size = core.marker_font_size(),
                        default_font_size = core.marker_font_size(),
                        text_horizontal_alignment = "center",
                        text_vertical_alignment = "center",
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 2, 2, 0 },
                        default_offset = { 2, 2, 0 },
                        size = { 320, 320 },
                        default_size = { 320, 320 },
                        text_color = core.colours.shadow,
                    },
                },
                {
                    pass_type = "text",
                    style_id = "marker_text",
                    value = MARKER_TEXT,
                    value_id = "marker_text",
                    style = {
                        font_type = font_settings.font_type,
                        font_size = core.marker_font_size(),
                        default_font_size = core.marker_font_size(),
                        text_horizontal_alignment = "center",
                        text_vertical_alignment = "center",
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 0, 0, 1 },
                        default_offset = { 0, 0, 1 },
                        size = { 320, 320 },
                        default_size = { 320, 320 },
                        text_color = core.colours.button,
                    },
                },
            }, scenegraph_id)
        end

        local function update_widget(widget, marker, marker_template)
            local font_size = core.marker_font_size()
            local unit = marker.unit or marker.data and marker.data.owner_unit or nil

            marker_template.max_distance = core.button_max_distance()
            widget.content.marker_text = MARKER_TEXT
            widget.style.marker_shadow.font_size = font_size
            widget.style.marker_shadow.default_font_size = font_size
            widget.style.marker_shadow.text_color = core.colours.shadow
            widget.style.marker_text.font_size = font_size
            widget.style.marker_text.default_font_size = font_size
            widget.style.marker_text.text_color = current_marker_colour(unit)
            marker.scale = 1
            marker.ignore_scale = true
        end

        template.on_enter = function(widget, marker)
            update_widget(widget, marker, marker.template)
        end

        template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
            update_widget(widget, marker, marker_template)
        end

        return template
    end

    local function ensure_template(world_markers)
        return core.ensure_marker_template(MARKER_TYPE, create_marker_template, world_markers)
    end

    local function request_marker(unit, colour)
        if not core.is_valid_unit(unit) or not ensure_template() then
            return
        end

        marker_colours[unit] = colour

        local marker_id = marker_ids[unit]

        if marker_id == PENDING_MARKER then
            local recovered_id = core.find_live_marker_id(MARKER_TYPE, unit)

            if recovered_id then
                marker_ids[unit] = recovered_id
                marker_pending_frames[unit] = nil
            end

            return
        end

        if core.marker_id_is_live(marker_id, MARKER_TYPE, unit) then
            marker_pending_frames[unit] = nil
            return
        end

        local recovered_id = core.find_live_marker_id(MARKER_TYPE, unit)

        if recovered_id then
            marker_ids[unit] = recovered_id
            marker_pending_frames[unit] = nil
            return
        end

        marker_ids[unit] = PENDING_MARKER
        marker_pending_frames[unit] = 0

        local function on_marker_added(new_marker_id)
            if marker_ids[unit] == PENDING_MARKER then
                marker_ids[unit] = new_marker_id
                marker_pending_frames[unit] = nil
            end
        end

        Managers.event:trigger("add_world_marker_unit", MARKER_TYPE, unit, on_marker_added, { owner_unit = unit })
    end

    local function update_pending_marker(unit)
        local marker_id = marker_ids[unit]

        if marker_id == PENDING_MARKER then
            local recovered_id = core.find_live_marker_id(MARKER_TYPE, unit)

            if recovered_id then
                marker_ids[unit] = recovered_id
                marker_pending_frames[unit] = nil
                return
            end

            local pending_frames = (marker_pending_frames[unit] or 0) + 1

            marker_pending_frames[unit] = pending_frames

            if pending_frames >= 30 then
                marker_ids[unit] = nil
                marker_pending_frames[unit] = nil
            end
        elseif marker_id and not core.marker_id_is_live(marker_id, MARKER_TYPE, unit) then
            marker_ids[unit] = nil
            marker_pending_frames[unit] = nil
        end
    end

    local function scan_live_units()
        if not core.is_target() or complete then
            return true
        end

        local unit_to_extension_map = core.extension_system_unit_map("decoder_device_system")

        if not unit_to_extension_map then
            return false
        end

        for unit, extension in pairs(unit_to_extension_map) do
            if core.is_valid_unit(unit) and manager.call_extension_boolean(extension, "unit_is_enabled") then
                track_unit(unit)
            end
        end

        return true
    end

    local function all_decoders_finished(proceed_hangars_active)
        if proceed_hangars_active then
            return true
        end

        if not has_tracked_units() then
            return false
        end

        for unit, _ in pairs(tracked_units) do
            if core.is_valid_unit(unit) and not decoder_is_finished(unit) then
                return false
            end
        end

        return true
    end

    local function extra_door_exclusion(unit)
        return tracked_units[unit] == true or unit == door_unit or manager.owns_unit(unit)
    end

    local function find_door(interaction_markers)
        if not interaction_markers then
            return nil
        end

        local best_unit = nil
        local best_score = -1

        for i = 1, #interaction_markers do
            local marker = interaction_markers[i]
            local unit = marker.unit

            if unit and not extra_door_exclusion(unit) then
                local score = manager.security_door_candidate_score(unit, extra_door_exclusion)

                if score and score > best_score then
                    best_unit = unit
                    best_score = score
                end
            end
        end

        return best_unit
    end

    local function refresh()
        table.clear(refresh_marker_units)

        for unit, _ in pairs(marker_ids) do
            refresh_marker_units[#refresh_marker_units + 1] = unit
        end

        for i = 1, #refresh_marker_units do
            remove_marker(refresh_marker_units[i])
        end

        for unit, _ in pairs(tracked_units) do
            if core.is_valid_unit(unit) then
                local marker_state = current_marker_state(unit)

                if marker_state == "setup" then
                    request_marker(unit, core.colours.midevent_setup)
                elseif marker_state == "restart" then
                    request_marker(unit, core.colours.midevent_restart)
                end
            else
                untrack_unit(unit)
            end
        end

        if door_unit and core.is_valid_unit(door_unit) then
            request_marker(door_unit, core.colours.button)
        end
    end

    local api = {}

    function api.on_mission_activated()
        clear_state(false)
    end

    function api.reset()
        clear_state(false)
    end

    function api.clear_marker_handles()
        table.clear(marker_ids)
        table.clear(marker_pending_frames)
    end

    function api.ensure_template(world_markers)
        return ensure_template(world_markers)
    end

    function api.scan_live_units()
        return scan_live_units()
    end

    function api.sync_objectives()
        if not core.is_target() or complete then
            return
        end

        if core.active_mission_objective(OBJECTIVES.reach_vault) or core.active_mission_objective(OBJECTIVES.interact_vaults_panel) or core.active_mission_objective(OBJECTIVES.deposit) or core.active_mission_objective(OBJECTIVES.send_assets) or core.active_mission_objective(OBJECTIVES.extraction) then
            finish()
        elseif core.active_mission_objective(OBJECTIVES.proceed_hangars) then
            complete = false
            door_search_active = door_unit == nil
            scan_live_units()
            core.request_refresh()
        elseif core.active_mission_objective(OBJECTIVES.decrypt) then
            complete = false
            scan_live_units()
        end
    end

    function api.on_objective_started(objective_name)
        if objective_name == OBJECTIVES.decrypt then
            complete = false
            scan_live_units()
            core.request_refresh()
        elseif objective_name == OBJECTIVES.proceed_hangars then
            complete = false
            scan_live_units()
            door_search_active = door_unit == nil
            core.request_refresh()
        elseif objective_name == OBJECTIVES.reach_vault or objective_name == OBJECTIVES.interact_vaults_panel or objective_name == OBJECTIVES.deposit or objective_name == OBJECTIVES.send_assets or objective_name == OBJECTIVES.extraction then
            finish()
        end
    end

    function api.on_decoder_init(unit)
        if not core.is_target() then
            return
        end

        if decoder_is_enabled(unit) then
            track_unit(unit)
        end
    end

    function api.on_decoder_enabled(unit)
        if not core.is_target() then
            return
        end

        complete = false
        track_unit(unit)
        core.request_refresh()
    end

    function api.on_decoder_hot_join(extension, unit_is_enabled, is_finished)
        if not core.is_target() then
            return
        end

        if is_finished then
            extension._is_finished = true
        end

        if unit_is_enabled then
            complete = false
            track_unit(extension._unit)
            core.request_refresh()
        end
    end

    function api.on_decoder_state_changed(unit)
        if core.is_target() then
            track_unit(unit)
            core.request_refresh()
        end
    end

    function api.on_decoder_finished(unit)
        if core.is_target() then
            track_unit(unit)
            door_search_active = true
            core.request_refresh()
        end
    end

    function api.on_door_state_changed(unit)
        if core.is_target() and door_unit == unit then
            finish()
        end
    end

    function api.on_interactable_used(unit)
        if core.is_target() and door_unit == unit then
            finish()
        end
    end

    function api.on_interactable_disabled(unit)
        if core.is_target() and door_unit == unit then
            finish()
        end
    end

    function api.on_interactee_active_changed(unit, is_active)
        if not core.is_target() then
            return
        end

        if is_active and door_search_active then
            core.request_refresh()
        elseif not is_active and door_unit == unit then
            finish()
        end
    end

    function api.refresh()
        refresh()
    end

    function api.update(interaction_markers)
        if not core.is_target() or complete then
            return
        end

        local proceed_hangars_active = core.active_mission_objective(OBJECTIVES.proceed_hangars) ~= nil

        table.clear(update_tracked_units)

        for unit, _ in pairs(tracked_units) do
            update_tracked_units[#update_tracked_units + 1] = unit
        end

        for i = 1, #update_tracked_units do
            local unit = update_tracked_units[i]

            if not core.is_valid_unit(unit) then
                untrack_unit(unit)
            else
                update_pending_marker(unit)

                local marker_state = current_marker_state(unit)

                if marker_state == "setup" then
                    request_marker(unit, core.colours.midevent_setup)
                elseif marker_state == "restart" then
                    request_marker(unit, core.colours.midevent_restart)
                else
                    remove_marker(unit)
                end
            end
        end

        if all_decoders_finished(proceed_hangars_active) then
            if door_unit and core.is_valid_unit(door_unit) and manager.is_active_interactable(door_unit) then
                door_search_active = false
                update_pending_marker(door_unit)
                request_marker(door_unit, core.colours.button)
            else
                if door_unit then
                    remove_marker(door_unit)
                    door_unit = nil
                end

                door_search_active = true

                local candidate = find_door(interaction_markers)

                if candidate then
                    door_unit = candidate
                    door_search_active = false
                    update_pending_marker(door_unit)
                    request_marker(door_unit, core.colours.button)
                end
            end
        else
            door_search_active = false

            if door_unit then
                remove_marker(door_unit)
                door_unit = nil
            end
        end
    end

    function api.apply_draw_settings(markers_by_type)
        local markers = markers_by_type and markers_by_type[MARKER_TYPE]

        if not markers then
            return
        end

        local max_distance = core.button_max_distance()

        for i = 1, #markers do
            local marker = markers[i]

            marker.template.max_distance = max_distance
            marker.scale = 1
            marker.ignore_scale = true
            marker.draw = type(marker.distance) == "number" and marker.distance <= max_distance
        end
    end

    function api.owns_unit(unit)
        return unit ~= nil and (tracked_units[unit] == true or unit == door_unit)
    end

    function api.has_live_marker(unit)
        return unit ~= nil and core.marker_id_is_live(marker_ids[unit], MARKER_TYPE, unit) or false
    end

    return api
end
