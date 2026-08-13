
---@param mod mod
return function(mod)
	if mod.shuffle_bag then
		return mod.shuffle_bag
	end

	local math_random = math.random
	local table_remove = table.remove

	---@class ShuffleBag
	local ShuffleBag = {}

	---@param bag any[]
	function ShuffleBag.shuffle(bag)
		for i = #bag, 2, -1 do
			local j = math_random(i)
			bag[i], bag[j] = bag[j], bag[i]
		end
	end

	---@param bag any[]
	---@param items any[]
	function ShuffleBag.refill(bag, items)
		for i = #bag, 1, -1 do
			bag[i] = nil
		end

		for i = 1, #items do
			bag[i] = items[i]
		end

		ShuffleBag.shuffle(bag)
	end

	---@generic T
	---@param bag any[] -- drained in place
	---@param accept fun(item: any): T|nil -- truthy result accepts the item; nil skips it
	---@param refill fun() -- repopulates `bag` when it empties (e.g. ShuffleBag.refill bound to a pool)
	---@return T|nil
	function ShuffleBag.draw(bag, accept, refill)
		for _ = 1, 2 do
			while #bag > 0 do
				local item = table_remove(bag, 1)
				local result = accept(item)
				if result then
					return result
				end
			end

			refill()
		end

		return nil
	end

	mod.shuffle_bag = ShuffleBag

	return mod.shuffle_bag
end
