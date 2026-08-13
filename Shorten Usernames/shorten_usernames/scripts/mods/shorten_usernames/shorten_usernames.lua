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
		if string.sub(text, i, i+1) == "{#" then
			local j = string.find(text, "}", i)
			if j then
				result = result .. string.sub(text, i, j)
				i = j + 1
			else
				local char = string.sub(text, i, i)
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
			local b = string.byte(text, i)
			local char_bytes = 1
			if b >= 0xC0 then
				if b >= 0xE0 then
					if b >= 0xF0 then
						char_bytes = 4
					else
						char_bytes = 3
					end
				else
					char_bytes = 2
				end
			end

			local char = string.sub(text, i, i + char_bytes - 1)

			visible_len = visible_len + 1
			if visible_len <= max_length then
				result = result .. char
			elseif not truncated then
				result = result .. truncation_string
				truncated = true
			end
			i = i + char_bytes
		end
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

mod:hook(CLASS.HumanPlayer, "name", function(func, self)
	local name = func(self)
	local is_self = self:local_player_id() == 1
	return mod.shorten(name, is_self)
end)

mod:hook(CLASS.RemotePlayer, "name", function(func, self)
	local name = func(self)
	if not self:is_human_controlled() then
		return name
	end
	return mod.shorten(name, false)
end)

local _shorten_account_name = function(name, account_id)
	if not name then
		return name
	end
	local is_self = _is_myself(account_id)

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

	local icon_prefix = ""
	if name and string.len(name) > 4
		and string.byte(name, 1) == 0xEE
		and string.byte(name, 2) == 0x81
		and string.byte(name, 4) == 0x20 then
		icon_prefix = string.sub(name, 1, 4)
		name = string.sub(name, 5)
	end

	local max_len = mod:get("max_length_account_name")
	local truncation_string = mod:get("truncation_string")
	return icon_prefix .. _shorten_name(name, max_len, truncation_string)
end

mod.on_all_mods_loaded = function()
	local who_are_you = get_mod("who_are_you")
	if who_are_you then
		mod:hook(who_are_you, "account_name", function(func, id)
			local name = func(id)
			return _shorten_account_name(name, id)
		end)
	end

	local state_your_name = get_mod("state_your_name")
	if state_your_name and state_your_name.identity then
		mod:hook(state_your_name.identity, "record", function(func, self, account_id, profile, character_name, player_info, slot_color)
			local record = func(self, account_id, profile, character_name, player_info, slot_color)
			if record and record.account_name then
				record.account_name = _shorten_account_name(record.account_name, account_id)
			end
			return record
		end)
	end
end