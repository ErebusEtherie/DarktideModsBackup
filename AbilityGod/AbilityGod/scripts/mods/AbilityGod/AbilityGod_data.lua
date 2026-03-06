local mod = get_mod("AbilityGod")

-- ── dropdown options --------------------------------------------------
local MODE = {
    never=1,
    tough=2,
    peril=3,
    health=4,
    tough_or_peril=5, -- legacy "both"
    tough_or_health=6,
    peril_or_health=7,
    tough_or_peril_or_health=8,
}

local function opts_psyker()
    return {
        { text = "mode_never", value = MODE.never },
        { text = "mode_tough", value = MODE.tough },
        { text = "mode_peril", value = MODE.peril },
        { text = "mode_health", value = MODE.health },
        { text = "mode_tough_or_peril", value = MODE.tough_or_peril },
        { text = "mode_tough_or_health", value = MODE.tough_or_health },
        { text = "mode_peril_or_health", value = MODE.peril_or_health },
        { text = "mode_tough_or_peril_or_health", value = MODE.tough_or_peril_or_health },
    }
end
local function opts_other()
    return {
        { text = "mode_never", value = MODE.never },
        { text = "mode_tough", value = MODE.tough },
        { text = "mode_health", value = MODE.health },
        { text = "mode_tough_or_health", value = MODE.tough_or_health },
    }
end

return {
    name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
            {
                setting_id = "master_enable",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id = "toughness_thresh",
                type = "numeric", 
                default_value = 20, 
                range = { 1, 100 }
            },
            {
                setting_id = "peril_thresh",
                type = "numeric",
                default_value = 90,
                range = { 1, 100 }
            },
            {
                setting_id = "health_thresh",
                type = "numeric",
                default_value = 50,
                range = { 1, 100 }
            },
            {
                setting_id = "header_veteran",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "veteran_exec",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "veteran_voice",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "veteran_infil",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                },
            },
            {
                setting_id = "header_psyker",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "psyker_shout",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_psyker(),
                    },
                    {
                        setting_id = "psyker_shield",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_psyker(),
                    },
                    {
                        setting_id = "psyker_over",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_psyker(),
                    },
                },
            },
            {
                setting_id = "header_zealot",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "zealot_dash",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "zealot_prayer",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "zealot_stealth",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                },
            },
            {
                setting_id = "header_ogryn",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "ogryn_rush",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "ogryn_taunt",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "ogryn_ammo",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                },
            },
            {
                setting_id = "header_arbiter",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "arbiter_stance",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "arbiter_drone",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "arbiter_charge",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                },
            },
            {
                setting_id = "header_broker",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "broker_focus",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "broker_punk",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                    {
                        setting_id = "broker_stimm",
                        type = "dropdown",
                        default_value = MODE.never,
                        options = opts_other(),
                    },
                },
            },
        },
	},
}
