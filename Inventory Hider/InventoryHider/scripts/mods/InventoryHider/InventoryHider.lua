local mod = get_mod("InventoryHider")

mod.draw_inventory = true
mod.toggle_inventory_hider = function()
    mod.draw_inventory = not mod.draw_inventory
end

mod:hook(CLASS.InventoryView, "draw", function(func, self, dt, t, input_service, layer)
    if mod.draw_inventory then
        func(self, dt, t, input_service, layer)
    end
end)

mod:hook(CLASS.InventoryBackgroundView, "draw", function(func, self, dt, t, input_service, layer)
    if mod.draw_inventory then
        func(self, dt, t, input_service, layer)
    end
end)

mod:hook(CLASS.InventoryCosmeticsView, "draw", function(func, self, dt, t, input_service, layer)
    if mod.draw_inventory then
        func(self, dt, t, input_service, layer)
    end
end)