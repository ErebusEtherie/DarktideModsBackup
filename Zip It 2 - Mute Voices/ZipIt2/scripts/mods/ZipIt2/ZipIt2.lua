-- File: ZipIt2/scripts/mods/ZipIt2/ZipIt2.lua
local mod = get_mod("ZipIt2")
if not mod then return end

mod.version = "ZipIt2 version 1.5.1"

if mod._zipit2_loaded then return end
mod._zipit2_loaded = true

mod.zipit2_trigger_selected_wheel_option = mod.zipit2_trigger_selected_wheel_option or function()
    if not mod:is_enabled() then
        return
    end

    local executor = mod.zipit2_execute_selected_wheel_option

    if type(executor) == "function" then
        executor()
    end
end

mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/core/ZipIt2_utils")
mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_settings")
mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/core/ZipIt2_rules")
mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_briefing")
mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_dialogue")
mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_audio")

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
mod._zipit2_state = mod._zipit2_state or {
    in_lobby_view = false,
    in_mission_intro_view = false,
    in_briefing_state = false,
    started_from_lobby = false,
    blocked_briefing_vo = false,
}

mod.zipit2_register_briefing_hooks()
mod.zipit2_register_dialogue_hooks()
mod.zipit2_register_audio_hooks()
