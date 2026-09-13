-- Observational diagnostics only. No mission state, damage or timing changes.
local M = {}
local mod, shared, events, run
local elapsed, frames, slow, worst, report_time = 0, 0, 0, 0, 0
local limits = {}
local emitted = 0
local active = false
local function enabled()
 return run and run.is_active() and not shared.is_in_hub()
  and not shared.is_in_psykhanium() and shared.game_mode_name() ~= nil
end
local function emit(kind, data, cap)
 if emitted >= 512 or not enabled() or not events.is_enabled() then return end
 local key = kind .. ':' .. tostring(data.name or '')
 local count = limits[key] or 0
 if count >= (cap or 32) then return end
 limits[key] = count + 1
 emitted = emitted + 1
 data.event = kind; data.t = shared.fixed_time(); data.mission = shared.mission_name()
 -- A failed diagnostic write must not interrupt the original game action.
 pcall(events.emit, data)
end
local function describe(unit)
 local manager = Managers.state and Managers.state.player_unit_spawn
 local player = unit and manager and manager:owner(unit)
 local profile = player and player:profile()
 return profile and (profile._pilgrimage_preset or profile.name) or tostring(unit)
end
function M.reset()
 elapsed=0;frames=0;slow=0;worst=0;report_time=0;limits={};emitted=0;active=false
end
function M.update(dt)
 if not active or type(dt)~='number' or dt<=0 then return end
 elapsed=elapsed+dt;frames=frames+1;worst=math.max(worst,dt)
 if dt>0.05 then slow=slow+1 end
end
function M.tick()
 active=enabled() and events.is_enabled()
 if not active or elapsed-report_time<30 then return end
 emit('mission_frame_window',{name=tostring(math.floor(elapsed/30)),
  seconds=elapsed-report_time,frames=frames,over_50ms=slow,max_ms=worst*1000},1)
 report_time=elapsed;frames=0;slow=0;worst=0
end
function M.observe_buff_pool(target)
 mod:hook(target,'request_proc_event_param_table',function(func,self,...)
  local result=func(self,...)
  if result==nil and active then
   emit('buff_proc_pool_exhausted',{name=describe(self._unit),
    in_use=self._num_params_table_in_use,
    trace=debug and debug.traceback and debug.traceback('',2) or ''},2)
  end
  return result
 end)
end
function M.init(deps)
 mod=deps.mod;shared=deps.shared;events=deps.events;run=deps.run
 mod:hook_require_now('scripts/extension_systems/mission_objective/mission_objective_system',function(target)
  for _,method in ipairs({'start_mission_objective','end_mission_objective'}) do
   local label=method
   mod:hook_safe(target,label,function(self,name,group)
    emit('mission_objective_transition',{name=name,action=label,group=group},24)
   end)
  end
 end)
 mod:hook_require_now('scripts/extension_systems/cinematic_scene/cinematic_scene_system',function(target)
  mod:hook(target,'_can_play',function(func,self,name,...)
   local result=func(self,name,...)
   emit('mission_cinematic_check',{name=name,allowed=result==true,
    current=tostring(self._current_cinematic_name),
    has_setup=self._cinematics_setups and self._cinematics_setups[name]~=nil},12)
   return result
  end)
  for _,method in ipairs({'play_cutscene','_cinematic_played'}) do
   local label=method
   mod:hook_safe(target,label,function(self,name)
    emit('mission_cinematic_transition',{name=name,action=label},12)
   end)
  end
 end)
 mod:hook_require_now('scripts/utilities/player_death',function(target)
  mod:hook_safe(target,'die',function(unit,despawn,attacker,reason)
   emit('mission_player_death',{name=describe(unit),reason=tostring(reason),
    attacker=describe(attacker)},8)
  end)
 end)
end
return M
