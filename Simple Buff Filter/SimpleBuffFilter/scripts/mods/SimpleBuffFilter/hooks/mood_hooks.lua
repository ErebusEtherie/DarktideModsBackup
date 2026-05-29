-- File: scripts/mods/SimpleBuffFilter/hooks/mood_hooks.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end


local DIRECT_SCREEN_MODE_TEMPLATE_NAMES = {
    chaos_daemonhost_ambience = true,
    corruptor_ambience = true,
    corruptor_ambience_burrowed = true,
}

-- Session cache to avoid retrying resolutions pointlessly
mod.tbf_mood_session_ignore = mod.tbf_mood_session_ignore or {}

local function _rule_blocks_entry(rule)
    if rule == "hide" then
        return true
    end

    if rule == "only_in_psykhanium" and mod.tbf_ctx and not mod.tbf_ctx.is_psykhanium() then
        return true
    end

    return false
end

local function _resolve_and_check_mood(mood_type, buff_extension)
    if type(mood_type) ~= "string" or mood_type == "" then
        return true
    end

    local prefs = mod.prefs and mod.prefs.buffs
    if not prefs then
        return true
    end

    local entry = prefs[mood_type]
    if entry then
        return not _rule_blocks_entry(entry.rule)
    end

    if mod.tbf_mood_session_ignore[mood_type] then
        return true
    end

    local group, loc = nil, nil
    if mod.tbf_moods and mod.tbf_moods.resolve then
        group, loc = mod.tbf_moods.resolve(mood_type, buff_extension)
    end

    if group and loc then
        mod.prefs_record_buff(mood_type, group, loc, "allow")

        local new_entry = prefs[mood_type]
        if new_entry then
            return not _rule_blocks_entry(new_entry.rule)
        end
    else
        mod.tbf_mood_session_ignore[mood_type] = true
    end

    return true
end

local function _is_local_buff_extension(self)
    return self and self._buff_context and self._buff_context.is_local_unit
end

local function _is_local_fx_extension(self)
    return self and self._is_local_unit
end

local function _is_screenspace_particle(particle_name)
    return type(particle_name) == "string" and particle_name:find("/screenspace/", 1, true) ~= nil
end

local function _plasmagun_low_threshold(self)
    local overheat_configuration = self and self._overheat_configuration
    local thresholds = overheat_configuration and overheat_configuration.thresholds
    local low_threshold = thresholds and thresholds.low

    if type(low_threshold) == "number" then
        return low_threshold
    end

    return nil
end

-- ============================================================================
-- NATIVE MOODS
-- ============================================================================
if not mod._tbf_moods_add_mood_hooked then
    mod:hook("PlayerUnitMoodExtension", "_add_mood", function(func, self, t, mood_type, reset_time)
        if self._is_local_human then
            if not _resolve_and_check_mood(mood_type, self._buff_extension) then
                return
            end
        end

        return func(self, t, mood_type, reset_time)
    end)

    mod._tbf_moods_add_mood_hooked = true
end

-- ============================================================================
-- BUFF-DRIVEN SCREEN EFFECTS (CONTINUOUS)
-- Record/filter by the actual on-screen particle path so this stays separate
-- from the buff icon rule space while still merging inside group == "moods".
-- ============================================================================
if not mod._tbf_moods_buff_fx_hooked then
    mod:hook("PlayerUnitBuffExtension", "start_on_screen_effect",
        function(func, self, index, on_screen_effect, stop_type, world)
            if _is_local_buff_extension(self) then
                if type(on_screen_effect) == "string" and on_screen_effect ~= "" then
                    if not _resolve_and_check_mood(on_screen_effect, self) then
                        return
                    end
                end
            end

            return func(self, index, on_screen_effect, stop_type, world)
        end)

    mod._tbf_moods_buff_fx_hooked = true
end

