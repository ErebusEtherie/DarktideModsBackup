-- Three mark-scoped heavy weapons. Build is read-only; commit/rollback belongs
-- to weapon_rebalance's atomic catalogue. Preserve networked tweak identifiers.
local M = {}
local S = { active = false, ready = {}, sources = {}, effects = {}, sounds = {}, actions = {}, audio_voices = {}, audio_retry = {} }
local SPECS = {
 { key = "autocannon", mark = "ogryn_heavystubber_p2_m3", clip = 12, reserve = 94,
   charge = 0, cycle = 0.65, reload = 4, range = 80, damage = {1080,1320}, armor = 0.95 },
 { key = "lascannon", mark = "ogryn_rippergun_p1_m3", clip = 4, reserve = 31,
   charge = 1.2, cycle = 2, reload = 4.5, range = 100, damage = {5800,7000}, armor = 1 },
 { key = "arc_cannon", mark = "ogryn_heavystubber_p1_m2", clip = 6, reserve = 62,
   charge = 0.5, cycle = 1.2, reload = 4, range = 30, damage = {900,1250}, armor = 0.9 },
}
local function copy(value)
 if type(value) ~= "table" then return value end
 local out = {}; for k,v in pairs(value) do out[k] = copy(v) end; return out
end
local function profile(base, spec, factor)
 local p = copy(base)
 -- Secondary electricity has no raycast actor for the native wound system.
 -- Keep direct-hit wounds, but never invoke Actor.node(nil) during a pulse.
 if factor then p.wounds_template=nil end
 p._pilgrimage_ogryn_heavy = spec.key
 p.armor_damage_modifier = nil
 p.armor_damage_modifier_ranged = {near={attack={},impact={}},far={attack={},impact={}}}
 for _,range in pairs(p.armor_damage_modifier_ranged) do
  for _,kind in ipairs({"unarmored","armored","resistant","player","berserker","super_armor","disgustingly_resilient","void_shield"}) do
   range.attack[kind] = kind == "super_armor" and spec.armor or 1; range.impact[kind] = 1
  end
 end
 p.ranges = {min={spec.range,spec.range},max={spec.range+1,spec.range+1}}
 p.cleave_distribution = {attack={spec.key == "lascannon" and 12 or 0, spec.key == "lascannon" and 12 or 0},impact={8,8}}
 p.crit_mod = nil
 local target = copy(base.targets and base.targets.default_target or {})
 target.power_distribution = {attack={spec.damage[1]*(factor or 1),spec.damage[2]*(factor or 1)},impact={30,40}}
 target.boost_curve_multiplier_finesse = {0.25,0.25}; target.crit_boost = 0.1
 if spec.key == "lascannon" then
  target.boost_curve_multiplier_finesse = {0.10,0.10}; target.crit_boost = 0.025
  -- Monster hit zones multiply the complete result AFTER the finesse bonus.
  -- Keep normal body damage, but do not multiply it again at a boss weakspot.
  p.ignore_hitzone_multipliers_breed_tags = {"monster"}
 end
 target.armor_damage_modifier = nil; target.armor_damage_modifier_ranged = nil
 p.targets = {default_target=target}
 return p
end
local function now() return S.shared and S.shared.fixed_time() or 0 end
local function exists(unit) return unit and ALIVE and ALIVE[unit] end
local function living(unit) return exists(unit) and HEALTH_ALIVE[unit] end
local function position(unit)
 if not exists(unit) then return nil end
 -- World position continues to follow a ragdoll after POSITION_LOOKUP is removed.
 return Unit.world_position(unit, Unit.has_node(unit,"j_spine") and Unit.node(unit,"j_spine") or 1)
end
local function warn(key, err)
 S.warned = S.warned or {}
 if S.warned[key] then return end; S.warned[key] = true
 if S.mod then S.mod:warning("Ogryn heavy weapons %s: %s", key, tostring(err)) end
end
local function resource(name)
 local ok, value = pcall(Application.can_get_resource, "particles", name)
 return ok and value
end
local FX = {
 arc = "content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_beam",
 arc_link = "content/fx/particles/abilities/chainlightning/cryptic_arc_chainlightning_attack_looping",
 corpse = "content/fx/particles/enemies/buff_chainlightning",
 las = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged",
 charge = "content/fx/particles/weapons/rifles/plasma_gun/plasma_gun_charge",
 las_muzzle = "content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle",
 las_hit = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_bfg_player",
 arc_hit = "content/fx/particles/weapons/rifles/arc_rifle/impact_arc_rifle_p1",
 arc_charge = "content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_lightning",
 arc_linger = "content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_beamlinger",
 auto_hit = "content/fx/particles/weapons/pistols/boltpistol/boltpistol_impact",
}
local SOUND={autocannon="wwise/events/weapon/play_weapon_bolter_m2",
 lascannon="wwise/events/weapon/play_lasgun_p2_m1_charged",
 arc_cannon="wwise/events/weapon/play_arc_rifle_p1_m1_fire_single",
 charge="wwise/events/weapon/play_weapon_plasmagun_charge_fast",
 charge_stop="wwise/events/weapon/stop_weapon_plasmagun_charge_fast",
 ready="wwise/events/weapon/play_electric_shield_fully_charged",
 las_hit="wwise/events/weapon/play_bullet_hits_lasgun",
 arc_hit="wwise/events/weapon/play_bullet_hits_arc_rifle",
 auto_hit="wwise/events/weapon/play_bullet_hits_explosive_gen"}
local function dependencies()
 if S.native then return S.native end
 S.native = {
  lines=require("scripts/settings/effects/line_effects"),
  profiles=require("scripts/settings/damage/damage_profile_templates"),
  explosions=require("scripts/settings/damage/explosion_templates"),
  attack=require("scripts/utilities/attack/attack"),
 }
 return S.native
