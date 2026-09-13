---@meta

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.add_missing(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.filter(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.filter_array(arg0, arg1, arg2) end

---@param destination? table
---@param original table
---@return table destination
function table.create_copy(destination, original) end

---@param destination? table
---@param original table
---@return table destination
function table.create_copy_instance(destination, original) end

---@param source table
---@param lookup table
---@return table
function table.clone_instance(source, lookup) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.shallow_copy_array(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.shallow_copy(arg0) end

---@param arg0 unknown
---@return any
function table.ensure_not_nil(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.equals(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.contains(arg0, arg1) end

---@param ... unknown
---@return any
function table.enum(...) end

---@param ... unknown
---@return any
function table.size(...) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.append(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.set(arg0, arg1) end

---@param t table
---@param arg1? unknown
---@return string[] keys
function table.keys(t, arg1) end

---@param arg0 unknown
---@return any
function table.reverse(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.index_of_condition(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.add_missing_recursive(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@return any
function table.dump(arg0, arg1, arg2, arg3) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.find(arg0, arg1) end

---@param source table
---@return table copy
function table.clone(source) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.merge_recursive_advanced(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.map(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.merge(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@return any
function table.move(arg0, arg1, arg2, arg3, arg4) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.select_array(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.enum_from_array(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.merge_recursive(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.variance(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.check_interface(arg0, arg1, arg2) end

---@param arg0 unknown
---@return any
function table.remove_empty_values(arg0) end

---@param arg0 unknown
---@return any
function table.is_empty(arg0) end

---@param arg0 unknown
---@return any
function table.sum(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.foreachi(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.average(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param ... unknown
---@return any
function table.nested_get(arg0, arg1, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.crop(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.compact_array(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.merge_array(arg0, arg1) end

table.fatshark = {}

---@param arg0 unknown
---@param ... unknown
---@return any
function table.safe_get(arg0, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.partition_map(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.partition(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.map_to_array(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.array_to_map(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.remap(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.select_map(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.max(arg0) end

---@param ... unknown
---@return any
function table.concat_arrays(...) end

---@param arg0 unknown
---@return any
function table.is_array(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.conditional_copy(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.any(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@return any
function table.tostring(arg0, arg1, arg2, arg3, arg4) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.percentile(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.array_remove_if(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.generate_random_table(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.unique_array_values(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@param arg5 unknown
---@return any
function table.make_strict_readonly(arg0, arg1, arg2, arg3, arg4, arg5) end

---@param arg0 unknown
---@return any
function table.make_strict_nil_exceptions(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.make_locked(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.verify_schema(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@return any
function table.make_strict_with_interface(arg0, arg1, arg2, arg3) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@return any
function table.make_strict(arg0, arg1, arg2, arg3) end

---@param arg0 unknown
---@return any
function table.make_non_unique(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.make_unique(arg0, arg1) end

---@param ... unknown
---@return any
function table.index_lookup_table(...) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.remove_sequence(arg0, arg1, arg2) end

---@param arg0 unknown
---@return any
function table.set_readonly(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.swap_delete(arg0, arg1) end

---@param ... unknown
---@return any
function table.clear(...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.foreach(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.add_meta_logging(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.table_to_array(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.array_to_table(arg0, arg1, arg2) end

---@param ... unknown
---@return any
function table.pack(...) end

---@param arg0 unknown
---@param arg1 unknown
---@param ... unknown
---@return any
function table.merge_varargs(arg0, arg1, ...) end

---@param arg0 unknown
---@param ... unknown
---@return any
function table.append_varargs(arg0, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.values(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.ukeys(arg0, arg1) end

---@param arg0 unknown
---@return any
function table.invert_inplace(arg0) end

---@param arg0 unknown
---@return any
function table.invert(arg0) end

---@param arg0 unknown
---@return any
function table.mirror_array_inplace(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.add_mirrored_entry(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.mirror_array(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.mirror_table(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.get_random_array_indices(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.for_each(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.reduce(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.shuffle(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.minidump(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.clear_array(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.insert_unique(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.insert_sorted(arg0, arg1) end

---@param t table
---@param keys table
---@param order_func? fun():boolean
---@return function
function table.sorted(t, keys, order_func) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.slice(arg0, arg1, arg2) end

---@param arg0 unknown
---@return any
function table.getn(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.index_of(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.find_func_array(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.find_func(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function table.find_by_key(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.has_intersection(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.array_equals(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.array_contains(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function table.append_non_indexed(arg0, arg1) end
