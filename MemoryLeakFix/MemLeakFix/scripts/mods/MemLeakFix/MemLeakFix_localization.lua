-- @Author: 我是派蒙啊
-- @Date:   2024-10-31 14:36:44
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-10-31 18:58:31
return {
	mod_name = {
		en = "MemLeakFix",
		["zh-cn"] = "内存泄漏修复",
	},
	mod_description = {
		en = "Try to fix Lua VM out of memory error by using aggressive strategy of Lua GC",
		["zh-cn"] = "尝试通过更激进的GC行为修复内存溢出",
	},
	pause_time = {
		en = "GC pause time",
		["zh-cn"] = "GC 间歇率",
	},
	step_mul = {
		en = "GC step multiple",
		["zh-cn"] = "GC 步进率",
	},
	memory = {
		en = "LuaMem",
		["zh-cn"] = "Lua内存",
	},
	-- gc_monitor = {
	-- 	en = "GC Monitor switch",
	-- 	["zh-cn"] = "GC 监视器开关",
	-- },
	-- duration = {
	-- 	en = "GC Monitor report duration",
	-- 	["zh-cn"] = "GC 监视器报告间隔",
	-- },
	-- call_gc = {
	-- 	en = "Press to call gc",
	-- 	["zh-cn"] = "按下清理内存",
	-- },
}
