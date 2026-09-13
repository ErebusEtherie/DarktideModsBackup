---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_conditions then
	return mod.hud_studio_conditions
end

local Conditions = {}

Conditions.MAX_ROWS = 10

local function as_numbers(lhs, rhs)
	local a, b = tonumber(lhs), tonumber(rhs)
	if a and b then
		return a, b
	end
	return nil, nil
end

local function op_eq(lhs, rhs)
	local a, b = as_numbers(lhs, rhs)
	if a then
		return a == b
	end
	return tostring(lhs) == tostring(rhs)
end

local function op_lt(lhs, rhs)
	local a, b = as_numbers(lhs, rhs)
	return a ~= nil and a < b
end

local function op_le(lhs, rhs)
	local a, b = as_numbers(lhs, rhs)
	return a ~= nil and a <= b
end

local NUMERIC = { number = true, integer = true }
local ORDERED = { number = true, integer = true }
local EQUATABLE = { number = true, integer = true, string = true, material = true, boolean = true }
local ANY = { number = true, integer = true, string = true, material = true, boolean = true }

Conditions.OPS = {
	{
		id = "true",
		loc = "cond_op_true",
		arity = 0,
		types = ANY,
		fn = function(lhs)

			return lhs and lhs ~= 0 and true or false
		end,
	},
	{
		id = "false",
		loc = "cond_op_false",
		arity = 0,
		types = ANY,
		fn = function(lhs)
			return not (lhs and lhs ~= 0)
		end,
	},
	{ id = "==", loc = "cond_op_equal_to", arity = 1, types = EQUATABLE, fn = op_eq },

	{ id = "<", loc = "cond_op_below", arity = 1, types = ORDERED, fn = op_lt },
	{ id = "<=", loc = "cond_op_at_most", arity = 1, types = ORDERED, fn = op_le },
	{
		id = ">",
		loc = "cond_op_above",
		arity = 1,
		types = ORDERED,
		fn = function(lhs, rhs)
			return op_lt(rhs, lhs)
		end,
	},
	{
		id = ">=",
		loc = "cond_op_at_least",
		arity = 1,
		types = ORDERED,
		fn = function(lhs, rhs)
			return op_le(rhs, lhs)
		end,
	},
	{
		id = "between",
		loc = "cond_op_between",
		arity = 2,
		types = NUMERIC,

		fn = function(lhs, rhs, rhs2)
			local value = tonumber(lhs)
			local lo, hi = tonumber(rhs), tonumber(rhs2)
			if not value or not lo or not hi then
				return false
			end
			if lo > hi then
				lo, hi = hi, lo
			end
			return value >= lo and value <= hi
		end,
	},

	{ id = "changed", loc = "cond_op_changed", arity = 0, types = ANY, fn = nil, stateful = true },

	{
		id = "increased",
		loc = "cond_op_increased",
		arity = 0,
		types = ANY,
		fn = nil,
		stateful = true,
		compare = function(previous, current)
			return current > previous
		end,
	},
	{
		id = "decreased",
		loc = "cond_op_decreased",
		arity = 0,
		types = ANY,
		fn = nil,
		stateful = true,
		compare = function(previous, current)
			return current < previous
		end,
	},
}

Conditions.OP_BY_ID = {}
for i = 1, #Conditions.OPS do
	local op = Conditions.OPS[i]
	Conditions.OP_BY_ID[op.id] = op
end

Conditions.DEFAULT_OP = "=="

function Conditions.op(id)
	return id and Conditions.OP_BY_ID[id] or nil
end

