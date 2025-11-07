local mod = get_mod("ImprovedHavocTags")

local function readable(text)
    local readable_string = ""
    local tokens = string.split(text, "_")
    for i, token in ipairs(tokens) do
        local first_letter = string.sub(token, 1, 1)
        token = string.format("%s%s", string.upper(first_letter), string.sub(token, 2))
        readable_string = string.trim(string.format("%s %s", readable_string, token))
    end
    return readable_string
end

local color_options = {}
if Color and Color.list then
    for _, color_name in ipairs(Color.list) do
        local localized_name = mod:localize(color_name)
        table.insert(color_options, { 
            text = color_name,
            value = color_name,
            localized_text = localized_name
        })
    end
    
    table.sort(color_options, function(a, b)
        return a.text < b.text
    end)
end

local function get_color_options()
    return table.clone(color_options)
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
			{
                setting_id = "increased_difficulty",
                type = "dropdown",
                default_value = "white",
                options = get_color_options()
            },
			{
                setting_id = "highest_difficulty",
                type = "dropdown",
                default_value = "white",
                options = get_color_options()
            },
            {
                setting_id = "bolstering_enemies",
                type = "dropdown",
                default_value = "item_rarity_5",
                options = get_color_options()
            },
            {
                setting_id = "encroaching_garden",
                type = "dropdown",
				tooltip = "encroaching_garden_tooltip",
                default_value = "blue_violet",
                options = get_color_options()
            },
            {
                setting_id = "enraged",
                type = "dropdown",
				tooltip = "enraged_tooltip",
                default_value = "ui_red_light",
                options = get_color_options()
            },
            {
                setting_id = "chaos_ritual",
                type = "dropdown",
                default_value = "lime",
                options = get_color_options()
            },
            {
                setting_id = "armored_infected",
                type = "dropdown",
                default_value = "steel_blue",
                options = get_color_options()
            },
			{
                setting_id = "enemies_corrupted",
                type = "dropdown",
                default_value = "olive",
                options = get_color_options()
            },
			{
                setting_id = "enemies_parasite_headshot",
                type = "dropdown",
                default_value = "light_salmon",
                options = get_color_options()
            },
			{
                setting_id = "tougher_skin",
                type = "dropdown",
                default_value = "citadel_ogryn_camo",
                options = get_color_options()
            },
			{
                setting_id = "rotten_armor",
                type = "dropdown",
                default_value = "citadel_nurgling_green",
                options = get_color_options()
            },
			{
                setting_id = "stimmed_minions",
                type = "dropdown",
                default_value = "citadel_dorn_yellow",
                options = get_color_options()
            },
			{
                setting_id = "ember",
                type = "dropdown",
                default_value = "sienna",
                options = get_color_options()
            },
            {
                setting_id = "toxic_gas",
                type = "dropdown",
                default_value = "yellow_green",
                options = get_color_options()
            },
			{
                setting_id = "toxic_gas_cultist_grenadier",
                type = "dropdown",
                default_value = "yellow_green",
                options = get_color_options()
            },
            {
                setting_id = "ventilation_purge",
                type = "dropdown",
                default_value = "gray",
                options = get_color_options()
            },
			{
                setting_id = "ventilation_purge_with_snipers",
                type = "dropdown",
                default_value = "gray",
                options = get_color_options()
            },
            {
                setting_id = "darkness",
                type = "dropdown",
                default_value = "citadel_nuln_oil",
                options = get_color_options()
            },
			{
                setting_id = "darkness_hunting_grounds",
                type = "dropdown",
                default_value = "citadel_nuln_oil",
                options = get_color_options()
            },
        }
    }
}