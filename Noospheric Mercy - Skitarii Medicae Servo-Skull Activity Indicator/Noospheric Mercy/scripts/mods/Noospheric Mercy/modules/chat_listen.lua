local mod = get_mod("Noospheric Mercy")
local Phrases = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/phrases")
local TargetResolve = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/target_resolve")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")
local Settings = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/settings")

local ChatListen = {}

local function party_names_and_lookup()
	local names, lookup = {}, {}

	for _, player in pairs(Managers.player:players()) do
		local name = player.name and player:name()
		local unit = player.player_unit

		if name and unit then
			names[#names + 1] = name
			lookup[name] = unit
		end
	end

	return names, lookup
end

function ChatListen.on_message(message)
	if not message or message.is_current_user then
		return
	end

	if not Settings.get("show_others") then
		return
	end

	local body = message.message_body

	if not body or not string.find(body, Phrases.BINARY_ID, 1, true) then
		return
	end

	local names, lookup = party_names_and_lookup()
	local matched = Phrases.match(body, names)

	if matched and lookup[matched] then
		Log.write("CHAT received broadcast, matched target=%s", matched)
		TargetResolve.set_pending(lookup[matched])
	else
		Log.write("CHAT saw our broadcast tag but no party-name matched in body=%q", body)
	end
end

return ChatListen
