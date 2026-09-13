-- Non-modal HUD: never changes input services, cursor ownership or player state.
local mod = get_mod("MortisBuffManager")
local UIHud = require("scripts/managers/ui/ui_hud")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local DraftInput = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_draft_input")
local Draft = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_draft")
local HUD = { geometry = { width = 960, card_width = 312, gap = 12, card_height = 216, top = 72, header = 50, padding = 20,
	progress_width = 220, progress_height = 38, progress_bottom = 150 } }
local enter_time, exit_time, award_time = Draft.enter_time, Draft.exit_time, Draft.reveal_time
local instances = setmetatable({}, { __mode = "k" })
local notices = { seen = {}, queue = {}, head = 1 }
local function text_pass(id, x, y, width, height, font, align)
	return { pass_type = "text", value_id = id, value = "", style_id = id,
		style = { font_type = "proxima_nova_bold", font_size = font, text_color = { 255, 232, 229, 210 },
			text_horizontal_alignment = align or "left", text_vertical_alignment = id == "description" and "top" or "center",
			size = { width, height }, offset = { x, y, 5 } } }
end
function HUD.definitions()
	local g = HUD.geometry
	local graph = { screen = UIWorkspaceSettings.screen,
		canvas = { parent = "screen", horizontal_alignment = "center", vertical_alignment = "center", size = { 1920, 1080 }, position = { 0, 0, 300 } },
		panel = { parent = "canvas", horizontal_alignment = "center", vertical_alignment = "top", size = { g.width, g.header + g.card_height }, position = { 0, g.top, 1 } },
		competition_status = { parent = "canvas", horizontal_alignment = "center", vertical_alignment = "bottom",
			size = { g.progress_width, g.progress_height }, position = { 0, -g.progress_bottom, 1 } } }
	local definitions = {}
	definitions.header = UIWidget.create_definition({ text_pass("text", 0, 0, g.width, 28, 21, "center") }, "panel")
	local function bar_visible(content) return content.bar == true end
	definitions.progress = UIWidget.create_definition({
		{ pass_type = "rect", style_id = "background", style = { color = { 160, 12, 20, 18 }, size = { g.progress_width, g.progress_height }, offset = { 0, 0, 0 } } },
		{ pass_type = "rect", style_id = "track", style = { color = { 220, 50, 61, 48 }, size = { g.progress_width - 24, 4 }, offset = { 12, 29, 2 } }, visibility_function = bar_visible },
		{ pass_type = "rect", style_id = "fill", style = { color = { 255, 225, 185, 85 }, size = { 0, 4 }, offset = { 12, 29, 3 } }, visibility_function = bar_visible },
		text_pass("text", 8, 2, g.progress_width - 16, 24, 17, "center"),
	}, "competition_status")
	for i = 1, 3 do
		local id = "card_" .. i
		graph[id] = { parent = "panel", horizontal_alignment = "left", vertical_alignment = "top", size = { g.card_width, g.card_height }, position = { (i - 1) * (g.card_width + g.gap), g.header, 1 } }
		local passes = {
			{ pass_type = "texture", value = "content/ui/materials/backgrounds/terminal_basic", style_id = "background", style = { color = { 220, 12, 20, 18 } } },
			{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style_id = "frame", style = { color = { 255, 167, 146, 82 }, offset = { 0, 0, 2 } } },
			-- Native Mortis ornament proportions, scaled to the compact card width.
			{ pass_type = "texture", value = "content/ui/materials/base/ui_default_base", style_id = "frame_top",
				style = { horizontal_alignment = "center", size = { g.card_width, g.card_width * 60 / 480 }, offset = { 0, -g.card_width * 20 / 480, 4 },
					material_values = { texture_map = "content/ui/textures/frames/horde/horde_buff_boon_selected" } } },
			{ pass_type = "texture", value = "content/ui/materials/base/ui_default_base", style_id = "frame_bottom",
				style = { horizontal_alignment = "center", vertical_alignment = "bottom", size = { g.card_width * 470 / 480, g.card_width * 52 / 480 }, offset = { 0, g.card_width * 30 / 480, 4 },
					material_values = { texture_map = "content/ui/textures/frames/horde/horde_buff_bottom" } } },
			{ pass_type = "rect", style_id = "flash", style = { color = { 0, 245, 225, 152 }, offset = { 0, 0, 3 } } },
			{ pass_type = "rect", style_id = "timer", style = { color = { 255, 225, 185, 85 }, size = { g.card_width - 2 * g.padding, 3 }, offset = { g.padding, g.card_height - 9, 3 } } },
			{ pass_type = "texture", value = "content/ui/materials/frames/talents/talent_icon_container", style_id = "icon",
				style = { size = { 42, 42 }, offset = { g.padding, 20, 4 }, color = { 255, 255, 255, 255 },
					material_values = { intensity = 0, saturation = 1, texture_map = "",
						frame = "content/ui/textures/frames/horde/hex_frame_horde", icon_mask = "content/ui/textures/frames/horde/hex_frame_horde_mask" } },
				visibility_function = function(content) return content.has_icon == true end },
			text_pass("title", 74, 18, g.card_width - 74 - g.padding, 40, 20),
			text_pass("subtitle", 74, 60, g.card_width - 74 - g.padding, 20, 15),
			text_pass("description", g.padding, 90, g.card_width - 2 * g.padding, 76, 18),
			text_pass("key", g.padding, g.card_height - 40, g.card_width - 2 * g.padding, 20, 17, "center"),
		}
		definitions[id] = UIWidget.create_definition(passes, id)
	end
	return graph, definitions
