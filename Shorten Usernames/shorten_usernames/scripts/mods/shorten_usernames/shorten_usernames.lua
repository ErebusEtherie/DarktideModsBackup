local mod = get_mod("shorten_usernames")

local _shorten_name = function(text, max_length, truncation_string)
	if not text or text == "" then
		return text
	end

	local visible_len = 0
	local result = ""
	local i = 1
	local len = string.len(text)
	local truncated = false

	while i <= len do
		local char = string.sub(text, i, i)
		
		if char == "{" and string.sub(text, i, i+1) == "{#" then
			local j = string.find(text, "}", i)
			if j then
				result = result .. string.sub(text, i, j)
				i = j + 1
			else
				visible_len = visible_len + 1
				if visible_len <= max_length then
					result = result .. char
				elseif not truncated then
					result = result .. truncation_string
					truncated = true
				end
				i = i + 1
			end
		else
			visible_len = visible_len + 1
			if visible_len <= max_length then
				result = result .. char
			elseif not truncated then
				result = result .. truncation_string
				truncated = true
			end
			i = i + 1
		end
	end

	if truncated then
		result = result .. "{#reset()}"
	end

	return result
end

local _is_in_gameplay = function()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	if not game_mode_manager then
		return false
	end
	
	local game_mode_name = game_mode_manager:game_mode_name()
	return game_mode_name ~= nil and game_mode_name ~= "hub"
end

mod.shorten = function(text, is_self)
	if is_self then
		if not mod:get("shorten_myself") then
			return text
		end
	else
		if not mod:get("shorten_teammates") then
			return text
		end
	end

	if not mod:get("enable_shorten_character_name") then
		return text
	end

	if mod:get("only_in_gameplay") and not _is_in_gameplay() then
		return text
	end

	local max_length = mod:get("max_length")
	local truncation_string = mod:get("truncation_string")

	return _shorten_name(text, max_length, truncation_string)
end

local _is_myself = function(account_id)
	local player = Managers.player:local_player(1)
	local player_account_id = player and player:account_id()
	return account_id == player_account_id
end

mod:hook(CLASS.PlayerInfo, "character_name", function(func, self)
	local name = func(self)
	if self._player and not self._player:is_human_controlled() then
		return name
	end
	local is_self = self._is_own_player
	return mod.shorten(name, is_self)
end)

mod:hook_origin(CLASS.PlayerInfo, "user_display_name", function(self, use_stale)
	local name = self._user_display_name
	if use_stale and name then
		return name
	end
	local presence = self:_get_presence()
	local platform_social = self._platform_social
	name = presence and presence:platform_persona_name_or_account_name() or platform_social and platform_social:name() or
		self._account_name or "N/A"

	if self._player and not self._player:is_human_controlled() then
		self._user_display_name = name
		return name
	end

	local is_self = self._is_own_player
	name = mod.shorten(name, is_self)

	self._user_display_name = name
	return name
end)

mod:hook(CLASS.RemotePlayer, "name", function(func, self)
	local name = func(self)
	if not self:is_human_controlled() then
		return name
	end
	return mod.shorten(name, false)
end)

mod:hook(CLASS.RemotePlayer, "character_name", function(func, self)
	local name = func(self)
	if not self:is_human_controlled() then
		return name
	end
	return mod.shorten(name, false)
end)

mod:hook(CLASS.HumanPlayer, "name", function(func, self)
	local name = func(self)
	local is_self = self:local_player_id() == 1 -- Assuming local player 1 is myself
	return mod.shorten(name, is_self)
end)

mod:hook(CLASS.BotPlayer, "name", function(func, self)
	local name = func(self)
	return name
end)

mod:hook(CLASS.PresenceEntryMyself, "character_name", function(func, self)
	local name = func(self)
	return mod.shorten(name, true)
end)

mod:hook(CLASS.PresenceEntryImmaterium, "character_name", function(func, self)
	local name = func(self)
	if self._player and not self._player:is_human_controlled() then
		return name
	end
	return mod.shorten(name, false)
end)

mod:hook_require("scripts/utilities/profile_utils", function(instance)
	mod:hook(instance, "character_name", function(func, profile)
		local name = func(profile)
		if not profile.account_id then
			return name
		end
		local player = Managers.player:player_by_account_id(profile.account_id)
		if player and not player:is_human_controlled() then
			return name
		end
		local is_self = _is_myself(profile.account_id)
		return mod.shorten(name, is_self)
	end)
end)

mod.on_all_mods_loaded = function()
	local who_are_you = get_mod("who_are_you")
	if who_are_you then
		mod:hook(who_are_you, "account_name", function(func, id)
			local name = func(id)
			local is_self = _is_myself(id)
			
			if is_self then
				if not mod:get("shorten_myself") then
					return name
				end
			else
				if not mod:get("shorten_teammates") then
					return name
				end
			end

			if not mod:get("enable_shorten_account_name") then
				return name
			end

			if mod:get("only_in_gameplay") and not _is_in_gameplay() then
				return name
			end

			local max_len = mod:get("max_length_account_name")
			local truncation_string = mod:get("truncation_string")
			return _shorten_name(name, max_len, truncation_string)
		end)
	end
end
