local mod = get_mod("helbore_passive_charge")

mod:debug("Hooking ui")

local charge_hud_element = {
    package = "packages/ui/views/inventory_background_view/inventory_background_view",
    use_hud_scale = true,
    class_name = "HudElementCharge",
    filename = "helbore_passive_charge/scripts/mods/helbore_passive_charge/hud_element_helbore_charge",
    visibility_groups = {
        "alive",
        "communication_wheel",
        "tactical_overlay"
    }
}
mod:add_require_path(charge_hud_element.filename)

local _add_hud_element = function(element_pool)
    
    local found_key, _ = table.find_by_key(element_pool, "class_name", charge_hud_element.class_name)
    if found_key then
        mod:debug("Replacing hud element, %s", tostring(charge_hud_element))
        element_pool[found_key] = charge_hud_element
    else
        mod:debug("Adding hud element, %s", tostring(charge_hud_element))
        table.insert(element_pool, charge_hud_element)
    end
end
mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", _add_hud_element)
mod:hook_require("scripts/ui/hud/hud_elements_player", _add_hud_element)

mod.get_hud_element = function()
    local hud = Managers.ui:get_hud()
    return hud and hud:element(charge_hud_element.class_name)
end
