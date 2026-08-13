---@type mod
local mod = get_mod("dopamine")

local lines = mod.dl.loc_helpers.lines

local bolt = mod.dl.str.rich_text("", { color = mod.dl.colors.reg.ui.hud_red_light })
local bolt_end = mod.dl.str.rich_text("", { color = mod.dl.colors.reg.gw.lugganath_orange })

local mod_name = mod.dl.str.rich_text_gradient(
	" DOPAMINE ",
	mod.dl.colors.reg.ui.hud_red_light,
	mod.dl.colors.reg.gw.lugganath_orange
)

return {
	mod_name = {
		en = mod.dl.str.join(" ", bolt, mod_name, bolt_end),
	},
	mod_description = {
		en = lines("A fast-paced and fun (hopefully) style kills + combo system."),
		["zh-cn"] = lines("一个快节奏且有趣（希望如此）的风格击杀 + 连击系统。"),
	},
}
