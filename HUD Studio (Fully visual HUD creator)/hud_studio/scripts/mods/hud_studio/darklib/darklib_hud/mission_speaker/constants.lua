
---@param module DLH_MissionSpeaker
return function(module)
	if module.constants then
		return module.constants
	end

	---@enum DLH_MissionSpeakerSpeakerID
	local speaker_id = {
		sergeant_a = "sergeant_a",
		interrogator_a = "interrogator_a",
		barber_a = "barber_a",
		commissar_a = "commissar_a",
		contract_vendor_a = "contract_vendor_a",
		travelling_salesman_a = "travelling_salesman_a",
		enginseer_a = "enginseer_a",
		shipmistress_a = "shipmistress_a",
		boon_vendor_a = "boon_vendor_a",
		training_ground_psyker_a = "training_ground_psyker_a",
		tech_priest_a = "tech_priest_a",
		explicator_a = "explicator_a",
		purser_a = "purser_a",
		pilot_a = "pilot_a",
		adamant_officer_a = "adamant_officer_a",
		tank_commander_a = "tank_commander_a",
	}

	---@class DLH_MissionSpeakerConstants
	local Constants = {
		LOGIC = {
			speaker_id = speaker_id,
			DEFAULT_SPEAKER = speaker_id.sergeant_a,
			SPEAKERS = {
				{ id = speaker_id.sergeant_a, label = "loc_sergeant_a" }, 
				{ id = speaker_id.interrogator_a, label = "loc_interrogator_a" }, 
				{ id = speaker_id.barber_a, label = "loc_barber_a" }, 
				{ id = speaker_id.commissar_a, label = "loc_commissar_a" }, 
				{ id = speaker_id.contract_vendor_a, label = "loc_contract_vendor_a" }, 
				{ id = speaker_id.travelling_salesman_a, label = "loc_travelling_salesman_a" }, 
				{ id = speaker_id.enginseer_a, label = "loc_enginseer_a" },
				{ id = speaker_id.shipmistress_a, label = "loc_shipmistress_a" }, 
				{ id = speaker_id.boon_vendor_a, label = "loc_boon_vendor_a" }, 
				{ id = speaker_id.training_ground_psyker_a, label = "loc_training_ground_psyker_a" }, 
				{ id = speaker_id.tech_priest_a, label = "loc_tech_priest_a" },
				{ id = speaker_id.explicator_a, label = "loc_explicator_a" },
				{ id = speaker_id.purser_a, label = "loc_purser_a" }, 
				{ id = speaker_id.pilot_a, label = "loc_pilot_a" },
				{ id = speaker_id.adamant_officer_a, label = "loc_adamant_officer_a" }, 
				{ id = speaker_id.tank_commander_a, label = "loc_tank_commander_a" },
			},
			SPEAKER_INDEX = {},
			DEFAULT_PORTRAIT = "content/ui/textures/icons/npc_portraits/mission_givers/default",
		},
		PRESENTATION = {

			PORTRAIT_SIZE = { 80, 90 },
			PORTRAIT_NUDGE_X = {
				LEFT = 6,
				RIGHT = -1,
			}, 
			BAR_AMOUNT = 7,
			BAR_SPACING = 10,
			BAR_SIZE = { 12, 30 },
			BAR_OFFSET = { -65, 0, 0 },
			RADIO_SIZE = { 64, 32 },
			RADIO_OFFSET = { -250, 55 },
			TEXT_GAP = 20,

			MARGIN_X = -50,
			Z = 20,

			SLIDE_DISTANCE = 56,
			ANIM_IN_SPEED = 3.45,
			ANIM_OUT_SPEED = 9,

			PANEL_IN_DELAY = 0.75,
			PANEL_OUT_DELAY = 0.5,

			SUPPRESS_OUT_SPEED = 12, 
			SUPPRESS_IN_SPEED = 6,

			TUNE_TIME = 1,

			VISIBLE_STATIC_TIME = 2,

			BAR_TICK = 0.1,

			SUBTITLE_WIDTH = 650,
			SUBTITLE_OFFSET_Y = 70, 
			SUBTITLE_FONT_SIZE = 24,
			SUBTITLE_SLIDE = 16, 
			SUBTITLE_IN_SPEED = 7,
			SUBTITLE_OUT_SPEED = 10,
		},
	}

	module.constants = Constants

	for i = 1, #module.constants.LOGIC.SPEAKERS do
		module.constants.LOGIC.SPEAKER_INDEX[module.constants.LOGIC.SPEAKERS[i].id] = i
	end
end
