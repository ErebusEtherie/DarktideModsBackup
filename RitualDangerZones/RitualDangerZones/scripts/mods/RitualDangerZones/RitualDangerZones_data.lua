local mod = get_mod("RitualDangerZones")

local function rgba(setting_id, r, g, b, a)
	return {
		setting_id = setting_id,
		type = "group",
		sub_widgets = {
			{ setting_id = setting_id .. "_r", type = "numeric", default_value = r, range = { 0, 100 } },
			{ setting_id = setting_id .. "_g", type = "numeric", default_value = g, range = { 0, 100 } },
			{ setting_id = setting_id .. "_b", type = "numeric", default_value = b, range = { 0, 100 } },
			{ setting_id = setting_id .. "_a", type = "numeric", default_value = a, range = { 0, 100 } },
		},
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{ setting_id = "enabled", type = "checkbox", default_value = true },

			-- Applies to ALL rings, so it sits above the per-ring toggles. Listed after them it read as
			-- a speedup-only setting, because DMF renders a flat list and only the colours are grouped.
			-- 0.1 = 10cm of vertical projection: no stair climb, no bleed to the floor above.
			-- decimals_number is required: base DMF defaults it to 0, which makes the slider snap to
			-- whole integers and puts every sub-1 value (that is, every useful value) out of reach.
			{
				setting_id = "ring_projection_depth", type = "numeric",
				default_value = 0.1, range = { 0.1, 40 }, decimals_number = 2,
			},

			-- Magenta at alpha 4 for both rings. See ring_renderer.lua RING_DEFAULT_RGBA for why.
			-- Keep these two in sync with that table: it is the fallback when a setting is unset.
			-- Off by default since 1.3.0: these describe euclidean distance from the daemonhost, and
			-- the game measures main-path distance instead. Kept as an opt-in site locator.
			{ setting_id = "ring_start_enabled",    type = "checkbox", default_value = false },
			rgba("ring_start_color", 90, 0, 90, 4),
			{ setting_id = "ring_speedup_enabled",  type = "checkbox", default_value = false },
			rgba("ring_speedup_color", 90, 0, 90, 4),

			-- Tripwires: the points ON THE MAIN PATH where crossing actually changes the ritual.
			-- Radius is small because these mark a spot on the route, not an area, so the alpha-4
			-- lesson from the 30m site rings does not apply here: alpha and area are coupled, and a
			-- 3m ring at alpha 4 is invisible. decimals_number is required or the radius slider
			-- snaps to whole integers.
			{
				setting_id = "tripwire_group", type = "group",
				sub_widgets = {
					{ setting_id = "tripwire_enabled", type = "checkbox", default_value = true },
					{
						setting_id = "tripwire_radius", type = "numeric",
						default_value = 3, range = { 1, 10 }, decimals_number = 1,
					},
					-- Separate from the site rings' depth on purpose, and much deeper. See
					-- ring_renderer.lua TRIPWIRE_DEPTH_DEFAULT: a 10cm projector on a 3m ring can miss
					-- the floor entirely on grating, a ramp or a step, and a ring this small cannot
					-- smear much even when deep. Raise this if a tripwire is not showing up.
					{
						setting_id = "tripwire_projection_depth", type = "numeric",
						default_value = 0.6, range = { 0.1, 5 }, decimals_number = 2,
					},
				},
			},
			rgba("tripwire_far_color", 100, 65, 0, 25),
			rgba("tripwire_close_color", 100, 10, 10, 35),

			{
				setting_id = "timer_group", type = "group",
				sub_widgets = {
					{ setting_id = "timer_enabled",   type = "checkbox", default_value = true },
					{ setting_id = "timer_text_size", type = "numeric", default_value = 24, range = { 12, 48 } },
				},
			},
			{
				setting_id = "marker_group", type = "group",
				sub_widgets = {
					{ setting_id = "marker_enabled",       type = "checkbox", default_value = true },
					-- The game's own Heinous Rituals circumstance icon, or the generic difficulty skull
					-- the mod used before 1.3.0. Applied through marker data, so it switches live.
					{
						setting_id = "marker_icon", type = "dropdown", default_value = "skull",
						options = {
							{ text = "marker_icon_skull",  value = "skull" },
							{ text = "marker_icon_ritual", value = "ritual" },
						},
					},
					{ setting_id = "marker_size",          type = "numeric",  default_value = 80, range = { 16, 124 } },
					{ setting_id = "marker_through_walls", type = "checkbox", default_value = true },
					{ setting_id = "marker_show_distance", type = "checkbox", default_value = true },
					{ setting_id = "marker_offscreen",     type = "checkbox", default_value = true },
				},
			},
			{
				setting_id = "warning_group", type = "group",
				sub_widgets = {
					{ setting_id = "warning_enabled",     type = "checkbox", default_value = true },
					{ setting_id = "warning_size",        type = "numeric",  default_value = 128, range = { 48, 256 } },
					{ setting_id = "warning_directional", type = "checkbox", default_value = true },
					{ setting_id = "warning_show_eta",    type = "checkbox", default_value = true },
				},
			},
			-- Warning banner text colour. The amber/red icon still signals the stage; this is only the
			-- text. Default white (100,100,100,100). Same 0-100 RGBA convention as the ring colours.
			rgba("warning_text_color", 100, 100, 100, 100),
		},
	},
}
