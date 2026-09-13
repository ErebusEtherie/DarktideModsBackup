-- Flat, character-keyed storage behind Pilgrimage's existing scalar settings.
-- Only the explicit run/loadout keys below are redirected. Wallet, unlocks,
-- captures, penances and other mods still use their original account settings.
local M = {}
local mod, shared, raw_get, raw_set, owner, before_switch, after_switch
local waiting_for_loading = false
local loading = false
local scoped, defaults = {}, {}
local PREFIX = "_operative_v1_"
local MIGRATED = PREFIX .. "legacy_owner"
local TEMPLATE = PREFIX .. "defaults_ready"
local LOADOUT = {"_boon_loadout_slotted", "_boon_loadout_slotmap",
 "_archetype_selected", "_legendary_slot"}
local EXTRA = {"_archetype_run", "_legendary_run", "_legendary_run_temp",
 "_legendary_pending", "_legendary_slot_temp", "_shop_consumables",
 "_shop_stacks", "_doctrine_unbroken_ready", "_preview_seed",
 "_run_pending_mission", "_run_pending_outcome", "_run_pending_result"}

local function valid(id)
 return type(id)=="string" and #id>0 and #id<=128
  and not id:find("[^%w_%-]") and id~="nil"
end
local function key_for(id,key) return PREFIX .. id .. ":" .. key end
function M.key(key)
 if not scoped[key] then return key end
 return owner and key_for(owner,key) or nil
end
function M.owner() return owner end
function M.ready() return owner~=nil end

local function selected_account()
 local managers=rawget(_G,"Managers")
 local account=managers and managers.data_service and managers.data_service.account
 if not account or type(account.selected_character)~="function" then return nil end
 local ok,character=pcall(account.selected_character,account)
 local id=ok and type(character)=="table" and character.character_id
 return valid(id) and id or nil
end
local function selected_player()
 local player=shared and shared.local_player and shared.local_player()
 if not player then return nil end
 if type(player.character_id)=="function" then
  local ok,id=pcall(player.character_id,player)
  if ok and valid(id) then return id end
 end
 if type(player.profile)=="function" then
  local ok,profile=pcall(player.profile,player)
  local id=ok and type(profile)=="table" and profile.character_id
  if valid(id) then return id end
 end
end
local function handoff_owner()
	-- A stale last-launch key cannot claim a hub or an unrelated mission.
 if raw_get(mod,"_launch_character_armed")~=true then return nil end
 if not shared or not shared.mission_name then return nil end
 if shared.is_in_hub and shared.is_in_hub() then return nil end
 if shared.is_in_psykhanium and shared.is_in_psykhanium() then return nil end
 local mission=shared.mission_name()
 if not mission or mission~=raw_get(mod,"_launch_mission") then return nil end
 local id=raw_get(mod,"_launch_character_id")
 return valid(id) and id or nil
end

local function prepare(id)
 if raw_get(mod,TEMPLATE)~=true then
  for key in pairs(defaults) do
   raw_set(mod,PREFIX.."default:"..key,raw_get(mod,key),false)
  end
  raw_set(mod,TEMPLATE,true,false)
 end
 if raw_get(mod,key_for(id,"ready"))==true then return end
 local legacy=raw_get(mod,MIGRATED)
 -- On first migration, claim once in the same in-memory DMF transaction as
 -- all copied scalars. No save occurs in the middle of this transaction.
 if not valid(legacy) then
  for key in pairs(scoped) do raw_set(mod,key_for(id,key),raw_get(mod,key),false) end
  raw_set(mod,MIGRATED,id,false)
  if not raw_get(mod,"_launch_character_id") then
   raw_set(mod,"_launch_character_id",id,false)
  end
 else
  for key in pairs(defaults) do
   raw_set(mod,key_for(id,key),raw_get(mod,PREFIX.."default:"..key),false)
  end
 end
 raw_set(mod,key_for(id,"ready"),true,false)
end

function M.select(id)
 if id~=nil and not valid(id) then return false,"invalid character id" end
 if id==owner then return owner~=nil end
 if owner and before_switch then before_switch(owner,id) end
 if id then prepare(id) end
 owner=id
 if after_switch then after_switch(id) end
 return owner~=nil
end

function M.refresh(phase)
 if phase=="menu" then waiting_for_loading=true;return M.select(nil) end
 if phase=="loading" then waiting_for_loading=false;loading=true end
 if waiting_for_loading then return false end
 if phase=="gameplay" and (not shared.game_mode_name or not shared.game_mode_name()) then
  return M.ready()
 end
 if phase=="entered" then loading=false end
 -- Old hub/player managers can survive between StateLoading and gameplay.
 -- Neither a maintenance tick nor a terminal request may undo that handoff.
 if loading and phase=="gameplay" then return M.ready() end
 if phase=="boot" and not selected_player() and not handoff_owner()
  and (not shared.game_mode_name or not shared.game_mode_name()) then return false end
 local id
 if phase=="loading" or phase=="entered" then
  -- The old local player can still exist while the next operative loads.
  id=selected_account() or (phase=="entered" and selected_player()) or owner or handoff_owner()
 else
  id=selected_player() or handoff_owner() or selected_account()
 end
 if id then
  local ready=M.select(id)
  -- Once gameplay has entered, the early-load handoff has served
  -- its purpose. A future unrelated visit to this map cannot reuse it.
  if phase=="entered"
   and raw_get(mod,"_launch_character_armed")==true then
   raw_set(mod,"_launch_character_armed",false,false)
  end
  return ready
 end
 return M.ready()
end
function M.set_callbacks(before,after)
 before_switch=before;after_switch=after
end
function M.record_launch()
 if not owner then return false end
 raw_set(mod,"_launch_character_id",owner,false)
 raw_set(mod,"_launch_character_armed",true,false)
 return true
end
function M.launch_matches()
 local id=raw_get(mod,"_launch_character_id")
 return owner~=nil and id==owner
end

function M.init(deps)
 mod=deps.mod;shared=deps.shared
 local previous=rawget(mod,"_pil_character_store")
 if previous then
  if previous.before_reload then previous.before_reload() end
  raw_get=previous.raw_get;raw_set=previous.raw_set
 else raw_get=mod.get;raw_set=mod.set end
 for _,key in pairs(deps.run_keys) do
  if key~="_launch_mission" and key~="_launch_circumstance" then scoped[key]=true end
 end
 for _,key in ipairs(LOADOUT) do scoped[key]=true;defaults[key]=true end
 for _,key in ipairs(EXTRA) do scoped[key]=true end
 mod.get=function(self,key)
  local resolved=M.key(key)
  if not resolved then return nil end
  return raw_get(self,resolved)
 end
 mod.set=function(self,key,value,notify)
  local resolved=M.key(key)
  if not resolved then return false end -- No anonymous run or consumable writes.
  return raw_set(self,resolved,value,notify)
 end
 mod._pil_character_store={raw_get=raw_get,raw_set=raw_set,
  before_reload=function() if owner and before_switch then before_switch(owner,owner) end end}
 M.refresh("boot")
end
return M
