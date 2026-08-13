local mod = get_mod("ServoSkullTransparency")

local Managers = Managers
local ScriptUnit = ScriptUnit
local CLASS = CLASS
local GameSession = GameSession
local table = table
local Vector3 = Vector3
local Quaternion = Quaternion
local World = World
local Application = Application
local Unit = Unit
local math = math

local SpecialRulesSettings = mod:original_require("scripts/settings/ability/special_rules_settings")
local SPECIAL_RULE_HACK = SpecialRulesSettings.special_rules.cryptic_servo_skull_hack

local CompanionServoSkullSettings = mod:original_require("scripts/settings/companion/companion_servo_skull_settings")
local SERVO_SKULL_STATES = CompanionServoSkullSettings.STATES
local FOLLOWING_STATES = {
    [SERVO_SKULL_STATES.following] = true,
    [SERVO_SKULL_STATES.following_shooting] = true,
    [SERVO_SKULL_STATES.following_shooting_ability] = true,
}

local tracked_units = {}

local function collect_child_units(unit)
    local children = {}
    local function recurse(u)
        local child_units = Unit.get_child_units(u)
        if child_units then
            for _, child in pairs(child_units) do
                children[child] = true
                recurse(child)
            end
        end
    end
    recurse(unit)
    return children
end

local function get_min_fade()
    local opacity = mod:get("opacity") or 100
    return 1 - (opacity / 100)
end

local function get_servo_skull_state(unit)
    if not unit or not ALIVE[unit] then
        return nil
    end

    local game_session = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    local game_object_exists = GameSession.game_object_exists(game_session, game_object_id)

    if not game_object_exists then
        return nil
    end

    return GameSession.game_object_field(game_session, game_object_id, "state")
end

local function is_following(unit)
    local state = get_servo_skull_state(unit)
    return state and FOLLOWING_STATES[state]
end

local function fade_skull(unit, min_fade)
    local fade_system = Managers.state.extension and Managers.state.extension:system("fade_system")
    if fade_system then
        fade_system:set_min_fade(unit, min_fade)
    end
end

local function fade_child(unit, opacity_value)
    if not Unit.is_valid(unit) then
        return
    end
    Unit.set_shader_pass_flag_for_meshes(unit, "one_bit_alpha", true, true)
    Unit.set_scalar_for_materials(unit, "inv_jitter_alpha", 1 - opacity_value, true)
    Unit.set_scalar_for_materials(unit, "alpha_multiplier", opacity_value, true)
end

local function apply_fade(unit, min_fade, is_child)
    if is_child then
        fade_child(unit, 1 - min_fade)
    else
        fade_skull(unit, min_fade)
    end
end

local function apply_unfade(unit, is_child)
    if is_child then
        fade_child(unit, 1)
    else
        fade_skull(unit, 0)
    end
end

local function fade_and_track(unit, min_fade, parent)
    apply_fade(unit, min_fade, parent ~= nil)
    tracked_units[unit] = { is_faded = true, parent = parent }
end

local function discover_children(skull_unit, min_fade)
    local children = collect_child_units(skull_unit)
    for child, _ in pairs(children) do
        if not tracked_units[child] then
            fade_and_track(child, min_fade, skull_unit)
        end
    end
end

local CHECK_INTERVAL = 0.25
local check_timer = 0

mod.update = function(dt, t)
    check_timer = check_timer + dt
    if check_timer < CHECK_INTERVAL then
        return
    end
    check_timer = 0

    local min_fade = get_min_fade()

    local player = Managers.player:local_player_safe(1)
    if player then
        local player_unit = player.player_unit
        if player_unit then
            local companion_spawner = ScriptUnit.has_extension(player_unit, "companion_spawner_system")
            if companion_spawner then
                local skull_unit = companion_spawner:spawned_unit_lookup(SPECIAL_RULE_HACK)
                if skull_unit and ALIVE[skull_unit] and not tracked_units[skull_unit] then
                    fade_and_track(skull_unit, min_fade)
                    discover_children(skull_unit, min_fade)
                end
            end
        end
    end

    local dead_units = {}

    for unit, data in pairs(tracked_units) do
        local skull_unit = data.parent or unit
        local is_child = data.parent ~= nil
        local unit_alive

        if is_child then
            unit_alive = Unit.is_valid(unit)
        else
            unit_alive = ALIVE[unit]
        end

        if not unit_alive then
            dead_units[unit] = true
        elseif is_following(skull_unit) then
            if not data.is_faded then
                apply_fade(unit, min_fade, is_child)
                data.is_faded = true
            end
        else
            if data.is_faded then
                apply_unfade(unit, is_child)
                data.is_faded = false
            end
        end
    end

    for unit, _ in pairs(dead_units) do
        tracked_units[unit] = nil
    end
