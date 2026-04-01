local mod = get_mod("AutoVault")

local enabled = false
local only_forward = false
local hotkey_enabled = true

mod.on_enabled = function()
    enabled = true
    only_forward = mod:get("onlyForward")
end

mod.on_disabled = function()
    enabled = false
end

mod.on_setting_changed = function()
    only_forward = mod:get("onlyForward")
end

function mod.toggle_auto_vault_hotkey()
    hotkey_enabled = not hotkey_enabled

    if hotkey_enabled then
        mod:echo("Auto Vault: ON")
    else
        mod:echo("Auto Vault: OFF")
    end
end

local AUSPEX_VIEW_PATTERNS = {
    "auspex",
    "expedition",
    "minigame",
    "puzzle",
    "decode",
    "scanner",
    "scan",
    "servo_skull",
}

local function string_contains_any_pattern(str, patterns)
    if type(str) ~= "string" then
        return false
    end

    local lower_str = string.lower(str)

    for i = 1, #patterns do
        if string.find(lower_str, patterns[i], 1, true) then
            return true
        end
    end

    return false
end

local function is_auspex_view_open()
    local managers = rawget(_G, "Managers")
    if not managers then
        return false
    end

    local ui_manager = managers.ui
    if not ui_manager then
        return false
    end

    local active_views = rawget(ui_manager, "_active_views")
    if active_views then
        for view_name, _ in pairs(active_views) do
            if string_contains_any_pattern(view_name, AUSPEX_VIEW_PATTERNS) then
                return true
            end
        end
    end

    local active_elements = rawget(ui_manager, "_active_constant_elements")
    if active_elements then
        for element_name, _ in pairs(active_elements) do
            if string_contains_any_pattern(element_name, AUSPEX_VIEW_PATTERNS) then
                return true
            end
        end
    end

    local using_cursor = false
    if ui_manager.is_using_cursor then
        using_cursor = ui_manager:is_using_cursor()
    end

    if using_cursor then
        local current_view_instance = rawget(ui_manager, "_current_view_instance")
        if current_view_instance then
            local view_name = rawget(current_view_instance, "view_name")
                or rawget(current_view_instance, "_view_name")
                or rawget(current_view_instance, "name")

            if string_contains_any_pattern(view_name, AUSPEX_VIEW_PATTERNS) then
                return true
            end
        end
    end

    return false
end

mod:hook("InputService", "_get", function(func, self, action_name)
    local original_result = func(self, action_name)

    if not enabled or not hotkey_enabled then
        return original_result
    end

    if action_name ~= "jump_held" then
        return original_result
    end

    if is_auspex_view_open() then
        return original_result
    end

    if only_forward then
        return func(self, "move_forward") == 1
    end

    return true
end)