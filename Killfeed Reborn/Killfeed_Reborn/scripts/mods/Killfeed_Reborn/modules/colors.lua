local colors = {}
local neon_formatting = get_mod("Killfeed_Reborn"):io_dofile("Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/neon_formatting")

-- Settings: color group titles
-- Maps each color slider to the DMF group header that should display that color.
colors.category_title_by_setting = {
    killer_1_r = "killer_1_color_group",
    killer_1_g = "killer_1_color_group",
    killer_1_b = "killer_1_color_group",
    killer_2_r = "killer_2_color_group",
    killer_2_g = "killer_2_color_group",
    killer_2_b = "killer_2_color_group",
    killer_3_r = "killer_3_color_group",
    killer_3_g = "killer_3_color_group",
    killer_3_b = "killer_3_color_group",
    killer_4_r = "killer_4_color_group",
    killer_4_g = "killer_4_color_group",
    killer_4_b = "killer_4_color_group",
    action_r = "action_color_group",
    action_g = "action_color_group",
    action_b = "action_color_group",
    death_action_r = "death_action_color_group",
    death_action_g = "death_action_color_group",
    death_action_b = "death_action_color_group",
    victim_r = "victim_color_group",
    victim_g = "victim_color_group",
    victim_b = "victim_color_group",
    neon_start_r = { "neon_settings_group", "neon_start_color_group" },
    neon_start_g = { "neon_settings_group", "neon_start_color_group" },
    neon_start_b = { "neon_settings_group", "neon_start_color_group" },
    neon_middle_r = { "neon_settings_group", "neon_middle_color_group" },
    neon_middle_g = { "neon_settings_group", "neon_middle_color_group" },
    neon_middle_b = { "neon_settings_group", "neon_middle_color_group" },
    neon_end_r = { "neon_settings_group", "neon_end_color_group" },
    neon_end_g = { "neon_settings_group", "neon_end_color_group" },
    neon_end_b = { "neon_settings_group", "neon_end_color_group" },
}

-- Text: markup cleanup
-- Removes Darktide rich-text tags so names and setting titles can be compared plainly.
function colors.strip_markup(text)
    if not text then
        return nil
    end

    local clean = string.gsub(text, "{#.-}", "")
    clean = string.gsub(clean, "{#reset%(%)%}", "")

    return clean
end

-- Text: color formatting
-- Wraps text in Darktide rich-text color tags used by the feed, chat, and subtitles.
function colors.colorize(text, color)
    return neon_formatting.colorize(text, color)
end

-- Text: neon formatting
-- Applies a per-character gradient across a string for the optional neon message style.
function colors.neon_text(text, neon_colors)
    return neon_formatting.gradient(text, neon_colors)
end

-- Killer colors: unit slot lookup
-- Resolves a player unit to its strike-team slot so Killer 1-4 colors stay in party order.
function colors.get_player_slot(unit)
    if not unit or not Managers.player then
        return nil
    end

    local player = Managers.player:player_by_unit(unit)
    return player and player.slot and player:slot() or nil
end

-- Killer colors: combat-feed color lookup
-- Returns the configured Killer color for a unit, falling back to Killer 1 when needed.
function colors.get_killer_color(unit, color_cache)
    local slot = colors.get_player_slot(unit)
    return color_cache.killers[slot] or color_cache.killers[1]
end

-- Killer colors: vanilla UI sync
-- Copies Killer 1-4 colors into UISettings so slot-colored UI surfaces inherit them.
function colors.apply_player_slot_colors(color_cache, UISettings)
    local player_slot_colors = UISettings and UISettings.player_slot_colors

    if not player_slot_colors then
        return
    end

    for slot = 1, 4 do
        local source_color = color_cache.killers[slot]
        local target_color = player_slot_colors[slot]

        if source_color and target_color then
            target_color[1] = 255
            target_color[2] = source_color[1]
            target_color[3] = source_color[2]
            target_color[4] = source_color[3]
        end
    end
end

-- Player lookup: player slot
-- Safely reads a player object's strike-team slot for chat and subtitle color matching.
local function player_slot(player)
    if not player or not player.slot then
        return nil
    end

    local ok, slot = pcall(function()
        return player:slot()
    end)

    return ok and slot or nil
end

-- Player lookup: color from player
-- Returns the configured Killer color for a player object.
local function player_color(player, color_cache)
    local slot = player_slot(player)
    return color_cache.killers[slot] or color_cache.killers[1]
end

-- Player lookup: normalized name
-- Converts rich-text player names into plain lowercase names for reliable matching.
local function normalize_player_name(name)
    local clean = colors.strip_markup(name)
    clean = clean and string.gsub(clean, "^%s+", "")
    clean = clean and string.gsub(clean, "%s+$", "")

    return clean and string.lower(clean) or nil
end

