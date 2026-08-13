-- excise-vault-scope_manager.lua
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

return function(core)
    local OBJECTIVES = core.objectives
    local MARKER_TYPE = core.marker_types.button
    local CASKET_MARKER_TYPE = core.marker_types.casket
    local BUTTON_MARKER_TEXT = ""
    local DEFAULT_CASKET_TEXT = ""
    local FINAL_DOOR_CANDIDATE_MAX_DISTANCE = 200
    local BUTTON_SEARCH_WINDOW = 5
    local EXIT_DOOR_SEARCH_WINDOW = 20
    local PENDING_MARKER = core.pending_marker

    local STATES = {
        inactive = 0,
        searching_button = 1,
        button_locked = 2,
        waiting_for_exit_objective = 3,
        searching_exit_door = 4,
        exit_door_locked = 5,
        done = 6,
    }

    local state = STATES.inactive
    local final_button_unit = nil
    local final_button_marker_id = nil
    local final_button_marker_pending_frames = nil
    local button_search_deadline_t = nil
    local exit_door_unit = nil
    local exit_door_marker_id = nil
    local exit_door_marker_pending_frames = nil
    local exit_door_search_deadline_t = nil
    local external_exclusion = nil

    local function gameplay_time()
        local time_manager = Managers and Managers.time

        if time_manager and time_manager.has_timer and time_manager:has_timer("gameplay") then
            return time_manager:time("gameplay")
        end

        return nil
    end

    local function is_excluded(unit, extra_exclusion)
        if not unit or core.is_casket(unit) or core.is_casket_tracked(unit) then
            return true
        end

        if external_exclusion and external_exclusion(unit) then
            return true
        end

        return extra_exclusion and extra_exclusion(unit) or false
    end

    local function get_door_control_panel_extension(unit)
        if not core.is_valid_unit(unit) then
            return nil
        end

        return ScriptUnit.has_extension(unit, "door_control_panel_system")
    end

    local function call_extension_boolean(extension, method_name)
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

    local function door_panel_is_active(unit)
        return call_extension_boolean(get_door_control_panel_extension(unit), "is_active")
    end

    local function door_panel_is_on_hold(unit)
        return call_extension_boolean(get_door_control_panel_extension(unit), "is_on_hold")
    end

    local function get_interactee_extension(unit)
        if not core.is_valid_unit(unit) then
            return nil
        end

        return ScriptUnit.has_extension(unit, "interactee_system")
    end

    local function call_interactee_value(unit, method_name)
        local extension = get_interactee_extension(unit)

        if not extension then
            return nil
        end

        local method = extension[method_name]

        if type(method) ~= "function" then
            return nil
        end

        local ok, value = pcall(method, extension)

        return ok and value or nil
    end

    local function localise_text(value)
        if type(value) ~= "string" or value == "" then
            return nil
        end

        if string.sub(value, 1, 4) == "loc_" then
            local ok, localised = pcall(Localize, value)

            if ok and type(localised) == "string" and localised ~= "" then
                value = localised
            end
        end

        return value
    end

    local function normalise_text(value)
        value = localise_text(value)

        if type(value) ~= "string" or value == "" then
            return nil
        end

        return string.lower(value)
    end

    local function unit_data_string(unit, key)
        if not core.is_valid_unit(unit) or not Unit.has_data(unit, key) then
            return nil
        end

        local value = Unit.get_data(unit, key)

        return type(value) == "string" and value ~= "" and value or nil
    end

    local function current_button_prompt(unit)
        return normalise_text(call_interactee_value(unit, "description") or unit_data_string(unit, "hud_description")),
            normalise_text(call_interactee_value(unit, "action_text") or unit_data_string(unit, "sub_description")),
            normalise_text(call_interactee_value(unit, "interaction_type") or unit_data_string(unit, "interaction_type")),
            normalise_text(call_interactee_value(unit, "ui_interaction_type") or unit_data_string(unit, "ui_interaction_type"))
    end

    local function is_active_interactable(unit)
        local extension = get_interactee_extension(unit)

        if not extension then
            return false
        end

        local used_function = extension.used

        if type(used_function) == "function" then
            local ok, used = pcall(used_function, extension)

            if ok and used then
                return false
            end
        end

        local active_function = extension.active

        if type(active_function) == "function" then
            local ok, active = pcall(active_function, extension)

            if ok and not active then
                return false
            end
        end

        return true
    end

    local function security_door_candidate_score(unit, extra_exclusion)
        if not core.is_valid_unit(unit) or is_excluded(unit, extra_exclusion) or Unit.has_data(unit, "pickup_type") then
            return nil
        end

        if not is_active_interactable(unit) then
            return nil
        end

        local description, action, interaction_type, ui_interaction_type = current_button_prompt(unit)

        if description ~= "security door" then
            return nil
        end

        if action ~= "open" and not (action and string.find(action, "open", 1, true)) then
            return nil
        end

        local score = 1000

        if get_door_control_panel_extension(unit) then
            score = score + 100
        end

        if interaction_type == "door_control_panel" then
            score = score + 100
        end

        if ui_interaction_type == "default" or ui_interaction_type == "mission" then
            score = score + 25
        end

        return score
    end

    local function button_candidate_score(unit)
        if not core.is_valid_unit(unit) or is_excluded(unit) or Unit.has_data(unit, "pickup_type") then
            return nil
        end

        if not is_active_interactable(unit) then
            return nil
        end

        local description, action, interaction_type, ui_interaction_type = current_button_prompt(unit)
        local score = 0

        if description then
            if description == "pneumatic conveyor" then
                score = score + 1000
            end

            if string.find(description, "pneumatic", 1, true) then
                score = score + 500
            end

            if string.find(description, "conveyor", 1, true) then
                score = score + 500
            end
        end

        if action then
            if action == "send" then
                score = score + 400
            elseif string.find(action, "send", 1, true) then
                score = score + 250
            end
        end

        if score > 0 and interaction_type == "door_control_panel" then
            score = score + 50
        end

        if score > 0 and (ui_interaction_type == "default" or ui_interaction_type == "mission") then
            score = score + 25
        end

        return score > 0 and score or nil
    end

    local function create_casket_marker_template()
    local font_settings = UIFontSettings.hud_body
    local template = {}

    template.name = CASKET_MARKER_TYPE
    template.size = { 64, 64 }
    template.unit_node = "ui_interaction_marker"
    template.position_offset = { 0, 0, 0 }
    template.max_distance = core.marker_max_distance()
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
    local arrow_font_size = core.casket_level_font_size()
    local arrow_offset = core.casket_level_offset()

    return UIWidget.create_definition({
    {
    pass_type = "text",
    style_id = "marker_shadow",
    value = DEFAULT_CASKET_TEXT,
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
    value = DEFAULT_CASKET_TEXT,
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
    text_color = core.colours.casket,
    },
    },
    {
    pass_type = "text",
    style_id = "upper_arrow_shadow",
    value = "",
    value_id = "upper_arrow_text",
    style = {
    font_type = font_settings.font_type,
    font_size = arrow_font_size,
    default_font_size = arrow_font_size,
    text_horizontal_alignment = "center",
    text_vertical_alignment = "center",
    horizontal_alignment = "center",
    vertical_alignment = "center",
    offset = { 2, -arrow_offset + 2, 0 },
    default_offset = { 2, -arrow_offset + 2, 0 },
    size = { 320, 320 },
    default_size = { 320, 320 },
    text_color = core.colours.shadow,
    },
    },
    {
    pass_type = "text",
    style_id = "upper_arrow_text",
    value = "",
    value_id = "upper_arrow_text",
    style = {
    font_type = font_settings.font_type,
    font_size = arrow_font_size,
    default_font_size = arrow_font_size,
    text_horizontal_alignment = "center",
    text_vertical_alignment = "center",
    horizontal_alignment = "center",
    vertical_alignment = "center",
    offset = { 0, -arrow_offset, 1 },
    default_offset = { 0, -arrow_offset, 1 },
    size = { 320, 320 },
    default_size = { 320, 320 },
    text_color = core.colours.casket,
    },
    },
    {
    pass_type = "text",
    style_id = "lower_arrow_shadow",
    value = "",
    value_id = "lower_arrow_text",
    style = {
    font_type = font_settings.font_type,
    font_size = arrow_font_size,
    default_font_size = arrow_font_size,
    text_horizontal_alignment = "center",
    text_vertical_alignment = "center",
    horizontal_alignment = "center",
    vertical_alignment = "center",
    offset = { 2, arrow_offset + 2, 0 },
    default_offset = { 2, arrow_offset + 2, 0 },
    size = { 320, 320 },
    default_size = { 320, 320 },
    text_color = core.colours.shadow,
    },
    },
    {
    pass_type = "text",
    style_id = "lower_arrow_text",
    value = "",
    value_id = "lower_arrow_text",
    style = {
    font_type = font_settings.font_type,
    font_size = arrow_font_size,
    default_font_size = arrow_font_size,
    text_horizontal_alignment = "center",
    text_vertical_alignment = "center",
    horizontal_alignment = "center",
    vertical_alignment = "center",
    offset = { 0, arrow_offset, 1 },
    default_offset = { 0, arrow_offset, 1 },
    size = { 320, 320 },
    default_size = { 320, 320 },
    text_color = core.colours.casket,
    },
    },
    }, scenegraph_id)
    end

    template.on_enter = function(widget, marker)
    local font_size = core.marker_font_size()
    local arrow_font_size = core.casket_level_font_size()
    local arrow_offset = core.casket_level_offset()
    local upper_arrow_text, lower_arrow_text = core.current_casket_level_text(marker.unit)

    widget.content.marker_text = core.current_casket_marker_text()
    widget.content.upper_arrow_text = upper_arrow_text
    widget.content.lower_arrow_text = lower_arrow_text

    widget.style.marker_shadow.font_size = font_size
    widget.style.marker_shadow.default_font_size = font_size
    widget.style.marker_text.font_size = font_size
    widget.style.marker_text.default_font_size = font_size

    widget.style.upper_arrow_shadow.font_size = arrow_font_size
    widget.style.upper_arrow_shadow.default_font_size = arrow_font_size
    widget.style.upper_arrow_shadow.offset[2] = -arrow_offset + 2
    widget.style.upper_arrow_shadow.default_offset[2] = -arrow_offset + 2
    widget.style.upper_arrow_text.font_size = arrow_font_size
    widget.style.upper_arrow_text.default_font_size = arrow_font_size
    widget.style.upper_arrow_text.offset[2] = -arrow_offset
    widget.style.upper_arrow_text.default_offset[2] = -arrow_offset

    widget.style.lower_arrow_shadow.font_size = arrow_font_size
    widget.style.lower_arrow_shadow.default_font_size = arrow_font_size
    widget.style.lower_arrow_shadow.offset[2] = arrow_offset + 2
    widget.style.lower_arrow_shadow.default_offset[2] = arrow_offset + 2
    widget.style.lower_arrow_text.font_size = arrow_font_size
    widget.style.lower_arrow_text.default_font_size = arrow_font_size
    widget.style.lower_arrow_text.offset[2] = arrow_offset
    widget.style.lower_arrow_text.default_offset[2] = arrow_offset

    marker.template.max_distance = core.marker_max_distance()
    marker.scale = 1
    marker.ignore_scale = true
    end

    template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
    local font_size = core.marker_font_size()
    local arrow_font_size = core.casket_level_font_size()
    local arrow_offset = core.casket_level_offset()
    local upper_arrow_text, lower_arrow_text = core.current_casket_level_text(marker.unit)

    marker_template.max_distance = core.marker_max_distance()
    widget.content.marker_text = core.current_casket_marker_text()
    widget.content.upper_arrow_text = upper_arrow_text
    widget.content.lower_arrow_text = lower_arrow_text

    widget.style.marker_shadow.font_size = font_size
    widget.style.marker_shadow.default_font_size = font_size
    widget.style.marker_text.font_size = font_size
    widget.style.marker_text.default_font_size = font_size
    widget.style.marker_shadow.text_color = core.colours.shadow
    widget.style.marker_text.text_color = core.colours.casket

    widget.style.upper_arrow_shadow.font_size = arrow_font_size
    widget.style.upper_arrow_shadow.default_font_size = arrow_font_size
    widget.style.upper_arrow_shadow.offset[2] = -arrow_offset + 2
    widget.style.upper_arrow_shadow.default_offset[2] = -arrow_offset + 2
    widget.style.upper_arrow_shadow.text_color = core.colours.shadow
    widget.style.upper_arrow_text.font_size = arrow_font_size
    widget.style.upper_arrow_text.default_font_size = arrow_font_size
    widget.style.upper_arrow_text.offset[2] = -arrow_offset
    widget.style.upper_arrow_text.default_offset[2] = -arrow_offset
    widget.style.upper_arrow_text.text_color = core.colours.casket

    widget.style.lower_arrow_shadow.font_size = arrow_font_size
    widget.style.lower_arrow_shadow.default_font_size = arrow_font_size
    widget.style.lower_arrow_shadow.offset[2] = arrow_offset + 2
    widget.style.lower_arrow_shadow.default_offset[2] = arrow_offset + 2
    widget.style.lower_arrow_shadow.text_color = core.colours.shadow
    widget.style.lower_arrow_text.font_size = arrow_font_size
    widget.style.lower_arrow_text.default_font_size = arrow_font_size
    widget.style.lower_arrow_text.offset[2] = arrow_offset
    widget.style.lower_arrow_text.default_offset[2] = arrow_offset
    widget.style.lower_arrow_text.text_color = core.colours.casket

    marker.scale = 1
    marker.ignore_scale = true
    end

    return template
    end


    local function create_button_marker_template()
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
                    value = BUTTON_MARKER_TEXT,
                    value_id = "marker_text",
                    style = {
                        font_type = font_settings.font_type,
                        font_size = core.button_font_size(),
                        default_font_size = core.button_font_size(),
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
                    value = BUTTON_MARKER_TEXT,
                    value_id = "marker_text",
                    style = {
                        font_type = font_settings.font_type,
                        font_size = core.button_font_size(),
                        default_font_size = core.button_font_size(),
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
            local font_size = core.button_font_size()

            marker_template.max_distance = core.button_max_distance()
            widget.content.marker_text = BUTTON_MARKER_TEXT
            widget.style.marker_shadow.font_size = font_size
            widget.style.marker_shadow.default_font_size = font_size
            widget.style.marker_shadow.text_color = core.colours.shadow
            widget.style.marker_text.font_size = font_size
            widget.style.marker_text.default_font_size = font_size
            widget.style.marker_text.text_color = core.colours.button
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

    local function ensure_casket_template(world_markers)
        return core.ensure_marker_template(CASKET_MARKER_TYPE, create_casket_marker_template, world_markers)
    end

    local function ensure_template(world_markers)
        return core.ensure_marker_template(MARKER_TYPE, create_button_marker_template, world_markers)
    end

    local function remove_final_button_marker()
        if final_button_unit then
            core.remove_live_markers(MARKER_TYPE, final_button_unit)
        end

        final_button_marker_id = nil
        final_button_marker_pending_frames = nil
    end

    local function remove_exit_door_marker()
        if exit_door_unit then
            core.remove_live_markers(MARKER_TYPE, exit_door_unit)
        end

        exit_door_marker_id = nil
        exit_door_marker_pending_frames = nil
    end

    local function clear_final_button_state()
        remove_final_button_marker()
        final_button_unit = nil
        button_search_deadline_t = nil
    end

    local function clear_exit_door_state()
        remove_exit_door_marker()
        exit_door_unit = nil
        exit_door_search_deadline_t = nil
    end

    local function request_unit_marker(unit, marker_role)
        if not unit or not core.is_valid_unit(unit) or not ensure_template() then
            return
        end

        local is_button = marker_role == "button"
        local marker_id = is_button and final_button_marker_id or exit_door_marker_id

        if marker_id == PENDING_MARKER then
            local recovered_id = core.find_live_marker_id(MARKER_TYPE, unit)

            if recovered_id then
                if is_button then
                    final_button_marker_id = recovered_id
                    final_button_marker_pending_frames = nil
                else
                    exit_door_marker_id = recovered_id
                    exit_door_marker_pending_frames = nil
                end
            end

            return
        end

        if core.marker_id_is_live(marker_id, MARKER_TYPE, unit) then
            if is_button then
                final_button_marker_pending_frames = nil
            else
                exit_door_marker_pending_frames = nil
            end

            return
        end

        local recovered_id = core.find_live_marker_id(MARKER_TYPE, unit)

        if recovered_id then
            if is_button then
                final_button_marker_id = recovered_id
                final_button_marker_pending_frames = nil
            else
                exit_door_marker_id = recovered_id
                exit_door_marker_pending_frames = nil
            end

            return
        end

        if is_button then
            final_button_marker_id = PENDING_MARKER
            final_button_marker_pending_frames = 0
        else
            exit_door_marker_id = PENDING_MARKER
            exit_door_marker_pending_frames = 0
        end

        Managers.event:trigger("add_world_marker_unit", MARKER_TYPE, unit, function(new_marker_id)
            if is_button and final_button_marker_id == PENDING_MARKER then
                final_button_marker_id = new_marker_id
                final_button_marker_pending_frames = nil
            elseif not is_button and exit_door_marker_id == PENDING_MARKER then
                exit_door_marker_id = new_marker_id
                exit_door_marker_pending_frames = nil
            end
        end, { owner_unit = unit })
    end

    local function request_final_button_marker()
        request_unit_marker(final_button_unit, "button")
    end

    local function request_exit_door_marker()
        request_unit_marker(exit_door_unit, "exit")
    end

    local function update_pending_marker(marker_role)
        local is_button = marker_role == "button"
        local marker_id = is_button and final_button_marker_id or exit_door_marker_id
        local owner_unit = is_button and final_button_unit or exit_door_unit
        local pending_frames = is_button and final_button_marker_pending_frames or exit_door_marker_pending_frames

        if marker_id == PENDING_MARKER then
            local recovered_id = core.find_live_marker_id(MARKER_TYPE, owner_unit)

            if recovered_id then
                marker_id = recovered_id
                pending_frames = nil
            else
                pending_frames = (pending_frames or 0) + 1

                if pending_frames >= 30 then
                    marker_id = nil
                    pending_frames = nil
                end
            end
        elseif marker_id and not core.marker_id_is_live(marker_id, MARKER_TYPE, owner_unit) then
            marker_id = nil
            pending_frames = nil
        end

        if is_button then
            final_button_marker_id = marker_id
            final_button_marker_pending_frames = pending_frames
        else
            exit_door_marker_id = marker_id
            exit_door_marker_pending_frames = pending_frames
        end
    end

    local function finish()
        clear_final_button_state()
        clear_exit_door_state()
        state = STATES.done
        core.request_refresh()
    end

    local function begin_final_button()
        if not core.is_target() then
            return
        end

        if state == STATES.done or state == STATES.button_locked or state == STATES.waiting_for_exit_objective or state == STATES.searching_exit_door or state == STATES.exit_door_locked then
            return
        end

        clear_final_button_state()
        clear_exit_door_state()
        state = STATES.searching_button
        button_search_deadline_t = (gameplay_time() or 0) + BUTTON_SEARCH_WINDOW
        core.request_refresh()
    end

    local function begin_exit_door()
        if not core.is_target() then
            return
        end

        if state == STATES.done or state == STATES.exit_door_locked then
            return
        end

        clear_exit_door_state()
        state = STATES.searching_exit_door
        exit_door_search_deadline_t = (gameplay_time() or 0) + EXIT_DOOR_SEARCH_WINDOW
        core.request_refresh()
    end

    local function wait_for_exit_objective()
        clear_final_button_state()
        clear_exit_door_state()

        if core.active_mission_objective(OBJECTIVES.extraction) then
            begin_exit_door()
        else
            state = STATES.waiting_for_exit_objective
            core.request_refresh()
        end
    end

    local function exit_door_candidate_score(unit, marker)
        if unit == final_button_unit or unit == exit_door_unit or not core.is_valid_unit(unit) then
            return nil
        end

        if marker and marker.distance and marker.distance > FINAL_DOOR_CANDIDATE_MAX_DISTANCE then
            return nil
        end

        if get_door_control_panel_extension(unit) and (not door_panel_is_active(unit) or door_panel_is_on_hold(unit)) then
            return nil
        end

        return security_door_candidate_score(unit)
    end

    local function find_best_final_button(interaction_markers)
        if not interaction_markers then
            return nil
        end

        local best_unit = nil
        local best_score = -1

        for i = 1, #interaction_markers do
            local unit = interaction_markers[i].unit

            if unit then
                local score = button_candidate_score(unit)

                if score and score > best_score then
                    best_unit = unit
                    best_score = score
                end
            end
        end

        return best_unit
    end

    local function find_best_exit_door(interaction_markers)
        if not interaction_markers then
            return nil
        end

        local best_unit = nil
        local best_score = -1

        for i = 1, #interaction_markers do
            local marker = interaction_markers[i]
            local unit = marker.unit

            if unit then
                local score = exit_door_candidate_score(unit, marker)

                if score and score > best_score then
                    best_unit = unit
                    best_score = score
                end
            end
        end

        return best_unit
    end

    local api = {}

    function api.set_external_exclusion(exclusion_function)
        external_exclusion = type(exclusion_function) == "function" and exclusion_function or nil
    end

    function api.on_mission_activated()
        state = STATES.inactive
        clear_final_button_state()
        clear_exit_door_state()
    end

    function api.reset()
        state = STATES.inactive
        clear_final_button_state()
        clear_exit_door_state()
    end

    function api.clear_marker_handles()
        final_button_marker_id = nil
        final_button_marker_pending_frames = nil
        exit_door_marker_id = nil
        exit_door_marker_pending_frames = nil
    end

    function api.ensure_casket_template(world_markers)
        return ensure_casket_template(world_markers)
    end

    function api.ensure_template(world_markers)
        return ensure_template(world_markers)
    end

    function api.begin_final_button()
        begin_final_button()
    end

    function api.begin_exit_door()
        begin_exit_door()
    end

    function api.sync_objectives(delivered_caskets)
        if not core.is_target() then
            return
        end

        if state == STATES.done then
            return
        end

        if core.active_mission_objective(OBJECTIVES.extraction) then
            begin_exit_door()
        elseif core.active_mission_objective(OBJECTIVES.send_assets) or delivered_caskets >= 3 then
            begin_final_button()
        end
    end

    function api.on_objective_started(objective_name, delivered_caskets)
        if objective_name == OBJECTIVES.extraction then
            begin_exit_door()
        elseif objective_name == OBJECTIVES.send_assets or objective_name == OBJECTIVES.deposit and delivered_caskets >= 3 then
            begin_final_button()
        end
    end

    function api.on_door_state_changed(unit)
        if not core.is_target() then
            return
        end

        if state == STATES.button_locked and final_button_unit == unit then
            begin_exit_door()
        elseif state == STATES.exit_door_locked and exit_door_unit == unit then
            finish()
        end
    end

    function api.on_interactable_used(unit)
        if not core.is_target() then
            return
        end

        if state == STATES.button_locked and final_button_unit == unit then
            begin_exit_door()
        elseif state == STATES.exit_door_locked and exit_door_unit == unit then
            finish()
        end
    end

    function api.on_interactable_disabled(unit)
        if not core.is_target() then
            return
        end

        if state == STATES.button_locked and final_button_unit == unit then
            wait_for_exit_objective()
        elseif state == STATES.exit_door_locked and exit_door_unit == unit then
            finish()
        end
    end

    function api.on_interactee_active_changed(unit, is_active)
        if not core.is_target() then
            return
        end

        if is_active then
            if state == STATES.searching_button or state == STATES.searching_exit_door then
                core.request_refresh()
            end
        elseif state == STATES.button_locked and final_button_unit == unit then
            wait_for_exit_objective()
        elseif state == STATES.exit_door_locked and exit_door_unit == unit then
            finish()
        end
    end

    function api.refresh()
        remove_final_button_marker()
        remove_exit_door_marker()

        if state == STATES.button_locked and final_button_unit and core.is_valid_unit(final_button_unit) then
            request_final_button_marker()
        elseif state == STATES.exit_door_locked and exit_door_unit and core.is_valid_unit(exit_door_unit) then
            request_exit_door_marker()
        end
    end

    function api.update(interaction_markers)
        if not core.is_target() then
            return
        end

        if state == STATES.button_locked then
            if not final_button_unit or not core.is_valid_unit(final_button_unit) then
                clear_final_button_state()
                state = STATES.searching_button
                button_search_deadline_t = (gameplay_time() or 0) + BUTTON_SEARCH_WINDOW
            elseif not is_active_interactable(final_button_unit) then
                begin_exit_door()
            else
                update_pending_marker("button")
                request_final_button_marker()
            end
        elseif state == STATES.waiting_for_exit_objective then
            if core.active_mission_objective(OBJECTIVES.extraction) then
                begin_exit_door()
            end
        elseif state == STATES.exit_door_locked then
            if not exit_door_unit or not core.is_valid_unit(exit_door_unit) or not is_active_interactable(exit_door_unit) then
                finish()
                return
            end

            local panel = get_door_control_panel_extension(exit_door_unit)

            if panel and (not call_extension_boolean(panel, "is_active") or call_extension_boolean(panel, "is_on_hold")) then
                finish()
                return
            end

            update_pending_marker("exit")
            request_exit_door_marker()
        end

        if state == STATES.searching_button and not final_button_unit then
            local candidate = find_best_final_button(interaction_markers)

            if candidate then
                final_button_unit = candidate
                state = STATES.button_locked
                button_search_deadline_t = nil
                request_final_button_marker()
            else
                local now = gameplay_time()

                if button_search_deadline_t and now and now > button_search_deadline_t then
                    button_search_deadline_t = now + BUTTON_SEARCH_WINDOW
                end
            end
        elseif state == STATES.searching_exit_door and not exit_door_unit then
            local candidate = find_best_exit_door(interaction_markers)

            if candidate then
                exit_door_unit = candidate
                state = STATES.exit_door_locked
                exit_door_search_deadline_t = nil
                request_exit_door_marker()
            else
                local now = gameplay_time()

                if exit_door_search_deadline_t and now and now > exit_door_search_deadline_t then
                    exit_door_search_deadline_t = now + EXIT_DOOR_SEARCH_WINDOW
                end
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
        return unit ~= nil and (unit == final_button_unit or unit == exit_door_unit)
    end

    function api.has_live_marker(unit)
        if unit == final_button_unit and core.marker_id_is_live(final_button_marker_id, MARKER_TYPE, unit) then
            return true
        end

        return unit == exit_door_unit and core.marker_id_is_live(exit_door_marker_id, MARKER_TYPE, unit) or false
    end

    function api.is_active_interactable(unit)
        return is_active_interactable(unit)
    end

    function api.call_extension_boolean(extension, method_name)
        return call_extension_boolean(extension, method_name)
    end

    function api.security_door_candidate_score(unit, extra_exclusion)
        return security_door_candidate_score(unit, extra_exclusion)
    end

    return api
end
