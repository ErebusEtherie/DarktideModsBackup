---@type mod
local mod = get_mod("dopamine")

if mod.kill_rate then
	return mod.kill_rate
end

local MAX_KILL_SAMPLES = 256

local function ring_index(head, offset)
	return (head - 1 + offset) % MAX_KILL_SAMPLES + 1
end

---@class KillRateConfig
---@field window_seconds? number Trailing window length in seconds (default 30).

---@class KillRate
---@field config KillRateConfig
---@field clock number Monotonic clock; sample timestamps are relative to it.
---@field sample_time number[] Ring buffer of kill timestamps.
---@field sample_head integer Ring index of the oldest live sample.
---@field sample_count integer Number of live samples in the ring.
local KillRate = {}
KillRate.__index = KillRate

---@param config? KillRateConfig
---@return KillRate
function KillRate.new(config)
	local self = setmetatable({}, KillRate)
	self.config = config or {}
	self.sample_time = {}
	self:reset()
	return self
end

---@return number
function KillRate:window()
	local window_seconds = self.config.window_seconds

	if not window_seconds or window_seconds <= 0 then
		return 30
	end

	return window_seconds
end

function KillRate:reset()
	self.clock = 0
	self.sample_head = 1
	self.sample_count = 0
end

---@param dt number
function KillRate:advance_clock(dt)
	self.clock = self.clock + dt
end

function KillRate:prune()
	local cutoff = self.clock - self:window()
	local times = self.sample_time
	local head = self.sample_head
	local count = self.sample_count

	while count > 0 and times[head] < cutoff do
		head = head % MAX_KILL_SAMPLES + 1
		count = count - 1
	end

	self.sample_head = head
	self.sample_count = count
end

function KillRate:record_kill()
	self:prune()

	local head = self.sample_head
	local count = self.sample_count

	if count >= MAX_KILL_SAMPLES then
		head = head % MAX_KILL_SAMPLES + 1
		count = count - 1
		self.sample_head = head
	end

	local tail = ring_index(head, count)
	self.sample_time[tail] = self.clock
	self.sample_count = count + 1
end

---@param dt number
function KillRate:tick(dt)
	self:advance_clock(dt)
	self:prune()
end

---@return integer
function KillRate:value()
	return self.sample_count
end

mod.kill_rate = KillRate

return KillRate
