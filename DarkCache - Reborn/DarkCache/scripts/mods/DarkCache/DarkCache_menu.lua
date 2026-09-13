local mod = get_mod("DarkCache")

-- ---------------------------------------------------------------------------
-- Live option tooltips
--
-- DMF resolves an option's tooltip once, when the mod's options are
-- initialised, and stores the finished string in dmf.options_widgets_data.
-- The options view then rebuilds its templates from that table every time it
-- is opened -- so updating the stored string is enough for the next open to
-- show it, with no restart.
--
-- That matters here because the only honest figures this mod has are ones it
-- measured, and a measurement taken this session would otherwise not reach the
-- menu until the next one.
--
-- Everything below reaches into DMF's internals, so all of it is optional: if
-- the shape ever changes, the tooltips simply keep whatever text they were
-- given at load and nothing else breaks.
-- ---------------------------------------------------------------------------

local menu = {}
mod.menu = menu

local widgets_by_setting = nil

local function find_widgets()
	if widgets_by_setting then
		return widgets_by_setting
	end

	local dmf = get_mod("DMF")
	local all = dmf and rawget(dmf, "options_widgets_data")

	if type(all) ~= "table" then
		return nil
	end

	local found = {}
	local mod_name = mod:get_name()

	for _, mod_widgets in ipairs(all) do
		if type(mod_widgets) == "table" then
			for _, widget in ipairs(mod_widgets) do
				if type(widget) == "table" and widget.mod_name == mod_name and widget.setting_id then
					found[widget.setting_id] = widget
				end
			end
		end
	end

	if next(found) then
		widgets_by_setting = found
	end

	return widgets_by_setting
end

-- DMF stores tooltips as "<title>\n<text>", so the title is put back on.
local function set_tooltip(setting_id, text)
	local widgets = find_widgets()
	local widget = widgets and widgets[setting_id]

	if not widget or not text then
		return
	end

	widget.tooltip = widget.title and (widget.title .. "\n" .. text) or text
end

local function join(...)
	local parts = {}

	for i = 1, select("#", ...) do
		local part = select(i, ...)

		if part and part ~= "" then
			parts[#parts + 1] = part
		end
	end

	return table.concat(parts, " ")
end

local function seconds(milliseconds)
	return string.format("%.1f", milliseconds / 1000)
end

-- What one level costs, in the player's language, from what was measured.
local function cost_text(figures)
	if not figures.vram_mb and not figures.ram_mb then
		return mod:localize("i18n_level_cost_unknown")
	end

	local cost = mod:localize("i18n_level_cost", figures.vram_mb or 0, figures.ram_mb or 0)
	local cold = figures.screen_cold_ms or figures.cold_ms
	local warm = figures.screen_warm_ms or figures.warm_ms

	if cold and warm and cold > warm then
		return join(cost, mod:localize("i18n_level_cost_time", seconds(warm), seconds(cold)))
	end

	return cost
end

function menu.refresh()
	local hub_cache = mod.hub_cache

	if not hub_cache or not find_widgets() then
		return
	end

	local levels = {
		{setting = "opt_cache_hub", base = "i18n_cache_hub_tooltip", level = hub_cache.HUB},
		{setting = "opt_cache_psykhanium", base = "i18n_cache_psykhanium_tooltip", level = hub_cache.PSYKHANIUM},
	}

	local total_vram, total_ram = 0, 0
	local any_enabled_and_measured = false

	for _, entry in ipairs(levels) do
		local figures = hub_cache.measurements(entry.level)

		set_tooltip(entry.setting, join(mod:localize(entry.base), cost_text(figures)))

		if mod:get(entry.setting) and (figures.vram_mb or figures.ram_mb) then
			total_vram = total_vram + (figures.vram_mb or 0)
			total_ram = total_ram + (figures.ram_mb or 0)
			any_enabled_and_measured = true
		end
	end

	local total = any_enabled_and_measured
		and mod:localize("i18n_levels_total", total_vram, total_ram)
		or mod:localize("i18n_levels_total_unknown")

	set_tooltip("opt_group_levels", join(mod:localize("i18n_group_levels_tooltip"), total))
end

return menu
