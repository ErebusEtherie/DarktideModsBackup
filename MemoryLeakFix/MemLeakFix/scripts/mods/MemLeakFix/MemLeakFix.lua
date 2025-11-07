-- @Author: 我是派蒙啊
-- @Date:   2024-10-31 14:36:44
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-10-31 18:53:34
local mod = get_mod("MemLeakFix");

(function()
  collectgarbage("stop")
  collectgarbage("setpause", mod:get("pause_time") * 10)
  collectgarbage("setstepmul", mod:get("step_mul") * 100)
  collectgarbage("restart")
end)()

mod:register_hud_element({
  class_name = "HudElementGCMonitor",
  filename = "MemLeakFix/scripts/mods/MemLeakFix/HudElementGCMonitor",
  use_hud_scale = true,
  visibility_groups = {
    "dead",
    "alive",
  },
})

mod.on_setting_changed = function(setting_id)
  collectgarbage("stop")
  if setting_id == "pause_time" then
    collectgarbage("setpause", mod:get(setting_id) * 10)
  elseif setting_id == "step_mul" then
    collectgarbage("setstepmul", mod:get(setting_id) * 100)
  end
  collectgarbage("restart")
end

-- local call_gc = function()
--   mod:echo("内存清理开始...")
--   local before = collectgarbage("count") / 1024;
--   if before >= 512 then
--     collectgarbage("step", 256 * 1024)
--   else
--     collectgarbage("collect")
--   end
--   local after = collectgarbage("count") / 1024;
--   mod:echo("内存清理量：" .. math.ceil(before - after) .. "MB")
--   mod:echo("内存(新/旧)：" .. math.ceil(after) .. "MB/" .. math.ceil(before) .. "MB")
-- end
