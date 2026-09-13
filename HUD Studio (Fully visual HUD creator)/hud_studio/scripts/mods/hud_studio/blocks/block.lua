---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_block then
	return mod.hud_studio_block
end

local Compiler = mod:core(mod.hud_studio_compiler, "engine/compiler")
local Sandbox = mod:core(mod.hud_studio_sandbox, "engine/sandbox")
local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local NodeRegistry = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Thresholds = mod:core(mod.hud_studio_thresholds, "blocks/thresholds")
local Conditions = mod:core(mod.hud_studio_conditions, "blocks/conditions")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local Animation = mod.dl.animation

local SCALE_MIN = 0.05
local SCALE_MAX = 20

---@class Block : EditorDoc
---@field name string                                    block identity (== filename); derived slug of label
---@field label string?                                   human-readable display label (name is the slug of this)
---@field offset number[]                                { x, y } from screen center
---@field nodes Node[]
---@field _env table                                     shared sandbox env (built once)
---@field _state table<integer, table>                   per-node persistent scratch
---@field _value_fns table<integer, table<string, function>>  node -> field -> resolver
---@field _style_fns table<integer, function>            node -> style-patch resolver
---@field _style_knob_set table<integer, table<string, true>>  node -> knobs its patch may own
---@field visible Binding?                            block-level visibility { kind, on?, body? }
---@field folder string?                                 folder membership (nil == root); see schema
---@field trashed_from string?                            trashed blocks: the folder to restore into
---@field deleted_nodes Node[]?                           the block's deleted-node bin; never compiled
---@field gamemodes table<string, boolean>?             allowed gamemodes (nil == all); { mission?, mourningstar?, meatgrinder? }
---@field classes table<string, boolean>?               allowed archetype ids (nil == all)
---@field players table<string, table<string, boolean>>?  per-party-slot state filter (nil == none)
---@field _visible_fn function?                          compiled block-visibility predicate (source / code / conditions mode)
---@field _visible_row_errors table<string, string>?      conditions mode: operand compile errors, keyed "<row>.<slot>"
---@field _visible_state table                           block-visibility code's persistent scratch
---@field scale Binding?                               block-level zoom { kind = "fixed"|"code", value?, body? }
---@field _scale_fn function?                            compiled block-zoom resolver (code mode only)
---@field _scale_error string?                           the zoom code's compile error
---@field _scale_state table                             block-zoom code's persistent scratch
---@field transition { fade_in: number?, fade_out: number?, ease: string? }?  block-level fade in/out
---@field _block_fade number                             current block fade (0..1)
---@field _fade table<integer, number>                   per-node fade state (0..1)
---@field origin BlockOrigin?                            present == shipped by a mod; its content is that author's
---@field _missing_requires string[]?                     mod ids origin.requires named that are not loaded / enabled; present == the block is switched off (see requires_error)
---@field script { body: string? }?                      block script: code run once per frame, before everything else
---@field state table                                    the block script's scratch, readable from every binding as block.state
---@field _script_fn function?                            compiled block script
---@field _script_error string?                           the block script's compile error
local Block = {}
Block.__index = Block

local EMPTY = {}

Block.SCALE_MIN = SCALE_MIN
Block.SCALE_MAX = SCALE_MAX

Block.SCALE_DEFAULT = 1

---@param rec Binding?
---@return boolean
function Block.scale_is_default(rec)
	if not rec then
		return true
	end
	if rec.kind == "code" then
		return false
	end
	if rec.body and rec.body:find("%S") then
		return false
	end
	local value = rec.value
	return value == nil or value == Block.SCALE_DEFAULT
end

