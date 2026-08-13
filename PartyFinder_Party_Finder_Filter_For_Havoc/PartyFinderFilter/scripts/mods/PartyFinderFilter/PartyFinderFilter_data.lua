local mod = get_mod("PartyFinderFilter")

local Archetypes = require("scripts/settings/archetype/archetypes")
local ArchetypeTalents = require("scripts/settings/ability/archetype_talents/archetype_talents")

local ARCHETYPE_ORDER = { "veteran", "zealot", "psyker", "ogryn", "adamant", "broker", "cryptic" }

local DEFAULT_DECLINE_CLASS = {}

local DEFAULT_ALLOWED_ABILITY = {}

local ARCHETYPE_FALLBACK_TITLE = {
	veteran = "Veteran",
	zealot = "Zealot",
	psyker = "Psyker",
	ogryn = "Ogryn",
	adamant = "Arbitrator",
	broker = "Hive Scum",
	cryptic = "Skitarii",
}

local function _localize_game(loc_key, fallback)
	if loc_key then
		local ok, text = pcall(Localize, loc_key)

		if ok and text and text ~= "" then
			return text
		end
	end

	return fallback
end

local function _class_title(archetype_name, archetype)
	return _localize_game(archetype.archetype_name, ARCHETYPE_FALLBACK_TITLE[archetype_name] or archetype_name)
end

local function _talent_label(archetype_name, talent_id)
	local talent_defs = ArchetypeTalents[archetype_name]
	local talent_def = talent_defs and talent_defs[talent_id]

	return _localize_game(talent_def and talent_def.display_name, talent_id)
end

local function _ability_talents(archetype)
	local layout_path = archetype.talent_layout_file_path
	local ok, layout = pcall(require, layout_path)
	local nodes = ok and layout and layout.nodes

	if not nodes then
		return nil
	end

	local talents = {}
	local seen = {}

	for i = 1, #nodes do
		local node = nodes[i]

		if node.type == "ability" and node.talent and node.talent ~= "not_selected" and not seen[node.talent] then
			seen[node.talent] = true
			talents[#talents + 1] = node.talent
		end
	end

	return #talents > 0 and talents or nil
end

mod._abilities_by_archetype = {}

local widgets = {
	{
		setting_id = "filter_enabled",
		type = "checkbox",
		default_value = true,
		tooltip = "filter_enabled_desc",
	},
	{
		setting_id = "show_notification",
		type = "checkbox",
		default_value = true,
		tooltip = "show_notification_desc",
	},
	{
		setting_id = "decline_ps5",
		type = "checkbox",
		default_value = false,
		tooltip = "decline_ps5_desc",
	},
	{
		setting_id = "min_havoc_rank",
		type = "numeric",
		default_value = 0,
		range = { 0, 40 },
		tooltip = "min_havoc_rank_desc",
	},
}

local whole_class_title = mod:localize("filter_whole_class")
local whole_class_desc = mod:localize("filter_whole_class_desc")
local unique_title = mod:localize("filter_unique")
local unique_desc = mod:localize("filter_unique_desc")
local ability_group_title = mod:localize("ability_group_title")
local ability_allow_desc = mod:localize("ability_allow_desc")

for i = 1, #ARCHETYPE_ORDER do
	local archetype_name = ARCHETYPE_ORDER[i]
	local archetype = Archetypes[archetype_name]

	if archetype then
		local sub_widgets = {
			{
				setting_id = "filter_" .. archetype_name,
				type = "checkbox",
				default_value = DEFAULT_DECLINE_CLASS[archetype_name] == true,
				localize = false,
				title = whole_class_title,
				tooltip = whole_class_desc,
			},
			{
				setting_id = "unique_" .. archetype_name,
				type = "checkbox",
				default_value = false,
				localize = false,
				title = unique_title,
				tooltip = unique_desc,
			},
		}

		local ability_talents = _ability_talents(archetype)

		if ability_talents then
			local labels = {}
			local defaults = DEFAULT_ALLOWED_ABILITY[archetype_name] or {}
			local ability_widgets = {}

			for j = 1, #ability_talents do
				local talent_id = ability_talents[j]
				local label = _talent_label(archetype_name, talent_id)

				labels[talent_id] = label
				ability_widgets[#ability_widgets + 1] = {
					setting_id = "allow_ability_" .. archetype_name .. "_" .. talent_id,
					type = "checkbox",
					default_value = defaults[talent_id] == true,
					localize = false,
					title = label,
					tooltip = ability_allow_desc,
				}
			end

			mod._abilities_by_archetype[archetype_name] = labels

			sub_widgets[#sub_widgets + 1] = {
				setting_id = "abilitygrp_" .. archetype_name,
				type = "group",
				localize = false,
				title = ability_group_title,
				sub_widgets = ability_widgets,
			}
		else
			mod:warning("No ability talents for archetype '%s', ability filter unavailable", tostring(archetype_name))
		end

		widgets[#widgets + 1] = {
			setting_id = "group_" .. archetype_name,
			type = "group",
			localize = false,
			title = _class_title(archetype_name, archetype),
			sub_widgets = sub_widgets,
		}
	else
		mod:warning("Archetype '%s' not found, skipped", tostring(archetype_name))
	end
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
