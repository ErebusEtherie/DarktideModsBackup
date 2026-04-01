-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_archetypes.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local UiSettings         = require("scripts/settings/ui/ui_settings")
local Personalities      = require("scripts/settings/character/personalities")
local type, pairs, table = type, pairs, table

local function _gender_suffix_for_personality(opt, voice_profile)
    local genders = opt and opt.visibility and opt.visibility.genders
    if type(genders) == "table" and #genders == 1 then
        local g = genders[1]
        if g == "male" then
            return " (" .. mod:localize("male") .. ")"
        elseif g == "female" then
            return " (" .. mod:localize("female") .. ")"
        end
    end

    if type(voice_profile) == "string" then
        if voice_profile:find("_male_", 1, true) or voice_profile:find("_male$") then
            return " (" .. mod:localize("male") .. ")"
        elseif voice_profile:find("_female_", 1, true) or voice_profile:find("_female$") then
            return " (" .. mod:localize("female") .. ")"
        end
    end
    return ""
end

-- Performance Impact: Moderate (runs only once during initial mod setup).
mod.zipit2_build_archetypes = function(D)
    do
        local archetypes = {}
        local archetypes_len = 0
        local archetype_set = {}

        local src = (UiSettings and (UiSettings.archetype_font_icon or UiSettings.archetype_font_icon_simple)) or {}
        if type(src) == "table" then
            for arch, _ in pairs(src) do
                if type(arch) == "string" and arch ~= "" then
                    archetype_set[arch] = true
                end
            end
        end

        for arch in pairs(archetype_set) do
            archetypes_len = archetypes_len + 1
            archetypes[archetypes_len] = arch
        end

        local arch_loc, arch_order = {}, {}
        for i = 1, archetypes_len do
            local arch = archetypes[i]
            local ad = mod.try_require(("scripts/settings/archetype/archetypes/%s_archetype"):format(arch))
            if type(ad) == "table" then
                if type(ad.archetype_name) == "string" and ad.archetype_name:find("^loc_") then
                    arch_loc[arch] = ad.archetype_name
                end
                if ad.ui_selection_order ~= nil then
                    arch_order[arch] = tonumber(ad.ui_selection_order)
                end
            end
        end

        table.sort(archetypes, function(a, b)
            local oa, ob = arch_order[a] or 999, arch_order[b] or 999
            if oa ~= ob then return oa < ob end
            return a < b
        end)

        D.archetypes = archetypes
        D.archetype_name_loc = arch_loc
        D.archetype_ui_order = arch_order
    end

    do
        local player_by_arch, all_player_set = {}, {}
        local voice_display_loc, voice_display, voice_to_arch = {}, {}, {}

        for _, opt in pairs(Personalities or {}) do
            if type(opt) == "table" then
                local voice = opt.character_voice
                if type(voice) == "string" and voice ~= "" then
                    all_player_set[voice] = true

                    local base_label = nil
                    local disp_loc = opt.display_name
                    if type(disp_loc) == "string" and disp_loc:find("^loc_") then
                        voice_display_loc[voice] = disp_loc
                        base_label = mod.try_localize_loc_key(disp_loc) or disp_loc
                    else
                        base_label = mod.speaker_label(voice)
                    end

                    voice_display[voice] = base_label .. _gender_suffix_for_personality(opt, voice)

                    local vis = opt.visibility
                    local arch_list = vis and vis.archetypes
                    local arch = (type(arch_list) == "table" and arch_list[1]) or (voice:match("^([^_]+)_") or voice)

                    voice_to_arch[voice] = arch
                    player_by_arch[arch] = player_by_arch[arch] or {}
                    local list = player_by_arch[arch]
                    list[#list + 1] = voice
                end
            end
        end

        for _, list in pairs(player_by_arch) do
            table.sort(list, function(a, b)
                local la, lb = voice_display[a] or a, voice_display[b] or b
                if la ~= lb then return la < lb end
                return a < b
            end)
        end

        D.player_by_arch = player_by_arch
        D.player_voice_set = all_player_set
        D.player_voice_display_loc = voice_display_loc
        D.player_voice_display = voice_display
        D.player_voice_to_archetype = voice_to_arch
    end
end