-- ============================================================================
-- BUFF-DRIVEN SCREEN EFFECTS (MOMENTARY / PROC)
-- Proc buffs directly call World.create_particles bypassing FX extensions.
-- We intercept their local startup, temporarily wiping the particle path
-- from the template if SBF blocks it, preventing the engine from spawning it.
-- Performance Impact: Minimal. Only executes when a proc buff activates,
-- avoiding high-frequency global particle spawn hooks.
-- ============================================================================
local BuffClasses = require("scripts/settings/buff/buff_classes")

if not mod._tbf_moods_proc_buff_hooked then
    for _, BuffClass in pairs(BuffClasses) do
        if type(BuffClass) == "table" and BuffClass._start_proc_active_fx then
            mod:hook(BuffClass, "_start_proc_active_fx", function(func, self, ...)
                local template = self._template
                local proc_effects = template and template.proc_effects
                local player_effects = proc_effects and proc_effects.player_effects
                local on_screen_effect = player_effects and player_effects.on_screen_effect

                if on_screen_effect and self._template_context and self._template_context.is_local_unit then
                    if not _resolve_and_check_mood(on_screen_effect, nil) then
                        player_effects.on_screen_effect = nil
                        func(self, ...)
                        player_effects.on_screen_effect = on_screen_effect
                        return
                    end
                end

                return func(self, ...)
            end)
        end
    end
    mod._tbf_moods_proc_buff_hooked = true
end

-- ============================================================================
-- LOCAL EXCLUSIVE SCREENSPACE PARTICLES
-- Captures things like stun/blood splatter style overlays.
-- ============================================================================
if not mod._tbf_moods_exclusive_particle_hooked then
    mod:hook("PlayerUnitFxExtension", "spawn_exclusive_particle", function(func, self, particle_name, ...)
        if _is_local_fx_extension(self) and _is_screenspace_particle(particle_name) then
            if not _resolve_and_check_mood(particle_name, nil) then
                return
            end
        end

        return func(self, particle_name, ...)
    end)

    mod._tbf_moods_exclusive_particle_hooked = true
end

-- ============================================================================
-- GLOBAL SCREEN-MODE TEMPLATE EFFECTS
-- Captures ambience-style visual effects such as daemonhost/corruptor.
-- ============================================================================
if not mod._tbf_moods_start_template_effect_hooked then
    mod:hook("FxSystem", "start_template_effect", function(func, self, template, ...)
        local template_name = template and template.name

        if DIRECT_SCREEN_MODE_TEMPLATE_NAMES[template_name] then
            if not _resolve_and_check_mood(template_name, nil) then
                return
            end
        end

        return func(self, template, ...)
    end)

    mod._tbf_moods_start_template_effect_hooked = true
end

-- Guard against nil ids if a start_template_effect call was blocked above.
if not mod._tbf_moods_stop_template_effect_hooked then
    mod:hook("FxSystem", "stop_template_effect", function(func, self, global_effect_id)
        if global_effect_id == nil then
            return
        end

        return func(self, global_effect_id)
    end)

    mod._tbf_moods_stop_template_effect_hooked = true
end

-- ============================================================================
-- PLASMAGUN OVERHEAT SCREENSPACE
-- Only check SBF when the effect is about to start.
-- If blocked, cache that decision until overheat drops back to/below the
-- vanilla low threshold, then allow a fresh check on the next start cycle.
-- ============================================================================
if not mod._tbf_moods_plasmagun_hooked then
    mod:hook("PlasmagunOverheatEffects", "_update_screenspace", function(func, self, overheat_percentage)
        local effect_name = self and self._on_screen_effect

        if self and self._is_local_unit and type(effect_name) == "string" and effect_name ~= "" then
            local low_threshold = _plasmagun_low_threshold(self)

            if low_threshold and overheat_percentage <= low_threshold then
                self._tbf_plasma_screen_effect_start_blocked = nil
            elseif low_threshold and not self._on_screen_effect_id and low_threshold < overheat_percentage then
                if self._tbf_plasma_screen_effect_start_blocked then
                    return
                end

                if not _resolve_and_check_mood(effect_name, nil) then
                    self._tbf_plasma_screen_effect_start_blocked = true
                    return
                end
            end
        end

        return func(self, overheat_percentage)
    end)

    mod._tbf_moods_plasmagun_hooked = true
end
