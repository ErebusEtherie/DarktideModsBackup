local mod = get_mod("Killfeed Details")
local UIFonts = require("scripts/managers/ui/ui_fonts")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local AttackSettings = require("scripts/settings/damage/attack_settings")
local HudElementCombatFeedSettings = require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_settings")

local MOD = {
    ENABLED = true,
    BUFFER = {}
}

local IconDefinitions = mod:io_dofile("Killfeed Details/scripts/mods/Killfeed Details/hud_element_combat_feed_icon_definition")

local IconTemplate = {
    fade_in = 0.5,
    fade_out = 1,
    widget_definition = IconDefinitions.notification_message_icon,
}

local ICON_CRIT_COLOR = {
    255,
    255,
    165,
    0,
}
local CRIT_COLOR = "{#color(255,165,0,255)}"
local WHITE_COLOR = "{#color(255,255,255,255)}"

local UNICODE_TABLE = {
    -- Attack Types
    companion_dog                 = "",
    shout                         = "",
    push                          = "",
    door_smash                    = "",
    chem                          = "",
    warp                          = "",
    -- Misc.
    kill_volume_and_off_navmesh   = "",
    psyker_biomancer_shout        = "",
    psyker_biomancer_shout_damage = "",
    -- Custom
    rock                          = mod:localize("rock_kill")
}

local ICON_TABLE = {
    -- Weaponry
    melee                                  = "content/ui/materials/icons/weapons/actions/linesman",
    melee_headshot                         = "content/ui/materials/icons/weapons/actions/smiter",
    headshot                               = "content/ui/materials/icons/weapons/actions/ads",
    ranged                                 = "content/ui/materials/icons/weapons/actions/hipfire",
    -- Bleeding
    bleeding                               = "content/ui/materials/icons/presets/preset_13",
    -- Electricity
    electricity                            = "content/ui/materials/icons/presets/preset_11",
    psyker_heavy_swings_shock              = "content/ui/materials/icons/presets/preset_11",
    powermaul_p2_stun_interval             = "content/ui/materials/icons/presets/preset_11",
    powermaul_p2_stun_interval_basic       = "content/ui/materials/icons/presets/preset_11",
    shockmaul_stun_interval_damage         = "content/ui/materials/icons/presets/preset_11",
    shock_grenade_stun_interval            = "content/ui/materials/icons/presets/preset_11",
    protectorate_force_field               = "content/ui/materials/icons/presets/preset_11",
    -- Explosion
    broker_flash_grenade_impact            = "content/ui/materials/icons/presets/preset_19",
    explosion                              = "content/ui/materials/icons/presets/preset_19",
    barrel_explosion_close                 = "content/ui/materials/icons/presets/preset_19",
    barrel_explosion                       = "content/ui/materials/icons/presets/preset_19",
    poxwalker_explosion_close              = "content/ui/materials/icons/presets/preset_19",
    poxwalker_explosion                    = "content/ui/materials/icons/presets/preset_19",
    default                                = "content/ui/materials/icons/presets/preset_19",
    -- Burn
    flame_grenade_liquid_area_fire_burning = "content/ui/materials/icons/presets/preset_20",
    liquid_area_fire_burning_barrel        = "content/ui/materials/icons/presets/preset_20",
    liquid_area_fire_burning               = "content/ui/materials/icons/presets/preset_20",
    burning                                = "content/ui/materials/icons/presets/preset_20",
    warpfire                               = "content/ui/materials/icons/presets/preset_20",
    -- Toxin
    toxin_variant_1                        = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    toxin_variant_2                        = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    toxin_variant_3                        = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    chem_burning                           = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    chem_burning_fast                      = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    chem_burning_slow                      = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    broker_stimm_field                     = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    broker_stimm_field_close               = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    broker_tox_grenade                     = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
    broker_toxin_stacks_stun_interval      = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
}

mod.on_enabled = function()
    MOD.ENABLED = true
end

mod.on_disabled = function()
    MOD.ENABLED = false
end

