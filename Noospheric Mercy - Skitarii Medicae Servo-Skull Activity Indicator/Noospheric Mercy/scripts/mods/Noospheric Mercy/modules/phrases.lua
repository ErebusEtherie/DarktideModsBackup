local mod = get_mod("Noospheric Mercy")

local Phrases = {
	BINARY_ID = "01001101",
	OUTLINE_NAME = "buff",
	OUTLINE_GUESS = "noospheric_mercy_guess",
	COG_PARTICLE = "content/fx/particles/abilities/cryptic/cryptic_servoskull_medicae_circle",
	COG_PARTICLE_GUESS = "content/fx/particles/abilities/cryptic/cryptic_servoskull_flamer_circle",
	LIGHT_UNIT = "content/weapons/player/attachments/flashlights/flashlight_01/flashlight_01",
	ARRIVAL_DISTANCE_SQ = 6.25,
	CONFIDENCE_CERTAIN = "certain",
	CONFIDENCE_GUESS = "guess",
	FADE_SECONDS = 0.4,
}

local RITES = {
	"Restoring the machine-spirit of",
	"Re-sanctifying the flesh-engine of",
	"Administering the Rite of Restoration to",
	"Reconsecrating the noospheric link to",
	"Anointing with sacred unguents,",
	"Purging corruption from the wetware of",
	"Channelling the Omnissiah's mercy unto",
	"Invoking the Canticles of Restoration over",
	"Realigning the bio-augmetics of",
	"Transmitting healing protocols to",
	"Rekindling the vital cogitators of",
	"Performing the emergency rites upon",
	"Splicing fresh life-code into",
	"Restoring power to the servos of",
	"Soothing the wounded machine-spirit of",
}

local string_find = string.find
local string_format = string.format
local math_random = math.random

Phrases.ARCHETYPE_COLORS = {
	veteran = { 219, 158, 73 },
	zealot  = { 198, 58, 52 },
	psyker  = { 150, 110, 210 },
	ogryn   = { 231, 196, 85 },
	adamant = { 96, 146, 196 },
	cryptic = { 110, 205, 150 },
	broker  = { 210, 130, 170 },
}

function Phrases.color_name(name, archetype_name)
	local c = archetype_name and Phrases.ARCHETYPE_COLORS[archetype_name]

	if not c then
		return name
	end

	return string_format("{#color(%d,%d,%d,255)}%s{#reset()}", c[1], c[2], c[3], name)
end

Phrases.GENERAL_NICKNAMES = {
	"the predecessor",
	"the precursor",
	"the deficient one",
	"the unblessed one",
	"the biomatter",
}

Phrases.ARCHETYPE_NICKNAMES = {
	veteran = { "the un-Augmented", "the baseline-pattern bioform", "the flesh-trooper" },
	zealot  = { "the Creed-bound", "the fervour-driven", "the Ecclesiarchy-pattern" },
	psyker  = { "the warp-anomaly", "the aberrant variable", "the unsanctioned bioform" },
	ogryn   = { "the abhuman servitor-stock", "the bulk-pattern chassis", "the low-cogitation chassis", "the vast one" },
	adamant = { "the Lex-enforcer", "the Judge-pattern", "the writ-bound" },
	cryptic = { "the cohort-brother", "the fellow adept-pattern", "the cant-kin" },
	broker  = { "the hive-scum", "the underhive-stock", "the sump-dweller", "the gutter-born", "the scrip-grubber" },
}

local NICKNAME_CHANCE = 0.80

function Phrases.maybe_nickname(archetype_name)
	if math_random() > NICKNAME_CHANCE then
		return nil
	end

	local extras = archetype_name and Phrases.ARCHETYPE_NICKNAMES[archetype_name]

	if not extras then
		return Phrases.GENERAL_NICKNAMES[math_random(#Phrases.GENERAL_NICKNAMES)]
	end

	local pool = {}

	for i = 1, #Phrases.GENERAL_NICKNAMES do
		pool[i] = Phrases.GENERAL_NICKNAMES[i]
	end

	for i = 1, #extras do
		pool[#pool + 1] = extras[i]
	end

	return pool[math_random(#pool)]
end

function Phrases.pick_phrase()
	return RITES[math_random(#RITES)]
end

function Phrases.build_message(target_name, archetype_name)
	local shown = Phrases.color_name(target_name, archetype_name)
	local phrase = Phrases.pick_phrase()
	local nick = Phrases.maybe_nickname(archetype_name)

	if nick then
		return phrase .. " " .. nick .. " " .. shown .. " " .. Phrases.BINARY_ID
	end

	return phrase .. " " .. shown .. " " .. Phrases.BINARY_ID
end

function Phrases.match(body, party_names)
	if not body or not string_find(body, Phrases.BINARY_ID, 1, true) then
		return nil
	end

	for i = 1, #party_names do
		local name = party_names[i]

		if name and name ~= "" and string_find(body, name, 1, true) then
			return name
		end
	end

	return nil
end

return Phrases
