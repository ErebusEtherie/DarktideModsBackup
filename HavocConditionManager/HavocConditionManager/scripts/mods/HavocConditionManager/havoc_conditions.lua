local HavocConditions = {
	storage_key = "havoc_circumstances_serialized",
	max_primary = math.huge,
	max_total = math.huge,
}

local function copy_array(values)
	local result = {}

	for i = 1, #(values or {}) do
		result[i] = values[i]
	end

	return result
end

local function is_real_condition(value)
	return type(value) == "string" and value ~= "" and value ~= "default"
end

HavocConditions.decode = function (serialized)
	local result = {}

	if type(serialized) ~= "string" or serialized == "" then
		return result
	end

	for value in string.gmatch(serialized, "[^:]+") do
		result[#result + 1] = value
	end

	return result
end

HavocConditions.encode = function (values)
	return table.concat(values or {}, ":")
end

HavocConditions.replace_delimited_field = function (serialized, delimiter, field_index, value)
	if type(serialized) ~= "string" or type(delimiter) ~= "string" or delimiter == "" then
		return serialized, false
	end

	local fields = {}
	local start_index = 1

	while true do
		local delimiter_index = string.find(serialized, delimiter, start_index, true)

		if not delimiter_index then
			fields[#fields + 1] = string.sub(serialized, start_index)
			break
		end

		fields[#fields + 1] = string.sub(serialized, start_index, delimiter_index - 1)
		start_index = delimiter_index + #delimiter
	end

	if field_index < 1 or field_index > #fields then
		return serialized, false
	end

	fields[field_index] = value or ""

	return table.concat(fields, delimiter), true
end

HavocConditions.contains = function (values, expected)
	for i = 1, #(values or {}) do
		if values[i] == expected then
			return true
		end
	end

	return false
end

HavocConditions.sanitize = function (values, allowed_lookup, max_count)
	local result = {}
	local seen = {}
	local limit = max_count or math.huge

	for i = 1, #(values or {}) do
		local value = values[i]
		local allowed = not allowed_lookup or allowed_lookup[value]

		if #result < limit and is_real_condition(value) and allowed and not seen[value] then
			seen[value] = true
			result[#result + 1] = value
		end
	end

	return result
end

HavocConditions.add = function (values, value, allowed_lookup, max_count)
	local result = HavocConditions.sanitize(values, allowed_lookup, max_count)
	local limit = max_count or math.huge

	if not is_real_condition(value) or allowed_lookup and not allowed_lookup[value] then
		return result, "invalid"
	end

	if HavocConditions.contains(result, value) then
		return result, "duplicate"
	end

	if #result >= limit then
		return result, "full"
	end

	result[#result + 1] = value

	return result, "added"
end

HavocConditions.remove = function (values, value, minimum_count)
	local source = copy_array(values)
	local minimum = minimum_count or 0

	if #source <= minimum then
		return source, "minimum"
	end

	local result = {}
	local removed = false

	for i = 1, #source do
		if not removed and source[i] == value then
			removed = true
		else
			result[#result + 1] = source[i]
		end
	end

	return result, removed and "removed" or "missing"
end

HavocConditions.compose = function (primary, extra_values, max_total)
	local result = {}
	local seen = {}
	local limit = max_total or HavocConditions.max_total

	local function append(values)
		for i = 1, #(values or {}) do
			local value = values[i]

			if #result < limit and is_real_condition(value) and not seen[value] then
				seen[value] = true
				result[#result + 1] = value
			end
		end
	end

	append(primary)
	append(extra_values)

	return result
end

HavocConditions.apply_to_mission_context = function (mission_context, primary, extra_values, max_total)
	if type(mission_context) ~= "table" or type(mission_context.havoc_data) ~= "string" then
		return mission_context, false
	end

	local conditions = HavocConditions.compose(primary, extra_values, max_total)
	local havoc_data, replaced = HavocConditions.replace_delimited_field(
		mission_context.havoc_data,
		";",
		5,
		HavocConditions.encode(conditions)
	)

	if replaced then
		mission_context.havoc_data = havoc_data
	end

	return mission_context, replaced
end

return HavocConditions
