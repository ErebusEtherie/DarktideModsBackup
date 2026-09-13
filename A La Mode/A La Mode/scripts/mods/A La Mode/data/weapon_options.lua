local mod = get_mod("A la Mode")

local M = {}

local function swatch(name)
	local fn = name and rawget(Color, name)

	if fn then
		return fn(255, true)
	end

	return Color.white(255, true)
end

M.swatch = swatch

local function display_name(key, data)
	local ok, text = pcall(Localize, data[1])

	if ok and type(text) == "string" and text ~= "" and text ~= data[1] then
		return text
	end

	return string.match(key, "[^/]+$") or key
end

M.build = function(valid_weapons)
	local entries = {}

	for key, data in pairs(valid_weapons) do
		entries[#entries + 1] = { key = key, data = data, label = display_name(key, data) }
	end

	table.sort(entries, function(a, b)
		if a.label == b.label then
			return a.key < b.key
		end

		return a.label < b.label
	end)

	local blocks, options = {}, { localize = false }

	options[1] = { text = mod:localize("alm_select_weapon"), value = "none", show_widgets = {} }

	for i = 1, #entries do
		local entry = entries[i]
		local key, data = entry.key, entry.data

		local sub = {
			{
				setting_id = key .. "-color_1",
				type = "color",
				title = "alm_color_normal",
				localize = true,
				default_value = swatch(data[2]),
				has_alpha = false,
			},
			{
				setting_id = key .. "-color_2",
				type = "color",
				title = "alm_color_active",
				localize = true,
				default_value = swatch(data[3]),
				has_alpha = false,
			},
		}

		if data[4] then
			sub[#sub + 1] = {
				setting_id = key .. "-color_3",
				type = "color",
				title = "alm_color_cooldown",
				localize = true,
				default_value = swatch(data[4]),
				has_alpha = false,
			}
		end

		blocks[i] = {
			setting_id = key .. "-group",
			type = "group",
			title = entry.label,
			localize = false,
			sub_widgets = sub,
		}

		options[i + 1] = { text = entry.label, value = key, show_widgets = { i } }
	end

	local stored = mod:get("alm_weapon_selector")

	if stored ~= nil then
		local known = false

		for i = 1, #options do
			if options[i].value == stored then
				known = true
				break
			end
		end

		if not known then
			mod:set("alm_weapon_selector", "none")
		end
	end

	M.entries = entries

	return {
		setting_id = "alm_weapon_selector",
		type = "dropdown",
		title = "alm_weapon_selector",
		default_value = "none",
		options = options,
		sub_widgets = blocks,
	}
end

return M