end

mod:hook("CompanionSpawnerExtension", "spawn_companion_unit", function(func, self, optional_position, optional_rotation, optional_special_rule, optional_companion_tag_extension)
    local spawned_unit = func(self, optional_position, optional_rotation, optional_special_rule, optional_companion_tag_extension)

    if optional_special_rule == SPECIAL_RULE_HACK and spawned_unit then
        local min_fade = get_min_fade()
        fade_and_track(spawned_unit, min_fade)
        discover_children(spawned_unit, min_fade)
    end

    return spawned_unit
end)

local DEFAULT_VFOV = mod:original_require("scripts/foundation/utilities/parameters/default_game_parameters").vertical_fov

local function is_fov_correction_enabled()
    return mod:get("fix_fov_position")
end

local function get_fov_correction_factor()
    local vertical_fov = Application.user_setting("render_settings", "vertical_fov") or DEFAULT_VFOV
    if vertical_fov == DEFAULT_VFOV then
        return nil
    end
    local linear_mult = vertical_fov / DEFAULT_VFOV
    local half_fov_rad = math.rad(vertical_fov / 2)
    local half_default_rad = math.rad(DEFAULT_VFOV / 2)
    local tan_mult = math.tan(half_fov_rad) / math.tan(half_default_rad)
    local correction = tan_mult / linear_mult
    if math.abs(correction - 1.0) < 0.0005 then
        return nil
    end
    return correction
end

local function apply_fov_position_correction(self)
    local unit = self._unit
    if not unit or not ALIVE[unit] then
        return
    end

    local game_session = self._game_session
    local game_object_id = self._game_object_id

    if not GameSession.game_object_exists(game_session, game_object_id) then
        return
    end

    local state = GameSession.game_object_field(game_session, game_object_id, "state")

    if not FOLLOWING_STATES[state] then
        return
    end

    local blackboard = self._blackboard
    if blackboard then
        local behavior = blackboard.behavior
        if behavior and behavior.has_move_to_position then
            return
        end
    end

    local correction = get_fov_correction_factor()
    if not correction then
        return
    end

    local first_person_extension = self._first_person_extension
    local first_person_unit = first_person_extension:first_person_unit()
    local first_person_position = Unit.world_position(first_person_unit, 1)

    local owner_rotation
    if self._is_hub then
        owner_rotation = Unit.local_rotation(self._owner_unit, 1)
    else
        owner_rotation = first_person_extension:extrapolated_rotation()
    end

    local owner_right_flat = Vector3.normalize(Vector3.flat(Quaternion.right(owner_rotation)))
    local current_pos = Unit.world_position(unit, 1)

    local to_unit = current_pos - first_person_position
    local x_offset = Vector3.dot(to_unit, owner_right_flat)

    local correction_delta = x_offset * (correction - 1.0)
    local corrected_pos = current_pos + owner_right_flat * correction_delta

    Unit.set_local_position(unit, 1, corrected_pos)

    if self._old_position then
        local old_pos = self._old_position:unbox()
        local adjusted_old = Vector3(
            old_pos.x + owner_right_flat.x * correction_delta,
            old_pos.y + owner_right_flat.y * correction_delta,
            old_pos.z
        )
        self._old_position:store(adjusted_old)
    end

    World.update_unit_and_children(self._world, unit)
end

mod:hook("FlyingCompanionMovementExtension", "post_update", function(func, self, unit, dt, t)
    func(self, unit, dt, t)

    if is_fov_correction_enabled() then
        apply_fov_position_correction(self)
    end
end)

mod:hook("FlyingCompanionHuskMovementExtension", "post_update", function(func, self, unit, dt, t)
    func(self, unit, dt, t)

    if is_fov_correction_enabled() then
        apply_fov_position_correction(self)
    end
end)

mod.on_setting_changed = function(setting_id)
    if setting_id == "opacity" then
        local min_fade = get_min_fade()
        for unit, data in pairs(tracked_units) do
            if data.is_faded then
                local is_child = data.parent ~= nil
                local unit_alive = is_child and Unit.is_valid(unit) or ALIVE[unit]
                if unit_alive then
                    apply_fade(unit, min_fade, is_child)
                end
            end
        end
    end
end

local function restore_all()
    for unit, data in pairs(tracked_units) do
        local is_child = data.parent ~= nil
        local unit_alive = is_child and Unit.is_valid(unit) or ALIVE[unit]
        if unit_alive then
            apply_unfade(unit, is_child)
        end
    end
    table.clear(tracked_units)
end

mod.on_game_state_changed = function(status, state_name)
    if status == "exit" then
        restore_all()
    end
end

mod.on_disabled = function(initial_call)
    restore_all()
end

mod.on_unload = function()
    restore_all()
end