---@param data BlockData
---@return Block
function Block.new(data)
	local self = setmetatable({}, Block)
	self.name = data.name
	self.label = data.label
	self.offset = data.offset or { 0, 0 }
	self.nodes = data.nodes or {}

	self.visible = data.visible

	self.scale = data.scale

	self.transition = data.transition

	self.script = data.script
	self.state = {}

	self.gamemodes = data.gamemodes
	self.classes = data.classes

	self.players = data.players

	self.folder = data.folder

	self.deleted_nodes = Schema.sanitize_deleted_nodes(data.deleted_nodes)
	data.deleted_nodes = self.deleted_nodes

	self.trashed_from = data.trashed_from

	self.origin = data.origin

	self.grid_rows = data.grid_rows
	self.grid_cols = data.grid_cols

	self.requires = data.requires
	self.summary = data.summary
	self.mod_version = data.mod_version
	self.tags = data.tags
	self.export_mod = data.export_mod
	self._env = Sandbox.build()
	self._state = {}
	self._value_fns = {}
	self._style_fns = {}
	self._style_knob_set = {}
	self._visible_state = {}
	self._scale_state = {}
	self._fade = {}
	self._block_fade = 1
	self:recompile()
	return self
end

---@param body string?
---@param result_var string
---@param init string?
---@return string
local function wrap_code(body, result_var, init)
	local decl = init and ("local " .. result_var .. " = " .. init) or ("local " .. result_var)
	return decl .. "\n" .. (body or "") .. "\nreturn " .. result_var .. "\n"
end

local LOG_METHODS = { "echo", "notify", "info", "warning", "error", "debug" }

local function inject_log_context(source, prefix)
	if not source or not source:find("mod%s*:%s*%a") then
		return source
	end
	local plit = string.format("%q", prefix)
	for _, m in ipairs(LOG_METHODS) do
		local mlit = string.format("%q", m)
		source = source:gsub("%f[%w_]mod%s*:%s*" .. m .. "%s*%(%s*%)", function()
			return "__hud_studio_log(" .. mlit .. ", " .. plit .. ")"
		end)
		source = source:gsub("%f[%w_]mod%s*:%s*" .. m .. "%s*%(", function()
			return "__hud_studio_log(" .. mlit .. ", " .. plit .. ", "
		end)
	end
	return source
end

local function node_log_prefix(block_name, node, field)
	return "[" .. block_name .. ":" .. tostring(node.id or node.type or "?") .. ":" .. field .. "]"
end

---@param binding Binding
---@param env table
---@param name string
---@param result_var string    code kind: the variable the wrapped body returns (field name, or "style")
---@param init string?         code kind: initial value literal for result_var ("{}" for a style patch)
---@param log_prefix string?   code kind: breadcrumb baked into this binding's log calls ([block:node:field])
---@return function?
---@return string?             the compile error, when the code failed to compile
local function compile_binding(binding, env, name, result_var, init, log_prefix)
	if binding.kind == "source" then

		local source, compiled = binding.source, Registry.compile_field(binding.field)
		return function()
			return Registry.resolve_compiled(source, compiled)
		end
	elseif binding.kind == "code" then
		local source = wrap_code(binding.body, result_var, init)
		if log_prefix then
			source = inject_log_context(source, log_prefix)
		end

		local fn, err = Compiler.compile(source, name, env)
		if fn then
			return Compiler.bind(fn, env)
		end
		mod.dl.log.error("binding compile failed (%s): %s", name, tostring(err))
		return nil, tostring(err)
	end
	return nil
end

---@param binding Binding|nil
---@param read_static fun(): any
---@return fun(raw: boolean?): any, string?
local function compile_threshold_input(binding, read_static, env, name, result_var, log_prefix)
	if binding and (binding.kind == "source" or binding.kind == "code") then
		local fn, err = compile_binding(binding, env, name, result_var, nil, log_prefix)
		if fn then
			return function(raw)
				local v = fn()
				if v == nil and not raw then
					return read_static()
				end
				return v
			end,
				err
		end
		return read_static, err
	end
	return read_static, nil
end