-- Player lookup: find by name
-- Searches current human players for a display name seen in chat or subtitles.
local function player_by_name(name)
    local target_name = normalize_player_name(name)
    local player_manager = Managers.player

    if not target_name or not player_manager or not player_manager.human_players then
        return nil
    end

    for _, player in pairs(player_manager:human_players() or {}) do
        local player_name = player and player.name and player:name()

        if normalize_player_name(player_name) == target_name then
            return player
        end
    end

    return nil
end

-- Player lookup: local player
-- Finds the local user for chat lines that Darktide labels as "You".
local function local_player()
    return Managers.player and Managers.player:local_player(1) or nil
end

-- Chat: local sender labels
-- Detects Darktide's local "You" sender labels so they can display the user's real name and color.
local function is_local_sender_label(sender)
    local clean = normalize_player_name(sender)

    return clean == "you" or clean and string.match(clean, "^you%s*%[") ~= nil
end

-- Chat: channel tag
-- Normalizes chat channel data so only player chat channels get sender recoloring.
local function chat_channel_tag(channel)
    return type(channel) == "table" and channel.tag or channel
end

-- Chat: sender colors
-- Recolors only the sender name shown in the local user's chat window.
function colors.colorize_chat_sender(sender, channel, color_cache, ChatManagerConstants)
    local ChannelTag = ChatManagerConstants and ChatManagerConstants.ChannelTag
    local chat_player_channels = ChannelTag and {
        [ChannelTag.HUB] = true,
        [ChannelTag.MISSION] = true,
        [ChannelTag.PARTY] = true,
        [ChannelTag.PRIVATE] = true,
    } or nil

    if not chat_player_channels or not chat_player_channels[chat_channel_tag(channel)] then
        return sender
    end

    local player = player_by_name(sender)
    local display_name = sender

    if not player and is_local_sender_label(sender) then
        player = local_player()

        if player then
            display_name = player:name() or sender
        end
    end

    if not player then
        return sender
    end

    return colors.colorize(display_name, player_color(player, color_cache))
end

-- Subtitles: trim speaker text
-- Removes edge spaces from the subtitle speaker name before matching it to a player.
local function trim(text)
    text = text and string.gsub(text, "^%s+", "")
    text = text and string.gsub(text, "%s+$", "")

    return text
end

-- Subtitles: speaker colors
-- Recolors only the player speaker name at the start of a subtitle line.
function colors.colorize_subtitle_speaker(text, color_cache)
    if not text or text == "" then
        return text
    end

    local prefix, suffix = string.match(text, "^(.-):(.*)$")

    if not prefix then
        return text
    end

    local speaker_name = trim(colors.strip_markup(prefix))
    local player = player_by_name(speaker_name)

    if not player then
        return text
    end

    return colors.colorize(speaker_name, player_color(player, color_cache)) .. ":" .. suffix
end

-- Settings: live color titles
-- Refreshes visible DMF color-group titles when a color setting changes.
function colors.refresh_color_group_title(mod, setting_id, category_title_by_setting)
    local base_keys = category_title_by_setting[setting_id]
    if not base_keys or not mod.apply_colours then
        return
    end

    if type(base_keys) ~= "table" then
        base_keys = { base_keys }
    end

    local dmf = get_mod("DMF")
    if not dmf or not dmf.options_widgets_data then
        return
    end

    local updated_loc = mod.apply_colours()
    local language = Managers.localization and Managers.localization:language() or "en"
    local mod_name = mod:get_name()
    local category_names = { mod:localize("mod_name") }
    local mod_data

    for i = 1, #dmf.options_widgets_data do
        mod_data = dmf.options_widgets_data[i]
        if mod_data[1] and mod_data[1].mod_name == mod_name then
            category_names[#category_names + 1] = mod_data[1].readable_mod_name
            category_names[#category_names + 1] = mod_data[1].title
            break
        end

        mod_data = nil
    end

    local view = Managers.ui and Managers.ui:view_instance("dmf_options_view")
    local widgets_by_category = view and view._settings_category_widgets
    if not widgets_by_category then
        return
    end

    local mod_widgets
    for i = 1, #category_names do
        if category_names[i] and widgets_by_category[category_names[i]] then
            mod_widgets = widgets_by_category[category_names[i]]
            break
        end
    end

    if not mod_widgets then
        return
    end

    for key_index = 1, #base_keys do
        local base_key = base_keys[key_index]
        local localized_group = updated_loc and updated_loc[base_key]
        local new_title = localized_group and (localized_group[language] or localized_group.en)

        if new_title then
            if mod_data then
                for j = 1, #mod_data do
                    if mod_data[j].setting_id == base_key then
                        mod_data[j].title = new_title
                        break
                    end
                end
            end

            local clean_target = colors.strip_markup(new_title)

            for i = 1, #mod_widgets do
                local content = mod_widgets[i].widget and mod_widgets[i].widget.content
                local entry = content and content.entry

                if entry and entry.setting_id == base_key then
                    entry.display_name = new_title
                    content.text = new_title
                    break
                end

                if content and colors.strip_markup(content.text) == clean_target then
                    if entry then
                        entry.display_name = new_title
                    end
                    content.text = new_title
                    break
                end
            end
        end
    end
end

return colors
