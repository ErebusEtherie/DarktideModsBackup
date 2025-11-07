[Darktide Modding Framework](https://dmf-docs.darkti.de/#/)


[UIWidget](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/managers/ui/ui_widget.lua#L4)
test
```lua
UIWidget.create_definition = function (pass_definitions, scenegraph_id, content_overrides, optional_size,
style_overrides)
```

[UiManager](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/managers/ui/ui_manager.lua)

````lua
UIManager.open_view = function(self, view_name, transition_time, close_previous, close_all, close_transition_time, context, settings_override)

UIManager.close_view = function(self, view_name, force_close)

UIManager.close_all_views = function(self, force_close, optional_excepted_views)
````

[BaseView](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/ui/views/base_view.lua)
```lua
BaseView._create_widget = function(self, name, definition, widgets_by_name)

BaseView.draw = function(self, dt, t, input_service, layer)
    -- draws self._widgets

BaseView._set_scenegraph_size = function(self, id, width, height, optional_ui_scenegraph)
```

[StateGameplay](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/game_states/game/state_gameplay.lua#L79)
````lua
StateGameplay.on_enter = function (self, parent, params, creation_context)
````

[PlayerManager](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/foundation/managers/player/player_manager.lua#L4)

[Talents](https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/settings/ability/archetype_talents/talents/veteran_talents.lua#L4)