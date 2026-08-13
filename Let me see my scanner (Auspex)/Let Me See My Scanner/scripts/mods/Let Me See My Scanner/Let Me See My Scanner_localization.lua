local ok, base = pcall(require, "Scanner Darkly/scripts/mods/Scanner Darkly/Scanner Darkly_localization")
if not ok then
    base = {}
end

local overrides = {
    mod_name = {
        en = "Let Me See My Scanner",
    },
    mod_description = {
        en = "Hide or fade selected HUD elements while using the auspex (includes smooth fade and configurable opacity).",
    },
}

for key, val in pairs(overrides) do
    base[key] = val
end

base.scanner_fade = nil

base.caption_opacity = { en = "Caption opacity while scanning" }
base.caption_opacity_description = { en = "Opacity applied to subtitles and letterbox bars when using the auspex." }

base.transparency_amount = { en = "Transparency amount" }
base.transparency_amount_description = { en = "How transparent HUD elements become when scanning. Lower values make elements more transparent (0 = fully transparent, 1 = fully opaque)." }

base.smooth_fade = { en = "Smooth fade" }
base.smooth_fade_description = { en = "Enable smooth fading transitions when elements appear or disappear while scanning." }

base.fade_duration = { en = "Fade duration" }
base.fade_duration_description = { en = "How long the fade transition takes in seconds when smooth fade is enabled." }

base.toggle_visibility_header = { en = "Toggle Visibility" }

base.hide_buff_bars_on_scan = { en = "Hide Better Buff Management buff bars" }
base.hide_buff_bars_on_scan_description = { en = "Hide or fade all buff bars created by the Better Buff Management mod while the auspex scanner is equipped or scanning." }

base.hide_crosshair = { en = "Hide Crosshair" }
base.hide_crosshair_description = { en = "Hide or fade the crosshair while using the auspex scanner." }

base.hide_crosshair_hud = { en = "Hide Crosshair HUD" }
base.hide_crosshair_hud_description = { en = "Hide or fade the crosshair HUD overlay while using the auspex scanner." }

base.hide_dodge_counter = { en = "Hide Dodge Counter (Vanilla)" }
base.hide_dodge_counter_description = { en = "Hide or fade the vanilla dodge counter bar display while using the auspex scanner." }

base.hide_dodge_count = { en = "Hide Dodge Count (Modded)" }
base.hide_dodge_count_description = { en = "Hide or fade the modded dodge count text/number display while using the auspex scanner." }

base.hide_stamina = { en = "Hide Stamina Bar" }
base.hide_stamina_description = { en = "Hide or fade the stamina bar while using the auspex scanner." }

base.hide_ability_icons = { en = "Hide Ability Icons" }
base.hide_ability_icons_description = { en = "Hide or fade player ability icons while using the auspex scanner." }

base.hide_buff_bars = { en = "Hide Buff Bars" }
base.hide_buff_bars_description = { en = "Hide or fade buff bars (including Better Buff Management mod buff bars) while using the auspex scanner." }

return base
