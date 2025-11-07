local mod = get_mod("Decode_Helper")
local MinigameSettings = require("scripts/settings/minigame/minigame_settings")
local ScannerDisplayViewDecodeSymbolsSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_decode_symbols_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local decode_targets = {}
local highlight_widgets = {}

mod:hook_safe(CLASS.MinigameDecodeSymbols, "current_decode_target", function(self)
	decode_targets = self._decode_targets
end)

mod:hook_safe(CLASS.MinigameDecodeSymbolsView, "_draw_targets", function(self, widgets_by_name, decode_start_time, on_target)
	if #decode_targets > 0 then		
		local scenegraph_id = "center_pivot"
		local minigame_extension = self._minigame_extension
		local minigame = minigame_extension:minigame(MinigameSettings.types.decode_symbols)
		local widget_size = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_widget_size
		local starting_offset_x = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_starting_offset_x
		local starting_offset_y = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_starting_offset_y
		local spacing = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_spacing
		local current_decode_stage = minigame:current_stage()
		local grid_widgets = {}
		
		local limit = math.min(#decode_targets, current_decode_stage + mod:get("reveal_count"))
		
		for i = current_decode_stage + 1, limit do
			
			if i > current_decode_stage then	
				local widget_name = "highlight_" .. tostring(i)
			
				local widget_definition = UIWidget.create_definition({
					{
						pass_type = "texture",
						value = "content/ui/materials/backgrounds/scanner/scanner_decode_symbol_highlight",
						style_id = "highlight",
						style = {
							hdr = true,
							color = {
								mod:get("highlight_opacity"),
								255,
								165,
								0
							}
						}
					}
				}, scenegraph_id, nil, widget_size)
				local widget = UIWidget.init(widget_name, widget_definition)
				grid_widgets[#grid_widgets + 1] = widget
				local offset = widget.offset
				offset[1] = starting_offset_x + (widget_size[1] + spacing) * (decode_targets[i] - 1)
				offset[2] = starting_offset_y + (widget_size[2] + spacing) * (i - 1)
			end	
		end
		highlight_widgets = grid_widgets
	end
end)

mod:hook_safe(CLASS.MinigameDecodeSymbolsView, "draw_widgets", function(self, dt, t, input_service, ui_renderer)
	for i = 1, #highlight_widgets do
		local widget = highlight_widgets[i]
		UIWidget.draw(widget, ui_renderer)
	end
end)
		

