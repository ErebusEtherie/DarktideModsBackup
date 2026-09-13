-- Doubly linked LRU list.
--
-- Keys here are the game's own request tables (the entries living inside
-- RenderTargetIconGeneratorBase._requests_by_size),
-- so identity is the key and no hashing of contents is ever needed.
--
-- Every operation is O(1): the cache is walked only when it is flushed, and
-- eviction always pops the tail. That matters because the budgets are in the
-- hundreds of entries and the list is touched on every icon shown or hidden.

local LRU = {}
LRU.__index = LRU

function LRU.new()
	return setmetatable({
		_nodes = {},
		_head = nil, -- most recently used
		_tail = nil, -- least recently used
		count = 0,
	}, LRU)
end

function LRU:contains(key)
	return self._nodes[key] ~= nil
end

-- Detach a key and hand its value back, or nil when it was not in the list.
function LRU:remove(key)
	local node = self._nodes[key]
	if not node then
		return nil
	end

	if node.prev then
		node.prev.next = node.next
	else
		self._head = node.next
	end

	if node.next then
		node.next.prev = node.prev
	else
		self._tail = node.prev
	end

	self._nodes[key] = nil
	self.count = self.count - 1

	local value = node.value
	node.prev, node.next, node.value, node.key = nil, nil, nil, nil

	return value
end

-- Insert (or re-insert) a key as the most recently used entry.
function LRU:push(key, value)
	self:remove(key)

	local node = {
		key = key,
		value = value,
		prev = nil,
		next = self._head,
	}

	if self._head then
		self._head.prev = node
	end

	self._head = node

	if not self._tail then
		self._tail = node
	end

	self._nodes[key] = node
	self.count = self.count + 1
end

-- The value stored against a key, without disturbing its position.
function LRU:value(key)
	local node = self._nodes[key]

	return node and node.value
end

-- Snapshot of every key, most recently used first. Only used for reporting.
function LRU:keys()
	local keys = {}
	local node = self._head

	while node do
		keys[#keys + 1] = node.key
		node = node.next
	end

	return keys
end

-- Remove and return the least recently used entry: key, value.
function LRU:pop_oldest()
	local node = self._tail
	if not node then
		return nil
	end

	local key, value = node.key, node.value
	self:remove(key)

	return key, value
end

return LRU
