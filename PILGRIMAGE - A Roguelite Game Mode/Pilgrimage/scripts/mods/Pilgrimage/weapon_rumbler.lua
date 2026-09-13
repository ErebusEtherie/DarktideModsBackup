-- Remote fuse release, confined to the balanced Rumbler and its shooter's rounds.
-- Native projectile fixed_update still owns explosions, sticky normals, buffs,
-- network effects and deletion. This module never creates a second explosion.
local M = { name = "ogryn_thumper_p1_m2" }
local MARKER = "pilgrim_rumbler_remote"
local DUMMY_PATH = "scripts/extension_systems/weapon/actions/action_dummy"
local PROJECTILES = {
	ogryn_thumper_grenade_hip_fire = true,
	ogryn_thumper_grenade_aim = true,
}
local _mod, _enabled = nil, false
local _rounds = setmetatable({}, { __mode = "k" })
local _pending = setmetatable({}, { __mode = "k" })

local function copy(t)
	local out = {}
	for k, v in pairs(t or {}) do out[k] = v end
	return out
end

function M.build(template)
	local actions = template and template.actions
	if type(actions) ~= "table" or not actions.action_shoot_hip
		or not actions.action_shoot_zoomed then
		return nil, "unexpected Rumbler action table"
	end
	local owned = copy(actions)
	for _, name in ipairs({ "action_bash", "action_bash_right" }) do
		local old = actions[name]
		if type(old) ~= "table" or old.kind ~= "sweep"
			or type(old.allowed_chain_actions) ~= "table" then
			return nil, "unexpected Rumbler special: " .. name
		end
		local chains = {}
		for input, chain in pairs(old.allowed_chain_actions) do
			chains[input] = copy(chain)
			if chains[input].chain_time then
				chains[input].chain_time = input == "bash" and 0.8 or 0.4
			end
		end
		-- Build a non-combat action, not a sweep with zero damage. No hit actors,
		-- melee procs, damage windows or inherited automatic-empty reload.
		owned[name] = {
			kind = "dummy", [MARKER] = true,
			start_input = old.start_input,
			allowed_during_sprint = true, stop_alternate_fire = true,
			total_time = 1, activation_time = 0.17,
			allowed_chain_actions = chains,
			fallback_anim_event = old.anim_event,
			haptic_trigger_template = old.haptic_trigger_template,
		}
	end
	local display = copy(template.displayed_attacks)
	display.special = { display_name = "loc_pilgrim_rumbler_remote",
		desc = "loc_pilgrim_rumbler_remote_desc", type = "special_attack" }
	return { template = template, actions = actions, owned_actions = owned,
		display = template.displayed_attacks, owned_display = display }
end

function M.apply(bundle)
	if not bundle then return end
	bundle.template.actions = bundle.owned_actions
	bundle.template.displayed_attacks = bundle.owned_display
	_enabled = true
end

function M.revert(bundle)
	_enabled = false
	if bundle then
		bundle.template.actions = bundle.actions
		bundle.template.displayed_attacks = bundle.display
	end
	-- These are only requests, no original fuse was changed yet.
	_pending = setmetatable({}, { __mode = "k" })
	_rounds = setmetatable({}, { __mode = "k" })
end

local function alive(round)
	return not round._marked_for_deletion and not round._marked_for_deletion_done
		and ALIVE and ALIVE[round._projectile_unit]
end

function M.request(owner)
	if not _enabled or not owner then return 0 end
	local count = 0
	-- Only this small Rumbler registry, never a scan of the level's units.
	for round in pairs(_rounds) do
		if not alive(round) then
			_rounds[round], _pending[round] = nil, nil
		elseif round._owner_unit == owner and not _pending[round] then
			_pending[round] = true
			count = count + 1
		end
	end
	return count
end

function M.install_projectiles(class)
	if rawget(class, "_pilgrim_rumbler_installed") then return end
	class._pilgrim_rumbler_installed = true
	_mod:hook(class, "init", function(func, self, ...)
		func(self, ...)
		local template = self._projectile_template
		if self._is_server and template and PROJECTILES[template.name] then
			_rounds[self] = true
		end
	end)
	_mod:hook(class, "fixed_update", function(func, self, ...)
		if not _rounds[self] then return func(self, ...) end
		if not alive(self) then
			_rounds[self], _pending[self] = nil, nil
			return func(self, ...)
		end
		if not _enabled or not _pending[self] then return func(self, ...) end
		_pending[self] = nil
		local original = self._projectile_template
		local damage = original and original.damage
		local fuse = damage and damage.fuse
		if not fuse or not fuse.explosion_template then return func(self, ...) end
		local owned = copy(original)
		owned.damage = copy(damage)
		owned.damage.fuse = copy(fuse)
		-- Bypass the minimum age even in mid-air, without faking a collision or
		-- altering lifetime, charge, critical status or the sticky attachment.
		owned.damage.fuse.min_lifetime = -1
		local original_override = self._fuse_override_time_or_nil
		self._projectile_template = owned
		-- Native fuse adds network rewind to this value. Already-expired by a
		-- wide finite margin means the next native tick explodes for remote owners too.
		self._fuse_override_time_or_nil = -1000000
		local ok, result = pcall(func, self, ...)
		self._projectile_template = original
		self._fuse_override_time_or_nil = original_override
		_rounds[self] = nil
		if not ok then error(result, 0) end
		return result
	end)
end

function M.install_action(class)
	if rawget(class, "_pilgrim_rumbler_installed") then return end
	class._pilgrim_rumbler_installed = true
	_mod:hook(class, "start", function(func, self, settings, ...)
		local result = func(self, settings, ...)
		if _enabled and settings[MARKER] then
			self._pilgrim_remote_sent = false
			local unit = self._first_person_unit
			local anim = settings.fallback_anim_event
			if unit and Unit and Unit.has_animation_event then
				if Unit.has_animation_event(unit, "toggle_flashlight") then
					anim = "toggle_flashlight"
				elseif not anim or not Unit.has_animation_event(unit, anim) then
					anim = nil
				end
			else
				anim = nil
			end
			-- The tap donor skips third-person animation. Keep that convention;
			-- never switch the Rumbler's entire animation graph just for this gesture.
			if anim then self:trigger_anim_event(anim) end
		end
		return result
	end)
	_mod:hook(class, "fixed_update", function(func, self, dt, t, time_in_action)
		local settings = self._action_settings
		if _enabled and settings and settings[MARKER]
			and not self._pilgrim_remote_sent
			and time_in_action >= settings.activation_time then
			self._pilgrim_remote_sent = true
			-- Remote player actions are already simulated on the authority. No
			-- custom unauthenticated RPC and no client-side duplicate explosions.
			if self._is_server then M.request(self._player_unit) end
		end
		return func(self, dt, t, time_in_action)
	end)
end

function M.init(deps)
	_mod = deps.mod
	if _mod.add_global_localize_strings then
		_mod:add_global_localize_strings({
			loc_pilgrim_rumbler_remote = { en = "Remote Detonation", ["zh-cn"] = "遥控引爆" },
			loc_pilgrim_rumbler_remote_desc = {
				en = "Detonate your live Rumbler grenades early. Without a signal, grenades retain their normal fuse.",
				["zh-cn"] = "提前引爆你发射的轰鸣者榴弹。未收到引爆信号时，榴弹仍按正常引信延时爆炸。",
			},
		})
	end
	deps.hooks.require_now(DUMMY_PATH, M.install_action)
	-- ProjectileDamageExtension has an existing entrypoint fanout for boons.
	-- Its owner calls install_projectiles; do not register that require twice.
end

return M
