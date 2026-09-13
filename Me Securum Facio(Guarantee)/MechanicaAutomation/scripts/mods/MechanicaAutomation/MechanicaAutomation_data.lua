local mod = get_mod("MechanicaAutomation")

local function safe_get(setting_id, fallback)
    if not mod or not mod.get then
        return fallback
    end

    local ok, value = pcall(mod.get, mod, setting_id)
    if ok and value ~= nil then
        return value
    end

    return fallback
end

local function normalize_language(language)
    language = tostring(language or "pt-br"):lower()
    if language == "br-pt" or language == "pt_br" then
        return "pt-br"
    end

    if language ~= "en" and language ~= "es" and language ~= "pt-br" then
        return "pt-br"
    end

    return language
end

local function safe_color_component(value, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value < 0 then
        return 0
    end

    if value > 255 then
        return 255
    end

    return math.floor(value + 0.5)
end

local function color(text, r, g, b)
    text = tostring(text or "")
    r = safe_color_component(r, 255)
    g = safe_color_component(g, 255)
    b = safe_color_component(b, 255)

    return string.format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, text)
end

local function L(en, pt_br, es)
    return {
        en = en,
        ["pt-br"] = pt_br or en,
        es = es or en,
    }
end

local TEXT = {
    mod_name = L(
        color("MECHANICA", 128, 255, 156) .. color(" // ", 255, 190, 70) .. color("AUTOMATION", 92, 214, 255),
        color("MECHANICA", 128, 255, 156) .. color(" // ", 255, 190, 70) .. color("AUTOMACAO", 92, 214, 255),
        color("MECHANICA", 128, 255, 156) .. color(" // ", 255, 190, 70) .. color("AUTOMATIZACION", 92, 214, 255)
    ),
    mod_description = L(
        color("Servo-skull automation for Skitarii puzzles/tasks, Noospheric Command refresh, and auto ping.", 176, 224, 192)
            .. "\n"
            .. color("Author: ", 255, 190, 70)
            .. color("Eduardo Do Carmo", 232, 238, 226)
            .. color("  |  Nicks: ", 255, 190, 70)
            .. color("TioKill", 232, 238, 226)
            .. color("  |  Darktide: ", 255, 190, 70)
            .. color("Sicarius", 232, 238, 226)
            .. "\n ",
        color("Automacao de servocranio para puzzles/tasks do Skitarii, auto ping e refresh do Comando Noosferico.", 176, 224, 192)
            .. "\n"
            .. color("Autor: ", 255, 190, 70)
            .. color("Eduardo Do Carmo", 232, 238, 226)
            .. color("  |  Nicks: ", 255, 190, 70)
            .. color("TioKill", 232, 238, 226)
            .. color("  |  Darktide: ", 255, 190, 70)
            .. color("Sicarius", 232, 238, 226)
            .. "\n ",
        color("Automatizacion de servocraneo para puzzles/tareas del Skitarii, auto ping y refresco del Comando Noosferico.", 176, 224, 192)
            .. "\n"
            .. color("Autor: ", 255, 190, 70)
            .. color("Eduardo Do Carmo", 232, 238, 226)
            .. color("  |  Nicks: ", 255, 190, 70)
            .. color("TioKill", 232, 238, 226)
            .. color("  |  Darktide: ", 255, 190, 70)
            .. color("Sicarius", 232, 238, 226)
            .. "\n "
    ),

    general_settings = L(color("Interface Core", 255, 205, 82), color("Interface Core", 255, 205, 82), color("Nucleo de Interfaz", 255, 205, 82)),
    task_settings = L(color("Servo Artificer Puzzle Cortex", 84, 218, 255), color("Cortex de Puzzles do Servo Artifice", 84, 218, 255), color("Cortex de Puzzles del Servo Artifice", 84, 218, 255)),
    noosphere_settings = L(color("Noospheric Command Loop", 132, 170, 255), color("Loop de Comando Noosferico", 132, 170, 255), color("Bucle de Comando Noosferico", 132, 170, 255)),
    smart_pox_settings = L(color("Smart Pox Protocol", 255, 86, 70), color("Protocolo Pox Inteligente", 255, 86, 70), color("Protocolo Pox Inteligente", 255, 86, 70)),
    advanced_settings = L(color("Machine Spirit Safeguards", 198, 205, 190), color("Salvaguardas do Espirito-Maquina", 198, 205, 190), color("Salvaguardas del Espiritu-Maquina", 198, 205, 190)),
}

local current_language = normalize_language(safe_get("panel_language", "pt-br"))

local function tr(key)
    local entry = TEXT[key]
    if entry then
        return entry[current_language] or entry.en
    end

    return mod:localize(key)
end

local function checkbox(setting_id, default_value, tooltip, sub_widgets)
    return {
        setting_id = setting_id,
        type = "checkbox",
        default_value = default_value,
        title = tr(setting_id),
        tooltip = tooltip and tr(tooltip) or nil,
        localize = false,
        sub_widgets = sub_widgets,
    }
end