end
function M.build(templates, ammo, dodge)
 local n = dependencies(); local bundles = {}
 for _,spec in ipairs(SPECS) do
  local w = templates[spec.mark]
  local lookup = w and w.__base_template_lookup
  if not w or not lookup or not lookup.ammo or not lookup.ammo.base or not lookup.dodge or not lookup.dodge.base then
   return nil, "missing heavy weapon tweak lookup: "..spec.mark
  end
  local ammo_id, dodge_id = lookup.ammo.base.base_identifier, lookup.dodge.base.base_identifier
  local original_ammo, original_dodge = ammo[ammo_id], dodge[dodge_id]
  if not original_ammo or not original_ammo.ammunition_clips or not original_ammo.ammunition_clips[1] or not original_dodge then
   return nil, "missing heavy weapon ammo/dodge source: "..spec.mark
  end
  local actions = copy(w.actions)
  if spec.key=="lascannon" then
   for _,a in pairs(actions) do
    if a.crosshair and a.crosshair.crosshair_type~="none" and a.crosshair.crosshair_type~="inspect" then
     a.crosshair={crosshair_type="pilgrimage_cannon_circle"}
    end
   end
   for _,key in ipairs({"action_zoom","action_unzoom"}) do
    if actions[key] then actions[key].crosshair={crosshair_type="pilgrimage_cannon_circle"} end
   end
  end
  local inputs, hierarchy = copy(w.action_inputs), copy(w.action_input_hierarchy)
  if spec.charge>0 then
   -- Full Auto starts holding as soon as AlternateFire.start runs. The donor
   -- allows shooting before its brace animation ends; charging must wait.
   for _,a in pairs(actions) do
    local chain=a.kind=="aim" and a.allowed_chain_actions and a.allowed_chain_actions.zoom_shoot
    if chain and type(a.total_time)=="number" and a.total_time<math.huge then
     chain.chain_time=math.max(chain.chain_time or 0,a.total_time)
    end
   end
  end
  -- Release is handled by the running action. A continuously true shoot_release
  -- at the head of the zoom hierarchy starves zoom_release and locks bracing.
  inputs.zoom_shoot.input_sequence={{input="action_one_hold",value=true}}
  -- A running braced attack needs its own branch. "stay" lets a held
  -- trigger queue the same attack repeatedly and cannot unwind on completion.
  for _,entry in ipairs(hierarchy) do
   if entry.input=="zoom" and type(entry.transition)=="table" then
    for _,child in ipairs(entry.transition) do
     if child.input=="zoom_shoot" then
      child.transition={{input="zoom_release",transition="base"},
       {input="shoot_release",transition="previous"},
       {input="reload",transition="base"},{input="wield",transition="base"},
       {input="combat_ability",transition="base"},{input="grenade_ability",transition="base"}}
     end
    end
   end
  end
  local base = n.profiles.arc_rifle_p1_m1_damage
  if not base or not base.targets then return nil, "arc rifle profile unavailable" end
  local owned_profile = profile(base,spec)
  if spec.key == "lascannon" then owned_profile.wounds_template = n.profiles.plasma_rifle and n.profiles.plasma_rifle.wounds_template or base.wounds_template end
  for _,name in ipairs({"action_shoot_hip","action_shoot_zoomed"}) do
   local a = actions[name]
   if not a or not a.fire_configuration then return nil, "missing heavy fire action: "..spec.mark end
   local previous = a.action_condition_func
   a.action_condition_func = function(settings,params,input,t,...)
    if previous and not previous(settings,params,input,t,...) then return false end
    if spec.charge>0 and params then
     if t<(S.ready[params.unit] or 0) then return false end
     local ext=params.input_extension
     if ext and ext._player and ext._player:is_human_controlled() and not ext:get("action_one_hold") then
      -- Do not start a buffered charge after its trigger has already released.
      return false
     end
    end
    return true
   end
   a.kind = "shoot_hit_scan"; a._pilgrimage_ogryn_heavy = spec
   a.total_time = spec.key == "autocannon" and math.huge or spec.cycle
   a.stop_input = "shoot_release"; a.minimum_hold_time = 0
   a.uninterruptible = false; a.ammunition_usage = 1; a.time_scale_stat_buffs = {}
   -- Repetition belongs to ActionShoot's fire timer, not action self-chaining.
   a.allowed_chain_actions.shoot=nil; a.allowed_chain_actions.zoom_shoot=nil
   if spec.charge>0 then
    a.total_time=math.huge; a.minimum_hold_time=math.huge; a.spread_template="none"
    a.crosshair={crosshair_type=spec.key=="lascannon" and "pilgrimage_cannon_circle" or "dot"}
    a.allowed_chain_actions.shoot=nil; a.allowed_chain_actions.zoom_shoot=nil
    a.fire_configuration.use_charge=true
   end
   a.action_movement_curve = {start_modifier=1}
   a.fire_configuration.shotshell = nil
   a.fire_configuration.damage_type = spec.key == "arc_cannon" and "arc_rifle" or spec.key == "lascannon" and "laser_bfg" or "boltshell_big"
   local scan = {range=spec.range,damage={impact={damage_profile=owned_profile,destroy_on_impact=spec.key ~= "lascannon"}},
    collision_tests={{test="ray",against="statics",collision_filter="filter_player_character_shooting_raycast_statics"},
     {test="ray",against="dynamics",collision_filter="filter_player_character_shooting_raycast_dynamics"}}}
   if spec.key=="lascannon" then
    scan.collision_tests[2].test="sphere";scan.collision_tests[2].radius=.2
   end
   -- Hit mass permits minion cleave. No object-penetration block: walls stop it.
   if spec.key == "autocannon" then
    local explosion = copy(n.explosions.bolt_shell_stop)
    if not explosion then return nil,"bolt explosion unavailable" end
    explosion.radius=2.5; explosion.close_radius=0.75; explosion.min_radius=2.5; explosion.min_close_radius=0.75
    explosion.damage_profile = profile(explosion.damage_profile,{key="autocannon_blast",damage={200,250},armor=0.5,range=3})
    explosion.close_damage_profile = explosion.damage_profile
    scan.damage.impact.explosion_template=explosion; scan.damage.impact.explode_once=true
    scan.damage.impact.explode_on_minion_hit=true; scan.damage.explosion_arming_distance=0
   end
   a.fire_configuration.hit_scan_template = scan
   a.fx = copy(a.fx or {})
   a.fx.line_effect = copy(n.lines[spec.key == "lascannon" and "lasbeam_bfg" or spec.key == "arc_cannon" and "arc_beam" or "heavy_stubber_bullet"])
   if spec.key == "arc_cannon" then
    a.fx.line_effect.vfx_width=0.18
    -- The random lightning emitter uses an extreme end offset, and the
    -- short lightning puff can envelop the camera. Keep only the beam trail.
    a.fx.line_effect.emitters.default={copy(a.fx.line_effect.emitters.default[1])}
   end
   if spec.key == "lascannon" then a.fx.line_effect.vfx_width=2.8 end
   a.fx.line_effect.vfx_crit=a.fx.line_effect.vfx
   if a.fx.line_effect.emitters then a.fx.line_effect.emitters.critical_strike=copy(a.fx.line_effect.emitters.default) end
   a.fx.ogryn_heavy_resources = {}; for _,path in pairs(FX) do a.fx.ogryn_heavy_resources[#a.fx.ogryn_heavy_resources+1]=path end
   if spec.key ~= "autocannon" then a.fx.shell_casing_effect=nil; a.fx.muzzle_flash_effect=nil end
   a.fx.looping_shoot_sfx_alias=nil
   a.fx.out_of_ammo_sfx_alias=nil; a.fx.no_ammo_shoot_sfx_alias=nil
   a.fx.post_loop_shoot_tail_sfx_alias=nil; a.fx.pre_loop_shoot_tail_sfx_alias=nil
   for key,chain in pairs(a.allowed_chain_actions or {}) do
    if key=="zoom" or key=="zoom_release" then chain.chain_time=0
    elseif key ~= "wield" and key ~= "combat_ability" and key ~= "grenade_ability" then chain.chain_time=0 end
   end
  end
  local owned_lookup = copy(lookup)
  local ammo_key, dodge_key = "pilgrimage_"..spec.key.."_ammo", "pilgrimage_"..spec.key.."_dodge"
  owned_lookup.ammo.base.base_identifier=ammo_key
  owned_lookup.dodge.base.base_identifier=dodge_key
  local owned_ammo=copy(original_ammo)
  owned_ammo.ammunition_clips[1]={lerp_basic=spec.clip,lerp_perfect=spec.clip}
  owned_ammo.ammunition_reserve={lerp_basic=spec.reserve,lerp_perfect=spec.reserve}
  local owned_dodge=copy(original_dodge)
  owned_dodge.diminishing_return_start={lerp_basic=2,lerp_perfect=2}
  owned_dodge.diminishing_return_limit={lerp_basic=2,lerp_perfect=2}
  local buffs=copy(w.buffs or {}); buffs.on_wield=buffs.on_wield or {}
  if #buffs.on_wield>=3 then return nil,"no heavy weapon wield buff slot" end
  buffs.on_wield[#buffs.on_wield+1]="pilgrim_weapon_"..spec.key.."_handling"
  local displayed=copy(w.displayed_attacks)
  local alternate=copy(w.alternate_fire_settings)
  if spec.key=="lascannon" and alternate then alternate.crosshair={crosshair_type="pilgrimage_cannon_circle"} end
  if spec.charge>0 then
   displayed.primary={type="charge",fire_mode="semi_auto",display_name="loc_ranged_attack_primary"}
   displayed.secondary={type="charge",fire_mode="semi_auto",display_name="loc_weapon_keyword_charged_attack"}
  else
   displayed.primary.fire_mode="full_auto"
   displayed.secondary.fire_mode="full_auto"
  end
  bundles[#bundles+1]={spec=spec,template=w,actions=w.actions,owned_actions=actions,
   displayed=w.displayed_attacks,owned_displayed=displayed,
   alternate=w.alternate_fire_settings,owned_alternate=alternate,
   crosshair=w.crosshair,owned_crosshair=spec.key=="lascannon" and {crosshair_type="pilgrimage_cannon_circle"} or w.crosshair,
   inputs=w.action_inputs,owned_inputs=inputs,hierarchy=w.action_input_hierarchy,owned_hierarchy=hierarchy,
   counter=w.weapon_counter,owned_counter=spec.charge>0 and {weapon_counter_type="pilgrimage_heavy_charge"} or w.weapon_counter,
   lookup=lookup,owned_lookup=owned_lookup,buffs=w.buffs,owned_buffs=buffs,
   ammo_key=ammo_key,dodge_key=dodge_key,ammo=ammo[ammo_key],dodge=dodge[dodge_key],
   owned_ammo=owned_ammo,owned_dodge=owned_dodge,profile=owned_profile}
 end
 return bundles
end
function M.apply(bundles, ammo, dodge)
 for _,b in ipairs(bundles) do
  b.template.actions=b.owned_actions; b.template.__base_template_lookup=b.owned_lookup; b.template.buffs=b.owned_buffs
  b.template.action_inputs=b.owned_inputs; b.template.action_input_hierarchy=b.owned_hierarchy; b.template.weapon_counter=b.owned_counter
  b.template.displayed_attacks=b.owned_displayed
  b.template.alternate_fire_settings=b.owned_alternate
  b.template.crosshair=b.owned_crosshair
  ammo[b.ammo_key]=b.owned_ammo; dodge[b.dodge_key]=b.owned_dodge
 end
 S.active=true
 M.install_fullauto()
 for _,name in pairs(FX) do pcall(S.mod.load_package,S.mod,name) end
 for _,name in pairs(SOUND) do pcall(S.mod.load_package,S.mod,name) end
end
function M.install_fullauto()
 local fa=get_mod and get_mod("FullAuto")
 if not fa or type(fa.get_native_intervals)~="function" or S.fullauto==fa then return end
 S.fullauto=fa
 S.mod:hook(fa,"get_native_intervals",function(func,template,...)
  if S.active and template and template.name==SPECS[1].mark then
   return SPECS[1].cycle,SPECS[1].cycle,"pilgrimage","pilgrimage"
  end
  return func(template,...)
 end)
end
function M.revert(bundles, ammo, dodge)
 S.active=false; S.ready={}; S.sources={}
 M.on_audio_settings_changed()
 for action in pairs(S.actions) do M.finish(action) end
 for _,sound in ipairs(S.sounds) do pcall(WwiseWorld.destroy_manual_source,sound.world,sound.id) end
 S.sounds={}
 for _,b in ipairs(bundles or {}) do
  b.template.actions=b.actions; b.template.__base_template_lookup=b.lookup; b.template.buffs=b.buffs
  b.template.action_inputs=b.inputs; b.template.action_input_hierarchy=b.hierarchy; b.template.weapon_counter=b.counter
  b.template.displayed_attacks=b.displayed
  b.template.alternate_fire_settings=b.alternate
  b.template.crosshair=b.crosshair
  ammo[b.ammo_key]=b.ammo; dodge[b.dodge_key]=b.dodge
 end
 for _,e in ipairs(S.effects) do pcall(World.destroy_particles,e.world,e.id) end
 S.effects={}
end
local function speed(self)
 local buffs=self._buff_extension and self._buff_extension:stat_buffs()
 return math.max(.1,(buffs and buffs.ranged_attack_speed or 1)+(buffs and buffs.attack_speed or 1)-1)
end
function M.fire_rate(self)
 local spec=S.active and self._action_settings and self._action_settings._pilgrimage_ogryn_heavy
 if spec then return {fire_time=spec.charge/speed(self),auto_fire_time=spec.key=="autocannon" and spec.cycle or nil,max_shots=spec.key=="autocannon" and math.huge or 1} end
end
function M.before_shoot(self,t)
 local spec=S.active and self._action_settings and self._action_settings._pilgrimage_ogryn_heavy
 if spec then
  S.ready[self._player_unit]=t+(spec.cycle-spec.charge)/speed(self)
  local state=S.actions[self]
  if state then state.recovery=(spec.cycle-spec.charge)/speed(self);M.stop_charge(self,state) end
  -- _play_shoot_sound is called at EVERY fire-state transition, including
  -- cancellation. Emit the replacement only at the actual hitscan shot.
  local ok,err=pcall(M.fx,"_confirmed_shot_sound",self)
  if not ok then warn("shot sound",err) end
  if spec.charge>0 then
   local ok_fx,err_fx=pcall(M.muzzle,self,spec)
   if not ok_fx then warn("discharge",err_fx) end
  end
 end
end

function M.start(self,t)
 local spec=S.active and self._action_settings and self._action_settings._pilgrimage_ogryn_heavy
 if spec then
  S.actions[self]={spec=spec,started=t,charge=0,last_update=t,charge_time=spec.charge/speed(self),
   recovery=(spec.cycle-spec.charge)/speed(self),muzzle=self:_muzzle_fx_source(),
   owned_sound=S.mod.package_status and S.mod:package_status(SOUND[spec.key])=="loaded"}
  -- Discard the donor's extra semi-auto delay, never our real shot cooldown.
  self._action_component.fire_at_time=math.max(t+spec.charge/speed(self),S.ready[self._player_unit] or 0)
  if spec.charge>0 and self._action_module_charge_component then
   self._action_module_charge_component.charge_level=0
   self._action_module_charge_component.max_charge=1
  end
 end
end
local function stop_voice(voice)
 if not voice then return end
 if not voice.finished and voice.id then pcall(voice.api.stop_file,voice.id,.035) end
 voice.finished=true;S.audio_voices[voice]=nil
end
local function custom_audio_enabled()
 return S.settings and S.settings.custom_weapon_sounds_enabled()
end
local shot_takes={autocannon={"autocannon_quiet","autocannon_quiet_2","autocannon_quiet_3"}}
local shot_take_index={}
local function next_shot_take(key)
 -- Cosmetic-only rotation: never consume the game's random numbers or alter
 -- weapon timing. The three quiet source takes already contain their clang.
 local takes=shot_takes[key]
 local index=(shot_take_index[key] or 0)%#takes+1
 shot_take_index[key]=index
 return takes[index]
end
local function play_audio(self,file,filters,loop)
 if not custom_audio_enabled() or not get_mod or now()<(S.audio_retry[file] or 0) then return end
 local count=0;for _ in pairs(S.audio_voices) do count=count+1 end
 if count>=24 then return end
 local ok,api=pcall(get_mod,"SimpleAudio")
 if not ok or not api or type(api.play_file)~="function" or type(api.stop_file)~="function" then return end
 if api.is_enabled then local checked,enabled=pcall(api.is_enabled,api);if not checked or not enabled then return end end
 local voice={api=api,owner=self._player_unit,local_owner=self._is_local_unit,position_t=now()}
 local spatial
 if not self._is_local_unit then
  local pose=self._fx_extension:vfx_spawner_pose(self:_muzzle_fx_source())
  spatial=Matrix4x4.translation(pose)
 end
 -- Only the lascannon discharge was too loud. Preserve approved charging,
 -- Autocannon takes and equal hip/braced owner levels; also scale remote fire.
 local gain=file:sub(1,12)=="arc_thunder_" and .9 or (file=="lascannon_shot" and .8 or 1)
 local volume=(self._is_local_unit and 70 or 100)*gain
 local played,id=pcall(api.play_file,"mods/Pilgrimage/audio/heavy/"..file..".wav",
  {audio_type="sfx",volume=volume,filters=filters,loop=loop,
   on_finished=function() voice.finished=true;S.audio_voices[voice]=nil end},spatial,.1,3,45)
 if not played or not id then
  S.audio_retry[file]=now()+30;return nil
 end
 voice.id=id;S.audio_voices[voice]=true
 return voice
end
-- THUNDER uses the approved half-second buildup with a short release tail.
-- The tail is presentation only; charge progress still uses duration, not tail.
local charge_audio_specs={lascannon={duration=1.2,prefix="lascannon"},
 arc_cannon={duration=.5,tail=.04,prefix="arc_thunder"}}
local function tempo_filters(level,rate,duration,tail)
 -- Trim in the original charge timeline BEFORE tempo conversion. No guessing
 -- whether a playback API's seek offset means source or post-filter seconds.
 local filters={string.format("atrim=start=%.6f:end=%s",math.min(.9999,math.max(0,level))*duration,tostring(duration+(tail or 0))),"asetpts=PTS-STARTPTS"}
 while rate>2 do filters[#filters+1]="atempo=2";rate=rate/2 end
 while rate<.5 do filters[#filters+1]="atempo=0.5";rate=rate*2 end
 filters[#filters+1]=string.format("atempo=%.6f",rate)
 if level>0 then filters[#filters+1]="afade=t=in:d=0.012" end
 return table.concat(filters,",")
end
local function charge_audio(self,state)
 local audio_spec=charge_audio_specs[state.spec.key]
 if not audio_spec then return false end
 if not custom_audio_enabled() then
  stop_voice(state.custom_charge);state.custom_charge=nil;return false
 end
 if state.audio_failed then return false end
 local rate=speed(self)
 local holding=state.charge>=1
 local voice=state.custom_charge
 if voice and not voice.finished and state.audio_hold==holding
  and (holding or math.abs((state.audio_rate or rate)-rate)<.001) then return true end
 stop_voice(voice)
 state.custom_charge=play_audio(self,audio_spec.prefix..(holding and "_hold" or "_charge"),
  not holding and tempo_filters(state.charge,rate,audio_spec.duration,audio_spec.tail) or nil,holding)
 state.audio_rate=rate;state.audio_hold=holding
 if not state.custom_charge then state.audio_failed=true end
 return state.custom_charge~=nil
end
function M.on_audio_settings_changed()
 for voice in pairs(S.audio_voices) do stop_voice(voice) end
 S.audio_retry={}
 for self,state in pairs(S.actions) do
  state.custom_charge=nil;state.audio_failed=nil
  if charge_audio_specs[state.spec.key] and state.charge_source then
   pcall(WwiseWorld.trigger_resource_event,self._wwise_world,SOUND.charge_stop,state.charge_source)
   pcall(WwiseWorld.destroy_manual_source,self._wwise_world,state.charge_source);state.charge_source=nil
  end
 end
end
function M.stop_charge(self,state)
 stop_voice(state.custom_charge);state.custom_charge=nil
 if state.charge_id then pcall(World.destroy_particles,self._world,state.charge_id);state.charge_id=nil end
 if state.charge_source then
  pcall(WwiseWorld.trigger_resource_event,self._wwise_world,SOUND.charge_stop,state.charge_source)
  pcall(WwiseWorld.destroy_manual_source,self._wwise_world,state.charge_source);state.charge_source=nil
 end
end
function M.finish(self)
 local state=S.actions[self]
 if state then M.stop_charge(self,state) end
 if state and state.spec.charge>0 and self._action_module_charge_component then self._action_module_charge_component.charge_level=0 end
 S.actions[self]=nil
end
function M.owns_muzzle(unit,source)
 if not S.active then return false end
 for action,state in pairs(S.actions) do
  if action._player_unit==unit and source==state.muzzle and state.owned_sound then return true end
 end
 return false
end
function M.install_shoot(ActionShoot)
 -- EWC overrides the subclass line argument. Use the native base line renderer
 -- for these three marks so magazine cosmetics cannot shrink the cannon beam.
 S.line_renderer=ActionShoot._play_line_fx
 S.mod:hook(ActionShoot,"start",function(func,self,settings,t,...)
  local result=func(self,settings,t,...);M.start(self,t);return result
 end)
 S.mod:hook(ActionShoot,"finish",function(func,self,...)
  local owned=S.actions[self]~=nil
  local result=func(self,...)
  M.finish(self)
  if owned then self._action_component.fire_at_time=S.ready[self._player_unit] or 0 end
  return result
 end)
end
function M.install_hitscan(ActionShootHitScan, shared_rates_installed)
 -- Darktide copies inherited methods when constructing a class. Installing
 -- only on ActionShoot after that does not update the subclass's fixed_update.
 if not shared_rates_installed then
  S.mod:hook(ActionShootHitScan,"_fire_rate_settings",function(func,self,...)
   return M.fire_rate(self) or func(self,...)
  end)
 end
 S.mod:hook(ActionShootHitScan,"fixed_update",function(func,self,dt,t,time_in_action,frame)
  if M.before_update(self,dt,t,time_in_action) then return true end
  return func(self,dt,t,time_in_action,frame)
 end)
end
local function particle(world,name,pos,rotation,scale,ttl,fx)
 if not resource(name) or #S.effects>=128 then return end
 local id=World.create_particles(world,name,pos,rotation,scale,fx and fx._player_particle_group_id)
 if fx and fx._is_in_first_person_mode then World.set_particles_use_custom_fov(world,id,true) end
 if ttl then S.effects[#S.effects+1]={id=id,world=world,ends=now()+ttl} end
 return id
end
local function sound_at(world,event,pos,rotation,first_person)
 if not S.mod.package_status or S.mod:package_status(event)~="loaded" then return end
 local id=WwiseWorld.make_manual_source(world,pos,rotation)
 S.sounds[#S.sounds+1]={id=id,world=world,ends=now()+3}
 WwiseWorld.set_source_parameter(world,id,"first_person_mode",first_person and 1 or 0)
 WwiseWorld.trigger_resource_event(world,event,id)
 return id
end
function M.muzzle(self,spec)
 if spec.key=="arc_cannon" then
  if not resource(FX.arc_hit) or #S.effects>=128 then return end
  -- Native local spawn resolves EWC's muzzle node and the active perspective.
  -- Link to the weapon, destroy if orphaned, and keep our bounded cleanup.
  local id=self._fx_extension:_spawn_unit_particles(FX.arc_hit,self:_muzzle_fx_source(),
   true,"destroy",nil,nil,Vector3(.45,.45,.45),false)
  if id then S.effects[#S.effects+1]={id=id,world=self._world,ends=now()+.35} end
  return
 end
 local pose=self._fx_extension:vfx_spawner_pose(self:_muzzle_fx_source())
 local pos,rotation=Matrix4x4.translation(pose),Matrix4x4.rotation(pose)
 particle(self._world,FX.las_muzzle,pos,rotation,Vector3(1,1,1),.35,self._fx_extension)
end
local function charge_visual(self,state,t)
 if state.spec.charge<=0 or self._action_component.fire_state~="waiting_to_shoot" then return end
 local pose=self._fx_extension:vfx_spawner_pose(state.muzzle)
 local pos,rotation=Matrix4x4.translation(pose),Matrix4x4.rotation(pose)
 if not state.charge_id and resource(FX.charge) then
  state.charge_id=particle(self._world,FX.charge,pos,rotation,Vector3(1,1,1),nil,self._fx_extension)
  state.charge_index=World.find_particles_variable(self._world,FX.charge,"charge_level")
 end
 local level=state.charge
 if state.charge_id then
  World.move_particles(self._world,state.charge_id,pos,rotation)
  World.set_particles_variable(self._world,state.charge_id,state.charge_index,Vector3(level,level,level))
 end
 local custom_charge=charge_audio(self,state)
 if custom_charge and state.charge_source then
  pcall(WwiseWorld.trigger_resource_event,self._wwise_world,SOUND.charge_stop,state.charge_source)
  pcall(WwiseWorld.destroy_manual_source,self._wwise_world,state.charge_source);state.charge_source=nil
 end
 if not custom_charge and not state.charge_source and S.mod.package_status and S.mod:package_status(SOUND.charge)=="loaded"
  and S.mod:package_status(SOUND.charge_stop)=="loaded" then
  state.charge_source=WwiseWorld.make_manual_source(self._wwise_world,pos,rotation)
  WwiseWorld.set_source_parameter(self._wwise_world,state.charge_source,"first_person_mode",self._is_local_unit and 1 or 0)
  WwiseWorld.trigger_resource_event(self._wwise_world,SOUND.charge,state.charge_source)
 end
 if state.charge_source then
  WwiseWorld.set_source_position(self._wwise_world,state.charge_source,pos)
  WwiseWorld.set_source_parameter(self._wwise_world,state.charge_source,"charge_level",level)
 end
 if level>=1 and not state.ready_cue then
  state.ready_cue=true
  if self._is_local_unit then sound_at(self._wwise_world,SOUND.ready,pos,rotation,true) end
 end
end
function M.fx(method,self,...)
 local spec=S.active and self._action_settings and self._action_settings._pilgrimage_ogryn_heavy
 if not spec then return false end
 if method=="_play_line_fx" and S.line_renderer then
  local _,pos,endpoint,attachment=...
  S.line_renderer(self,self._action_settings.fx.line_effect,pos,endpoint,attachment)
  return true
 elseif method=="_update_looping_shoot_sound" then
  self.fake_looping_shoot_sfx_alias=nil;self.fake_timer=nil;return true
 elseif method=="_play_shoot_sound" then
  -- Suppress waiting, preparation, finish and cancel, not just repeated fire.
  return S.mod.package_status and S.mod:package_status(SOUND[spec.key])=="loaded" or false
 elseif method=="_play_muzzle_flash_vfx" or method=="_play_muzzle_smoke" then
  return spec.charge>0
 elseif method=="_confirmed_shot_sound" then
  local replacement=spec.key=="lascannon" and "lascannon_shot"
  if spec.key=="arc_cannon" then replacement="arc_thunder_shot" end
  if spec.key=="autocannon" and custom_audio_enabled() then replacement=next_shot_take(spec.key) end
  if replacement and play_audio(self,replacement) then
   if S.actions[self] then S.actions[self].owned_sound=true end
   return true
  end
  local event=SOUND[spec.key]
  if not S.mod.package_status or S.mod:package_status(event)~="loaded" then return false end
  local ok,err=pcall(function()
   local state=S.actions[self]
   local pose=self._fx_extension:vfx_spawner_pose(self:_muzzle_fx_source())
   local id=WwiseWorld.make_manual_source(self._wwise_world,Matrix4x4.translation(pose),Matrix4x4.rotation(pose))
   S.sounds[#S.sounds+1]={id=id,world=self._wwise_world,ends=now()+3}
   WwiseWorld.set_source_parameter(self._wwise_world,id,"first_person_mode",self._is_local_unit and 1 or 0)
   WwiseWorld.trigger_resource_event(self._wwise_world,event,id)
   if state then state.owned_sound=true end
  end)
  if not ok then
   if S.actions[self] then S.actions[self].owned_sound=false end
   warn("shot sound",err)
  end
  return ok
 end
 return false
end

function M.before_update(self,dt,t,time_in_action)
 local spec=S.active and self._action_settings and self._action_settings._pilgrimage_ogryn_heavy
 if not spec then return end
 if not S.actions[self] then M.start(self,t-time_in_action) end
 local state=S.actions[self]
 if state and spec.charge>0 and not state.release_committed and self._action_component.fire_state=="waiting_to_shoot" then
  state.charge_time=spec.charge/speed(self)
  state.charge=math.min(1,state.charge+math.max(0,t-state.last_update)/state.charge_time)
  state.last_update=t
  -- Standard component consumed by both the HUD and Full Auto's Helbore path.
  if self._action_module_charge_component then self._action_module_charge_component.charge_level=state.charge end
 end
 if spec.key=="autocannon" and self._is_human_controlled and self._action_component.num_shots_fired>0
  and not self._input_extension:get("action_one_hold") then return true end
 if spec.charge<=0 then return end
 local component=self._action_component
 if component.fire_state=="shot" then
  return t-component.fire_last_t >= state.recovery
 end
 if component.fire_state=="waiting_to_shoot" and self._is_human_controlled then
  local held=self._input_extension:get("action_one_hold")
  local required=1
  local fa=get_mod and get_mod("FullAuto")
  if fa and fa.get and (not fa.is_enabled or fa:is_enabled())
   and (not fa.class_features_enabled or fa.class_features_enabled()) and fa:get("chargeup_autofire") then
   required=math.max(.01,math.min(1,(fa:get("chargeup_autofire_amt") or 100)/100))
  end
  if not held and not state.release_committed then
   if state.charge+0.000001<required then return true end
   -- Full Auto's release can last one sampled frame. Once accepted, do not
   -- lose it to a following synthetic hold while waiting for shot recovery.
   state.release_committed=true
  end
  -- Input is the processed game input, so Full Auto can release and re-press it.
  -- Never fire during recovery, even if an input adapter clicks unusually fast.
  component.fire_at_time=math.max(state.release_committed and t or t+dt,S.ready[self._player_unit] or 0)
 end
 -- An immediately rejected queued input must not chirp the charge-up sound.
 if state then local ok,err=pcall(charge_visual,self,state,t);if not ok then warn("charge cue",err) end end
end

function M.charge_status(mark,t)
 if not S.active then return end
 for action,state in pairs(S.actions) do
  if action._is_local_unit and state.spec.mark==mark then
   local component=action._action_component
   if component.fire_state=="shot" then
    local left=math.max(0,state.recovery-(t-component.fire_last_t))
    return "recovery",left/state.recovery,left
   end
   local extra=state.release_committed and 0 or math.max(0,t-state.last_update)/state.charge_time
   local progress=math.max(0,math.min(1,state.charge+extra))
   return progress>=1 and "ready" or "charging",progress,(1-progress)*state.charge_time
  end
 end
 return "idle",0,0
end
function M.attach_counter(hud)
 -- Uses the existing weapon-counter registration, not a second HUD init hook
 -- or an extra dependency. No damage or charge decisions are made by the HUD.
 local UIWidget=require("scripts/managers/ui/ui_widget")
 local template={name="pilgrimage_heavy_charge",size={200,200},center_size={4,4},data={}}
 template.on_enter=function(_,slot,widget) widget.content.heavy_slot=slot end
 template.update_function=function(element,renderer,widget,wielded)
  widget.visible=false
  if not wielded or not S.active then return end
  local ext=element._parent:player_extensions()
  local weapon=ext and ext.visual_loadout and ext.visual_loadout:weapon_template_from_slot(widget.content.heavy_slot)
  if not weapon then return end
  local spec
  for _,s in ipairs(SPECS) do if weapon.name==s.mark then spec=s end end
  if not spec or spec.charge<=0 then return end
  local phase,progress=M.charge_status(spec.mark,now())
  if not phase then return end
  widget.visible=true
  local values=widget.style.charge_bar.material_values
  values.progress=.028+(.252-.028)*progress
  values.active=(phase=="charging" or phase=="ready") and 1 or 0
  values.lockout=phase=="recovery" and 1 or 0
  values.color_blend=phase=="recovery" and 1 or 0
 end
 local definition=UIWidget.create_definition({
  {pass_type="texture",style_id="charge_bar",value="content/ui/materials/effects/powersword_bar",
   style={horizontal_alignment="center",vertical_alignment="center",offset={102,35,1},size={200,200},
    color={255,255,215,135},material_values={active=0,color_blend=0,fill_opacity=.75,lockout=0,outline_opacity=1.5,progress=.028}}},
 },"pivot")
 hud._weapon_counter_templates[template.name]=template
 hud._weapon_counter_widget_definitions[template.name]=definition
end

-- A source is gameplay state on the host, not a health buff on a living enemy.
-- Clients receive endpoint coordinates, so their corpse limit cannot cancel damage.
local function as_array(v) return {v.x,v.y,v.z} end
local function vector(a)
 if type(a)~="table" or #a~=3 then return nil end
 for i=1,3 do if type(a[i])~="number" or a[i]~=a[i] or math.abs(a[i])>100000 then return nil end end
 return Vector3(a[1],a[2],a[3])
end
function M.render(packet)
 if not S.active or type(packet)~="table" or type(packet.links)~="table" or #packet.links>4 or #S.effects>=128 then return end
 local world=Managers.world:world("level_world"); if not world then return end
 local t=now()
 for _,link in ipairs(packet.links) do
  if #S.effects>=128 then break end
  if type(link)~="table" then return end
  local from,to=vector(link[1]),vector(link[2])
  if from and to and Vector3.distance_squared(from,to)<=26 and resource(FX.arc_link) then
   local direction,length=Vector3.direction_length(to-from)
   if length>0.01 then
    -- Same source-to-target contract as native arc_chain_to_position and
    -- Skitarii arc grenades. A rifle tracer's hit_distance is not this link.
    local id=World.create_particles(world,FX.arc_link,from,Quaternion.look(direction))
    local index=World.find_particles_variable(world,FX.arc_link,"length")
    World.set_particles_variable(world,id,index,Vector3(length,1,1))
    S.effects[#S.effects+1]={id=id,world=world,ends=t+0.3}
    particle(world,FX.arc_hit,to,Quaternion.look(-direction),Vector3(.7,.7,.7),.35)
   end
  end
 end
end
local function minion(unit)
 local ext=exists(unit) and ScriptUnit.has_extension(unit,"unit_data_system")
 local breed=ext and ext:breed()
 return breed and breed.breed_type=="minion" and not breed.is_untargetable,breed
end
local function electrocute(unit,source,t)
 local valid,breed=minion(unit)
 if not valid or not living(unit) or (breed.tags and breed.tags.monster) then return end
 local ext=ScriptUnit.has_extension(unit,"buff_system")
 if ext then
  ext:add_internally_controlled_buff("pilgrim_arc_cannon_electrocution",t,"owner_unit",source.owner,"source_item",source.item)
  local n=dependencies()
  if not n.stun then
   n.stun=copy(n.profiles.cryptic_arc_shock_damage)
   n.stun.power_distribution.attack=0
  end
  n.attack.execute(unit,n.stun,"power_level",125,"attacking_unit",source.owner,
   "attack_type","buff","damage_type","electrocution","attack_direction",Vector3(0,1,0))
 end
end
local function targets(source,from,used,limit)
 local ext=Managers.state.extension
 local side=ext:system("side_system").side_by_unit[source.owner]
 if not side then return {} end
 local broadphase=ext:system("broadphase_system").broadphase
 local found={}; local count=broadphase.query(broadphase,from,5,found,side:relation_side_names("enemy"))
 local choices={}
 for i=1,count do
  local unit=found[i]
  if not used[unit] and living(unit) and minion(unit) then
   local to=position(unit); local direction,length=Vector3.direction_length(to-from)
   if length>0.01 and not PhysicsWorld.raycast(source.physics,from,direction,length,"any","collision_filter","filter_chain_lightning_line_of_sight") then
    choices[#choices+1]={unit=unit,pos=Vector3Box(to),distance=length}
   end
  end
 end
 table.sort(choices,function(a,b) return a.distance<b.distance end)
 local out={}
 for i=1,math.min(limit,#choices) do out[i]=choices[i]; used[out[i].unit]=true end
 return out
end
local function arc_hit(source,target,from,factor,t)
 local to=target.pos:unbox()
 local n=dependencies()
 local p=factor==0.5 and source.first_profile or source.second_profile
 local damage=n.attack.execute(target.unit,p,"power_level",source.power,"attacking_unit",source.owner,
  "attack_type","arc","damage_type","arc_chain","hit_zone_name","center_mass",
  "attack_direction",Vector3.normalize(to-from),"hit_world_position",to,"item",source.item)
 if damage and damage>0 then electrocute(target.unit,source,t) end
 return {as_array(from),as_array(to)}
end
function M.pulse(source,t)
 local origin=position(source.unit); if not origin then return false end
 if resource(FX.corpse) and #S.effects<128 then
  local ok,id=pcall(World.create_particles,source.world,FX.corpse,origin)
  if ok then
   local linked=pcall(World.set_particles_surface_effect,source.world,id,source.unit,nil,nil,true)
   if linked then S.effects[#S.effects+1]={id=id,world=source.world,ends=t+0.5}
   else pcall(World.destroy_particles,source.world,id) end
  end
 end
 local used={[source.unit]=true,[source.owner]=true}
 local first=targets(source,origin,used,2); local packet={origin=as_array(origin),links={}}
 for _,target in ipairs(first) do
  packet.links[#packet.links+1]=arc_hit(source,target,origin,0.5,t)
 end
 for _,target in ipairs(first) do
  local from=exists(target.unit) and position(target.unit) or target.pos:unbox()
  for _,next_target in ipairs(targets(source,from,used,1)) do
   packet.links[#packet.links+1]=arc_hit(source,next_target,from,0.25,t)
  end
 end
 local ok,err=pcall(M.render,packet); if not ok then warn("arc presentation",err) end
 if S.realms and S.realms.send_weapon_fx then S.realms.send_weapon_fx(packet) end
 return true
end
function M.update(t)
 if not S.active then return end
 for voice in pairs(S.audio_voices) do
  if not exists(voice.owner) then stop_voice(voice)
  elseif not voice.local_owner and voice.api.set_position and t>=voice.position_t+.05 then
   voice.position_t=t
   local ok,pos=pcall(position,voice.owner)
   if ok and pos then pcall(voice.api.set_position,voice.id,pos,.1,3,45) end
  end
 end
 for i=#S.sounds,1,-1 do local sound=S.sounds[i];if t>=sound.ends then pcall(WwiseWorld.destroy_manual_source,sound.world,sound.id);table.remove(S.sounds,i) end end
 for i=#S.effects,1,-1 do local e=S.effects[i]; if t>=e.ends then pcall(World.destroy_particles,e.world,e.id); table.remove(S.effects,i) end end
end
function M.fixed_update(t)
 if not S.active or not next(S.sources) then return end
 if not Managers.state.game_session or not Managers.state.game_session:is_server() then return end
 for unit,source in pairs(S.sources) do
  if not exists(unit) or not exists(source.owner) or t>source.expires then S.sources[unit]=nil
  elseif t>=source.next_t then
   local ok,keep=pcall(M.pulse,source,t)
   if not ok then warn("arc pulse",keep) end
   source.remaining=source.remaining-1; source.next_t=t+0.5
   if not ok or not keep or source.remaining<=0 then S.sources[unit]=nil end
  end
 end
end
-- Ray contacts include scenery as well as enemies. Native wound/damage routing
-- remains intact; this is one cosmetic impact at the closest contact per shot.
function M.impact(world,owner,config,hits,t,endpoint)
 local p=config.hit_scan_template and config.hit_scan_template.damage.impact.damage_profile
 local key=p and p._pilgrimage_ogryn_heavy
 if not key or not hits or not hits[1] then return end
 local action,state
 for a,s in pairs(S.actions) do if a._player_unit==owner then action,state=a,s;break end end
 if not action or state.impact_t==t then return end
 -- The first raw contact may be the player or a pierced enemy. Prefer the
 -- actual stopping surface returned by HitScan, never a point beyond a wall.
 local hit
 for _,candidate in ipairs(hits) do
  local actor=candidate.actor or candidate[4]
  local unit=actor and Actor and Actor.unit(actor)
  local point=candidate.position or candidate[1]
  if unit~=owner and point then
   if not hit then hit=candidate end
   if endpoint and Vector3.distance_squared(point,endpoint)<.0001 then hit=candidate;break end
  end
 end
 if not hit then return end
 state.impact_t=t
 local pos=endpoint or hit.position or hit[1]; local normal=hit.normal or hit[3]
 if not pos then return end
 if normal then pos=pos+normal*.05 end
 local rotation=normal and Quaternion.look(normal) or Quaternion.identity()
 local arc=key=="arc_cannon"
 particle(world,key=="autocannon" and FX.auto_hit or arc and FX.arc_hit or FX.las_hit,pos,rotation,
  arc and Vector3(1.4,1.4,1.4) or Vector3(1.15,1.15,1.15),.6)
 sound_at(action._wwise_world,key=="autocannon" and SOUND.auto_hit or arc and SOUND.arc_hit or SOUND.las_hit,pos,rotation,false)
end
function M.attach_crosshair(hud)
 local UIWidget=require("scripts/managers/ui/ui_widget")
 local Crosshair=require("scripts/ui/utilities/crosshair")
 local passes={}
 for _,corner in ipairs({"top_left","bottom_left","top_right","bottom_right"}) do
  passes[#passes+1]=Crosshair.hit_indicator_segment(corner)
  passes[#passes+1]=Crosshair.weakspot_hit_indicator_segment(corner)
 end
 for i=0,3 do
  local angle=math.rad(i*90)
  passes[#passes+1]={pass_type="rotated_texture",style_id="ring_"..i,
   value="content/ui/materials/hud/crosshairs/shotgun_spread_2",
   style={horizontal_alignment="center",vertical_alignment="center",angle=angle,
    offset={math.sin(angle)*8,-math.cos(angle)*8,1},size={14,5},color={255,238,238,210}}}
 end
 local template={name="pilgrimage_cannon_circle",on_enter=function() end,
  update_function=function(parent,renderer,widget,_,settings,dt,t,draw_hit)
   local progress,color,weakspot=parent:hit_indicator()
   Crosshair.update_hit_indicator(widget.style,progress,color,weakspot,draw_hit)
  end}
 hud._crosshair_templates[template.name]=template
 hud._crosshair_widget_definitions[template.name]=UIWidget.create_definition(passes,"pivot")
end
local function on_hits(is_server,world,physics,owner,config,power,item,results)
 if not S.active or not is_server or not results or not exists(owner) then return end
 local p=config.hit_scan_template.damage.impact.damage_profile
 if p._pilgrimage_ogryn_heavy~="arc_cannon" then return end
 for _,hit in ipairs(results) do
  if (hit.hit_result=="damaged" or hit.hit_result=="died") and minion(hit.hit_unit) then
   local t=now(); local unit=hit.hit_unit; local old=S.sources[unit]
   if not old then
    local count=0; for _ in pairs(S.sources) do count=count+1 end
    if count>=32 then return end
   end
   local spec=SPECS[3]
   local source={unit=unit,owner=owner,item=item,world=world,physics=physics,power=power or 500,
    remaining=4,next_t=old and old.next_t or t+0.5,expires=t+2.5,
    first_profile=profile(p,spec,0.5),second_profile=profile(p,spec,0.25)}
   S.sources[unit]=source; electrocute(unit,source,t)
   return -- One origin per shot, never one per body actor or corpse fragment.
  end
 end
end
function M.install_gib(Visual)
 -- This is the cosmetic corpse path, after damage and kill attribution.
 -- A native profile keeps rpc_minion_gib resolvable for Realms clients;
 -- never replace the actual shot profile or create a damaging explosion.
 local ok,profiles=pcall(require,"scripts/settings/damage/damage_profile_templates")
 local burst=ok and profiles.close_krak_grenade
 if type(burst)~="table" or burst.name~="close_krak_grenade" then
  warn("lascannon dismemberment","native cosmetic profile unavailable");return
 end
 S.mod:hook(Visual,"gib",function(func,self,zone,direction,damage_profile,critical)
  if S.active and damage_profile and damage_profile._pilgrimage_ogryn_heavy=="lascannon" then
   local unit=self._unit
   local data=ScriptUnit.has_extension(unit,"unit_data_system")
   local breed=data and data:breed()
   local health=ScriptUnit.has_extension(unit,"health_system")
   if breed and breed.breed_type=="minion" and not (breed.tags and breed.tags.monster)
    and health and health:health_depleted() and self:can_gib("center_mass") then
    -- The original function retains local gore/region checks and sends the
    -- existing native gib RPC. Unsupported bodies use their normal fallback.
    return func(self,"center_mass",direction,burst,false)
   end
  end
  return func(self,zone,direction,damage_profile,critical)
 end)
end
function M.init(deps)
 S.mod,S.shared,S.realms=deps.mod,deps.shared,deps.realms
 S.settings=deps.settings
 local catalogue={}
 -- Reload-speed buffs scale animation and reload events together, not just the end timestamp.
 local reload_base={autocannon=5.8,lascannon=3,arc_cannon=7}
 for _,spec in ipairs(SPECS) do
  catalogue[#catalogue+1]={id="weapon_"..spec.key.."_handling",buff_template="pilgrim_weapon_"..spec.key.."_handling",
   custom={stat_buffs={movement_speed=-0.10,reload_speed=reload_base[spec.key]/spec.reload-1}}}
 end
 catalogue[#catalogue+1]={id="arc_cannon_electrocution",buff_template="pilgrim_arc_cannon_electrocution",custom={template=function(settings)
  -- Do not require buff_templates while its registration callback is running.
  -- The owned buff has native keywords/presentation but no hidden damage ticks.
  return {name="pilgrim_arc_cannon_electrocution",class_name="buff",duration=0.5,
   predicted=false,max_stacks=1,max_stacks_cap=1,refresh_duration_on_stack=true,
   buff_category=settings.buff_categories.generic,
   keywords={settings.keywords.electrocuted,settings.keywords.shock_grenade_shock},
   minion_effects={node_effects={{node_name="j_spine",vfx={material_emission=true,
    orphaned_policy="destroy",particle_effect=FX.corpse,stop_type="stop"},
    sfx={looping_wwise_start_event="wwise/events/weapon/play_psyker_chain_lightning_hit",
     looping_wwise_stop_event="wwise/events/weapon/stop_psyker_chain_lightning_hit"}}}}}
 end}}
 deps.passives.register_template_source(catalogue)
 deps.hooks.require_now("scripts/extension_systems/visual_loadout/minion_visual_loadout_extension",function(Visual)
  if deps.hooks.claim(Visual,"__pilgrimage_lascannon_gib") then return end
  M.install_gib(Visual)
 end)
 deps.hooks.require_now("scripts/ui/hud/elements/crosshair/hud_element_crosshair",function(Hud)
  if deps.hooks.claim(Hud,"__pilgrimage_heavy_circle") then return end
  S.mod:hook(Hud,"init",function(func,self,...)
   local result=func(self,...);M.attach_crosshair(self);return result
  end)
 end)
 -- DMF's frame callback runs outside the combat update and its temporary
 -- Vector3 lifetime. Keep Attack.execute inside the extension simulation pass.
 deps.hooks.require_now("scripts/foundation/managers/extension/extension_system_holder",function(Holder)
  if deps.hooks.claim(Holder,"__pilgrimage_heavy_fixed") then return end
  S.mod:hook(Holder,"fixed_update",function(func,self,dt,t,frame)
   local result=func(self,dt,t,frame)
   if dt>0 then M.fixed_update(t) end
   return result
  end)
 end)
 if S.realms and S.realms.set_weapon_fx_handler then S.realms.set_weapon_fx_handler(M.render) end
 deps.hooks.require_now("scripts/utilities/attack/hit_scan",function(HitScan)
  if deps.hooks.claim(HitScan,"__pilgrimage_ogryn_heavy_hits") then return end
  M.install_hits(HitScan)
 end)
end
function M.install_surface(ImpactEffect)
  S.mod:hook(ImpactEffect,"play_surface_effect",function(func,physics,owner,pos,normal,direction,damage_type,hit_type,data)
   if S.active and S.surface_context and S.surface_context.owner==owner then
    -- These transformed donors do not load arc/laser decal-unit packages.
    -- Capture the actual native surface contact and use our loaded particles,
    -- rather than requesting a missing decal or guessing a raw ray endpoint.
    S.surface_context.contact={position=Vector3Box(pos),normal=normal and Vector3Box(normal)}
    return
   end
   -- A cached third-party HitScan alias can enter before our context wrapper.
   -- Do not let that cosmetic path request the missing decal either.
   if S.active then
    for action,state in pairs(S.actions) do
     local expected=state.spec.key=="arc_cannon" and "arc_rifle"
      or state.spec.key=="lascannon" and "laser_bfg" or "boltshell_big"
     if action._player_unit==owner and damage_type==expected then return end
    end
   end
   return func(physics,owner,pos,normal,direction,damage_type,hit_type,data)
  end)
end
function M.install_hits(HitScan)
  S.mod:hook(HitScan,"process_hits",function(func,is_server,world,physics,owner,config,hits,pos,dir,power,charge,fx,range,debug_draw,local_unit,player,instakill,critical,item,slot,get_results)
   local owned=config.hit_scan_template and config.hit_scan_template.damage.impact.damage_profile._pilgrimage_ogryn_heavy
   -- Full Auto's optional early charge threshold must not grant a full-power
   -- discharge for a tiny windup. Full charge remains the normal manual path.
   if S.active and (owned=="lascannon" or owned=="arc_cannon") and charge and charge<1 then
    power=(power or 500)*math.max(.1,charge)
   end
   local previous_context=S.surface_context
   local context=S.active and owned and {owner=owner} or nil
   S.surface_context=context
   local ok,endpoint,elite,weakspot,killed,minion_hit,count,result,results=pcall(func,is_server,world,physics,owner,config,hits,pos,dir,power,charge,fx,range,debug_draw,local_unit,player,instakill,critical,item,slot,get_results)
   S.surface_context=previous_context
   if not ok then error(endpoint,0) end
   if S.active and (local_unit or is_server) then
    local surface=context and context.contact
    local impact_hits=surface and {{surface.position:unbox(),0,surface.normal and surface.normal:unbox()}} or hits
    local impact_end=surface and surface.position:unbox() or endpoint
    local ok_fx,err_fx=pcall(M.impact,world,owner,config,impact_hits,now(),impact_end)
    if not ok_fx then warn("impact",err_fx) end
   end
   local ok,err=pcall(on_hits,is_server,world,physics,owner,config,power,item,results)
   if not ok then warn("arc hit",err) end
   return endpoint,elite,weakspot,killed,minion_hit,count,result,results
  end)
end
M.specs=SPECS
M.state=S -- Internal harness access, no console command or saved setting.
return M
