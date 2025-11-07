local mod = get_mod("Bubblelicious")

-- list of personalities & shield failing voicelines
-- disabled voicelines that imply that the shield is already dead
local voicelines = {
	["psyker_female_a"] = { -- female loner
		"loc_psyker_female_a__ability_protectorate_stop_01", -- cannot, hold it
		"loc_psyker_female_a__ability_protectorate_stop_02", -- shield..failing
		"loc_psyker_female_a__ability_protectorate_stop_03", -- the shield is falling
		"loc_psyker_female_a__ability_protectorate_stop_04", -- cannot, keep going
		"loc_psyker_female_a__ability_protectorate_stop_05", -- I cannot do this all day
		"loc_psyker_female_a__ability_protectorate_stop_06", -- it's going! IT'S GOING!
		--"loc_psyker_female_a__ability_protectorate_stop_07", -- shield is down
		"loc_psyker_female_a__ability_protectorate_stop_08", -- I can't..(sigh)
	},
	["psyker_female_b"] = { -- female seer
		"loc_psyker_female_b__ability_protectorate_stop_01", -- can't go on!
		"loc_psyker_female_b__ability_protectorate_stop_02", -- oh no! it's coming apart
		"loc_psyker_female_b__ability_protectorate_stop_03", -- the shield's failing
		"loc_psyker_female_b__ability_protectorate_stop_04", -- the shield's going
		"loc_psyker_female_b__ability_protectorate_stop_05", -- I can't dream this shield forever
		"loc_psyker_female_b__ability_protectorate_stop_06", -- falling. falling. falling sorry!
		"loc_psyker_female_b__ability_protectorate_stop_07", -- oh no! my shield!
		--"loc_psyker_female_b__ability_protectorate_stop_08", -- shield's gone, don't yell at me!
	},
	["psyker_female_c"] = { -- female savant
		"loc_psyker_female_c__ability_protectorate_stop_01", -- shield..falling!
		"loc_psyker_female_c__ability_protectorate_stop_02", -- cannot..keep going! (sigh)
		"loc_psyker_female_c__ability_protectorate_stop_03", -- aegis faltering
		"loc_psyker_female_c__ability_protectorate_stop_04", -- aegis..failing!
		"loc_psyker_female_c__ability_protectorate_stop_05", -- collapse imminent
		"loc_psyker_female_c__ability_protectorate_stop_06", -- shield's going (sigh)
		"loc_psyker_female_c__ability_protectorate_stop_07", -- I cannot maintain this!
		--"loc_psyker_female_c__ability_protectorate_stop_08", -- Aegis cannot hold!
	},
	["psyker_male_a"] = { -- male loner
		"loc_psyker_male_a__ability_protectorate_stop_01", -- cannot hold it (sigh)
		"loc_psyker_male_a__ability_protectorate_stop_02", -- shield failing (sigh)
		"loc_psyker_male_a__ability_protectorate_stop_03", -- the shield is failing
		"loc_psyker_male_a__ability_protectorate_stop_04", -- cannot keep going (sigh)
		"loc_psyker_male_a__ability_protectorate_stop_05", -- I cannot do this all day!
		"loc_psyker_male_a__ability_protectorate_stop_06", -- it's going! IT'S GOING!
		--"loc_psyker_male_a__ability_protectorate_stop_07", -- shield is down!
		"loc_psyker_male_a__ability_protectorate_stop_08", -- I can't! (sigh)
	},
	["psyker_male_b"] = { -- male seer
		"loc_psyker_male_b__ability_protectorate_stop_01", -- can't go on!
		"loc_psyker_male_b__ability_protectorate_stop_02", -- oh no! it's coming apart!
		"loc_psyker_male_b__ability_protectorate_stop_03", -- the shield's failing!
		"loc_psyker_male_b__ability_protectorate_stop_04", -- the shield's going!
		"loc_psyker_male_b__ability_protectorate_stop_05", -- I can't dream this shield forever
		"loc_psyker_male_b__ability_protectorate_stop_06", -- falling. falling. falling. sorry
		"loc_psyker_male_b__ability_protectorate_stop_07", -- oh, no! my shield!
		--"loc_psyker_male_b__ability_protectorate_stop_08", -- shield's gone. don't yell at me!
	},
	["psyker_male_c"] = { -- male savant
		"loc_psyker_male_c__ability_protectorate_stop_01", -- (sigh) shield falling
		"loc_psyker_male_c__ability_protectorate_stop_02", -- cannot keep going
		"loc_psyker_male_c__ability_protectorate_stop_03", -- aegis faltering
		"loc_psyker_male_c__ability_protectorate_stop_04", -- aegis failing
		"loc_psyker_male_c__ability_protectorate_stop_05", -- collapse imminent
		"loc_psyker_male_c__ability_protectorate_stop_06", -- shield's going!
		"loc_psyker_male_c__ability_protectorate_stop_07", -- I cannot maintain this!
		--"loc_psyker_male_c__ability_protectorate_stop_08", -- aegis cannot hold
	},
}

mod.voicelines = {}
local last_index = 0

-- get random voice line matching current personality
local get_random_voice_line = function(player)
	local personality = player:profile().selected_voice
	local vlines = voicelines[personality]
	local num_vlines = #vlines

	--pseudo-shuffle (avoid replaying the previous line)
	local offset = math.random(num_vlines - 1)
	local index = (last_index + offset - 1) % num_vlines + 1

	last_index = index
	return vlines[index]
end

mod.voicelines.play_shield_failing_voiceline = function()
	--Thanks to Norkkom (SanctionedPsyker) for this on-demand audio playback procedure
	local world = Managers.ui:world()
	local wwise_world = Managers.world:wwise_world(world)
	local player = Managers.player:local_player_safe(1)

	if player.player_unit then
		local source_id = wwise_world:make_auto_source(player.player_unit, 1)
		local soundfile = "wwise/externals/" .. get_random_voice_line(player)
		local sfx = "wwise/events/vo/play_sfx_es_player_vo"
		local priority = "es_vo_prio_1"

		wwise_world:trigger_resource_external_event(sfx, priority, soundfile, 4, source_id)
	end
end