mod.on_game_state_changed = function(state, state_name)
    -- Preload Preset Icons
    Managers.package:load("packages/ui/views/inventory_view/inventory_view", "KillfeedDetails", nil, true)
    Managers.package:load("packages/ui/views/inventory_weapons_view/inventory_weapons_view", "KillfeedDetails", nil, true)
    Managers.package:load("packages/ui/views/inventory_background_view/inventory_background_view", "KillfeedDetails", nil, true)
    Managers.package:load("packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view", "KillfeedDetails", nil, true)
    -- Preload Weapon Icons
    Managers.package:load("packages/ui/hud/player_weapon/player_weapon", "KillfeedDetails", nil, true)
    Managers.package:load("packages/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view", "KillfeedDetails", nil, true)
    -- Other stuff that probably isn't needed but don't dare remove just yet
    Managers.package:load("packages/ui/views/cosmetics_inspect_view/cosmetics_inspect_view", "KillfeedDetails", nil, true)
    Managers.package:load("packages/ui/views/masteries_overview_view/masteries_overview_view", "KillfeedDetails", nil, true)
end

mod.on_unload = function()
end

mod.on_all_mods_loaded = function()
    MOD.ENABLED = mod:get("ENABLED")
end

mod.on_setting_changed = function(setting_id)
    if MOD[setting_id] ~= nil then
        MOD[setting_id] = mod:get(setting_id)
    end
end

mod.update = function()
end

local temp_kill_message_localization_params = {
    killer = "n/a",
    victim = "n/a",
}
local kill_message_localization_key = "loc_hud_combat_feed_kill_message"

mod:hook("HudElementCombatFeed", "event_combat_feed_kill", function(func, self, attacking_unit, attacked_unit)
    if not MOD.ENABLED then return func(self, attacking_unit, attacked_unit) end
    if type(attacked_unit) == "string" then
        -- scoreboard mod compatibility
        return
    end
    local killer = self:_get_unit_presentation_name(attacking_unit)
    local victim = self:_get_unit_presentation_name(attacked_unit)
    temp_kill_message_localization_params.killer = killer
    temp_kill_message_localization_params.victim = victim
    local use_icon = false
    local icon = nil
    local is_critical = false
    -- Kill Lookup
    for entry, record in ipairs(MOD.BUFFER) do
        if record.killer == attacking_unit and record.victim == attacked_unit then
            local damage_type = record.damage_type
            if not damage_type or damage_type == "buff" or (not ICON_TABLE[damage_type] and not UNICODE_TABLE[damage_type])then
                damage_type = record.damage_profile.name
            end
            
            -- Overrides
            if record.damage_profile.name == "psyker_protectorate_spread_chain_lightning_interval" then
                damage_type = "electricity"
            end
            if record.damage_profile.name == "psyker_smite_kill" then
                damage_type = "warp"
            end
            if record.damage_profile.name == "ogryn_friendly_rock_impact" then
                damage_type = "rock"
            end
            -- Unicode
            if damage_type == "melee" and record.hit_weakspot then
                damage_type = "melee_headshot"
            end
            if damage_type == "ranged" and record.hit_weakspot then
                damage_type = "headshot"
            end
            is_critical = record.is_critical
            -- Color rock headshots as crits to distinguish them, as the rock cannot crit and lacks a headshot icon
            if damage_type == "rock" and record.hit_weakspot then
                is_critical = true
            end
            if UNICODE_TABLE[damage_type] then
                use_icon = false
                icon = UNICODE_TABLE[damage_type]
                if is_critical then
                    icon = CRIT_COLOR .. icon
                else
                    icon = WHITE_COLOR .. icon
                end
            end
            -- Icons
            if ICON_TABLE[damage_type] then
                use_icon = true
                icon = ICON_TABLE[damage_type]
            end
            -- DEBUG: DISPLAY MISSING ICON INFORMATION
            local debug = false
            if debug and not icon then
                mod:echo("MISSING ICON FOR KILL RECORD:")
                mod:echo("Killer: %s, Victim: %s", killer, victim)
                mod:echo("Damage Type: %s", damage_type)
                mod:echo("Damage Profile: %s", record.damage_profile.name)
            end
            table.remove(MOD.BUFFER, entry)
        end
    end

    -- Base Text
    local vanilla_text = self:_localize(kill_message_localization_key, true, temp_kill_message_localization_params)
    local prefix, suffix
    local killed_pos = string.find(vanilla_text, "killed")
    if killed_pos then
        prefix = string.sub(vanilla_text, 1, killed_pos - 1)
        suffix = string.sub(vanilla_text, killed_pos + 6)
    end

    if not self:_enabled() then
        return
    end
    
    -- Text Modification + Notification Generation
    if use_icon and prefix and suffix then
        ------------------------------------------------------------------------
        local notification_template = IconTemplate
        local widget_definition = notification_template.widget_definition
        local name = "notification_" .. self._notification_id_counter

        self._notification_id_counter = self._notification_id_counter + 1

        local widget = self:_create_widget(name, widget_definition)
        local notification = table.clone(notification_template)

        notification.widget = widget
        notification.type = "icon"
        if is_critical then
            notification.widget.style.icon.color = ICON_CRIT_COLOR
        end
        notification.id = self._notification_id_counter
        local parent_id = notification.id
        notification.time = 0

        local notifications = self._notifications
        local start_index = 1
        local start_height = self:_get_height_of_notification_index(start_index)

        self:_set_widget_position(widget, nil, start_height)
        table.insert(notifications, start_index, notification)
        ------------------------------------------------------------------------
        if not icon then
            icon = ICON_TABLE.icon_01
        end
        -- Set Icon
        self:_set_icon(notification.id, icon)
        -- Add Corresponding Text
        -- Prefix
        local _, prefix_id = self:_add_notification_message("default")
        local prefix_notification = self:_notification_by_id(prefix_id)
        prefix_notification.parent_id = parent_id
        prefix_notification.type = "prefix"
        notification.prefix = prefix_id
        self:_set_text(prefix_id, prefix)
        -- Suffix
        local _, suffix_id = self:_add_notification_message("default")
        local suffix_notification = self:_notification_by_id(suffix_id)
        suffix_notification.parent_id = parent_id
        notification.suffix = suffix_id
        suffix_notification.type = "suffix"
        self:_set_text(suffix_id, suffix)
    else
        local _, notification_id = self:_add_notification_message("default")
        if prefix and suffix then
            if not icon then icon = "killed" end
            local new_text = prefix .. " " .. icon .. " " .. suffix
            self:_set_text(notification_id, new_text)
        else
            -- Failsafe
            self:_set_text(notification_id, vanilla_text)
        end
    end
end)

