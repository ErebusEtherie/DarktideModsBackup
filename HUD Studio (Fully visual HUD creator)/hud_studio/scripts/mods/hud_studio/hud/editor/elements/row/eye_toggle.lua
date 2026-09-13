
local mod = get_mod("hud_studio")

if mod.eye_toggle_component then
	return mod.eye_toggle_component
end

local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local CursorState = mod:core(mod.cursor_state, "hud/editor/input/cursor_state")
local Tooltip = mod:core(mod.tooltip_component, "hud/editor/elements/tooltip/tooltip")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local MATERIAL = {
	OPEN = "content/ui/materials/icons/item_types/eye_color",
	CLOSED = "content/ui/materials/icons/circumstances/ventilation_purge_01",
	COG = "content/ui/materials/icons/item_types/cryptic_lens_color",
}

local TINT = {
	NORMAL = { 205, 255, 255, 255 },

	BADGE_OFF = { 255, 250, 190, 90 },
	BADGE_ON = { 255, 130, 225, 140 },
	RED = { 255, 220, 105, 105 },
	ORANGE = { 255, 220, 145, 75 },
	BLUE = { 255, 75, 230, 255 },
	GREEN = { 255, 150, 255, 180 },
}

local GEO = {
	SIZE = 18, 
	RIGHT_PAD = 8, 
	BADGE = 4, 
}

local EyeToggle = {}

EyeToggle.SIZE = GEO.SIZE
EyeToggle.RIGHT_PAD = GEO.RIGHT_PAD

function EyeToggle.rect(x, row_y, w, row_h)
	local size = GEO.SIZE
	return {
		x = x + w - size - GEO.RIGHT_PAD,
		y = row_y + math.floor((row_h - size) / 2),
		w = size,
		h = size,
	}
end

local DYNAMIC_LABEL = mod:localize("visibility_eye_dynamic_mode")

local function tooltip_label(dynamic, on, is_block, error_message, state, override)

	if error_message then
		return mod:localize("visibility_eye_script_error") .. error_message
	end

	if override then
		return type(override) == "function" and override(on) or override
	end
	if dynamic then

		if state == "off" then
			return mod:localize("visibility_eye_force_hidden") .. DYNAMIC_LABEL
		elseif state == "on" then
			return mod:localize("visibility_eye_force_shown") .. DYNAMIC_LABEL
		end
		return DYNAMIC_LABEL
	end
	if on then
		return is_block and mod:localize("visibility_eye_tooltip_hide_block")
			or mod:localize("visibility_eye_tooltip_hide_node")
	end
	return is_block and mod:localize("visibility_eye_tooltip_show_block")
		or mod:localize("visibility_eye_tooltip_show_node")
end

function EyeToggle.draw(d, id, rect, z, opts)

	local computed = opts.dynamic and true or false

	local state = computed and (opts.state or "auto") or nil
	local overridden = state == "on" or state == "off"
	local on = overridden and (state == "on") or (opts.on and true or false)

	local hovered, clicked = CursorState.test(d, id, rect.x, rect.y, rect.w, rect.h)

	local material = on and MATERIAL.OPEN or MATERIAL.CLOSED
	local tint = TINT.NORMAL
	if opts.error then
		tint = TINT.RED
	elseif computed and not overridden then
		tint = TINT.BLUE
		material = MATERIAL.COG
	elseif not on and overridden then
		tint = TINT.ORANGE
	elseif on and overridden then
		tint = TINT.GREEN
	end

	if MaterialDeps.ready_to_draw(material) then
		d:texture(material, rect.x, rect.y, z, rect.w, rect.h, tint)
	end

	if overridden then
		local size = GEO.BADGE
		d:rect(rect.x + rect.w - size, rect.y, z + 1, size, size, on and TINT.BADGE_ON or TINT.BADGE_OFF)
	end

	if hovered then
		Tooltip.draw(d, tooltip_label(computed, on, opts.is_block, opts.error, state, opts.tooltip))
	end

	if clicked then
		if computed then
			if opts.on_set_state then
				opts.on_set_state(Visibility.next_eye_state(state, true))
			end
		elseif opts.on_toggle then
			opts.on_toggle(not on)
		end
	end
end

mod.eye_toggle_component = EyeToggle

return EyeToggle
