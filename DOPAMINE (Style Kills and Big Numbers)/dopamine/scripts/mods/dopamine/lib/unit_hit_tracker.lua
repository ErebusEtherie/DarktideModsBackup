

---@param mod mod
return function(mod)
	if mod.unit_hit_tracker then
		return mod.unit_hit_tracker
	end

	local Unit = Unit

	local PRUNE_EVERY_DEFAULT = 32

	---@class UnitHitTrackerConfig
	---@field threshold? integer Hits beyond this count "qualify" (default 0).
	---@field prune_every? integer Sweep dead units out every N hits (default 32).

	---@alias UnitHitHook fun(unit: Unit, hit_count: integer, context: EventContext)

	---@class UnitHitTracker
	---@field config UnitHitTrackerConfig
	---@field hit_counts table<table, integer> Live unit -> consecutive hit count.
	---@field hits_since_prune integer Hits recorded since the last dead-unit sweep.
	---@field hooks UnitHitHook[] Callbacks fired after every recorded hit.
	local UnitHitTracker = {}
	UnitHitTracker.__index = UnitHitTracker

	---@param config? UnitHitTrackerConfig
	---@return UnitHitTracker
	function UnitHitTracker.new(config)
		local self = setmetatable({}, UnitHitTracker)

		self.config = config or {}
		self.hit_counts = {} 
		self.hits_since_prune = 0
		self.hooks = {}

		return self
	end

	local _shared = {}

	---@param key string
	---@param config? UnitHitTrackerConfig
	---@return UnitHitTracker
	function UnitHitTracker.shared(key, config)
		local existing = _shared[key]
		if existing then
			return existing
		end

		local tracker = UnitHitTracker.new(config)
		_shared[key] = tracker
		return tracker
	end

	---@return integer
	function UnitHitTracker:threshold()
		return self.config.threshold or 0
	end

	---@return integer
	function UnitHitTracker:prune_every()
		local prune_every = self.config.prune_every
		if not prune_every or prune_every <= 0 then
			return PRUNE_EVERY_DEFAULT
		end
		return prune_every
	end

	function UnitHitTracker:prune_dead_units()
		local counts = self.hit_counts
		for unit in pairs(counts) do
			if not unit or not Unit.alive(unit) then
				counts[unit] = nil
			end
		end
	end

	---@param hook UnitHitHook
	function UnitHitTracker:on_hit(hook)
		self.hooks[#self.hooks + 1] = hook
	end

	---@param unit Unit
	---@param context? any
	---@return integer hit_count
	function UnitHitTracker:record_hit(unit, context)
		if not unit  then
			return 0
		end

		local hit_count = (self.hit_counts[unit] or 0) + 1
		self.hit_counts[unit] = hit_count

		self.hits_since_prune = self.hits_since_prune + 1
		if self.hits_since_prune >= self:prune_every() then
			self.hits_since_prune = 0
			self:prune_dead_units()
		end

		local hooks = self.hooks
		for i = 1, #hooks do
			hooks[i](unit, hit_count, context)
		end

		return hit_count
	end

	---@param hits integer
	---@return boolean
	function UnitHitTracker:qualifies(hits)
		return hits > self:threshold()
	end

	---@param hits integer
	---@return integer
	function UnitHitTracker:hits_since_threshold(hits)
		return hits - self:threshold()
	end

	---@param unit Unit
	function UnitHitTracker:clear_unit(unit)
		if unit then
			self.hit_counts[unit] = nil
		end
	end

	function UnitHitTracker:reset()
		self.hit_counts = {}
		self.hits_since_prune = 0
	end

	mod.unit_hit_tracker = UnitHitTracker

	return mod.unit_hit_tracker
end
