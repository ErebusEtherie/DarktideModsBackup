local mod = get_mod("improve-yourself")

local Manager = {}
Manager.adapters = {
    scores = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/scores_adapter"),
}

function Manager:available_sources()
    local available = {}
    for id, adapter in pairs(self.adapters) do
        if adapter:is_available() then available[id] = true end
    end
    return available
end

-- Resolve the active Scoreboard-backed collector selected in Mod Options.
function Manager:selected_adapter()
    local adapter = self.adapters.scores
    return adapter and adapter:is_available() and adapter or nil, "scores"
end

-- Return the normalized live match consumed by the Tactical Overlay.
function Manager:get_current_match()
    local adapter = self:selected_adapter()
    return adapter and adapter:get_current_match() or nil
end

return Manager
