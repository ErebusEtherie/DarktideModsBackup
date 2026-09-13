local mod = get_mod("reforged_in_fury_males")

local male_agitator = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_a")
local male_fanatic = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_b")
local male_judge = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_c")

local banisher_events_a = male_agitator.banisher_events_a
local banisher_impact_events_a = male_agitator.banisher_impact_events_a
local maniac_events_a = male_agitator.maniac_events_a

local banisher_events_b = male_fanatic.banisher_events_b
local banisher_impact_events_b = male_fanatic.banisher_impact_events_b
local maniac_events_b = male_fanatic.maniac_events_b

local banisher_events_c = male_judge.banisher_events_c
local banisher_impact_events_c = male_judge.banisher_impact_events_c
local maniac_events_c = male_judge.maniac_events_c