mod:hook("HudElementCombatFeed","_get_notifications_text_height",function (func, self, notification, ui_renderer)
    if not MOD.ENABLED then return func(self, notification, ui_renderer) end
    local widget = notification.widget
	local content = widget.content
	local text = content.text
	local style = widget.style
	local text_style = style.text
    if not text_style then return 21.215 end -- Default override for non-text notifications
	local text_size = text_style.size
    local font_type = text_style.font_type
    local font_size = text_style.font_size
	local text_options = UIFonts.get_font_options_by_style(text_style)
	local text_length, text_height = UIRenderer.text_size(ui_renderer, text, font_type, font_size, text_size, text_options)
	return text_height, text_length
end)

mod:hook("HudElementCombatFeed","_align_notification_widgets", function (func, self, dt)
    if not MOD.ENABLED then return func(self, dt) end
	local ui_renderer = self._parent:ui_renderer()
	local entry_spacing = HudElementCombatFeedSettings.entry_spacing
	local text_height_spacing = HudElementCombatFeedSettings.text_height_spacing
	local header_size = HudElementCombatFeedSettings.header_size
	local offset_y = 0
	local notifications = self._notifications

	for i = 1, #notifications do
		local notification = notifications[i]

		if notification then
			local widget = notification.widget
			local widget_offset = widget.offset
			local text_height, text_length = self:_get_notifications_text_height(notification, ui_renderer)
			local widget_height = text_height
			local style = widget.style

			if style.background then
				widget_height = math.max(header_size[2], widget_height + text_height_spacing * 2)
				style.background.size[2] = widget_height
			end

			if style.text then
				style.text.size[2] = widget_height
			end

			if style.icon then
				local icon_height = style.icon.size[2]
				style.icon.offset[2] = (widget_height * 0.5 - icon_height * 0.5) - 2
			end

            local prefix, suffix
            -- Icon Prefix Alignment
            if notification.type == "prefix" then
                prefix = true
                local parent = self:_notification_by_id(notification.parent_id)
                if parent then
                    local parent_widget = parent.widget
                    -- Move icon horizontally to fit after prefix
                    parent_widget.offset[1] = parent_widget.style.icon.offset[1] + text_length + 15
                    -- Match vertical alignment to icon
                    widget_offset[2] = parent_widget.offset[2]
                else
                    -- Correct for orphaned notification fragments
                    self:_remove_notification(notification.id)
                end
            end
            -- Icon Suffix Alignment
            if notification.type == "suffix" then
                suffix = true
                local parent = self:_notification_by_id(notification.parent_id)
                if parent then
                    local parent_widget = parent.widget
                    -- Move suffix horizontally to fit after icon
                    widget.offset[1] = parent_widget.offset[1] - 10
                    -- Match vertical alignment to icon
                    widget_offset[2] = parent_widget.offset[2]
                else
                    -- Correct for orphaned notification fragments
                    self:_remove_notification(notification.id)
                end
            end
            if offset_y > widget_offset[2] then
                widget_offset[2] = math.lerp(widget_offset[2], offset_y, dt * 6)
            else
                widget_offset[2] = math.lerp(widget_offset[2], offset_y, dt * 2)
            end
            -- Increment total offset only once per notification/icon group
            if not (prefix or suffix) then
                offset_y = offset_y + widget_height + entry_spacing
            end
		end
	end
end)