end
local function cleanup(hud)
	local ui = instances[hud]
	if ui and hud._ui_renderer then
		for _, widget in pairs(ui.widgets) do UIWidget.destroy(hud._ui_renderer, widget) end
	end
	instances[hud] = nil
end
function HUD.cleanup()
	for hud in pairs(instances) do cleanup(hud) end
	DraftInput.cleanup(); notices = { seen = {}, queue = {}, head = 1 }
end
local function instance(hud)
	local ui = instances[hud]
	if ui then return ui end
	local graph, definitions = HUD.definitions()
	ui = { graph = UIScenegraph.init_scenegraph(graph), widgets = {}, age = 0 }
	for name, definition in pairs(definitions) do ui.widgets[name] = UIWidget.init("mbm_draft_" .. name, definition) end
	instances[hud] = ui
	return ui
end
local function allowed(hud)
	local player = Managers.player and Managers.player:local_player_safe(1)
	return mod:is_enabled() and player and hud._player == player and Managers.world:is_world_enabled(hud._world_name)
		and Managers.package and Managers.package:has_loaded("packages/ui/constant_elements/mission_buffs/mission_buffs")
end
-- Measure only when text changes. Preserve the native description in full;
-- normal cards stay small, while a long translation can grow the shared row.
local function measure(hud, widget, id, minimum)
    local style = widget.style[id]
    if not UIRenderer.styled_text_size then return minimum end
    local _, height = UIRenderer.styled_text_size(hud._ui_renderer, widget.content[id], style, { style.size[1], 1080 }, true)
    return math.max(minimum, height)
end
local function fill_cards(hud, ui, active)
    local height, count = HUD.geometry.card_height, #active.choices
    for i = 1, 3 do
        local widget, name = ui.widgets["card_" .. i], active.choices[i]
        local data = name and mod.mortis_choice_ui_data(name, active.kind)
        widget.content.title = data and data.display_name or ""
        widget.content.description = data and data.description or ""
        widget.content.subtitle = data and data.subtitle or ""
        widget.content.key = "Ctrl + " .. i
        widget.style.title.font_size = 20
        local title_height = measure(hud, widget, "title", 40)
        if title_height > 48 then
            widget.style.title.font_size = 18
            title_height = measure(hud, widget, "title", 40)
        end
        widget.style.title.size[2] = title_height
        widget.style.subtitle.offset[2] = 20 + title_height
        local subtitle_height = measure(hud, widget, "subtitle", 20)
        widget.style.subtitle.size[2] = subtitle_height
        local description_y = widget.style.subtitle.offset[2] + subtitle_height + 10
        widget.style.description.offset[2] = description_y
        widget.style.description.font_size = 18
        local description_height = measure(hud, widget, "description", 76)
        widget.style.description.size[2] = description_height
        height = math.max(height, description_y + description_height + 52)
        widget.content.has_icon = data and data.icon ~= nil or false
        local material = widget.style.icon.material_values
        material.icon, material.gradient_map = data and data.icon, data and data.gradient
        material.frame = data and data.family and "content/ui/textures/frames/horde/circle_frame_horde" or "content/ui/textures/frames/horde/hex_frame_horde"
        material.icon_mask = data and data.family and "content/ui/textures/frames/horde/circle_frame_horde_mask" or "content/ui/textures/frames/horde/hex_frame_horde_mask"
    end
    ui.height = height
    ui.graph.panel.size[2] = height + HUD.geometry.header
    for i = 1, 3 do
        local widget, node = ui.widgets["card_" .. i], ui.graph["card_" .. i]
        node.size[2] = height
        node.position[1] = (i - 1) * (HUD.geometry.card_width + HUD.geometry.gap) + (3 - count) * (HUD.geometry.card_width + HUD.geometry.gap) / 2
        widget.style.key.offset[2] = height - 40
        widget.style.timer.offset[2] = height - 9
    end
