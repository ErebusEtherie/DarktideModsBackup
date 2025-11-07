local mod = get_mod("UnlimitedPower")

local settings_volume = mod:get("mod_volume")
local settings_chance = mod:get("mod_chance")
local settings_shadow = mod:get("mod_shadow")
mod.on_setting_changed = function(setting_name)
    if setting_name == "mod_volume" then
        settings_volume = mod:get(setting_name)
    elseif setting_name == "mod_chance" then
        settings_chance = mod:get(setting_name)
    elseif setting_name == "mod_shadow" then
        settings_shadow = mod:get(setting_name)
    end
end

local LocalServer = get_mod("DarktideLocalServer")
local Audio
local check_dependencies = function()
    Audio = get_mod("Audio")
    if not LocalServer then
        mod:echo(
            'Required mod "Darktide Local Server" not found: Download from Nexus Mods and include in mod_load_order.txt'
        )
        mod:disable_all_hooks()
        mod:disable_all_commands()
    end
    if not Audio then
        mod:echo(
            'Required mod "Audio Plugin" not found: Download from Nexus Mods and include in mod_load_order.txt'
        )
        mod:disable_all_hooks()
        mod:disable_all_commands()
    end
end

local action_chain_lightning_new_last = 0
local ActionActivateSpecial_last = 0
mod.on_all_mods_loaded = function()
    check_dependencies()
    mod:hook_require("scripts/extension_systems/weapon/actions/action_chain_lightning_new", function(instance)
        mod:hook_safe(instance, "start", function(self, action_settings, t, time_scale, action_start_params)
            if action_chain_lightning_new_last + 6 < t then
                if math.random() < (settings_chance / 100) then
                    if settings_shadow == true then
                        Audio.play_file("UnlimitedPower/audio/shadow.ogg",
                            { audio_type = "sfx", volume = settings_volume, speechnorm = "e=50:r=0.0001:l=1" })
                    else
                        Audio.play_file("UnlimitedPower/audio/unlimitedpower.ogg",
                            { audio_type = "sfx", volume = settings_volume, speechnorm = "e=50:r=0.0001:l=1" })
                    end
                    action_chain_lightning_new_last = t
                end
            end
        end)
    end)

    mod:hook_require("scripts/extension_systems/weapon/actions/action_overload_explosion", function(instance)
        mod:hook_safe(instance, "start", function()
            if math.random() < (settings_chance / 100) then
                Audio.play_file("UnlimitedPower/audio/nonono.ogg",
                    { audio_type = "sfx", volume = settings_volume, speechnorm = "e=50:r=0.0001:l=1" })
            end
        end)
        mod:hook_safe(instance, "finish", function()
            if math.random() < (settings_chance / 100) then
                Audio.play_file("UnlimitedPower/audio/theattemptonmylife.ogg",
                    { audio_type = "sfx", volume = settings_volume, speechnorm = "e=50:r=0.0001:l=1" })
            end
        end)
    end)

    mod:hook_safe(CLASS.ActionActivateSpecial, "start", function(self, action_settings, t, time_scale, params)
        if ActionActivateSpecial_last + 3 < t then
            if math.random() < (settings_chance / 100) then
                if (table.contains(self._weapon_template.keywords, "force_sword") == true) then
                    Audio.play_file("UnlimitedPower/audio/itstreasonthen.ogg",
                        { audio_type = "sfx", volume = settings_volume, speechnorm = "e=50:r=0.0001:l=1" })
                end
                ActionActivateSpecial_last = t
            end
        end
    end)
end
