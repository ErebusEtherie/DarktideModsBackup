local mod = get_mod("realms_loadout")
if not mod then
  return
end

local loadout_names = get_mod("LoadoutNames")
if not loadout_names then
  return
end

local Storage = require("realms_loadout/scripts/mods/realms_loadout/storage")



-- Install against the cached private class supplied by the owning module.
local RealmsViewElementProfilePresets = mod._realms_loadoutnames_presets_class
local RealmsInventoryBackgroundView = mod._realms_loadoutnames_background_class

-- Make sure the LoadoutNames widget/scenegraph definitions are present. They
-- normally arrive through LoadoutNames' own hook_require; re-run its
-- definitions file if some load-order edge case skipped it.
do
  local Definitions = require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_definitions")

  if not (Definitions.widget_definitions and Definitions.widget_definitions.loadout_name_tbox) then
    loadout_names:io_dofile("LoadoutNames/scripts/mods/LoadoutNames/ViewDefinitions")
  end
end

-- Names for custom slots never use an official preset's key.
local function loadout_name_key(loadout_id) return loadout_id end

local function is_uuid_like(value)
  return type(value) == "string" and string.match(value, "^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local function loadout_display_name(loadout_id, preset_name_key, fallback_name)
  local key = preset_name_key or loadout_name_key(loadout_id)
  local raw_name = loadout_names:get(key)
  local name = type(raw_name) == "string" and raw_name or ""

  -- Never display an id/key as if it were a name.
  if name == "" or is_uuid_like(name) or name == key or name == loadout_id then
    local preset_name = fallback_name

    if preset_name == nil then
      local preset = loadout_id and Storage.get_profile_preset(loadout_id)

      preset_name = preset and preset.name
    end

    name = type(preset_name) == "string" and preset_name or ""
  end


  return name
end

local function element_loadout_id(background_view)
  local element = background_view and background_view._profile_presets_element

  return element and element._active_profile_preset_id or background_view and background_view._active_profile_preset_id
end

local function active_loadout_id(background_view)
  return mod._ln_active_loadout_id or element_loadout_id(background_view)
end

local function set_is_typing(is_typing)
  is_typing = is_typing == true

  if is_typing then
    mod._ln_has_typed = true
  end

  if mod._ln_is_typing == is_typing then
    return
  end

  mod._ln_is_typing = is_typing

  local view = Managers.ui and Managers.ui:view_instance("realms_inventory_background_view")

  if view then
    view._allow_close_hotkey = not is_typing

    if view._settings then
      view._settings.close_on_hotkey_pressed = not is_typing
    end
  end

  local tbox = mod._ln_tbox_widget
  local tbox_content = tbox and tbox.content

  if tbox_content then
    tbox_content.is_writing = is_typing
    tbox_content.hide_baseline = not is_typing
    tbox_content.selected_text = is_typing and tbox_content.selected_text or nil
    tbox_content._selection_start = is_typing and tbox_content._selection_start or nil
    tbox_content._selection_end = is_typing and tbox_content._selection_end or nil
  end

  local tbox_style = tbox and tbox.style

  if tbox_style then
    if tbox_style.background then
      tbox_style.background.visible = is_typing
    end

    if tbox_style.display_text then
      tbox_style.display_text.text_horizontal_alignment = is_typing and "left" or "right"
    end
  end
end

local function end_typing()
  set_is_typing(false)
end

local function save_loadout_name(background_view, deletion)
  local tbox = mod._ln_tbox_widget
  local tbox_content = tbox and tbox.content

  if not tbox_content then
    return
  end

  local loadout_id = active_loadout_id(background_view)

  if not loadout_id then
    return
  end

  local name_key = loadout_name_key(loadout_id)

  if deletion then
    loadout_names:set_loadout_name(name_key, nil)

    return
  end

  -- Only persist names the user actually typed. Programmatically shown
  -- fallback names must not overwrite existing LoadoutNames entries.
  if not mod._ln_has_typed then
    return
  end

  local raw_name = tbox_content.input_text

  if type(raw_name) == "string" and raw_name ~= "" and not is_uuid_like(raw_name) and raw_name ~= name_key and raw_name ~= loadout_id then
    loadout_names:set_loadout_name(name_key, raw_name)
  else
    loadout_names:set_loadout_name(name_key, nil)
  end
end

local function display_loadout_name(background_view)
  local element = background_view and background_view._profile_presets_element
  local widgets_by_name = element and element._widgets_by_name
  local tbox = widgets_by_name and widgets_by_name.loadout_name_tbox
  local tooltip = widgets_by_name and widgets_by_name.loadout_name_tooltip


  if tbox then
    mod._ln_tbox_widget = tbox
  end

  if tooltip then
    mod._ln_tooltip_widget = tooltip
  end

  local tbox_content = tbox and tbox.content

  if tbox_content then
    local loadout_id = active_loadout_id(background_view)
    local shown_name = loadout_display_name(loadout_id)

    tbox_content.visible = loadout_id ~= nil and loadout_id ~= "" or false
    tbox_content.input_text = shown_name
    tbox_content.placeholder_text = shown_name
    mod._ln_active_display_name = shown_name
  end

  local tooltip_content = tooltip and tooltip.content

  if tooltip_content then
    tooltip_content.text = ""
    tooltip.visible = false
  end

end

if RealmsViewElementProfilePresets then
  function mod._refresh_loadoutnames_preset_setup()
    local orig_setup_preset_buttons = RealmsViewElementProfilePresets._setup_preset_buttons

    if orig_setup_preset_buttons == mod._loadoutnames_preset_setup_wrapper then return end

    if orig_setup_preset_buttons then
      function RealmsViewElementProfilePresets:_setup_preset_buttons(...)
        orig_setup_preset_buttons(self, ...)

        local buttons = self._profile_buttons_widgets

        for i = 1, #(buttons or {}) do
          local content = buttons[i] and buttons[i].content

          if content and content.profile_preset_id then
            local preset = Storage.get_profile_preset(content.profile_preset_id)

            content.loadout_name_key = content.profile_preset_id
            content.loadout_fallback_name = preset and preset.name or ""
          end
        end

        local active_id = self._active_profile_preset_id
        local active_name = active_id and loadout_display_name(active_id) or ""
        local tbox = self._widgets_by_name and self._widgets_by_name.loadout_name_tbox

        if tbox and tbox.content then
          mod._ln_tbox_widget = tbox
          mod._ln_active_display_name = active_name
          tbox.content.placeholder_text = active_name

          if not tbox.content.is_writing then
            tbox.content.input_text = active_name
          end
        end
      end
      mod._loadoutnames_preset_setup_wrapper = RealmsViewElementProfilePresets._setup_preset_buttons
    end
  end
  mod._refresh_loadoutnames_preset_setup()

  local orig_update = RealmsViewElementProfilePresets.update

  if orig_update then
    function RealmsViewElementProfilePresets:update(dt, t, input_service)
      orig_update(self, dt, t, input_service)

      local tbox = mod._ln_tbox_widget

      if not tbox then
        tbox = self._widgets_by_name and self._widgets_by_name.loadout_name_tbox
        mod._ln_tbox_widget = tbox
      end

      if tbox and tbox.content then
        set_is_typing(tbox.content.is_writing or false)

        local current_name = mod._ln_active_display_name
        local current_id = mod._ln_active_loadout_id or self._active_profile_preset_id

        if (not current_name or current_name == "") and current_id then
          current_name = loadout_display_name(current_id)
        end

        if current_name and current_name ~= "" then
          mod._ln_active_display_name = current_name
          tbox.content.placeholder_text = current_name
        end
      end

      local tooltip = mod._ln_tooltip_widget

      if not tooltip then
        tooltip = self._widgets_by_name and self._widgets_by_name.loadout_name_tooltip
        mod._ln_tooltip_widget = tooltip
      end

      if tooltip and tooltip.content.text ~= nil and self._profile_buttons_widgets then
        local hovered_id
        local hovered_name_key
        local hovered_fallback_name

        for i = 1, #self._profile_buttons_widgets do
          local content = self._profile_buttons_widgets[i].content

          if content and content.hotspot and content.hotspot.is_hover and content.profile_preset_id then
            hovered_id = content.profile_preset_id
            hovered_name_key = content.loadout_name_key
            hovered_fallback_name = content.loadout_fallback_name

            break
          end
        end

        local shown_name = ""

        if hovered_id then
          shown_name = loadout_display_name(hovered_id, hovered_name_key, hovered_fallback_name)
        end

        tooltip.content.text = shown_name
        tooltip.visible = shown_name ~= ""
      end
    end
  end
end

if RealmsInventoryBackgroundView then
  local orig_setup_profile_presets = RealmsInventoryBackgroundView._setup_profile_presets

  if orig_setup_profile_presets then
    function RealmsInventoryBackgroundView:_setup_profile_presets(...)
      orig_setup_profile_presets(self, ...)

      mod._ln_has_typed = false
      mod._ln_active_loadout_id = element_loadout_id(self)
      display_loadout_name(self)
    end
  end

  local orig_event_on_profile_preset_changed = RealmsInventoryBackgroundView.event_on_profile_preset_changed

  if orig_event_on_profile_preset_changed then
    function RealmsInventoryBackgroundView:event_on_profile_preset_changed(profile_preset, on_preset_deleted)
      save_loadout_name(self, on_preset_deleted)
      end_typing()

      orig_event_on_profile_preset_changed(self, profile_preset, on_preset_deleted)

      mod._ln_has_typed = false
      mod._ln_active_loadout_id = element_loadout_id(self)
      display_loadout_name(self)
    end
  end

  local function save_active_preset_name(self)
    save_loadout_name(self)
    end_typing()
  end

  local function clear_preset_name_state(self)
    mod._ln_has_typed = false
    mod._ln_active_loadout_id = nil
    mod._ln_active_display_name = nil
    mod._ln_tbox_widget = nil
    mod._ln_tooltip_widget = nil
  end

  local orig_remove_profile_presets = RealmsInventoryBackgroundView._remove_profile_presets

  if orig_remove_profile_presets then
    function RealmsInventoryBackgroundView:_remove_profile_presets(...)
      save_active_preset_name(self)
      orig_remove_profile_presets(self, ...)
      clear_preset_name_state(self)
    end
  end

  local orig_on_exit = RealmsInventoryBackgroundView.on_exit

  if orig_on_exit then
    function RealmsInventoryBackgroundView:on_exit(...)
      save_active_preset_name(self)
      orig_on_exit(self, ...)
      clear_preset_name_state(self)
    end
  end

  local orig_handle_input = RealmsInventoryBackgroundView._handle_input

  if orig_handle_input then
    function RealmsInventoryBackgroundView:_handle_input(input_service, dt, t)
      if mod._ln_is_typing and input_service and (input_service:get("send_chat_message") or input_service:get("back")) then
        end_typing()
      end

      orig_handle_input(self, input_service, dt, t)
    end
  end

  local orig_weapon_swap = RealmsInventoryBackgroundView.cb_on_weapon_swap_pressed

  if orig_weapon_swap then
    function RealmsInventoryBackgroundView:cb_on_weapon_swap_pressed(...)
      if not mod._ln_is_typing then
        orig_weapon_swap(self, ...)
      end
    end
  end

  local orig_clear_all_talents = RealmsInventoryBackgroundView.cb_on_clear_all_talents_pressed

  if orig_clear_all_talents then
    function RealmsInventoryBackgroundView:cb_on_clear_all_talents_pressed(...)
      if not mod._ln_is_typing then
        orig_clear_all_talents(self, ...)
      end
    end
  end
end

-- LoadoutNames also blocks tab switching while typing. Its official hook only
-- checks the official textbox state, so add a Realms-aware hook to the shared
-- ViewElementMenuPanel class. The preset and background integrations share
-- this one hook.
if not mod._realms_loadoutnames_menu_hooked then
  mod:hook("ViewElementMenuPanel", "_select_next_tab", function (func, self, ...)
    if not mod._ln_is_typing then
      return func(self, ...)
    end
  end)

  mod._realms_loadoutnames_menu_hooked = true
end

return true
