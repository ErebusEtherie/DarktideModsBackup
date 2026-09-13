-- Single owner of the ProfileSynchronizerHost:override_singleplay_profile hook.
--
-- DMF keeps one hook per mod and function: a second mod:hook() from the same
-- mod is rejected with "Attempting to rehook active hook [...]" and its handler
-- is never added to the chain (dmf/modules/core/hooks.lua:227-255). realms_loadout
-- has two profile transforms - the equipment catalog rebuild and the talent
-- transform - so both must register here instead of hooking the synchronizer
-- themselves. Exactly one DMF hook is installed and the transforms run in
-- priority order (lower first), which keeps the weapon rebuild ahead of the
-- talent transform that clones the profile.
--
-- Every module must register here instead of calling mod:hook directly.
local mod = get_mod("realms_loadout")
if mod._realms_profile_hooks then return mod._realms_profile_hooks end

local ProfileSynchronizerHost = require("scripts/loading/profile_synchronizer_host")

local ProfileHooks = {
	installed = false,
	order = {},
	sequence = 0,
	transforms = {},
}
local owned_updates = setmetatable({}, { __mode = "k" })

local function rebuild_order()
	local order = {}

	for _, entry in pairs(ProfileHooks.transforms) do
		order[#order + 1] = entry
	end

	table.sort(order, function (a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end

		return a.sequence < b.sequence
	end)

	ProfileHooks.order = order
end

local function dispatch(peer_id, local_player_id, profile)
	local current = profile

	for i = 1, #ProfileHooks.order do
		local entry = ProfileHooks.order[i]
		local ok, transformed = pcall(entry.callback, peer_id, local_player_id, current)

		if not ok then
			mod:warning("realms_loadout profile transform '%s' failed: %s", tostring(entry.key), tostring(transformed))
		elseif type(transformed) == "table" then
			current = transformed
		end
	end

	return current
end

local function queued_profile(synchronizer, peer_id, local_player_id)
	local profile_updates = synchronizer and synchronizer._profile_updates
	local peer_updates = profile_updates and profile_updates[peer_id]

	return peer_updates and peer_updates[local_player_id], peer_updates, profile_updates
end

local function forget_owned_update(synchronizer, peer_id, local_player_id)
	local synchronizer_updates = owned_updates[synchronizer]
	local peer_updates = synchronizer_updates and synchronizer_updates[peer_id]

	if not peer_updates then
		return
	end

	peer_updates[local_player_id] = nil

	if not next(peer_updates) then
		synchronizer_updates[peer_id] = nil
	end

	if not next(synchronizer_updates) then
		owned_updates[synchronizer] = nil
	end
end

local function track_owned_update(synchronizer, peer_id, local_player_id, source)
	local profile = queued_profile(synchronizer, peer_id, local_player_id)

	if type(profile) ~= "table" then
		forget_owned_update(synchronizer, peer_id, local_player_id)

		return
	end

	local synchronizer_updates = owned_updates[synchronizer]

	if not synchronizer_updates then
		synchronizer_updates = {}
		owned_updates[synchronizer] = synchronizer_updates
	end

	local peer_updates = synchronizer_updates[peer_id]

	if not peer_updates then
		peer_updates = {}
		synchronizer_updates[peer_id] = peer_updates
	end

	peer_updates[local_player_id] = {
		profile = profile,
		source = tostring(source or "unknown"),
	}
end

local function discard_owned_updates(synchronizer, missing_players_only)
	local synchronizer_updates = owned_updates[synchronizer]

	if not synchronizer_updates then
		return 0
	end

	local discarded = 0
	local player_manager = Managers.player

	for peer_id, local_players in pairs(synchronizer_updates) do
		for local_player_id, owned in pairs(local_players) do
			local current, peer_updates, profile_updates = queued_profile(synchronizer, peer_id, local_player_id)
			local forget = current ~= owned.profile

			if not forget then
				local player = player_manager and player_manager:player(peer_id, local_player_id)
				local can_discard = not missing_players_only or not player or player.__deleted

				if can_discard then
					peer_updates[local_player_id] = nil
					discarded = discarded + 1
					forget = true

					if profile_updates and not next(peer_updates) then
						profile_updates[peer_id] = nil
					end
				end
			end

			if forget then
				local_players[local_player_id] = nil
			end
		end

		if not next(local_players) then
			synchronizer_updates[peer_id] = nil
		end
	end

	if not next(synchronizer_updates) then
		owned_updates[synchronizer] = nil
	end

	return discarded
end

function ProfileHooks.cancel_owned_updates(synchronizer, reason)
	local discarded = 0

	if synchronizer then
		discarded = discard_owned_updates(synchronizer, false)
	else
		for tracked_synchronizer in pairs(owned_updates) do
			discarded = discarded + discard_owned_updates(tracked_synchronizer, false)
		end
	end

	if discarded > 0 then
		mod:info("Discarded %d pending realms_loadout profile update(s): %s", discarded, tostring(reason or "cleanup"))
	end

	return discarded
end

function ProfileHooks.install()
	if ProfileHooks.installed then
		return true
	end

	if type(ProfileSynchronizerHost) ~= "table"
		or type(ProfileSynchronizerHost.override_singleplay_profile) ~= "function" then
		mod:warning("realms_loadout profile hooks could not find ProfileSynchronizerHost:override_singleplay_profile")

		return false
	end

	ProfileHooks.installed = true

	mod:hook(ProfileSynchronizerHost, "override_singleplay_profile", function (func, self, peer_id, local_player_id, new_profile)
		local context = mod._realms_profile_apply_context
		local owned = context and context.owner == "realms_loadout"
		local suppress_transforms = owned and (
			context.suppress_profile_transforms == true
			or context.source == "official_ui"
		)

		if owned and mod._realms_profile_writes_suspended and context.allow_while_suspended ~= true then
			return
		end

		local profile = suppress_transforms and new_profile or dispatch(peer_id, local_player_id, new_profile)
		local result = func(self, peer_id, local_player_id, profile)

		if owned then
			track_owned_update(self, peer_id, local_player_id, context.source)
		else
			forget_owned_update(self, peer_id, local_player_id)
		end

		return result
	end)

	if type(ProfileSynchronizerHost.update) == "function" then
		mod:hook(ProfileSynchronizerHost, "update", function (func, self, dt, ...)
			local discarded = discard_owned_updates(self, true)

			if discarded > 0 then
				mod:warning("Discarded %d orphaned realms_loadout profile update(s)", discarded)
			end

			return func(self, dt, ...)
		end)
	end

	return true
end

-- key: stable identifier; re-registering the same key replaces the callback.
-- callback: function(peer_id, local_player_id, profile) -> table|nil.
-- priority: lower runs first (default 100).
function ProfileHooks.set_transform(key, callback, priority)
	if type(key) ~= "string" or type(callback) ~= "function" then
		mod:warning("realms_loadout profile hooks received an invalid transform registration")

		return false
	end

	local previous = ProfileHooks.transforms[key]

	ProfileHooks.sequence = ProfileHooks.sequence + 1
	ProfileHooks.transforms[key] = {
		callback = callback,
		key = key,
		priority = tonumber(priority) or 100,
		sequence = previous and previous.sequence or ProfileHooks.sequence,
	}

	rebuild_order()

	return ProfileHooks.install()
end

mod._realms_profile_hooks = ProfileHooks

return ProfileHooks