---@param binding Binding
---@param node Node
---@return function?, table<string, string>?
local function compile_thresholds(binding, node, env, name, log_prefix)
	local spec = binding.thresholds
	if not spec then
		return nil, nil
	end
	local list = spec.list

	local mirror = spec.mirror
	if not mirror then
		local node_type = node.type and NodeRegistry.get(node.type)
		mirror = node_type and node_type.threshold_values
	end
	local node_bindings = node.callbacks and node.callbacks.value

	local current_binding, read_current, max_binding, read_max
	if mirror then
		local current_field, max_field = mirror.current, mirror.max
		current_binding = node_bindings and node_bindings[current_field]
		max_binding = node_bindings and node_bindings[max_field]
		read_current = function()
			local values = node.values
			return values and values[current_field]
		end
		read_max = function()
			local values = node.values
			return values and values[max_field]
		end
	else
		current_binding = spec.current
		max_binding = spec.max
		read_current = function()
			local rec = spec.current
			return rec and rec.value
		end
		read_max = function()
			local rec = spec.max
			return rec and rec.value
		end
	end

	local errors = nil
	local current_fn, current_err =
		compile_threshold_input(current_binding, read_current, env, name .. ".current", "current", log_prefix)
	local max_fn, max_err = compile_threshold_input(max_binding, read_max, env, name .. ".max", "max", log_prefix)

	local bool_current_fn, bool_current_err = current_fn, nil
	if mirror then
		bool_current_fn, bool_current_err = compile_threshold_input(spec.current, function()
			local rec = spec.current
			return rec and rec.value
		end, env, name .. ".boolean_current", "current", log_prefix)
	end

	if current_err or max_err or bool_current_err then
		errors = { current = current_err or bool_current_err, max = max_err }
	end

	return function()
		local scale = spec.scale
		if scale == "boolean" then

			return Thresholds.bool_color_at(list, bool_current_fn(true))
		elseif scale == "number" then
			return Thresholds.color_at(list, Thresholds.value(current_fn()))
		end
		return Thresholds.color_at(list, Thresholds.pct(current_fn(), max_fn()))
	end,
		errors
end

---@param row table          the spec row owning the slot
---@param slot "lhs"|"rhs"|"rhs2"
---@return function, string?
local function compile_operand(row, slot, env, name, log_prefix)
	local binding = row[slot]
	if binding and (binding.kind == "source" or binding.kind == "code") then
		local fn, err = compile_binding(binding, env, name, "value", nil, log_prefix)
		if fn then
			return fn, err
		end
		return function()
			return binding.value
		end, err
	end
	return function()
		local live = row[slot]
		return live and live.value
	end, nil
end

---@param binding Binding
---@return function?, table<string, string>?
local function compile_conditions(binding, env, name, log_prefix)
	local spec = binding.conditions
	if not spec then
		return nil, nil
	end
	Conditions.normalize(spec)

	local errors = nil
	local function note(key, err)
		if err then
			errors = errors or {}
			errors[key] = err
		end
	end

	local rows = {}
	for i = 1, #spec.rows do
		local row = spec.rows[i]
		local op = Conditions.op(row.op) or Conditions.op(Conditions.DEFAULT_OP)
		local slot_name = name .. ".row" .. i
		local lhs_fn, lhs_err = compile_operand(row, "lhs", env, slot_name .. ".lhs", log_prefix)
		note(i .. ".lhs", lhs_err)

		local compiled = { join = row.join, negate = row.negate, op = op, stateful = op.stateful or nil, lhs = lhs_fn }
		if op.arity >= 1 then
			local rhs_fn, rhs_err = compile_operand(row, "rhs", env, slot_name .. ".rhs", log_prefix)
			note(i .. ".rhs", rhs_err)
			compiled.rhs = rhs_fn
		end
		if op.arity >= 2 then
			local rhs2_fn, rhs2_err = compile_operand(row, "rhs2", env, slot_name .. ".rhs2", log_prefix)
			note(i .. ".rhs2", rhs2_err)
			compiled.rhs2 = rhs2_fn
		end
		rows[i] = compiled
	end

	local scratch = {}

	return function()

		local raw = Conditions.evaluate(rows, env, scratch, Conditions.truth_table(spec, env.t))
		local delay, linger = spec.delay, spec.linger
		if not delay and not linger then
			return raw
		end

		local now = env.t or 0
		if raw then
			scratch.true_since = scratch.true_since or now
			if delay and (now - scratch.true_since) < delay then

				return false
			end
			scratch.last_true = now
			return true
		end
		scratch.true_since = nil
		if linger and scratch.last_true and (now - scratch.last_true) < linger then
			return true
		end
		scratch.last_true = nil
		return false
	end,
		errors
