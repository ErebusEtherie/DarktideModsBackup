local mod = get_mod("Noospheric Mercy")
local Phrases = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/phrases")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")
local Settings = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/settings")

local ChatManagerConstants = require("scripts/foundation/managers/chat/chat_manager_constants")

local Broadcast = {}

local function pick_channel()
	local chat = Managers.chat

	if not chat or not chat.sessions then
		return nil
	end

	local sessions = chat:sessions()

	if type(sessions) ~= "table" then
		return nil
	end

	local party, party_tag, any, any_tag

	for handle, channel in pairs(sessions) do
		local tag = channel.tag or chat:tag_from_session_handle(handle)

		if tag == ChatManagerConstants.ChannelTag.PARTY then
			party, party_tag = handle, tag
		end

		any, any_tag = any or handle, any_tag or tag
	end

	if party then
		return party, party_tag
	end

	return any, any_tag
end

local function ally_name_and_archetype(ally_unit)
	local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
	local player = player_unit_spawn and player_unit_spawn:owner(ally_unit)

	if not player then
		return nil, nil
	end

	local profile = player:profile()
	local archetype = profile and profile.archetype and profile.archetype.name

	return player:name(), archetype
end

function Broadcast.rescue(ally_unit)
	if not Settings.get("broadcast_enabled") then
		Log.write("BROADCAST skipped: disabled in options")

		return
	end

	local name, archetype = ally_name_and_archetype(ally_unit)

	if not name then
		Log.write("BROADCAST failed: could not resolve ally name")

		return
	end

	local handle, tag = pick_channel()

	if not handle then
		Log.write("BROADCAST failed: no chat session found")

		return
	end

	local message = Phrases.build_message(name, archetype)
	Managers.chat:send_channel_message(handle, message)
	Log.write("BROADCAST sent on tag=%s body=%q", tostring(tag), message)
end

return Broadcast
