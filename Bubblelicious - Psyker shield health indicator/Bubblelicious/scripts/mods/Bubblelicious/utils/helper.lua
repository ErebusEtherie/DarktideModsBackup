local mod = get_mod("Bubblelicious")

mod.helper = {}

mod.helper.count_bubbles = function(bubble_table)
	local count = 0
	for _, _ in pairs(bubble_table) do count = count + 1 end

	return count
end

mod.helper.get_player_unit = function()
	return Managers.player:local_player_safe(1) and Managers.player:local_player_safe(1).player_unit
end

mod.helper.get_player_class = function(peer_id)
	if not peer_id then
		return Managers.player:local_player_safe(1):profile().archetype.name
	end

	local player = Managers.player:player(peer_id, 1)
	return player:profile().archetype.name, player.player_unit
end

mod.helper.player_is_psyker = function(peer_id)
	if not peer_id then
		return mod.helper.get_player_class() == "psyker"
	end

	local player_class, player_unit = mod.helper.get_player_class(peer_id)
	return player_class == "psyker", player_unit
end