local mod = get_mod("MortisBuffManager")

local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

local function current_game_mode_name()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	return game_mode_manager and game_mode_manager:game_mode_name() or nil
end

local function current_host_type()
	local multiplayer_session = Managers.multiplayer_session

	return multiplayer_session and multiplayer_session:host_type() or nil
end

-- Reuse the derived context while the native session values are unchanged.
-- Callers read this snapshot; native role/mode changes are checked on every call.
local cached_context, cached_connection, cached_session
mod.session_context = function()
	local game_mode_name = current_game_mode_name()
	local host_type = current_host_type()
	local is_hub = game_mode_name == "hub"
	local is_shooting_range = game_mode_name == "shooting_range"
	local is_prologue = game_mode_name == "prologue"
	local is_prologue_hub = game_mode_name == "prologue_hub"
	local is_solo_play = host_type == HOST_TYPES.singleplay or host_type == HOST_TYPES.singleplay_backend_session
	local is_realms = host_type == HOST_TYPES.player
	local connection = Managers.connection
	local is_realms_host = is_realms and connection and connection:is_host() or false
	local is_realms_client = is_realms and connection and connection:is_client() or false
	local game_session = Managers.state and Managers.state.game_session
	local is_server = game_session and game_session:is_server() or false
	if cached_context and cached_connection == connection and cached_session == game_session
		and cached_context.game_mode_name == game_mode_name and cached_context.host_type == host_type
		and cached_context.is_realms_host == is_realms_host and cached_context.is_realms_client == is_realms_client
		and cached_context.is_server == is_server then return cached_context end
	local supported

	if is_realms then
		supported = is_realms_host and is_server
	else
		supported = is_shooting_range or is_prologue or is_prologue_hub or is_solo_play
	end

	cached_connection, cached_session = connection, game_session
	cached_context = {
		game_mode_name = game_mode_name,
		host_type = host_type,
		is_hub = is_hub,
		is_shooting_range = is_shooting_range,
		is_prologue = is_prologue,
		is_prologue_hub = is_prologue_hub,
		is_solo_play = is_solo_play,
		is_realms = is_realms,
		is_realms_host = is_realms_host,
		is_realms_client = is_realms_client,
		is_server = is_server,
		supported = supported,
	}
	return cached_context
end

-- Kept for compatibility with the original mod and third-party callers.
mod.is_client_map = function()
	local context = mod.session_context()

	return context.supported,
		context.is_shooting_range,
		context.is_prologue,
		context.is_prologue_hub,
		context.is_solo_play,
		context.is_realms,
		context.is_realms_host
end

mod.is_server_authority = function()
	local context = mod.session_context()

	return context.supported and context.is_server
end
