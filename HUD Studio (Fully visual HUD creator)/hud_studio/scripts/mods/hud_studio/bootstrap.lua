---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Bootstrap = {}

local function load(path)
	mod:io_dofile("hud_studio/scripts/mods/hud_studio/" .. path)
end

mod:io_dofile("hud_studio/scripts/mods/hud_studio/darklib/darklib")(mod, "hud_studio/scripts/mods/hud_studio/darklib")

load("api/register_blocks")

function Bootstrap.script_phase()

	mod:io_dofile("hud_studio/scripts/mods/hud_studio/lib/lib_loader")(mod)

	load("engine/compiler")
	load("engine/registry")
	load("engine/sandbox")
	load("engine/context")

	load("blocks/registry")
	load("blocks/block")
	load("blocks/node_types/text")
	load("blocks/node_types/rect")
	load("blocks/node_types/progress_bar")

	load("sources/manifest")

	load("document/schema")
	load("document/serialize")
	load("document/store")

	load("document/material_deps")

	load("document/session")

	load("hooks/hud_registration")

	load("hooks/editor_input")

	load("hooks/vanilla_hud")

	load("hud/news/news")
	load("hooks/news_registration")

	mod.hud_studio_register_probe_command()
end

mod.bootstrap = Bootstrap

return Bootstrap
