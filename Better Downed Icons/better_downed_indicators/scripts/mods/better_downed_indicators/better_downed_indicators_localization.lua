local loc = {}

loc.mod_name = {
    en = "Better Downed Indicators",
}
loc.mod_description = {
    en = "Replaces the generic exclamation point icon on teammate and personal HUD panels with specific icons that show what took them down (pounced by dog, netted by trapper, etc.), making it clearer how to respond.",
}
loc.icon_style = {
    en = "Icon Style",
}
loc.icon_style_option_glowing = {
    en = "Glowing",
}
loc.icon_style_option_plain = {
    en = "Plain (Uses Status Colors)",
}
loc.icon_style_option_plain_slot_color = {
    en = "Plain (Teammate Color)",
}

loc.enable_background_tint = {
    en = "Enable Background Tint",
}

loc.group_team_panels = { en = "Team Panels (Bottom Left)" }
loc.group_floating_markers = { en = "Floating Markers (In-World)" }
loc.tab_general = { en = "General" }
loc.floating_icon_style = { en = "Icon Style" }
loc.floating_icon_size = { en = "Icon Size" }
loc.enable_floating_markers = { en = "Enable Floating Markers" }

loc.group_status_colors = { en = "Status Colors" }
loc.tab_status_colors = { en = "Status Colors" }
loc.group_distinct_colors = { en = "Requires 'Plain' Style to Recolor" }
loc.group_plain_only_colors = { en = "Always Recolorable (No Vanilla \"Glowly\" Version)" }

loc.group_aggro_colors = { en = "Aggro Colors" }
loc.tab_aggro = { en = "Aggro Detection" }

local statuses = {
    { "knocked_down", "Knocked-down" },
    { "ledge_hanging", "Hanging" },
    { "pounced", "Pounced" },
    { "netted", "Netted" },
    { "consumed", "Consumed" },
    { "grabbed", "Grabbed" },
    { "mutant_charged", "Mutant-charged" },
    { "hogtied", "Hogtied" },
    { "dead", "Dead" },
    { "respawning", "Respawning" },
    
    { "warp_grabbed", "Warp-grabbed" },
    { "auspex", "Auspex" },
    { "luggable", "Luggable" },
    { "healing", "Healing" },
    { "helping", "Helping" },
    { "interacting", "Interacting" },
}

for _, v in ipairs(statuses) do
    loc[v[1] .. "_header"] = { en = v[2] }
    loc[v[1] .. "_r"] = { en = "Red" }
    loc[v[1] .. "_g"] = { en = "Green" }
    loc[v[1] .. "_b"] = { en = "Blue" }
end

loc.aggro_header = { en = "Aggro Detection (Border Glow)" }
loc.aggro_daemonhost_enabled = { en = "Enable Daemonhost Aggro Glow" }
loc.aggro_monstrosity_enabled = { en = "Enable Monstrosity Aggro Glow" }
loc.aggro_captain_enabled = { en = "Enable Captain/Twins Aggro Glow" }
loc.aggro_disabler_enabled = { en = "Enable Disabler Aggro Glow" }
loc.aggro_crusher_enabled = { en = "Enable Crusher/Mauler Aggro Glow" }
loc.aggro_rager_enabled = { en = "Enable Rager Aggro Glow" }
loc.aggro_sniper_enabled = { en = "Enable Sniper Aggro Glow" }
loc.aggro_pox_burster_enabled = { en = "Enable Pox Burster Aggro Glow" }

loc.aggro_daemonhost_header = { en = "Daemonhost Glow Color" }
loc.aggro_daemonhost_r = { en = "Red" }
loc.aggro_daemonhost_g = { en = "Green" }
loc.aggro_daemonhost_b = { en = "Blue" }

loc.aggro_captain_header = { en = "Captain / Twins Glow Color" }
loc.aggro_captain_r = { en = "Red" }
loc.aggro_captain_g = { en = "Green" }
loc.aggro_captain_b = { en = "Blue" }

loc.aggro_monstrosity_header = { en = "Monstrosity Glow Color" }
loc.aggro_monstrosity_r = { en = "Red" }
loc.aggro_monstrosity_g = { en = "Green" }
loc.aggro_monstrosity_b = { en = "Blue" }

loc.aggro_disabler_header = { en = "Disabler Glow Color" }
loc.aggro_disabler_r = { en = "Red" }
loc.aggro_disabler_g = { en = "Green" }
loc.aggro_disabler_b = { en = "Blue" }

loc.aggro_sniper_header = { en = "Sniper Glow Color" }
loc.aggro_sniper_r = { en = "Red" }
loc.aggro_sniper_g = { en = "Green" }
loc.aggro_sniper_b = { en = "Blue" }

loc.aggro_pox_burster_header = { en = "Pox Burster Glow Color" }
loc.aggro_pox_burster_r = { en = "Red" }
loc.aggro_pox_burster_g = { en = "Green" }
loc.aggro_pox_burster_b = { en = "Blue" }

loc.aggro_crusher_header = { en = "Crusher/Mauler Glow Color" }
loc.aggro_crusher_r = { en = "Red" }
loc.aggro_crusher_g = { en = "Green" }
loc.aggro_crusher_b = { en = "Blue" }

loc.aggro_rager_header = { en = "Rager Glow Color" }
loc.aggro_rager_r = { en = "Red" }
loc.aggro_rager_g = { en = "Green" }
loc.aggro_rager_b = { en = "Blue" }

loc.aggro_grenadier_enabled = { en = "Enable Grenadier/Tox Bomber Aggro Glow" }
loc.aggro_grenadier_header = { en = "Grenadier Glow Color" }
loc.aggro_grenadier_r = { en = "Red" }
loc.aggro_grenadier_g = { en = "Green" }
loc.aggro_grenadier_b = { en = "Blue" }

loc.aggro_flamer_enabled = { en = "Enable Flamer Aggro Glow" }
loc.aggro_flamer_header = { en = "Flamer Glow Color" }
loc.aggro_flamer_r = { en = "Red" }
loc.aggro_flamer_g = { en = "Green" }
loc.aggro_flamer_b = { en = "Blue" }

return loc