mod:hook("AttackReportManager", "_process_attack_result", function(func, self, buffer_data)
    if not MOD.ENABLED then return func(self, buffer_data) end
    -- Baseline data collection
    local attacked_unit = buffer_data.attacked_unit
	local attacking_unit = buffer_data.attacking_unit
	local hit_weakspot = buffer_data.hit_weakspot
	local attack_result = buffer_data.attack_result
	local attack_type = buffer_data.attack_type
	local damage_profile = buffer_data.damage_profile
	local is_critical_strike = buffer_data.is_critical_strike
	local player_unit_spawn_manager = Managers.state.player_unit_spawn
	local attacking_player = attacking_unit and player_unit_spawn_manager:owner(attacking_unit)

	local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	local breed_or_nil = unit_data_extension and unit_data_extension:breed()

	if attacking_player then
		local tags = breed_or_nil and breed_or_nil.tags
		local allowed_breed = tags and (tags.captain or tags.monster or tags.special or tags.elite)

		if allowed_breed and attack_result == AttackSettings.attack_results.died then
			table.insert(MOD.BUFFER, {
                killer = attacking_unit,
                victim = attacked_unit,
                damage_type = attack_type,
                damage_profile = damage_profile,
                is_critical = is_critical_strike,
                hit_weakspot = hit_weakspot
            })
            -- Add Captains
            if tags.captain then
                Managers.event:trigger("event_combat_feed_kill", attacking_unit, attacked_unit)
            end
		end
	end
    return func(self, buffer_data)
end)

mod:hook("HudElementCombatFeed", "_draw_widgets", function (func, self, dt, t, input_service, ui_renderer, render_settings)
    if not MOD.ENABLED then return func(self, dt, t, input_service, ui_renderer, render_settings) end
	HudElementCombatFeed.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

	local header_size = HudElementCombatFeedSettings.header_size
	local notifications = self._notifications
	local total_time = self._message_duration

    local total_notifications = 0
    for i = 1, #notifications do
        local notification = notifications[i]
        if notification then
            if notification.type == "icon" or not notification.type then
                total_notifications = total_notifications + 1
            end
            if total_notifications > self._max_messages then
                --[[
                if notification.suffix then
                    self:_remove_notification(notification.suffix)
                end
                if notification.prefix then
                    self:_remove_notification(notification.prefix)
                end
                if notification.parent_id then
                    self:_remove_notification(notification.parent_id)
                end
                --]]
                self:_remove_notification(notification.id)
            end
        end
    end

	for i = #notifications, 1, -1 do
		local notification = notifications[i]

		if notification then
			notification.time = (notification.time or 0) + dt

			local time = notification.time

			if time and total_time and total_time <= time then
				self:_remove_notification(notification.id)
			else
				local widget = notification.widget
				local alpha_multiplier = 1
				local fade_out = notification.fade_out
				local fade_in = notification.fade_in
				local time_passed = time

				if fade_in and time_passed <= fade_in then
					local progress = math.min(time_passed / fade_in, 1)

					alpha_multiplier = math.easeInCubic(progress)
				elseif total_time and fade_out and time_passed >= total_time - fade_out then
					alpha_multiplier = (total_time - time_passed) / fade_out
				end

				if notification.animate_x_axis then
					self:_set_widget_position(widget, -header_size[1] + math.easeCubic(alpha_multiplier) * header_size[1])
				end

				widget.alpha_multiplier = alpha_multiplier

				UIWidget.draw(widget, ui_renderer)
			end
		end
	end
end)