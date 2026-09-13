-- Grace options. The Melee Attacks and Repeat Special Attack groups appear
-- only when the optional GracefulSwinging.lua is installed beside this file.

local mod = get_mod("Grace")

local _attacks_present = (function()
	local io_lib = Mods and Mods.lua and Mods.lua.io

	if not io_lib then
		return false
	end

	local f = io_lib.open("./../mods/Grace/scripts/mods/Grace/GracefulSwinging.lua", "r")

	if f then
		io_lib.close(f)

		return true
	end

	return false
end)()

-- ───────────────────── ❀ ─────────────────────
--  The options tree
-- ───────────────────── ❀ ─────────────────────

local options = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			-- ───────────────────── ❀ ─────────────────────
			--  Base
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_vanilla",
				type        = "group",
				sub_widgets = {
					{
						setting_id  = "group_vanilla_inner",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "vanilla_hold_to_crouch",
								type          = "checkbox",
								default_value = true,
							},
							{
								setting_id    = "vanilla_hold_to_sprint",
								type          = "checkbox",
								default_value = true,
							},
							{
								setting_id    = "vanilla_stationary_dodge",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "vanilla_diagonal_forward_dodge",
								type          = "checkbox",
								default_value = true,
							},
							{
								setting_id    = "vanilla_always_dodge",
								type          = "checkbox",
								default_value = false,
							},
						},
					},
					{
						setting_id  = "group_grace_base",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "sprint_perseverance",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "toggle_undo_hold",
								type          = "checkbox",
								default_value = false,
							},
						},
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Sprint
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_sprint",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "sprint_enabled",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "sprint_hold_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_hold_sprint",
					},
					{
						setting_id      = "sprint_toggle_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_toggle_sprint",
					},
					{
						setting_id    = "sprint_reload_wait",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "reload_swap_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_hold_reload_swap",
					},
					{
						setting_id    = "sprint_melee_charge",
						type          = "checkbox",
						default_value = false,
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Slide
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_slide",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "slide_always_on",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "slide_hold_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_hold_slide",
					},
					{
						setting_id      = "slide_toggle_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_toggle_slide",
					},
					{
						setting_id    = "slide_once_per_sprint",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "slide_extra_delay",
						type            = "numeric",
						default_value   = 0.08,
						range           = { 0, 3 },
						decimals_number = 2,
					},
					{
						setting_id      = "slide_chain_delay",
						type            = "numeric",
						default_value   = 0.01,
						range           = { 0, 3 },
						decimals_number = 2,
					},
					{
						setting_id    = "sprint_charge_slide",
						type          = "checkbox",
						default_value = false,
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Dodge
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_dodge",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "dodge_slide_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "_kb_dodge_slide",
					},
					{
						setting_id    = "dodge_keep_sprint",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "dodge_slide",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "dodge_slide_diagonal",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "dodge_easy_slide",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "dodge_hold",
						type          = "dropdown",
						default_value = "off",
						options       = {
							{ text = "dodge_hold_off",   value = "off" },
							{ text = "dodge_hold_slide", value = "slide" },
							{ text = "dodge_hold_keep",  value = "keep" },
						},
					},
					{
						setting_id    = "jump_block",
						type          = "dropdown",
						default_value = "off",
						options       = {
							{ text = "jump_block_off",    value = "off" },
							{ text = "jump_block_dodges", value = "dodges" },
							{ text = "jump_block_always", value = "always" },
						},
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Vault
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_vault",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "vault_mantle",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "vault_sprinting",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "vault_walking",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "vault_safe",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "vault_fall_limit",
						type            = "numeric",
						default_value   = 7,
						range           = { 1, 25 },
						decimals_number = 0,
					},
					{
						setting_id      = "vault_min_height",
						type            = "numeric",
						default_value   = 0.6,
						range           = { 0, 1.5 },
						decimals_number = 2,
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Swing
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_swing",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "swing_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "_kb_hold_swing",
					},
					{
						setting_id    = "swing_grace_ms",
						type          = "numeric",
						default_value = 100,
						range         = { 0, 500 },
					},
					{
						setting_id    = "swing_skip_when_still",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "swing_skip_when_sprinting",
						type          = "checkbox",
						default_value = false,
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Classes
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_class",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "per_class",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "per_class_vanilla",
						type          = "checkbox",
						default_value = false,
					},

					{
						setting_id  = "group_disable_class",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "disable_veteran",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "disable_zealot",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "disable_psyker",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "disable_ogryn",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "disable_adamant",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "disable_broker",
								type          = "checkbox",
								default_value = false,
							},
						},
					},
					{
						setting_id  = "group_class_reset",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "per_class_reset",
								type          = "checkbox",
								default_value = false,
							},
						},
					},
				},
			},
			-- ───────────────────── ❀ ─────────────────────
			--  Debug
			-- ───────────────────── ❀ ─────────────────────
			{
				setting_id  = "group_debug",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "debug_notify",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "debug_sprint",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "debug_slide",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "debug_dodge",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "debug_vault",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "debug_swing",
						type          = "checkbox",
						default_value = false,
					},
					-- ───────────────────── ❀ ─────────────────────
					--  Repeat Special Attack
					-- ───────────────────── ❀ ─────────────────────
					{
						setting_id    = "debug_class",
						type          = "checkbox",
						default_value = false,
					},
				},
			},
		},
	},
}

-- ───────────────────── ❀ ─────────────────────
--  The optional module groups
-- ───────────────────── ❀ ─────────────────────

if _attacks_present then
	local keybind = function(id, trigger, handler)
		return {
			setting_id      = id,
			type            = "keybind",
			default_value   = {},
			keybind_global  = false,
			keybind_trigger = trigger,
			keybind_type    = "function_call",
			function_name   = handler,
		}
	end

	local widgets = options.options.widgets

	for i = 1, #widgets do
		local group = widgets[i]

		if group.setting_id == "group_swing" then
			group.sub_widgets[#group.sub_widgets + 1] = {
				setting_id  = "group_special_repeat",
				type        = "group",
				sub_widgets = {
					-- ───────────────────── ❀ ─────────────────────
					--  Melee Attacks
					-- ───────────────────── ❀ ─────────────────────
					{
						setting_id    = "special_repeat",
						type          = "checkbox",
						default_value = false,
					},
				},
			}
			group.sub_widgets[#group.sub_widgets + 1] = {
				setting_id  = "group_attacks",
				type        = "group",
				sub_widgets = {
					keybind("attacks_invert_keybind", "held", "_kb_attacks_invert"),
					keybind("attacks_light_toggle_keybind", "pressed", "_kb_attacks_light_toggle"),
					keybind("attacks_light_hold_keybind", "held", "_kb_attacks_light_hold"),
					keybind("attacks_heavy_toggle_keybind", "pressed", "_kb_attacks_heavy_toggle"),
					keybind("attacks_heavy_hold_keybind", "held", "_kb_attacks_heavy_hold"),
					keybind("attacks_push_toggle_keybind", "pressed", "_kb_attacks_push_toggle"),
					keybind("attacks_push_hold_keybind", "held", "_kb_attacks_push_hold"),
				},
			}
		elseif group.setting_id == "group_debug" then
			group.sub_widgets[#group.sub_widgets + 1] = {
				setting_id    = "debug_attacks",
				type          = "checkbox",
				default_value = false,
			}
		end
	end
end

return options
