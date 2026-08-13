-- File: uptime\scripts\mods\uptime\libs\_libs.lua
local mod = get_mod("uptime"); if not mod then return end
mod.lib = {}

mod:io_dofile("uptime/scripts/mods/uptime/libs/debug")
mod:io_dofile("uptime/scripts/mods/uptime/libs/items")
mod:io_dofile("uptime/scripts/mods/uptime/libs/json")
mod:io_dofile("uptime/scripts/mods/uptime/libs/missions")
mod:io_dofile("uptime/scripts/mods/uptime/libs/os")
mod:io_dofile("uptime/scripts/mods/uptime/libs/package_manager")
mod:io_dofile("uptime/scripts/mods/uptime/libs/talents")
mod:io_dofile("uptime/scripts/mods/uptime/libs/ui")