end
local function collect_awards(snapshot)
    if notices.epoch ~= snapshot.epoch then
        notices = { epoch = snapshot.epoch, seen = {}, queue = {}, head = 1 }
        -- A first snapshot after joining may contain historical awards. Show
        -- only the latest completed round, then deliver every new award once.
        notices.baseline = snapshot.completed or 0
    end
    for _, reward in ipairs(snapshot.rewards or {}) do
        if not notices.seen[reward.id] then
            notices.seen[reward.id] = true
            if reward.round >= (notices.baseline or 0) then notices.queue[#notices.queue + 1] = reward end
        end
    end
end
local function update_award(hud, ui, dt)
    if Managers.ui:using_input() then return end
    if ui.award then
        ui.award_age = ui.award_age + dt
        if ui.award_age >= award_time then ui.award = nil end
    end
    if not ui.award and not ui.id and notices.queue[notices.head] then
        local round, choices = notices.queue[notices.head].round, {}
        while notices.queue[notices.head] and notices.queue[notices.head].round == round and #choices < 3 do
            choices[#choices + 1] = notices.queue[notices.head].name
            notices.head = notices.head + 1
        end
        -- Reuse the actual picker widgets, icons, frame, text and adaptive
        -- geometry. Each round fades in, holds for three seconds, then fades out.
        ui.award, ui.award_age, ui.age, ui.choices = true, 0, 0, choices
        fill_cards(hud, ui, { choices = choices, kind = "legendary" })
        ui.widgets.header.content.text = mod:localize("mortis_auto_award")
        for i = 1, #choices do ui.widgets["card_" .. i].content.key = mod:localize("mortis_draft_chosen") end
        if notices.head > #notices.queue then notices.queue, notices.head = {}, 1 end
    end
end
mod:hook_safe(UIHud, "update", function(hud, dt, t, input)
    if not allowed(hud) then return end
    local snapshot, lag, pending = mod.mortis_draft_snapshot()
    if not snapshot then
        if instances[hud] then cleanup(hud); DraftInput.context = nil end
        return
    end
    local display = mod._settings.mortis_competition_hud_style or "bar_percent"
    local progress_visible = snapshot.mode == "competition" and snapshot.counting ~= false and not snapshot.exhausted and display ~= "hidden"
    local ui = instances[hud]
    -- No allocations or render setup when finished and there is nothing to show.
    if not ui and not snapshot.active and not progress_visible and #(snapshot.rewards or {}) == 0 then return end
    ui = ui or instance(hud)
    if not ui.input_context then
        ui.input_context = function()
            if allowed(hud) and instances[hud] == ui then
                return ui.id or (ui.award and "mortis_award"), not ui.resolving and not ui.award, ui.age
            end
        end
    end
    DraftInput.context = ui.input_context
    if ui.epoch ~= snapshot.epoch then
        ui.id, ui.resolving, ui.selected, ui.award = nil, nil, nil, nil
        ui.epoch = snapshot.epoch
    end
    if ui.rewards ~= snapshot.rewards or notices.epoch ~= snapshot.epoch then
        collect_awards(snapshot); ui.rewards = snapshot.rewards
    end
    ui.snapshot = snapshot
    ui.age = ui.age + dt
    local active = snapshot.active
    if ui.id and (not active or active.id ~= ui.id) then
        if not ui.resolving then
            ui.resolving = 0
            ui.selected = snapshot.last and snapshot.last.id == ui.id and snapshot.last.index or nil
            if ui.selected then ui.widgets["card_" .. ui.selected].content.key = mod:localize("mortis_draft_chosen") end
        end
        ui.resolving = ui.resolving + dt
        if ui.resolving >= Draft.selection_time then ui.id, ui.resolving, ui.selected = nil, nil, nil end
    end
    update_award(hud, ui, dt)
    local ready = not active or (active.delay or 0) <= (lag or 0)
    if active and ready and not ui.id and not ui.award then
        ui.header_snapshot = nil
        ui.id, ui.choices, ui.age, ui.kind = active.id, active.choices, 0, active.kind
        fill_cards(hud, ui, active)
    end
    if DraftInput.pending and (not input or input:is_null_service()) then DraftInput.pending = nil end
    if active and active.id == ui.id and not pending and not ui.resolving
        and input and not input:is_null_service() and not Managers.ui:using_input() then
        local index = DraftInput.take(active.id)
        if index and active.choices[index] then mod.choose_mortis_draft(index) end
    end
    ui.remaining = active and math.max(0, active.remaining - math.max(0, (lag or 0) - (active.delay or 0))) or 0
    local seconds = math.ceil(ui.remaining)
    if ui.id and (ui.header_seconds ~= seconds or ui.header_pending ~= pending or ui.header_snapshot ~= snapshot or ui.header_kind ~= ui.kind) then
        ui.widgets.header.content.text = ui.resolving and mod:localize("mortis_draft_chosen")
            or mod:localize(pending and "mortis_draft_sending" or ui.kind == "family" and "mortis_route_header" or "mortis_draft_header", seconds, snapshot.queued, snapshot.spent, snapshot.limit)
        ui.header_seconds, ui.header_pending, ui.header_snapshot, ui.header_kind = seconds, pending, snapshot, ui.kind
    end
    local progress = ui.widgets.progress
    progress.content.show = progress_visible
    if progress_visible and (ui.progress_value ~= snapshot.progress or ui.display ~= display) then
        ui.progress_value, ui.display = snapshot.progress, display
        progress.content.bar = display ~= "percent"
        progress.content.text = display ~= "bar" and mod:localize("mortis_competition_percentage", snapshot.progress) or ""
        progress.style.fill.size[1] = (HUD.geometry.progress_width - 24) * math.clamp(snapshot.progress / 100, 0, 1)
        progress.style.text.offset[2] = progress.content.bar and 2 or 7
        local background = progress.style.background
        background.size[1] = display == "percent" and 96 or HUD.geometry.progress_width
        background.size[2] = display == "bar" and 14 or display == "percent" and 30 or HUD.geometry.progress_height
        background.offset[1] = (HUD.geometry.progress_width - background.size[1]) / 2
        background.offset[2] = (HUD.geometry.progress_height - background.size[2]) / 2
        progress.style.track.offset[2] = display == "bar" and 17 or 29
        progress.style.fill.offset[2] = progress.style.track.offset[2]
    end
    ui.visible = ui.id ~= nil or ui.award ~= nil or progress_visible
end)
mod:hook_safe(UIHud, "draw", function(hud, dt, t, input)
    local ui = instances[hud]
    if not ui or not ui.visible or not allowed(hud) or Managers.ui:using_input() then return end
    ui.render_settings = ui.render_settings or { force_retained_mode = false }
    local settings = ui.render_settings
    settings.scale, settings.inverse_scale, settings.alpha_multiplier = RESOLUTION_LOOKUP.scale, RESOLUTION_LOOKUP.inverse_scale, 1
    UIScenegraph.update_scenegraph(ui.graph)
    UIRenderer.begin_pass(hud._ui_renderer, ui.graph, input, dt, settings)
    if ui.id or ui.award then
        -- Use the same paused clock for both ends of an automatic notice.
        -- The host reserves this full presentation before the next choice.
        local enter = math.min(1, (ui.award and ui.award_age or ui.age) / enter_time)
        local fade = ui.resolving and math.clamp((Draft.selection_time - ui.resolving) / exit_time, 0, 1)
            or ui.award and math.min(enter, math.clamp((award_time - ui.award_age) / exit_time, 0, 1)) or enter
        ui.widgets.header.alpha_multiplier = fade
        UIWidget.draw(ui.widgets.header, hud._ui_renderer)
        for i = 1, 3 do
            local widget, selected = ui.widgets["card_" .. i], ui.award or ui.selected == i
            widget.offset[2] = 12 * (1 - enter) - (selected and 8 or 0)
            widget.alpha_multiplier = fade * (ui.selected and not selected and 0.22 or 1)
            widget.style.flash.color[1] = selected and math.max(0, 145 * (1 - (ui.resolving or ui.award_age or 0) / 0.45)) or 0
            widget.style.frame.color[2] = selected and 255 or 167
            widget.style.frame.color[3] = selected and 236 or 146
            widget.style.background.color[2] = selected and 55 or 12
            widget.style.background.color[3] = selected and 75 or 20
            widget.style.timer.size[1] = (HUD.geometry.card_width - 2 * HUD.geometry.padding) * (selected and 1 or math.min(1, ui.remaining / 60))
            if ui.choices[i] then UIWidget.draw(widget, hud._ui_renderer) end
        end
    end
    if ui.widgets.progress.content.show then UIWidget.draw(ui.widgets.progress, hud._ui_renderer) end
    UIRenderer.end_pass(hud._ui_renderer)
end)
mod:hook(UIHud, "destroy", function(func, hud, ...) cleanup(hud); return func(hud, ...) end)
return HUD
