table.find_predicate = function(tbl, predicate_func)
	for k, v in pairs(tbl) do
		if predicate_func(k, v) then
			return v
		end
	end
end
