-- ===== File: Targeter/scripts/mods/Targeter/Targeter_data.lua =====
local mod = get_mod("Targeter")
if not mod then return end

local DMF = get_mod("DMF")
if not DMF then return end

mod:io_dofile("Targeter/scripts/mods/Targeter/Targeter_init")

local function _clone_options(opts)
    local len = #opts
    local clone = Script.new_array(len)

    for i = 1, len do
        local opt = opts[i]
        clone[i] = { text = opt.text, value = opt.value }
    end

    clone.localize = opts.localize

    return clone
end

-- ####################################################################
-- ##### Crosshair discovery (vanilla + Targeter + other mods) ########
-- ####################################################################
local crosshair_options = mod.get_crosshair_options()

-- ####################################################################
-- ##### Color dropdown options (AugurArray-style) ####################
-- ####################################################################
local color_list = Color.list
local color_options = Script.new_array(#color_list)

for i = 1, #color_list do
    local color_name = color_list[i]
    color_options[i] = { text = color_name, value = color_name }
end

table.sort(color_options, function(a, b) return a.text < b.text end)

local function _pick_color(preferred, fallback)
    for i = 1, #color_options do
        if color_options[i].value == preferred then
            return preferred
        end
    end
    if fallback then
        for i = 1, #color_options do
            if color_options[i].value == fallback then
                return fallback
            end
        end
    end
    return (color_options[1] and color_options[1].value) or "ui_terminal"
end

-- ####################################################################
-- ##### Weapon-class dropdown options ################################
-- ####################################################################
local weapon_class_options = {}

if mod.HARDCODED_CLASSES then
    local hardcoded = mod.HARDCODED_CLASSES
    for i = 1, #hardcoded do
        local hc = hardcoded[i]
        weapon_class_options[#weapon_class_options + 1] = { text = hc, value = hc }
    end
end

if mod.dynamic_weapon_classes then
    local dynamic = mod.dynamic_weapon_classes
    for i = 1, #dynamic do
        local dyn = dynamic[i]
        weapon_class_options[#weapon_class_options + 1] = { text = dyn, value = dyn }
    end
end

-- ####################################################################
-- ##### Action-state selector options ################################
-- ####################################################################
local action_state_options = {
    { text = "action_primary",   value = "primary" },
    { text = "action_secondary", value = "secondary" },
    { text = "action_special",   value = "special" },
}

-- ####################################################################
-- ##### Widget Helpers ###############################################
-- ####################################################################
local function _dropdown(setting_id, default_value, options)
    return {
        setting_id = setting_id,
        type = "dropdown",
        default_value = default_value,
        options = _clone_options(options),
        description = setting_id .. "_description",
    }
end

local function _color_channel(prefix, channel, default_value)
    return {
        setting_id = prefix .. "_" .. channel,
        type = "numeric",
        default_value = default_value,
        range = { 0, 255 },
    }
end

local function _color_group(group_prefix, default_color_name)
    return {
        setting_id = "group_" .. group_prefix .. "_color",
        type = "group",
        description = "group_" .. group_prefix .. "_color_description",
        sub_widgets = {
            {
                setting_id = group_prefix .. "_color",
                type = "dropdown",
                default_value = default_color_name,
                options = _clone_options(color_options),
            },
            _color_channel(group_prefix, "alpha", 255),
        }
    }
end

-- ####################################################################
-- ##### First-run defaults for runtime (non-UI) ######################
-- ####################################################################
mod._default_settings = {
    default_alpha               = 255,
    target_locked_alpha         = 255,
    weakspot_locked_alpha       = 255,

    default_color               = _pick_color("white", "ui_white"),
    target_locked_color         = _pick_color("citadel_troll_slayer_orange", "ui_yellow_light"),
    weakspot_locked_color       = _pick_color("ui_zealot", "ui_red_medium"),

    shape_editor_action_state   = "primary",
    shape_editor_default_shape  = "weapon_default",
    shape_editor_enemy_shape    = "weapon_default",
    shape_editor_weakspot_shape = "weapon_default",
    shape_editor_weapon_class   = "melee_class",
    use_current_ranged_weapon   = false,
}

-- ####################################################################
-- ##### Main Return Data #############################################
-- ####################################################################
return {
    name = "Targeter",
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "color_settings",
                type = "group",
                description = "color_settings_description",
                sub_widgets = {
                    _color_group("default", _pick_color("white", "ui_white")),
                    _color_group("target_locked", _pick_color("citadel_troll_slayer_orange", "ui_yellow_light")),
                    _color_group("weakspot_locked", _pick_color("ui_zealot", "ui_red_medium")),
                }
            },
            {
                setting_id = "shape_editor",
                type = "group",
                description = "shape_editor_description",
                sub_widgets = {
                    {
                        setting_id    = "shape_editor_weapon_class",
                        type          = "dropdown",
                        default_value = "melee_class",
                        options       = _clone_options(weapon_class_options),
                        description   = "shape_editor_weapon_class_description",
                    },
                    {
                        setting_id    = "use_current_ranged_weapon",
                        type          = "checkbox",
                        default_value = false,
                        description   = "use_current_ranged_weapon_description",
                    },
                    {
                        setting_id    = "shape_editor_action_state",
                        type          = "dropdown",
                        default_value = "primary",
                        options       = _clone_options(action_state_options),
                        description   = "shape_editor_action_state_description",
                    },
                    _dropdown("shape_editor_default_shape", "weapon_default", crosshair_options),
                    _dropdown("shape_editor_enemy_shape", "weapon_default", crosshair_options),
                    _dropdown("shape_editor_weakspot_shape", "weapon_default", crosshair_options),
                }
            },
        }
    }
}