function Conditions.ops_for(data_type)
	if not data_type then
		return Conditions.OPS
	end
	local out = {}
	for i = 1, #Conditions.OPS do
		local op = Conditions.OPS[i]
		if op.types[data_type] then
			out[#out + 1] = op
		end
	end
	if #out == 0 then
		return Conditions.OPS
	end
	return out
end

function Conditions.coerce_op(data_type, wanted)
	local op = Conditions.op(wanted)
	if op and (not data_type or op.types[data_type]) then
		return op.id
	end
	local offered = Conditions.ops_for(data_type)
	for i = 1, #offered do
		if offered[i].id == Conditions.DEFAULT_OP then
			return Conditions.DEFAULT_OP
		end
	end
	return offered[1] and offered[1].id or Conditions.DEFAULT_OP
end

function Conditions.default_row()
	return { join = "and", op = Conditions.DEFAULT_OP, lhs = { kind = "fixed" } }
end

function Conditions.default_spec()
	return { rows = {} }
end

function Conditions.normalize(spec)
	if type(spec) ~= "table" then
		spec = Conditions.default_spec()
	end
	local rows = spec.rows
	if type(rows) ~= "table" then
		rows = {}
		spec.rows = rows
	end

	local write = 0
	for i = 1, #rows do
		local row = rows[i]
		if type(row) == "table" and write < Conditions.MAX_ROWS then
			row.join = (row.join == "or") and "or" or "and"
			row.negate = row.negate and true or nil
			row.op = Conditions.OP_BY_ID[row.op] and row.op or Conditions.DEFAULT_OP
			if type(row.lhs) ~= "table" then
				row.lhs = { kind = "fixed" }
			end
			write = write + 1
			rows[write] = row
		end
	end
	for i = #rows, write + 1, -1 do
		rows[i] = nil
	end
	spec.linger = tonumber(spec.linger)
	spec.delay = tonumber(spec.delay)
	if spec.linger and spec.linger <= 0 then
		spec.linger = nil
	end
	if spec.delay and spec.delay <= 0 then
		spec.delay = nil
	end
	return spec
end

local function eval_row(row, ctx, scratch, index)
	local lhs = row.lhs and row.lhs(ctx)
	local result
	if row.stateful then

		if scratch then
			local previous = scratch[index]
			local compare = row.op.compare
			if compare then

				local previous_number, current_number = tonumber(previous), tonumber(lhs)
				result = previous_number ~= nil and current_number ~= nil and compare(previous_number, current_number)
			else
				result = previous ~= nil and previous ~= lhs
			end

			scratch[index] = lhs == nil and false or lhs
		else
			result = false
		end
	else
		result = row.op.fn(lhs, row.rhs and row.rhs(ctx), row.rhs2 and row.rhs2(ctx)) and true or false
	end
	if row.negate then
		return not result
	end
	return result
end

function Conditions.evaluate(rows, ctx, scratch, truth)
	local count = rows and #rows or 0
	if count == 0 then
		return true
	end
	local result, term = false, true
	for i = 1, count do
		local row = rows[i]
		if i > 1 and row.join == "or" then
			result = result or term
			term = true
		end

		if truth or (term and not result) or row.stateful then
			local row_truth = eval_row(row, ctx, scratch, i)
			if truth then
				truth[i] = row_truth
			end
			if term then
				term = row_truth
			end
		end
	end
	return result or term
end

local watched = setmetatable({}, { __mode = "k" })

local TRUTH_TTL = 0.5

function Conditions.watch(spec)
	if spec and not watched[spec] then
		watched[spec] = {}
	end
end

function Conditions.unwatch(spec)
	if spec then
		watched[spec] = nil
	end
end

---@return table|nil
function Conditions.truth_table(spec, now)
	local truth = spec and watched[spec]
	if truth then
		truth.t = now
	end
	return truth
end

---@return boolean|nil
function Conditions.row_truth(spec, i, now)
	local truth = spec and watched[spec]
	if not truth or not truth.t or (now and (now - truth.t) > TRUTH_TTL) then
		return nil
	end
	return truth[i]
end

function Conditions.sentence(spec, label_of)
	local rows = spec and spec.rows
	if type(rows) ~= "table" or #rows == 0 then
		return nil
	end
	local parts = {}
	for i = 1, #rows do
		local row = rows[i]
		local op = Conditions.op(row.op) or Conditions.OP_BY_ID[Conditions.DEFAULT_OP]
		if i > 1 then
			parts[#parts + 1] = (row.join == "or") and mod:localize("cond_sentence_or")
				or mod:localize("cond_sentence_and")
		end
		parts[#parts + 1] = label_of(row.lhs, row, "lhs")
		parts[#parts + 1] = row.negate and mod:localize("cond_sentence_is_not")
			or mod:localize("cond_sentence_is")
		parts[#parts + 1] = mod:localize(op.loc)
		if op.arity >= 1 then
			parts[#parts + 1] = label_of(row.rhs, row, "rhs")
		end
		if op.arity >= 2 then
			parts[#parts + 1] = mod:localize("cond_sentence_and")
			parts[#parts + 1] = label_of(row.rhs2, row, "rhs2")
		end
	end
	return table.concat(parts, " ")
end

mod.hud_studio_conditions = Conditions

return Conditions
