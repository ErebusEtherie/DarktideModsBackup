-- File: uptime/scripts/mods/uptime/tracking/uptime_loadout_tracking.lua
local mod = get_mod("uptime")
if not mod then
    return
end

local talent_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/talents")
local CharacterSheet = mod:original_require("scripts/utilities/character_sheet")
local MasterItems = mod:original_require("scripts/backend/master_items")
local Archetypes = mod:original_require("scripts/settings/archetype/archetypes")

local pairs = pairs
local type = type
local string_find = string.find

local ABILITY_TYPE = "combat_ability"

local DEFAULT_CATEGORIES = { "Blitz", "Aura", "Ability", "Keystone" }
local COMPANION_CATEGORIES = { "Blitz", "Aura", "Ability", "Keystone", "Companion" }

local CATEGORY_GRADIENTS = {
    Blitz = "content/ui/textures/color_ramps/talent_blitz",
    Aura = "content/ui/textures/color_ramps/talent_aura",
    Ability = "content/ui/textures/color_ramps/talent_ability",
    Keystone = "content/ui/textures/color_ramps/talent_keystone",
    Companion = "content/ui/textures/color_ramps/talent_keystone",
}

local EMPTY_TABLE = {}
local current_team_loadouts = {}

function mod:get_current_team_loadouts()
    return current_team_loadouts
end

local function get_player_profile(player)
    if not player then return nil end
    if player._profile then return player._profile end
    if type(player.profile) == "function" then return player:profile() end
    return nil
end

local function get_player_name(player)
    if not player then return nil end
    if type(player.name) == "function" then return player:name() end
    return player.name or player._name
end

local function get_player_account_id(player)
    if not player then return nil end
    if type(player.account_id) == "function" then return player:account_id() end
    return player.account_id or player._account_id
end

local function get_player_archetype_name(player, profile)
    local profile_archetype = profile and profile.archetype

    if type(profile_archetype) == "string" then return profile_archetype end

    local profile_archetype_name = profile_archetype and (profile_archetype.name or profile_archetype.archetype_name)

    if profile_archetype_name then return profile_archetype_name end
    if player and type(player.archetype_name) == "function" then return player:archetype_name() end
    return nil
end

local function get_is_human_controlled(player)
    if player and type(player.is_human_controlled) == "function" then
        return player:is_human_controlled()
    end
    return false
end

local function get_archetype_settings(archetype_name, profile)
    local profile_archetype = profile and profile.archetype

    if type(profile_archetype) == "table" then
        return profile_archetype
    end

    return Archetypes and Archetypes[archetype_name]
end

local function fill_class_loadout(profile, sheet_data)
    if not CharacterSheet or type(CharacterSheet.class_loadout) ~= "function" then
        return false
    end

    if not profile or not sheet_data or type(profile.archetype) ~= "table" then
        return false
    end

    local selected_nodes = type(profile.selected_nodes) == "table" and profile.selected_nodes or EMPTY_TABLE

    CharacterSheet.class_loadout(profile, sheet_data, false, selected_nodes)

    return true
end

local function get_runtime_combat_ability_icon(player)
    local unit = player and player.player_unit
    if not unit then return nil end
    if ALIVE and not ALIVE[unit] then return nil end
    if not ScriptUnit or type(ScriptUnit.has_extension) ~= "function" then return nil end

    local ability_extension = ScriptUnit.has_extension(unit, "ability_system")
    if not ability_extension or not ability_extension.equipped_abilities then return nil end

    local equipped_abilities = ability_extension:equipped_abilities()
    local ability = equipped_abilities and equipped_abilities[ABILITY_TYPE]

    return ability and ability.hud_icon
end

local function get_weapon_data(profile, slot_name)
    local loadout = profile and profile.loadout
    local item = loadout and loadout[slot_name]
    if not item then return nil end

    local item_name = item.name
    local icon = item.hud_icon or item.icon
    local display_name = "Weapon"

    if item_name and MasterItems and type(MasterItems.get_item) == "function" then
        local master_item = MasterItems.get_item(item_name)
        if master_item then
            icon = icon or master_item.hud_icon or master_item.icon
            display_name = master_item.display_name and Localize(master_item.display_name) or display_name
        end
    end

    local description = ""
    if item.traits and MasterItems and type(MasterItems.get_item) == "function" then
        for i = 1, #item.traits do
            local trait = item.traits[i]
            if trait and trait.id then
                local trait_master_item = MasterItems.get_item(trait.id)
                if trait_master_item and trait_master_item.display_name then
                    local trait_name = Localize(trait_master_item.display_name)
                    if description ~= "" then
                        description = description .. "\n"
                    end
                    description = description .. "• " .. trait_name
                end
            end
        end
    end

    local weapon_icon = icon or "content/ui/materials/icons/weapons/hud/combat_blade_01"

    if mod.packages and type(mod.packages.load_resource) == "function" then
        mod.packages.load_resource(weapon_icon)
    end

    return {
        slot = slot_name,
        icon = weapon_icon,
        display_name = display_name,
        description = description,
    }
end

local function find_talent_key_by_def(talent_def, arch_talents)
    if not talent_def or type(arch_talents) ~= "table" then return "" end
    for k, v in pairs(arch_talents) do
        if v == talent_def then return k end
    end
    return ""
end

local function get_talent_definition(talent_id, arch_talents)
    if type(talent_id) ~= "string" or talent_id == "" then
        return nil
    end

    if type(arch_talents) == "table" and arch_talents[talent_id] then
        return arch_talents[talent_id]
    end

    return talent_lib and talent_lib.get_talent and talent_lib.get_talent(talent_id) or nil
