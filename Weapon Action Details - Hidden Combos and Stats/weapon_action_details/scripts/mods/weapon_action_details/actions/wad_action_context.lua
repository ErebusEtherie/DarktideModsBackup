-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_context.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")
local Weapon = mod:original_require("scripts/extension_systems/weapon/weapon")

mod.ACTIONS_WEAPON_CONTEXTS = mod.ACTIONS_WEAPON_CONTEXTS or {}

function mod.weapon_has_actions(item)
    local weapon_template = WeaponTemplate.weapon_template_from_item(item)

    return weapon_template and type(weapon_template.actions) == "table"
end

function mod.item_weapon_tweak_templates(item, weapon_template)
    if not item or not weapon_template then
        return nil
    end

    local weapon_tweak_templates, damage_profile_lerp_values = Weapon._init_traits(nil, weapon_template, item, nil, nil)

    return weapon_tweak_templates, damage_profile_lerp_values
end

function mod.get_shortest_paths(actions)
    local distances = {}
    local queue = {}

    if not actions then
        return distances
    end

    local wield_action = "action_wield"
    if actions[wield_action] then
        distances[wield_action] = 0
        queue[#queue + 1] = wield_action
    else
        for name, _ in pairs(actions) do
            if string.find(name, "wield", 1, true) then
                distances[name] = 0
                queue[#queue + 1] = name
            end
        end
    end

    local head = 1

    while head <= #queue do
        local current_name = queue[head]
        head = head + 1
        local current_action = actions[current_name]

        if current_action and type(current_action) == "table" and current_action.allowed_chain_actions then
            for _, chain_data in pairs(current_action.allowed_chain_actions) do
                local targets = {}

                if type(chain_data) == "table" then
                    if type(chain_data.action_name) == "string" then
                        targets[#targets + 1] = chain_data.action_name
                    elseif #chain_data > 0 then
                        for i = 1, #chain_data do
                            local c = chain_data[i]

                            if type(c) == "table" and type(c.action_name) == "string" then
                                targets[#targets + 1] = c.action_name
                            end
                        end
                    end
                end

                for i = 1, #targets do
                    local target = targets[i]

                    if not distances[target] then
                        distances[target] = distances[current_name] + 1
                        queue[#queue + 1] = target
                    end
                end
            end
        end
    end

    return distances
end
