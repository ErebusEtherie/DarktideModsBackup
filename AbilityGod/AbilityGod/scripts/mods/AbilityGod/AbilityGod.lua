local mod = get_mod("AbilityGod")

----------------------------------------------------------------
-- 1) Inject a virtual combat-ability key press when needed
----------------------------------------------------------------
local inject = false
mod:hook("InputService", "_get", function(orig, self, action)
  if action == "combat_ability_pressed" and inject then
    inject = false
    return true
  end
  return orig(self, action)
end)

----------------------------------------------------------------
-- 2) Ability registry  (keys match game archetype names)
----------------------------------------------------------------
local AB = {
  veteran = {
    { id="veteran_exec",  talents={ "veteran_combat_ability_elite_and_special_outlines" } },
    { id="veteran_voice", talents={ "veteran_combat_ability_stagger_nearby_enemies" } },
    { id="veteran_infil", talents={ "veteran_invisibility_on_combat_ability" } },
  },
  psyker = {
    { id="psyker_shout",  talents={ "psyker_shout_vent_warp_charge" } },
    { id="psyker_shield", talents={ "psyker_combat_ability_force_field" } },
    { id="psyker_over",   talents={ "psyker_combat_ability_stance" } },
  },
  zealot = {
    { id="zealot_dash",    talents={ "zealot_attack_speed_post_ability" } },
    { id="zealot_prayer",  talents={ "zealot_bolstering_prayer" } },
    { id="zealot_stealth", talents={ "zealot_stealth" } },
  },
  ogryn = {
    { id="ogryn_rush",  talents={ "ogryn_longer_charge" } },
    { id="ogryn_taunt", talents={ "ogryn_taunt_shout" } },
    { id="ogryn_ammo",  talents={ "ogryn_special_ammo" } },
  },
  adamant = {
    { id="arbiter_stance", talents={ "adamant_stance" } },
    { id="arbiter_drone",  talents={ "adamant_area_buff_drone" } },
    { id="arbiter_charge", talents={ "adamant_charge" } },
  },
  broker = {
    { id="broker_focus", talents={ "broker_ability_focus_improved" } },
    { id="broker_punk",  talents={ "broker_ability_punk_rage" } },
    { id="broker_stimm", talents={ "broker_ability_stimm_field" } },
  },
}

local MODE = {
  never=1,
  tough=2,
  peril=3,
  health=4,
  tough_or_peril=5,
  tough_or_health=6,
  peril_or_health=7,
  tough_or_peril_or_health=8,
}

----------------------------------------------------------------
-- 3) Safe helpers (menu-proof)
----------------------------------------------------------------
local function in_gameplay()
  return rawget(_G, "Managers")
     and Managers.state
     and Managers.state.game_mode
     and Managers.player
end

local function get_player()
  if not in_gameplay() then return nil end
  local ok, player = pcall(function()
    return Managers.player:local_player(1)
  end)
  if not ok then return nil end
  return player
end

-- 0–1 toughness
local function tough_pct(u)
  if not u or not Unit.alive(u) then return 1 end
  local ok, ext = pcall(ScriptUnit.extension, u, "toughness_system")
  if not ok or not ext or not ext.current_toughness_percent then return 1 end
  return ext:current_toughness_percent()
end

-- 0–1 peril (non-psyker ⇒ 0)
local function peril_pct(u)
  if not u or not Unit.alive(u) then return 0 end
  local ok, ud = pcall(ScriptUnit.extension, u, "unit_data_system")
  if not ok or not ud then return 0 end
  local wc = ud:read_component("warp_charge")
  return (wc and wc.current_percentage) or 0
end

-- 0â€“1 health
local function health_pct(u)
  if not u or not Unit.alive(u) then return 1 end
  local ok, ext = pcall(ScriptUnit.extension, u, "health_system")
  if not ok or not ext then return 1 end
  if ext.current_health_percent then
    return ext:current_health_percent()
  end
  if ext.max_health and ext.current_health then
    local max = ext:max_health()
    return (max and max > 0) and (ext:current_health() / max) or 1
  end
  return 1
end

local function profile_has(profile, aliases)
  if not profile or not profile.talents then return false end
  local t = profile.talents
  for _, k in ipairs(aliases or {}) do
    local v = t[k]
    if v == 1 or v == true then
      return true
    end
  end
  return false
end

----------------------------------------------------------------
-- 4) Anti-spam / toggle handling
----------------------------------------------------------------
local TOGGLE_LIKE = { zealot_prayer = true }
local last_cond, last_press = {}, {}
local now_s = 0
local function can_press_again(id, cd)
  return (now_s - (last_press[id] or -1e9)) >= (cd or 0.2)
end

----------------------------------------------------------------
-- 5) Main update (supports update(dt) and update(self, dt))
----------------------------------------------------------------
function mod.update(a1, a2)
  -- Don't run at title/menus; fixes startup crash
  if not in_gameplay() then return end

  local dt = (type(a1) == "number") and a1 or (type(a2) == "number" and a2 or 0)
  now_s = now_s + dt

  if not mod:get("master_enable") then return end

  local player = get_player(); if not player then return end
  local unit = player.player_unit; if not unit or not Unit.alive(unit) then return end
  local profile = player:profile(); if not profile then return end

  local archetype = player:archetype_name() or ""
  local entries   = AB[archetype] or {}
  if #entries == 0 then return end

  local tp = tough_pct(unit)
  local pp = (archetype == "psyker") and peril_pct(unit) or 0
  local hp = health_pct(unit)

  local t_ok = tp <= ((mod:get("toughness_thresh") or 20) / 100)
  local p_ok = pp >= ((mod:get("peril_thresh")     or 100) / 100)
  local h_ok = hp <= ((mod:get("health_thresh")    or 20) / 100)

  -- strict pass: only equipped ability can fire
  for _, e in ipairs(entries) do
    local mode = mod:get(e.id) or MODE.never
    if mode ~= MODE.never and profile_has(profile, e.talents) then
      local cond = (mode == MODE.tough and t_ok)
                or (mode == MODE.peril and p_ok)
                or (mode == MODE.health and h_ok)
                or (mode == MODE.tough_or_peril and (t_ok or p_ok))
                or (mode == MODE.tough_or_health and (t_ok or h_ok))
                or (mode == MODE.peril_or_health and (p_ok or h_ok))
                or (mode == MODE.tough_or_peril_or_health and (t_ok or p_ok or h_ok))

      local was = last_cond[e.id] or false
      last_cond[e.id] = cond

      if TOGGLE_LIKE[e.id] then
        -- Rising edge for toggle-like abilities
        if cond and not was and can_press_again(e.id, 0.3) then
          inject = true
          last_press[e.id] = now_s
          return
        end
      else
        if cond and can_press_again(e.id, 0.2) then
          inject = true
          last_press[e.id] = now_s
          return
        end
      end
    else
      last_cond[e.id] = false
    end
  end
end

return mod
