-- Native callbacks need selection state, not a second menu. No UI is created.
return function()
  return {
    selected_index = function(self) return self.index end,
    set_selected_panel_index = function(self, index) self.index = index end,
    add_entry = function() end,
    set_is_handling_navigation_input = function() end,
  }
end
