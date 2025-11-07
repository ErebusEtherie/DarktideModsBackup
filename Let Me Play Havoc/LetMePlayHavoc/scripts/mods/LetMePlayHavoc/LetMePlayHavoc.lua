local mod = get_mod("LetMePlayHavoc")

local havoc_info = Managers.data_service.havoc:get_settings()

local name_from_member = function(member)
	local account_id = member and member:account_id()
	local account_name = account_id and Managers.data_service.social:get_player_info_by_account_id(account_id)
	local character_name = member and member:name()
	if character_name then
		return tostring(character_name)
	else
		return "A:"..tostring(account_name)
	end
end

local members_not_in_hub = function(members)
	local res = {}
	for _, member in pairs(members) do
		if member:presence_name() ~= "hub" and member:presence_name() ~= "training_grounds" then
			table.insert(res, name_from_member(member))
		end
	end

	return res
end

mod:hook_safe(CLASS.HavocPlayView, "_update_can_play", function (self)
    local widgets_by_name = self._widgets_by_name
	local all_can_play, denied_info = Managers.data_service.havoc:can_all_party_members_play_havoc()
	local all_participants_available = self._party_manager:are_all_members_in_hub()
	local min_participants = havoc_info and havoc_info.min_participants or 2
	local party_members

	if GameParameters.prod_like_backend then
		party_members = self._party_manager:all_members()
	else
		party_members = self._party_manager:members()
	end

	local all_party_members_participants = true

	if self._parent.havoc_order.participants then
		for i = 1, #party_members do
			local found = false
			local party_member = party_members[i]
			local account_id = party_member:account_id()

			for f = 1, #self._parent.havoc_order.participants do
				local participant_account_id = self._parent.havoc_order.participants[f]

				if account_id == participant_account_id then
					found = true

					break
				end
			end

			if not found then
				all_party_members_participants = false

				break
			end
		end
	end

	local party_size = party_members and #party_members > 0 and #party_members or 1
	local is_min_party_size = min_participants <= party_size
	local order_id = self._parent.havoc_order.id

	if order_id and all_can_play and all_participants_available and is_min_party_size and all_party_members_participants then
		widgets_by_name.play_button.content.hotspot.disabled = false
		widgets_by_name.play_button_disabled_info.visible = false
	else
		widgets_by_name.play_button.content.hotspot.disabled = true
		widgets_by_name.play_button_disabled_info.visible = true

		local reasons = ""

		if not order_id then
			reasons = reasons.."order_id = nil\n"
		end

		if not all_party_members_participants then
			reasons = reasons.."all_party_members_participants = nil/false\n"
		end

		if not is_min_party_size then
			reasons = reasons..Localize("loc_minimum_participants_required", true, {
				amount = min_participants,
			}).."\n"
        end

		local players_and_reasons = {}

		if not all_participants_available then
			local members = members_not_in_hub(party_members)
			for _, member_name in pairs(members) do
				table.insert(players_and_reasons, {player = member_name, reason = "not_in_hub"})
			end
		end

		if not all_can_play then
			if not denied_info then
				reasons = reasons..mod:localize("no_denied_info_found").."\n"
			elseif #denied_info == 0 then
				reasons = reasons..mod:localize("no_denied_players_found").."\n"
			elseif denied_info and #denied_info > 0 then
				for _, info in pairs(denied_info) do
					local name = info and name_from_member(info.member)
					local member_name = name and tostring(name) or mod:localize("unknown_player")
					-- Find a list of possible statuses in order to localize them?
					local status = tostring(info.denied_reason)
					table.insert(players_and_reasons, {player = member_name, reason = status})
				end
			end
		end

		table.sort(players_and_reasons, function(a,b)
		  return a.player < b.player
		end)

		for _, player_and_reason in pairs(players_and_reasons) do
			local player = player_and_reason.player
			local reason = mod:localize(player_and_reason.reason)
			local player_error_info = player.." - "..reason
			reasons = reasons..player_error_info.."\n"
		end

		-- Small manip to remove the extra "\n" at the end
		if string.len(reasons) >= 1 then
			reasons = string.sub(reasons, 1, string.len(reasons) - 1)
		end
		
		widgets_by_name.play_button_disabled_info.content.text = reasons
	end
end)