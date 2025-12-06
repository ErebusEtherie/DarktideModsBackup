-- File: RingHud/scripts/mods/RingHud/features/stimm_targeting.lua
local mod = get_mod("RingHud")
if not mod then return end

-- Guard against double-loading (one file owns all ActionTargetAlly hooks)
if mod._stimm_targeting_loaded then
    return
end
mod._stimm_targeting_loaded         = true

-- Cross-file state (read-only from other modules; write from this file only)
mod.stimm_target_is_active          = false                                     -- true while *local* player is aiming a syringe (ActionTargetAlly)
mod.stimm_target_pids               = mod.stimm_target_pids or {}               -- [peer_id] = true (at most 1)
mod.stimm_target_tint_by_pid        = mod.stimm_target_tint_by_pid or {}        -- [peer_id] = ARGB-255 color
mod.stimm_target_force_float_by_pid = mod.stimm_target_force_float_by_pid or {} -- [peer_id] = true while aiming
mod.stimm_target_variant_current    = nil                                       -- "health" | "toughness" | "speed" | "damage" | "stamina" | nil
mod.stimm_target_tint_current       = nil                                       -- cached ARGB-255 for quick writes during aim

--========== Internals ==========

local ActionTargetAlly              = require("scripts/extension_systems/weapon/actions/action_target_ally")

local function _local_player_unit()
    local lp = Managers.player and Managers.player:local_player_safe(1)
    return lp and lp.player_unit or nil
end

local function _is_local_owner(self)
    local owner = self and (self._owner_unit or self._player_unit)
    local lpu   = _local_player_unit()
    return owner and lpu and owner == lpu
end

-- Best-effort detection of whether the current weapon template is a syringe (stimm)
local function _weapon_template_of_action(self)
    -- Common on ActionWeaponBase-derived actions
    if self and self._weapon_template then
        return self._weapon_template
    end
    -- Fallbacks (defensive)
    if self and self._weapon_extension then
        if self._weapon_extension.weapon_template then
            return self._weapon_extension:weapon_template()
        end
        if self._weapon_extension.template then
            return self._weapon_extension:template()
        end
    end
    return nil
end

local function _keywords_has(keywords, needle)
    if not keywords or not needle then
        return false
    end
    for i = 1, #keywords do
        local k = keywords[i]
        if k == needle or (type(k) == "string" and string.find(k, needle, 1, true)) then
            return true
        end
    end
    return false
end

local function _is_syringe_template(tmpl)
    if not tmpl then return false end
    -- Primary test: explicit "syringe"/"stimm" keyword (generator adds this)
    if _keywords_has(tmpl.keywords, "syringe") or _keywords_has(tmpl.keywords, "stimm") then
        return true
    end
    -- Fallback: name hints
    local n = string.lower(tostring(tmpl.name or ""))
    return string.find(n, "syringe", 1, true) or string.find(n, "stimm", 1, true) or false
end

-- Try to infer stimm variant from template (used for HUD tint)
local function _infer_stimm_variant(tmpl)
    if not tmpl then return "health" end
    local n  = string.lower(tostring(tmpl.name or ""))
    local kw = tmpl.keywords or {}

    local function has(hint)
        return string.find(n, hint, 1, true) or _keywords_has(kw, hint)
    end

    if has("heal") or has("medicae") then
        return "health"
    elseif has("tough") or has("guard") or has("shield") then
        return "toughness"
    elseif has("speed") or has("haste") then
        return "speed"
    elseif has("crit") or has("damage") or has("frenzy") or has("power") or has("strength") then
        return "damage"
    elseif has("stamina") or has("endurance") then
        return "stamina"
    end

    -- Safe default if we can't tell
    return "health"
end

local function _clear_target_maps()
    for k in pairs(mod.stimm_target_pids) do
        mod.stimm_target_pids[k] = nil
    end
    for k in pairs(mod.stimm_target_tint_by_pid) do
        mod.stimm_target_tint_by_pid[k] = nil
    end
    for k in pairs(mod.stimm_target_force_float_by_pid) do
        mod.stimm_target_force_float_by_pid[k] = nil
    end
end

local function _reset_all_state()
    mod.stimm_target_is_active       = false
    mod.stimm_target_variant_current = nil
    mod.stimm_target_tint_current    = nil
    _clear_target_maps()
end

local function _pid_from_unit(unit)
    if not unit or not Unit.alive(unit) then
        return nil
    end
    local player = Managers.player and Managers.player:owner(unit)
    if not player then
        return nil
    end
    -- Prefer peer_id for humans; bots fall back to a stable synthetic id
    if player.peer_id then
        local pid_ok, pid = pcall(function() return player:peer_id() end)
        if pid_ok and pid then
            return pid
        end
    end
    -- Synthetic id for bots / edge cases (string, to avoid collisions with numeric peer_ids)
    local slot = (player.local_player_id and player:local_player_id()) or 0
    return "bot_" .. tostring(slot)
end

--===================== Hooks (single owner) =====================

-- Entering ally-aim: decide if this ActionTargetAlly belongs to a syringe
mod:hook_safe(ActionTargetAlly, "start", function(self, action_settings, t, time_scale, ...)
    if not _is_local_owner(self) then
        return
    end

    local tmpl = _weapon_template_of_action(self)
    if not _is_syringe_template(tmpl) then
        -- Not a syringe aim (could be “give medkit/ammo”), make sure we’re clean.
        _reset_all_state()
        return
    end

    -- It is a syringe (stimm)
    local variant                    = _infer_stimm_variant(tmpl)

    mod.stimm_target_variant_current = variant
    mod.stimm_target_tint_current    = (mod.resolve_stimm_tint and mod.resolve_stimm_tint(variant)) or
        mod.PALETTE_ARGB255.GENERIC_WHITE

    mod.stimm_target_is_active       = true

    -- Clear any previous targets at the start of aim
    _clear_target_maps()
end)

-- While aiming: update the currently targeted teammate
mod:hook_safe(ActionTargetAlly, "fixed_update", function(self, dt, t)
    if not mod.stimm_target_is_active then
        return
    end
    if not _is_local_owner(self) then
        return
    end

    local comp = self._action_module_targeting_component
    local unit = comp and comp.target_unit_1 or nil

    -- Refresh the maps each tick (syringe aim selects a single target)
    _clear_target_maps()

    if unit and Unit.alive(unit) then
        local pid = _pid_from_unit(unit)
        if pid then
            mod.stimm_target_pids[pid]               = true
            mod.stimm_target_tint_by_pid[pid]        = mod.stimm_target_tint_current -- ARGB-255
            mod.stimm_target_force_float_by_pid[pid] = true
        end
    end
end)

-- Exiting ally-aim: clear state regardless of reason (used, canceled, or switched)
mod:hook_safe(ActionTargetAlly, "finish", function(self, reason, data, t, time_in_action)
    if not _is_local_owner(self) then
        return
    end
    _reset_all_state()
end)
