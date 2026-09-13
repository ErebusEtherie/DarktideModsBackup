-- voices.lua
--
-- v0.22.28: preset bot voices.
--
-- ===========================================================================
-- WHY THIS EXISTS
-- ===========================================================================
--
-- Setting profile.selected_voice at bot-spawn time is not enough. Two
-- things have to happen at RUNTIME for a bot to actually speak that voice:
--
--   1. The bot's DialogueExtension has to have its vo_profile pushed to
--      that voice. Init reads profile.selected_voice once, but the game's
--      package sync loaded audio for the SOURCE character's real backend
--      voice, not our preset override; without pushing vo_profile the
--      extension resolves lines against the wrong bank and goes silent.
--
--   2. The chosen voice's audio packages have to be resident in memory.
--      PackageSynchronizerClient.resolve_profile_packages loads only the
--      profile.selected_voice at fetch time. If we set the value AFTER
--      that (which we do, in add_bot), the audio never gets loaded on
--      our behalf.
--
-- Aussiemon's Personality Picker solves BOTH of these end-to-end for its
-- own per-slot bot voice settings. Kaizen uses PP already, so instead of
-- duplicating its DialogueSystem hooks + Managers.package reference
-- counting here, this module SYNCS Pilgrimage's per-slot preset voices
-- into PP's per-slot bot voice settings. PP's own
-- DialogueSystem.extensions_ready hook then pushes vo_profile and loads
-- audio at the correct moments.
--
-- This is a lot smaller than reimplementing PP's whole voice-loading
-- pipeline, and it means the exact code path that already works for
-- Kaizen's own character now works for our bots too. If PP is ever
-- uninstalled, bot voices go silent (same as before v0.22.28); a
-- fallback in-tree implementation is on the deferred list.
--
-- ===========================================================================
-- WHEN THIS FIRES
-- ===========================================================================
--
-- Called from Pilgrimage.on_game_state_changed on StateLoading enter,
-- which is the same trigger that resets our spawn counter. StateLoading
-- runs before any dialogue extension is initialised, so PP's own
-- extensions_ready hook picks up the freshly-synced setting.
--
-- Also exposed as /pil_voices_sync (debug.lua) so it can be triggered
-- manually while iterating on preset voice keys.

local M = {}

local _mod
local _shared
local _preset
local _debug_log

function M.init(deps)
    _mod = deps.mod
    _shared = deps.shared
    _preset = deps.preset
    _debug_log = deps.debug_log or function() end
    -- v0.22.75: bot voice fx filters (Heavy Combat Servitor's robotic
    -- voice). Installed once at init; see the section at the bottom of
    -- this file for the mechanism.
    M.install_filter_hooks()
end

-- Personality Picker's default sentinel value. Reading its data module
-- (PersonalityPicker_data.lua) shows every dropdown widget uses
-- DEFAULT_VALUE for "no override". Passing "" or nil there would leave
-- PP treating the previous pick as valid.
local PP_DEFAULT_VALUE = "__default__"

local function _pp()
    local get_mod = rawget(_G, "get_mod")
    if not get_mod then return nil end
    local pp = get_mod("PersonalityPicker")
    if type(pp) ~= "table" then return nil end
    return pp
end

-- True if PP is loaded and its public setter is present.
function M.pp_available()
    local pp = _pp()
    return pp ~= nil and type(pp.set) == "function"
end

-- Push each Pilgrimage-bound slot's personality choice into PP so PP's
-- runtime hooks apply it at the next dialogue extension init. Unlike the bot
-- profile's official backing voice, this preserves virtual ids such as
-- Binharic-only and Silent Test.
-- Slots without a Pilgrimage preset are reset to DEFAULT so PP's own
-- per-slot picks (if any) take over cleanly.
function M.sync_pp()
    -- v0.22.75: same trigger (StateLoading enter) also invalidates the
    -- bot voice-filter unit cache, so a fresh mission never reuses a
    -- stale unit->filter resolution.
    if M.reset_filter_cache then M.reset_filter_cache() end
    local pp = _pp()
    if not pp or type(pp.set) ~= "function" then
        return false, "PersonalityPicker not installed"
    end
    if type(_preset) ~= "table" or type(_preset.resolve_for_slot) ~= "function" then
        return false, "preset module missing"
    end

    local written = 0
    local cleared = 0
    for slot = 1, 6 do
        local preset_id = _preset.resolve_for_slot(slot)
        local preset = preset_id and _preset.get and _preset.get(preset_id) or nil
        local voice = preset and _preset.personality_for and _preset.personality_for(preset_id)
            or (preset and _preset.voice_for and _preset.voice_for(preset_id))
            or (preset and preset.selected_voice)
        local key = "bot_" .. tostring(slot) .. "_voice"
        if voice and type(voice) == "string" and voice ~= "" then
            -- durable=false: this is a per-session runtime write, not a
            -- persistent user pref. Kaizen's own PP dropdown values in
            -- the options screen stay whatever he set them to; we only
            -- change the live in-memory value here.
            local ok = pcall(function() pp:set(key, voice, false) end)
            if ok then written = written + 1 end
        else
            local ok = pcall(function() pp:set(key, PP_DEFAULT_VALUE, false) end)
            if ok then cleared = cleared + 1 end
        end
    end

    _debug_log("voices", 0,
        string.format("PP bot voice sync: %d written, %d cleared", written, cleared),
        0, "info")
    return true, { written = written, cleared = cleared }
