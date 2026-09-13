local mod = get_mod("scores")

mod.coherency_frequency = 0.25
mod.coherency_timer = mod.coherency_frequency
mod.coherency_time = mod.coherency_time or {}
mod.coherency_eligible_time = mod.coherency_eligible_time or {}

local function coherency_count(extension)
	if extension.num_units_in_coherency then
		return extension:num_units_in_coherency()
	end

	return extension._num_units_in_coherence or 0
end

local function coherency_eligible(unit)
	local character_state = mod:safe_component(unit, "character_state")
	local state_name = mod:safe_component_field(character_state, "state_name")

	return state_name ~= "dead" and state_name ~= "hogtied" and state_name ~= "knocked_down"
end

local function refresh_coherency_percent(account_id)
	local coherent = mod.coherency_time[account_id] or 0
	local eligible = mod.coherency_eligible_time[account_id] or 0
	local percent = eligible > 0 and coherent / eligible * 100 or 0

	mod:set_row_value("coherency_efficiency", account_id, percent)
end

mod.update_coherency = function(self, dt)
	if not self:row_tracking_enabled("coherency_efficiency") then
		if self.coherency_time then table.clear(self.coherency_time) end
		if self.coherency_eligible_time then table.clear(self.coherency_eligible_time) end
		self.coherency_last_sample = nil
		return
	end

	if self.player_manager and self.coherency_timer then
		if self.coherency_timer <= 0 then
			local time_manager = Managers and Managers.time
			local now = time_manager and time_manager:has_timer("gameplay") and time_manager:time("gameplay") or nil
			local elapsed = now and self.coherency_last_sample and now - self.coherency_last_sample or self.coherency_frequency
			self.coherency_last_sample = now
			local players = self.player_manager:players()
			for _, player in pairs(players) do
				local unit = player.player_unit
				if unit and coherency_eligible(unit) then
					local coherency_extension = self:safe_extension(unit, "coherency_system")
					if coherency_extension then
						local account_id = self:account_id_from_player(player)
						if account_id then
							self.coherency_eligible_time[account_id] = (self.coherency_eligible_time[account_id] or 0) + elapsed
							if coherency_count(coherency_extension) > 1 then
								self.coherency_time[account_id] = (self.coherency_time[account_id] or 0) + elapsed
							end
							refresh_coherency_percent(account_id)
						end
					end
				end
			end
			self.coherency_timer = self.coherency_frequency
		else
			self.coherency_timer = self.coherency_timer - dt
		end
	end
end