local function numeric(setting_id, default_value, range, tooltip, decimals_number, unit_text)
    return {
        setting_id = setting_id,
        type = "numeric",
        default_value = default_value,
        range = range,
        title = tr(setting_id),
        tooltip = tooltip and tr(tooltip) or nil,
        localize = false,
        decimals_number = decimals_number,
        unit_text = unit_text and tr(unit_text) or nil,
    }
end

local function localized_options(items)
    local result = {}

    for i = 1, #items do
        local item = items[i]
        result[i] = {
            text = tr(item.text),
            value = item.value,
        }
    end

    result.localize = false
    return result
end

local function dropdown(setting_id, default_value, options, tooltip, title)
    return {
        setting_id = setting_id,
        type = "dropdown",
        default_value = default_value,
        title = title or tr(setting_id),
        options = localized_options(options),
        tooltip = tooltip and tr(tooltip) or nil,
        localize = false,
    }
end

local function group(setting_id, sub_widgets)
    return {
        setting_id = setting_id,
        type = "group",
        title = tr(setting_id),
        localize = false,
        sub_widgets = sub_widgets,
    }
end

local language_options = {
    { text = "language_en", value = "en" },
    { text = "language_es", value = "es" },
    { text = "language_pt_br", value = "pt-br" },
}

local widgets = {
    group("general_settings", {
        dropdown("panel_language", "pt-br", language_options, "panel_language_tooltip"),
        checkbox("toggle_mod", true, "toggle_mod_tooltip"),
        checkbox("auto_ping_enabled", true, "auto_ping_enabled_tooltip"),
        {
            setting_id = "toggle_mod_keybind",
            type = "keybind",
            default_value = {},
            title = tr("toggle_mod_keybind"),
            localize = false,
            keybind_trigger = "pressed",
            keybind_type = "function_call",
            function_name = "toggle_mod",
        },
        checkbox("toggle_notifications", true, "toggle_notifications_tooltip"),
        checkbox("debug_mode", false, "debug_mode_tooltip"),
    }),
    group("noosphere_settings", {
        checkbox("noosphere_enabled", true, "noosphere_enabled_tooltip"),
        numeric("noosphere_interval", 1.60, { 1.50, 2.00 }, "noosphere_interval_tooltip", 2, "seconds"),
        numeric("noosphere_release_health_percent", 0, { 0, 90 }, "noosphere_release_health_percent_tooltip", 0, "percent"),
        checkbox("noosphere_auto_target", true, "noosphere_auto_target_tooltip"),
        checkbox("noosphere_skip_passive_daemonhost", true, "noosphere_skip_passive_daemonhost_tooltip"),
    }),
    group("task_settings", {
        checkbox("auto_tasks_enabled", true, "auto_tasks_enabled_tooltip"),
        numeric("task_interval", 0.55, { 0.25, 5.00 }, "task_interval_tooltip", 2, "seconds"),
        numeric("task_max_range", 15, { 5, 15 }, "task_max_range_tooltip", 0, "meters"),
        checkbox("task_prefer_crosshair", true, "task_prefer_crosshair_tooltip"),
        checkbox("task_use_interactor_target", true, "task_use_interactor_target_tooltip"),
        checkbox("task_use_scannable_units", true, "task_use_scannable_units_tooltip"),
        checkbox("task_require_los", true, "task_require_los_tooltip"),
        checkbox("task_ignore_pickups", true, "task_ignore_pickups_tooltip"),
        numeric("task_context_memory", 2.50, { 0.50, 5.00 }, "task_context_memory_tooltip", 2, "seconds"),
        checkbox("task_fast_retry_on_new_context", true, "task_fast_retry_on_new_context_tooltip"),
        checkbox("task_cancel_burst_on_invalid_target", true, "task_cancel_burst_on_invalid_target_tooltip"),
        numeric("task_burst_attempts", 10, { 1, 10 }, "task_burst_attempts_tooltip", 0, "requests"),
        numeric("task_burst_spacing", 0.08, { 0.08, 0.35 }, "task_burst_spacing_tooltip", 2, "seconds"),
        checkbox("task_trigger_interaction", false, "task_trigger_interaction_tooltip"),
    }),
    group("smart_pox_settings", {
        checkbox("smart_pox_enabled", true, "smart_pox_enabled_tooltip"),
        numeric("smart_pox_max_range", 45, { 15, 100 }, "smart_pox_max_range_tooltip", 0, "meters"),
        numeric("smart_pox_min_distance", 10, { 10, 30 }, "smart_pox_min_distance_tooltip", 0, "meters"),
        numeric("smart_pox_ally_safe_radius", 10, { 10, 30 }, "smart_pox_ally_safe_radius_tooltip", 0, "meters"),
        checkbox("smart_pox_require_los", true, "smart_pox_require_los_tooltip"),
    }),
    group("advanced_settings", {
        checkbox("alert_hud_enabled", true, "alert_hud_enabled_tooltip"),
        numeric("alert_hud_range", 45, { 10, 100 }, "alert_hud_range_tooltip", 0, "meters"),
        numeric("alert_hud_interval", 1.00, { 0.35, 5.00 }, "alert_hud_interval_tooltip", 2, "seconds"),
    }),
}

return {
    name = tr("mod_name"),
    description = tr("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets,
    },
}