end

-- Diagnostic: dump the current effective PP bot slot voices, plus the
-- Pilgrimage preset each slot resolves to. Used by /pil_voices_diag.
function M.diagnose()
    local pp = _pp()
    local lines = {}
    lines[#lines + 1] = "== Pilgrimage voices =="
    lines[#lines + 1] = "PP installed:      " .. tostring(pp ~= nil)
    if pp and type(pp.get) == "function" then
        for slot = 1, 6 do
            local preset_id = _preset.resolve_for_slot(slot) or "<none>"
            local preset = _preset.get and _preset.get(preset_id) or nil
            local preset_voice = preset and _preset.personality_for
                and _preset.personality_for(preset_id)
                or (preset and _preset.voice_for and _preset.voice_for(preset_id))
                or (preset and preset.selected_voice or "<none>")
            local captured_voice = preset and _preset.stored_personality
                and _preset.stored_personality(preset_id) or "<none>"
            local pp_voice = "?"
            pcall(function() pp_voice = pp:get("bot_" .. tostring(slot) .. "_voice") or "<default>" end)
            lines[#lines + 1] = string.format(
                "  slot %d: preset=%s (voice=%s, captured=%s), PP bot_%d_voice=%s",
                slot, preset_id, preset_voice, captured_voice, slot, tostring(pp_voice))
        end
    end
    return lines
end

-- ===========================================================================
-- v0.22.75 (Session I): bot voice fx filters
-- ===========================================================================
--
-- A "voice fx preset" is the filtered sound of helmets, masks and the
-- Skitarii vox: internally one RTPC number stored on the dialogue
-- extension as `_voice_fx_preset` and re-sent to Wwise every time a
-- line plays. Kaizen's VoxFilter mod forces that number for the LOCAL
-- player; this section mirrors the mechanism for PILGRIMAGE BOTS only.
-- The public bridge added to VoxFilter is read-only and keeps both mods
-- scoped to their own units.
--
-- Which bots get a filter: any bot whose profile.character_id carries
-- the pilgrim_<preset_id> mangle (v0.22.67 shape) AND whose preset
-- resolves a filter key via Preset.voice_filter_key (explicit preset
-- field first, then the VoxFilter snapshot captured with the look).
--
-- The hooks mirror VoxFilter's seams (trigger_voice / set_voice_data /
-- play_event apply-before, set_voice_fx_preset re-assert-after), which
-- themselves follow the old VoxMask precedent. DMF chains hooks, so
-- VoxFilter's own hooks on the same methods coexist fine; its apply()
-- exits for non-local units, ours exits for non-Pilgrimage-bot units.

-- The game's filter numbers, from
-- scripts/settings/dialogue/voice_fx_preset_settings.lua (same table
-- VoxFilter exposes). 0 is clean / no filter.
local FILTERS = {
    none          = 0,
    metal         = 10,
    cloth         = 11,
    genestealer   = 20,
    enforcer      = 30,
    psyker_collar = 35,
    voice_box     = 40,
    robotic       = 50,
}

local CHARACTER_ID_MANGLE_PREFIX = "pilgrim_"

-- unit -> resolved capture cache, weak-keyed so despawned units drop out
-- on their own. Dialogue lines fire constantly in-mission; walking the
-- player list on every line would be wasteful. false = "checked, not a
-- filtered Pilgrimage bot" (cached negative); a table carries the pin,
-- resolved RTPC and whether Skitarii modulation must be neutralized.
local _unit_filter_cache = setmetatable({}, { __mode = "k" })

-- Invalidate on demand (bindings changed between missions). Cheap to
-- call; the cache rebuilds lazily.
function M.reset_filter_cache()
    _unit_filter_cache = setmetatable({}, { __mode = "k" })
end

local function _filter_for_unit(unit)
    if unit == nil then return nil end
    local cached = _unit_filter_cache[unit]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local resolved = false  -- default: not ours / no filter
    local Managers = rawget(_G, "Managers")
    local player_manager = Managers and Managers.player
    if player_manager and type(player_manager.players) == "function" then
        local ok_players, players = pcall(player_manager.players, player_manager)
        if ok_players and type(players) == "table" then
            for _, player in pairs(players) do
                if player and player.player_unit == unit then
                    local profile = nil
                    if type(player.profile) == "function" then
                        local ok_p, res = pcall(player.profile, player)
                        if ok_p then profile = res end
                    end
                    profile = profile or player._profile
                    local cid = type(profile) == "table" and profile.character_id or nil
                    if type(cid) == "string"
                        and cid:sub(1, #CHARACTER_ID_MANGLE_PREFIX) == CHARACTER_ID_MANGLE_PREFIX then
                        local preset_id = cid:sub(#CHARACTER_ID_MANGLE_PREFIX + 1)
                        local snapshot = _preset and _preset.voice_filter_snapshot
                            and _preset.voice_filter_snapshot(preset_id) or nil
                        local key = snapshot and snapshot.key
                        if not key and _preset and _preset.voice_filter_key then
                            key = _preset.voice_filter_key(preset_id)
                        end
                        key = key or "default"
                        local desired = key == "default"
                            and snapshot and snapshot.game_preset or FILTERS[key]
                        resolved = {
                            key = key,
                            desired = type(desired) == "number" and desired or nil,
                            neutralize_cryptic = key ~= "default",
                        }
                    end
                    break
                end
            end
        end
    end

    _unit_filter_cache[unit] = resolved
    return resolved ~= false and resolved or nil
end

local CRYPTIC_VOICE_FX_IDS = {
    "vox_effect_01",
    "vox_effect_02",
    "vox_effect_03",
}

local function _set_cryptic_source(dialogue_extension, sound_source, neutralize)
    local voice_effects = dialogue_extension and dialogue_extension._cryptic_voice_effects
    if not sound_source or type(voice_effects) ~= "table"
        or type(dialogue_extension._set_source_parameter) ~= "function" then
        return
    end
    for i = 1, #CRYPTIC_VOICE_FX_IDS do
        local voice_fx_id = CRYPTIC_VOICE_FX_IDS[i]
        local value = neutralize and 0 or voice_effects[voice_fx_id]
        if value ~= nil then
            pcall(dialogue_extension._set_source_parameter, dialogue_extension,
                voice_fx_id, value, sound_source)
        end
    end
end

local function _set_cryptic_sources(dialogue_extension, optional_sound_source, neutralize)
    if optional_sound_source then
        _set_cryptic_source(dialogue_extension, optional_sound_source, neutralize)
    end
    local dialogue_source = dialogue_extension and dialogue_extension._wwise_source_id
    if dialogue_source and dialogue_source ~= optional_sound_source then
        _set_cryptic_source(dialogue_extension, dialogue_source, neutralize)
    end
end

-- Force the filter onto a bot's dialogue component right before a
-- line plays. Mirrors VoxFilter's apply(), with the ownership test
-- inverted: it insists on the local player's unit, we insist on a
-- Pilgrimage bot's unit.
local function _apply_bot_filter(dialogue_extension, optional_sound_source)
    local unit = dialogue_extension and dialogue_extension._unit
    local filter = _filter_for_unit(unit)
    if not filter then return end

    if filter.desired ~= nil then
        dialogue_extension._voice_fx_preset = filter.desired
        if dialogue_extension._context then
            dialogue_extension._context.voice_fx_preset = filter.desired
        end
    end
    _set_cryptic_sources(dialogue_extension, optional_sound_source,
        filter.neutralize_cryptic)
end

local _filter_hooks_installed = false

function M.install_filter_hooks()
    if _filter_hooks_installed then return end
    if not _mod then return end
    local classes = rawget(_G, "CLASS")
    if not classes or not classes.DialogueExtension then
        _debug_log("voices", 0, "CLASS.DialogueExtension unavailable; bot filters off", 0, "warn")
        return
    end
    _filter_hooks_installed = true

    _mod:hook(classes.DialogueExtension, "trigger_voice",
        function(func, self, wwise_event_name, sound_source)
            pcall(_apply_bot_filter, self, sound_source)
            return func(self, wwise_event_name, sound_source)
        end)

    _mod:hook(classes.DialogueExtension, "set_voice_data", function(func, self)
        pcall(_apply_bot_filter, self)
        return func(self)
    end)

    _mod:hook(classes.DialogueExtension, "play_event", function(func, self, event)
        pcall(_apply_bot_filter, self)
        return func(self, event)
    end)

    -- The dialogue source is created here, immediately before Darktide applies
    -- saved Skitarii controls. Re-assert Clean/other overrides afterwards.
    _mod:hook(classes.DialogueExtension, "extensions_ready",
        function(func, self, world, unit)
            local result = func(self, world, unit)
            pcall(_apply_bot_filter, self)
            return result
        end)

    -- The game calls this when gear changes the preset; let it run,
    -- then re-assert ours on top (same shape as VoxFilter).
    _mod:hook(classes.DialogueExtension, "set_voice_fx_preset",
        function(func, self, optional_preset)
            local result = func(self, optional_preset)
            pcall(_apply_bot_filter, self)
            return result
        end)

    -- Skitarii write their character-creation modulation separately from the
    -- ordinary voice preset. Explicit VoxFilter pins, including Clean (none),
    -- must zero those writes for Pilgrimage bots just as VoxFilter does locally.
    _mod:hook(classes.DialogueExtension, "set_cryptic_voice_fx",
        function(func, self, value, voice_fx_id)
            local ok, filter = pcall(_filter_for_unit, self and self._unit)
            if ok and filter and filter.neutralize_cryptic then value = 0 end
            return func(self, value, voice_fx_id)
        end)

    _debug_log("voices", 0, "bot voice filter hooks installed", 0, "info")
end

return M
