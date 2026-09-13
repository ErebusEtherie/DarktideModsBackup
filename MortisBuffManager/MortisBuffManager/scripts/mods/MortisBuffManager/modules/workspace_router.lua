local mod = get_mod("MortisBuffManager")
if mod._workspace_router then return mod._workspace_router end
local Router = {}
mod._workspace_router = Router
-- Shared protocol state, not a dependency on another optional mod.
local framework = get_mod("DMF")
framework._inventory_extensions_v1 = framework._inventory_extensions_v1 or { owners = {} }
local registry = framework._inventory_extensions_v1
local native = { view_name = "mortisbuffmanager_workspace_native_view", native = true,
  can_select = function(view, tab) return view:can_select_workspace_page(tab) end,
  select = function(view, tab) return view:select_workspace_page(tab) end }
local base = {
  equipment = { id = "equipment", order = 10, label = function() return Localize("loc_inventory_view_display_name") end, page = native },
  cosmetics = { id = "cosmetics", order = 20, label = function() return Localize("loc_cosmetics_view_display_name") end, page = native },
  talents = { id = "talents", order = 40, label = function() return Localize("loc_talent_view_display_name") end, page = native },
}

local function participants()
  local result = {}
  for name, owner in pairs(registry.owners) do
    if owner.enabled() then result[#result + 1] = { name = name, owner = owner } end
  end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

function Router.entries(player)
  local by_id = {}
  for id, entry in pairs(base) do by_id[id] = entry end
  for _, item in ipairs(participants()) do
    for _, entry in ipairs(item.owner.pages()) do
      if not entry.applies or entry.applies(player) then by_id[entry.id] = entry end
    end
  end
  local result = {}
  for _, entry in pairs(by_id) do result[#result + 1] = entry end
  table.sort(result, function(a, b)
    if a.order == b.order then return a.id < b.id end
    return a.order < b.order
  end)
  return result
end

function Router.page(tab, player)
  for _, entry in ipairs(Router.entries(player)) do if entry.id == tab then return entry.page end end
end

function Router.native_nodes(player)
  -- Extensions may supply their untouched official build for native previews.
  for _, item in ipairs(participants()) do
    if item.owner.native_nodes then
      local nodes = item.owner.native_nodes(player)
      if nodes then return nodes end
    end
  end
  return player:profile().selected_nodes or {}
end

function Router.open(tab)
  if not mod:is_enabled() or not Managers.ui then return false end
  local player = Managers.player and Managers.player:local_player_safe(1)
  local profile = player and not player.__deleted and player:profile()
  if not profile or not profile.archetype then return false end
  for _, item in ipairs(participants()) do
    local owner = item.owner
    local view = Managers.ui:view_instance(owner.window)
    if view then return view:select_page(tab) end
    if Managers.ui:view_active(owner.window) then owner.request(tab); return true end
  end
  if Managers.ui:view_active("inventory_background_view") then
    mod:notify(mod:localize("workspace_close_native")); return false
  end
  if not Router.page(tab, player) then return false end
  local realms = get_mod("Realms")
  local preparation = realms and realms._preparation
  if preparation and preparation.is_finalizing and preparation.is_finalizing() then return false end
  if preparation and preparation.is_waiting and preparation.is_waiting()
    and preparation.local_ready and preparation.local_ready() then preparation.perform_action() end
  Managers.ui:open_view(mod._workspace_window_name, nil, nil, nil, nil,
    { player = player, initial_page = tab, is_readonly = false })
  return true
end

function Router.enable()
  registry.owners["MortisBuffManager"] = {
    window = mod._workspace_window_name,
    enabled = function() return mod:is_enabled() end,
    pages = function() return mod.workspace_pages or {} end,
    native_nodes = function(player) return mod.workspace_native_nodes and mod.workspace_native_nodes(player) end,
    request = function(tab) mod._workspace_requested_tab = tab end,
  }
end

function Router.install()
  if not mod._workspace_window_name then
    mod._workspace_window_name = "mortisbuffmanager_workspace_view"
    for _, view in ipairs({
      { "mortisbuffmanager_workspace_view", "MortisBuffManagerWorkspaceShell", "workspace_shell", "inventory_background_view" },
      { "mortisbuffmanager_workspace_native_view", "MortisBuffManagerWorkspaceNativeView", "workspace_native_view", "inventory_background_view" },
    }) do
      mod:add_require_path("MortisBuffManager/scripts/mods/MortisBuffManager/modules/" .. view[3])
      local settings = view[3] == "workspace_native_view"
        and table.clone_instance(require("scripts/ui/views/views").inventory_background_view) or {}
      settings.class, settings.path, settings.state_bound = view[2], "MortisBuffManager/scripts/mods/MortisBuffManager/modules/" .. view[3], true
      settings.package = "packages/ui/views/" .. view[4] .. "/" .. view[4]
      settings.init_view_function = function() return true end
      mod:register_view({ view_name = view[1], view_settings = settings, view_transitions = {} })
    end
    mod:command("mortisbuffs", mod:localize("workspace_command"), function() return Router.open("mortis") end)
  end
  Router.enable()
end

function Router.cleanup()
  registry.owners["MortisBuffManager"] = nil
  mod._workspace_requested_tab = nil
  if Managers.ui and mod._workspace_window_name and Managers.ui:view_active(mod._workspace_window_name) then
    Managers.ui:close_view(mod._workspace_window_name, true)
  end
end

return Router
