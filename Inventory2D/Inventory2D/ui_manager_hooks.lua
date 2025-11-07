local s = Inventory2D

s.mod:hook_safe("UIManager", "update", function(self, dt, t)
	if s.icon_renderer then
		s.icon_renderer:update(dt, t)
	end
end)

s.mod:hook_safe("UIManager", "event_on_render_settings_applied", function(self)
	if s.icon_renderer and s.icon_renderer.update_all then
		s.icon_renderer:update_all()
	end
end)

s.mod:hook_safe("UIManager", "update_item_icon_priority", function(self, id)
	if s.icon_renderer and s.icon_renderer:has_request(id) then
		s.icon_renderer:prioritize_request(id)
	end
end)

s.mod:hook_safe("UIManager", "increment_item_icon_load_by_existing_id",
		function(self, id)
	if s.icon_renderer and s.icon_renderer:has_request(id) then
		return s.icon_renderer:increment_icon_request_by_reference_id(id)
	end
end)

s.mod:hook_safe("UIManager", "item_icon_updated", function(self, item)
	if s.icon_renderer then
		s.icon_renderer:weapon_icon_updated(item)
	end
end)