end

local function archetype_has_companion(archetype_settings)
    local num_companions = archetype_settings and archetype_settings.num_companions

    return type(num_companions) == "number" and num_companions > 0
end

local function is_companion_node(archetype_settings, node)
    if not archetype_has_companion(archetype_settings) or not node then
        return false
    end

    local talent_id = node.talent
    if type(talent_id) == "string" and string_find(talent_id, "companion", 1, true) then
        return true
    end

    local requirements = node.requirements
    local incompatible_talent = requirements and requirements.incompatible_talent
    if type(incompatible_talent) == "string" and string_find(incompatible_talent, "companion", 1, true) then
        return true
    end

    local exclusive_group = requirements and requirements.exclusive_group
    if type(exclusive_group) == "string" and string_find(exclusive_group, "dog", 1, true) then
        return true
    end

    return false
end

local function category_for_node(archetype_settings, node)
    local node_type = node and node.type

    if node_type == "ability" then
        return "Ability"
    elseif node_type == "tactical" then
        return "Blitz"
    elseif node_type == "aura" then
        return "Aura"
    elseif node_type == "keystone" then
        return is_companion_node(archetype_settings, node) and "Companion" or "Keystone"
    end

    return nil
end

local function category_order_for_archetype(archetype_settings)
    return archetype_has_companion(archetype_settings) and COMPANION_CATEGORIES or DEFAULT_CATEGORIES
end

function mod:capture_team_loadouts()
    local player_manager = Managers.player
    if not player_manager then
        current_team_loadouts = {}

        return current_team_loadouts
    end

    local players = player_manager:players()
    if not players then
        current_team_loadouts = {}

        return current_team_loadouts
    end

    local loadouts = {}

    for _, player in pairs(players) do
        local is_human = get_is_human_controlled(player)

        if is_human then
            local profile = get_player_profile(player)
            local archetype_name = get_player_archetype_name(player, profile)
            local player_name = get_player_name(player)
            local account_id = get_player_account_id(player) or player_name

            if account_id and archetype_name and profile then
                local archetype_settings = get_archetype_settings(archetype_name, profile)
                local player_talents = type(profile.talents) == "table" and profile.talents or EMPTY_TABLE
                local arch_talents = archetype_settings and archetype_settings.talents or EMPTY_TABLE

                -- 1. Get base loadout as fallback
                local sheet_data = { ability = {}, blitz = {}, aura = {} }
                fill_class_loadout(profile, sheet_data)

                -- 2. Read layout tree to find explicitly selected nodes for exact icons and exact dictionary keys
                local layout_nodes_found = {}
                local layout_path = archetype_settings and archetype_settings.talent_layout_file_path
                local layout = layout_path and mod:original_require(layout_path)

                if layout and layout.nodes then
                    for i = 1, #layout.nodes do
                        local node = layout.nodes[i]
                        local talent_id = node and node.talent

                        if talent_id and player_talents[talent_id] then
                            local category = category_for_node(archetype_settings, node)

                            if category then
                                layout_nodes_found[category] = node
                            end
                        end
                    end
                end

                local icons = {}
                local category_order = category_order_for_archetype(archetype_settings)

                for i = 1, #category_order do
                    local category = category_order[i]
                    local talent_id = ""
                    local icon = ""
                    local gradient_map = CATEGORY_GRADIENTS[category]
                    local display_name = category
                    local talent_def = nil

                    -- Try layout node first (explicitly selected by player)
                    local node = layout_nodes_found[category]
                    if node then
                        talent_id = node.talent or ""
                        talent_def = get_talent_definition(talent_id, arch_talents)
                        icon = node.icon or ""
                    end

                    -- Fallback to sheet_data for base talents (if player hasn't spent points yet)
                    if not talent_def then
                        local fallback_data = nil
                        if category == "Ability" then
                            fallback_data = sheet_data.ability
                        elseif category == "Blitz" then
                            fallback_data = sheet_data.blitz
                        elseif category == "Aura" then
                            fallback_data = sheet_data.aura
                        end

                        if fallback_data and fallback_data.talent then
                            talent_def = fallback_data.talent
                            talent_id = find_talent_key_by_def(talent_def, arch_talents)
                            icon = fallback_data.icon or icon
                        end
                    end

                    -- Special fallback for ability icon
                    if category == "Ability" and (not icon or icon == "") then
                        icon = get_runtime_combat_ability_icon(player) or ""
                    end

                    -- Fallback icon if missing
                    if not icon or icon == "" then
                        icon = talent_def and (talent_def.icon or talent_def.large_icon or talent_def.hud_icon) or ""
                    end

                    -- Gradient and name
                    if talent_def then
                        gradient_map = talent_def.gradient or talent_def.gradient_map or gradient_map
                        display_name = talent_def.display_name or talent_def.name or display_name
                    end

                    icons[i] = {
                        category = category,
                        valid = icon ~= "",
                        talent_id = talent_id,
                        icon = icon,
                        gradient_map = gradient_map,
                        display_name = display_name,
                    }
                end

                local weapons = {}
                weapons[1] = get_weapon_data(profile, "slot_primary")
                weapons[2] = get_weapon_data(profile, "slot_secondary")

                loadouts[account_id] = {
                    name = player_name,
                    archetype = archetype_name,
                    is_human = true,
                    icons = icons,
                    weapons = weapons,
                }
            end
        end
    end

    current_team_loadouts = loadouts

    return current_team_loadouts
end

