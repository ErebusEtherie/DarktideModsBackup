
local mod = get_mod("hud_studio")

if mod.editor_icons then
	return mod.editor_icons
end

local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local EditorIcons = {}

local FONT = {
	text = mod.dl.fonts.validated("itc_novarese_medium"),
}

local function icon_color(color, disabled)
	if color then
		local a = (disabled and math.clamp(color[1] - 100, 50, 200)) or color[1]
		return { a, color[2], color[3], color[4] }
	end
	local l = disabled and 100 or 200
	return { 255, l, l, l }
end

local copy_w, copy_h = 10, 12

function EditorIcons.draw_copy_icon(d, x, y, z, target_disabled, front_color, backing_color)
	local origin_x, origin_y = math.floor(x + 5), math.floor(y + 5)
	local color = icon_color(front_color, target_disabled)

	d:rect(origin_x + 1, origin_y, z + 2, copy_w + 1, copy_h + 1, color)

	d:rect(origin_x + 3, origin_y + 1, z + 3, copy_w, copy_h, backing_color)

	d:rect(origin_x + 5, origin_y + 3, z + 4, copy_w, copy_h, color)
end

local trash_icon_material = "content/ui/materials/icons/player_states/lugged"

function EditorIcons.draw_trash_icon(d, x, y, z, target_disabled, front_color)
	local origin_x, origin_y = math.floor(x - 4), math.floor(y - 4)
	local overlay_origin_x, overlay_origin_y = math.floor(x + 8), math.floor(y + 10)
	local face_w, face_h = 33, 25
	local color = icon_color(front_color, target_disabled)

	if MaterialDeps.ready_to_draw(trash_icon_material) then
		d:texture(trash_icon_material, origin_x, origin_y, z + 2, face_w, face_h, color, mod.dl.uv.clip_top(0.67))

		d:rect(overlay_origin_x, overlay_origin_y, z + 3, 9, 9, color)
	end
end

function EditorIcons.draw_field_layout_icon(d, x, y, z, labelled, front_color)
	local origin_x, origin_y = math.floor(x + 4), math.floor(y + 4)
	local color = icon_color(front_color, false)
	local bar_h = 3

	if labelled then

		d:rect(origin_x, origin_y + 4, z + 2, 5, bar_h, color)
		d:rect(origin_x + 7, origin_y + 4, z + 2, 6, bar_h, color)
	else

		d:rect(origin_x, origin_y + 1, z + 2, 6, bar_h, color)
		d:rect(origin_x, origin_y + 7, z + 2, 12, bar_h, color)
	end
end

local caret_to_left_material = "content/ui/materials/hud/backgrounds/weapon_frame_arrow"

function EditorIcons.draw_collapse_expand_all_blocks(d, x, y, z, all_collapsed, front_color)
	local origin_x, origin_y = math.floor(x + 9), math.floor(y + 3)
	local color = icon_color(front_color, false)
	local face_s = 7

	if MaterialDeps.ready_to_draw(caret_to_left_material) then
		if all_collapsed then
			d:texture(caret_to_left_material, origin_x, origin_y + 1, z + 5, face_s, face_s, color, nil, -90)
			d:texture(caret_to_left_material, origin_x, origin_y + face_s + 4, z + 5, face_s, face_s, color, nil, 90)
		else
			d:texture(caret_to_left_material, origin_x, origin_y + 2, z + 5, face_s, face_s, color, nil, 90)
			d:texture(
				caret_to_left_material,
				origin_x,
				origin_y + 3 + face_s + 2,
				z + 5,
				face_s,
				face_s,
				color,
				nil,
				270
			)
		end
	end
end

function EditorIcons.draw_library_icon(d, x, y, z, front_color)
	local origin_x, origin_y = math.floor(x + 4), math.floor(y + 4)
	local color = icon_color(front_color, false)
	local sq_w = 7
	local sq_h = 7
	local sq_gap_x = sq_w + 3
	local sq_gap_y = sq_h + 3

	d:rect(origin_x, origin_y, z, sq_w, sq_h, color)

	d:outline(origin_x + sq_gap_x, origin_y, origin_x + sq_gap_x + sq_w, origin_y + sq_h, z, color)

	d:rect(origin_x, origin_y + sq_gap_y, z, sq_w, sq_h, color)

	d:rect(origin_x + sq_gap_x, origin_y + sq_gap_y, z, sq_w, sq_h, color)
end

local function plus_pass(d, x, y, z, color)
	d:text_left("+", 14, x + 3, y + 2, z + 3, 8, 8, color)
end

function EditorIcons.draw_add_block_icon(d, x, y, z, target_disabled, front_color)
	local color = icon_color(front_color, target_disabled)
	plus_pass(d, x, y, z, color)
	d:outline(x + 10, y + 9, x + 20, y + 19, z + 4, color)
end

function EditorIcons.draw_folder_icon(d, x, y, z, target_disabled, front_color, is_open)
	local color = icon_color(front_color, target_disabled)
	local darker = color[2] - (target_disabled and 15 or 70)
	local darker_color = { color[1], darker, darker, darker }
	d:rect(x + 10, y + 8, z + 4, 7, 7, darker_color) 
	d:rect(x + 10, y + 9, z + 4, 11, 7, darker_color) 
	local open_diff = is_open == nil and 0 or is_open and 2 or 0
	d:rect(x + 10, y + 11 + open_diff, z + 4, 11, 8 - open_diff, color) 
end

function EditorIcons.draw_add_folder_icon(d, x, y, z, target_disabled, front_color)
	plus_pass(d, x, y, z, icon_color(front_color, target_disabled))
	EditorIcons.draw_folder_icon(d, x, y, z, target_disabled, front_color, nil)
end

function EditorIcons.draw_add_progress_bar_node_icon(d, x, y, z, target_disabled, front_color)
	local color = icon_color(front_color, target_disabled)

	plus_pass(d, x, y, z, color)

	local darker = color[2] - (target_disabled and 15 or 90)
	d:rect(x + 4, y + 13, z + 2, 16, 6, { color[1], darker, darker, darker })

	d:rect(x + 4, y + 13, z + 3, 11, 6, color)
end

function EditorIcons.draw_add_rect_node_icon(d, x, y, z, target_disabled, front_color)
	local color = icon_color(front_color, target_disabled)

	plus_pass(d, x, y, z, color)
	d:rect(x + 10, y + 9, z + 3, 10, 10, color)
end

function EditorIcons.draw_add_text_node_icon(d, x, y, z, target_disabled, front_color)
	local color = icon_color(front_color, target_disabled)

	plus_pass(d, x, y, z, color)
	d:text_left("T", 17, x + 11, y + 5, z + 3, 17, 17, icon_color(front_color, target_disabled), FONT.text, false)
end

mod.editor_icons = EditorIcons

return EditorIcons