end

---@param node Node
---@param field string
---@param err string?
function Block:_note_compile_error(node, field, err)
	if err == nil then
		return
	end
	local per_node = self._compile_errors[node]
	if not per_node then
		per_node = {}
		self._compile_errors[node] = per_node
	end
	per_node[field] = err
end

function Block:recompile()

	Block.arm_budget()
	self._value_fns = {}
	self._style_fns = {}
	self._style_knob_set = {}

	self._value_keys = {}
	self._value_key_set = {}

	self._out = {}
	self._scratch_out = {}
	self._scratch_values = {}

	self._static = {}
	self._settled = {}

	self._runaway_reported = {}

	self._visible_error = nil
	self._scale_error = nil
	self._script_error = nil
	self._compile_errors = {} 
	self._runtime_errors = {} 
	self._node_index = {}

	local missing = mod.missing_required_mods(self:required_mods())
	self._missing_requires = (missing and #missing > 0) and missing or nil

	self._script_fn = nil
	local script_body = self.script and self.script.body
	if script_body and script_body:find("%S") then
		local name = "hud_studio:" .. self.name .. ".script"
		local source = inject_log_context(script_body, "[" .. self.name .. ":script]")
		local fn, err = Compiler.compile(source, name, self._env)
		if fn then
			self._script_fn = Compiler.bind(fn, self._env)
		else
			mod.dl.log.error("block script compile failed (%s): %s", name, tostring(err))
			self._script_error = tostring(err)
		end
	end

	self._visible_fn = nil

	self._visible_row_errors = nil
	local rec = self.visible
	local kind = rec and rec.kind
	if kind == "code" or kind == "source" then
		self._visible_fn, self._visible_error = compile_binding(
			rec,
			self._env,
			"hud_studio:" .. self.name .. ".visible",
			"visible",
			nil,
			"[" .. self.name .. ":visible]"
		)
	elseif kind == "conditions" then
		self._visible_fn, self._visible_row_errors = compile_conditions(
			rec,
			self._env,
			"hud_studio:" .. self.name .. ".visible",
			"[" .. self.name .. ":visible]"
		)
	end

	self._scale_fn = nil
	local scale_rec = self.scale
	if scale_rec and scale_rec.kind == "code" then
		self._scale_fn, self._scale_error = compile_binding(
			scale_rec,
			self._env,
			"hud_studio:" .. self.name .. ".scale",
			"scale",
			nil,
			"[" .. self.name .. ":scale]"
		)
	end

	for i = 1, #self.nodes do
		local node = self.nodes[i]
		self._state[i] = self._state[i] or {}
		self._node_index[node] = i

		local callbacks = node.callbacks
		if callbacks then
			if callbacks.value then
				local fns = {}
				for field, binding in pairs(callbacks.value) do
					local name = "hud_studio:" .. node.type .. ".value." .. field
					local log_prefix = node_log_prefix(self.name, node, field)
					if binding.kind == "thresholds" then

						local fn, errors = compile_thresholds(binding, node, self._env, name, log_prefix)
						fns[field] = fn
						if errors then
							self:_note_compile_error(node, field .. "/current", errors.current)
							self:_note_compile_error(node, field .. "/max", errors.max)
						end
					elseif binding.kind == "conditions" then

						local fn, errors = compile_conditions(binding, self._env, name, log_prefix)
						fns[field] = fn
						if errors then
							for slot, err in pairs(errors) do
								self:_note_compile_error(node, field .. "/" .. slot, err)
							end
						end
					else

						local fn, err = compile_binding(binding, self._env, name, field, nil, log_prefix)
						fns[field] = fn
						self:_note_compile_error(node, field, err)
					end
				end
				self._value_fns[i] = fns
			end
			if callbacks.style then

				local fn, err = compile_binding(
					callbacks.style,
					self._env,
					"hud_studio:" .. node.type .. ".style",
					"style",
					"{}",
					node_log_prefix(self.name, node, "style")
				)
				self._style_fns[i] = fn
				self:_note_compile_error(node, "style", err)

				local node_type = NodeRegistry.get(node.type)
				local knobs = node_type and node_type.style_knobs
				if knobs then
					local knob_set = {}
					for k = 1, #knobs do
						knob_set[knobs[k]] = true
					end
					self._style_knob_set[i] = knob_set
				end
			end
		end

		local keys, key_set = {}, {}
		local function add_key(k)
			if not key_set[k] then
				key_set[k] = true
				keys[#keys + 1] = k
			end
		end
		for k in pairs(node.values or EMPTY) do
			add_key(k)
		end
		for field in pairs(self._value_fns[i] or EMPTY) do
			add_key(field)
		end
		for knob in pairs(self._style_knob_set[i] or EMPTY) do
			add_key(knob)
		end
		self._value_keys[i] = keys
		self._value_key_set[i] = key_set
		self._scratch_out[i] = {}
		self._scratch_values[i] = {}

		self._static[i] = self._value_fns[i] == nil and self._style_fns[i] == nil
	end
end

local sethook = debug and debug.sethook

local INSTRUCTION_BUDGET = 2e6

local RUNAWAY = {}

local RUNAWAY_MESSAGE = "runaway loop / unbounded recursion"

local function on_instruction_budget()
	error(RUNAWAY)
end

local WARMUP_FRAMES = 300
local budget_frames = 0
local budget_forced = false

function Block.arm_budget()
	budget_frames = WARMUP_FRAMES
end

local function budget_is_armed()
	return budget_forced or budget_frames > 0
end

---@return boolean
function Block.budget_armed()
	return budget_is_armed()
end

---@param force boolean?
function Block.tick_budget(force)
	budget_forced = force and true or false
	if budget_frames > 0 then
		budget_frames = budget_frames - 1
	end
end

local auditing = false
local audit_reported = setmetatable({}, { __mode = "k" })

---@param enabled boolean
function Block.audit_scratch(enabled)
	auditing = enabled and true or false
	audit_reported = setmetatable({}, { __mode = "k" })
end

---@param block_name string
---@param node Node
---@param values table
---@param key_set table<string, true>?
local function audit_scratch_keys(block_name, node, values, key_set)
	for k in pairs(values) do
		if not (key_set and key_set[k]) then
			local seen = audit_reported[node]
			if seen == nil then
				seen = {}
				audit_reported[node] = seen
			end
			if not seen[k] then
				seen[k] = true
				mod.dl.log.error(
					"[scratch audit] %s produced key %q that its manifest does not cover -- reusing the values table would leak it",
					node_log_prefix(block_name, node, tostring(k)),
					tostring(k)
				)
			end
		end
	end
end

local function safe_call(fn)
	if sethook and budget_is_armed() then
		sethook(on_instruction_budget, "", INSTRUCTION_BUDGET)
		local ok, result = pcall(fn)
		sethook()
		if ok then
			return result
		end
		if result == RUNAWAY then
			return nil, true, RUNAWAY_MESSAGE
		end
		return nil, false, tostring(result)
	end
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	return nil, false, tostring(result)
end

---@param fn function
---@param err string?
function Block:_note_runtime_error(fn, err)
	if err ~= nil or self._runtime_errors[fn] ~= nil then
		self._runtime_errors[fn] = err
	end
end

function Block:_report_runaway(fn)
	if self._runaway_reported[fn] then
		return false
	end
	self._runaway_reported[fn] = true
	return true
end

local function ease_value(progress, ease)
	if ease == "in_out" then
		if progress < 0.5 then
			return 2 * progress * progress
		else
			return 1 - 2 * (1 - progress) * (1 - progress)
		end
	end
	return progress
end

local function step_fade(fade, target, dt, duration)
	if not duration or duration <= 0 then
		return target and 1 or 0
	end
	if fade == (target and 1 or 0) then
		return fade
	end
	local step = dt / duration
	if target then
		return math.min(fade + step, 1)
	else
		return math.max(fade - step, 0)
	end
end

---@param ctx Context
---@return boolean

---@param spec table<string, table<string, boolean>>|nil
---@return boolean
local function passes_players(spec)
	if not spec then
		return true
	end
	local checks = Visibility.PLAYER_CHECKS
	for slot = 1, Visibility.PLAYER_COUNT do
		local player_id = Visibility.player_id(slot)
		local wanted = spec[player_id]
		if wanted then
			local any_set, satisfied = false, false
			for c = 1, #checks do
				local check = checks[c]
				if wanted[check.value] then
					any_set = true
					if Registry.resolve_field(player_id, check.field) then
						satisfied = true
						break
					end
				end
			end
			if any_set and not satisfied then
				return false
			end
		end
	end
	return true
end

function Block:_get_block_fade_in_duration()
	local tr = self.transition
	if tr and tr.fade_in then
		return tr.fade_in
	end
	return nil
end

function Block:_get_block_fade_out_duration()
	local tr = self.transition
	if tr and tr.fade_out then
		return tr.fade_out
	end
	return nil
end

function Block:_get_block_ease()
	local tr = self.transition
	if tr and tr.ease then
		return tr.ease
	end
	return "linear"
end

function Block:get_fade_state()
	local eased = ease_value(self._block_fade, self:_get_block_ease())
	return eased
end

function Block:_passes_filters(ctx)
	local gm = self.gamemodes
	if gm and not gm[ctx.gamemode] then
		return false
	end
	local cl = self.classes
	if cl and not cl[ctx.archetype or ""] then
		return false
	end
	if not passes_players(self.players) then
		return false
	end
	return true
end

---@param ctx Context
function Block:run_script(ctx)
	local fn = self._script_fn
	if not fn then
		return
	end
	local env = self._env
	env.t, env.dt = ctx.t, ctx.dt
	env.block = self
	env.state = self.state
	local _, runaway, err = safe_call(fn)
	env.state, env.block, env.t, env.dt = nil, nil, nil, nil
	self:_note_runtime_error(fn, err)
	if runaway and self:_report_runaway(fn) then
		mod.dl.log.error("[%s:script] aborted: runaway loop / unbounded recursion -- block script skipped", self.name)
	end
end

---@param ctx Context
---@return boolean
function Block:is_visible(ctx)
	if self._missing_requires then
		self._block_fade = 0
		return false
	end
	local on = self.visible and self.visible.on
	if on == false then
		self._block_fade = step_fade(self._block_fade, false, ctx.dt, self:_get_block_fade_out_duration())
		return self._block_fade > 0
	end
	if not self:_passes_filters(ctx) then
		self._block_fade = step_fade(self._block_fade, false, ctx.dt, self:_get_block_fade_out_duration())
		return self._block_fade > 0
	end

	self:run_script(ctx)
	if on == true then
		self._block_fade = step_fade(self._block_fade, true, ctx.dt, self:_get_block_fade_in_duration())
		return true
	end
	local visible = true
	if self._visible_fn then
		local env = self._env
		env.t, env.dt = ctx.t, ctx.dt
		env.block = self
		env.state = self._visible_state
		local result, runaway, err = safe_call(self._visible_fn)
		env.state, env.block, env.t, env.dt = nil, nil, nil, nil
		self:_note_runtime_error(self._visible_fn, err)
		if runaway and self:_report_runaway(self._visible_fn) then
			mod.dl.log.error(
			"[%s:visible] aborted: runaway loop / unbounded recursion -- block treated visible",
				self.name
			)
		end
		if result ~= nil then
			visible = result and true or false
		end
	end
	self._block_fade = step_fade(
		self._block_fade,
		visible,
		ctx.dt,
		visible and self:_get_block_fade_in_duration() or self:_get_block_fade_out_duration()
	)
	return self._block_fade > 0
end

---@param ctx Context
---@return number
function Block:get_scale(ctx)
	local rec = self.scale
	if not rec then
		return 1
	end

	local static = rec.value
	if type(static) ~= "number" then
		static = 1
	end

	if self._scale_fn then
		local env = self._env
		env.t, env.dt = ctx.t, ctx.dt
		env.block = self
		env.state = self._scale_state
		local result, runaway, err = safe_call(self._scale_fn)
		env.state, env.block, env.t, env.dt = nil, nil, nil, nil
		self:_note_runtime_error(self._scale_fn, err)
		if runaway and self:_report_runaway(self._scale_fn) then
			mod.dl.log.error("[%s:scale] aborted: runaway loop / unbounded recursion -- block left unzoomed", self.name)
		end
		if type(result) == "number" then
			static = result
		end
	end

	if static ~= static then

		return 1
	end
	if static < SCALE_MIN then
		return SCALE_MIN
	end
	if static > SCALE_MAX then
		return SCALE_MAX
	end
	return static
end

---@type table<Node, table>
local last_eval = setmetatable({}, { __mode = "k" })

---@param node Node
---@return { values: table?, style: table?, hidden: boolean? }|nil
function Block.last_eval(node)
	return last_eval[node]
end

---@param node Node
---@param visible_fn function?
---@return boolean visible
---@return boolean runaway   the visibility predicate was aborted as a runaway (caller logs it)
---@return string? err       the predicate's runtime error, if it raised (caller records it)
local function node_is_visible(node, visible_fn)
	local on = node.style and node.style.visible
	if on == false then
		return false, false, nil
	end

	if not passes_players(node.players) then
		return false, false, nil
	end
	if on == true then
		return true, false, nil
	end
	local runaway, err = false, nil
	if visible_fn then
		local result, ra, e = safe_call(visible_fn)
		runaway, err = ra or false, e
		if result ~= nil then
			return (result and true or false), runaway, err
		end
	end
	return true, runaway, err
end

---@param ctx Context
---@return table<integer, { values: table?, style: table?, hidden: boolean? }>

function Block:evaluate(ctx)
	local out = self._out
	local env = self._env

	env.t = ctx.t
	env.dt = ctx.dt
	env.block = self

	local editor_active = mod.hud_studio_editor_active == true

	for i = 1, #self.nodes do
		local node = self.nodes[i]

		if self._static[i] and self._settled[i] and not editor_active then
			out[i] = self._scratch_out[i]

			goto continue
		end

		env.state = self._state[i]

		local value_fns = self._value_fns[i]

		local visible, vis_runaway, vis_err = node_is_visible(node, value_fns and value_fns.visible)
		if value_fns and value_fns.visible then
			self:_note_runtime_error(value_fns.visible, vis_err)
		end
		if vis_runaway and self:_report_runaway(value_fns.visible) then
			mod.dl.log.error(
				"%s aborted: runaway loop / unbounded recursion -- node treated visible",
				node_log_prefix(self.name, node, "visible")
			)
		end
		if not visible and ctx.force_nodes and ctx.force_nodes[node] then
			visible = true
		end

		self._fade[i] = self._fade[i] or 0
		local tr = node.style and node.style.transition
		local fade_in_dur = tr and tr.fade_in
		local fade_out_dur = tr and tr.fade_out
		local ease = tr and tr.ease or "linear"
		self._fade[i] = step_fade(self._fade[i], visible, ctx.dt, visible and fade_in_dur or fade_out_dur)

		if not visible and self._fade[i] <= 0 then

			local result = self._scratch_out[i]
			result.hidden = true
			result.values = nil
			result.style = nil
			result.node_fade = nil
			out[i] = result
			last_eval[node] = result

			if self._static[i] then
				self._settled[i] = true
			end
		else

			local values = self._scratch_values[i]
			local keys = self._value_keys[i]
			local key_set = self._value_key_set[i]
			for ki = 1, #keys do
				values[keys[ki]] = nil
			end

			for k, v in pairs(node.values or EMPTY) do
				if not key_set[k] then
					key_set[k] = true
					keys[#keys + 1] = k
				end
				values[k] = v
			end
			if value_fns then
				for field, fn in pairs(value_fns) do

					if field ~= "visible" then
						local computed, runaway, err = safe_call(fn)
						self:_note_runtime_error(fn, err)
						if runaway and self:_report_runaway(fn) then
							mod.dl.log.error(
								"%s aborted: runaway loop / unbounded recursion -- using fallback",
								node_log_prefix(self.name, node, field)
							)
						end
						if computed ~= nil then
							values[field] = computed
						end
					end
				end
			end

			local style_patch = nil
			local style_fn = self._style_fns[i]
			if style_fn then
				env.values = values
				env.value = values.value
				local runaway, err
				style_patch, runaway, err = safe_call(style_fn)
				self:_note_runtime_error(style_fn, err)
				if runaway and self:_report_runaway(style_fn) then
					mod.dl.log.error(
						"%s aborted: runaway loop / unbounded recursion -- style patch dropped",
						node_log_prefix(self.name, node, "style")
					)
				end

				if style_patch then
					local knob_set = self._style_knob_set[i]
					if knob_set then
						for k in pairs(style_patch) do
							if knob_set[k] then
								values[k] = nil
							end
						end
					end
				end
			end

			if auditing then
				audit_scratch_keys(self.name, node, values, self._value_key_set[i])
			end

			local result = self._scratch_out[i]
			result.hidden = nil
			result.values = values
			result.style = style_patch
			result.node_fade = ease_value(self._fade[i], ease)
			out[i] = result
			last_eval[node] = result

			if self._static[i] and self._fade[i] >= 1 and not (ctx.force_nodes and ctx.force_nodes[node]) then
				self._settled[i] = true
			end
		end

		::continue::
	end

	env.state, env.values, env.value = nil, nil, nil
	env.t, env.dt = nil, nil
	env.block = nil
	return out
end

---@param node Node|nil
---@param field string|nil   node bindings: the value field name, "<field>/current|max", or "style"
---@return string?
function Block:binding_error(node, field)
	if node == nil then

		if field == "script" then
			return self:script_error()
		end

		if field == "scale" then
			return self:scale_error()
		end

		if field and self._visible_row_errors then
			return self._visible_row_errors[field]
		end
		return self._visible_error or (self._visible_fn and self._runtime_errors[self._visible_fn]) or nil
	end

	local per_node = self._compile_errors[node]
	if per_node and per_node[field] then
		return per_node[field]
	end

	local i = self._node_index[node]
	if not i then
		return nil
	end
	local fn
	if field == "style" then
		fn = self._style_fns[i]
	else
		local fns = self._value_fns[i]
		fn = fns and fns[field]
	end
	return fn and self._runtime_errors[fn] or nil
end

---@return string?
function Block:script_error()
	return self._script_error or (self._script_fn and self._runtime_errors[self._script_fn]) or nil
end

---@return string[]?
function Block:required_mods()
	return self.requires or (self.origin and self.origin.requires) or nil
end

---@return string[]?
function Block:missing_requires()
	return self._missing_requires
end

---@return boolean changed
function Block:refresh_requires()
	local missing = mod.missing_required_mods(self:required_mods())
	missing = (missing and #missing > 0) and missing or nil
	local was = self._missing_requires
	self._missing_requires = missing
	return (was ~= nil) ~= (missing ~= nil)
end

---@return string?
function Block:requires_error()
	local missing = self._missing_requires
	if not missing then
		return nil
	end
	return "requires a mod that is not installed or is switched off: " .. table.concat(missing, ", ")
end

---@return string?
function Block:scale_error()
	return self._scale_error or (self._scale_fn and self._runtime_errors[self._scale_fn]) or nil
end

---@param node Node|nil
---@return string?
function Block:row_error(node)
	if node == nil then

		return self:requires_error() or self:binding_error(nil) or self:script_error() or self:scale_error()
	end

	local per_node = self._compile_errors[node]
	if per_node then

		for _, err in pairs(per_node) do
			return err
		end
	end

	local i = self._node_index[node]
	if not i then
		return nil
	end
	local fns = self._value_fns[i]
	if fns then
		for _, fn in pairs(fns) do
			local err = self._runtime_errors[fn]
			if err then
				return err
			end
		end
	end
	local style_fn = self._style_fns[i]
	return style_fn and self._runtime_errors[style_fn] or nil
end

mod.hud_studio_block = Block

return Block
