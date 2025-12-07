local mod = get_mod("simplecolorselector")

local UISettings = require("scripts/settings/ui/ui_settings")

local in_gameplay_state = false

-- Basic color presets table (built from Color.list)
local color_presets = {}
for _, name in ipairs(Color.list or {}) do
    local c = Color[name](255, true) -- {a,r,g,b}
    color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end

do -- sort alphabetically by name
    table.sort(color_presets, function(a,b) return a.name < b.name end)
end

local function preset_options()
    local opts = {}
    for i, p in ipairs(color_presets) do
        opts[#opts+1] = { text = p.name, value = p.id }
    end
    return opts
end

-- Utility to fetch saved RGB for a given slot (1-4) or bot
local function get_slot_rgb(slot)
    local prefix = string.format("slot%d_", slot)
    local r = mod:get(prefix .. "r") or 255
    local g = mod:get(prefix .. "g") or 255
    local b = mod:get(prefix .. "b") or 255
    return {255, r, g, b}
end

local function get_bot_rgb()
    local r = mod:get("bot_r") or 128
    local g = mod:get("bot_g") or 128
    local b = mod:get("bot_b") or 128
    return {255, r, g, b}
end

-- ColorAllocator: full player-to-slot reassignment (matching ColorSelection)
local ColorAllocator = {
    cfg_colors = {},
    bot_color = nil,
    slot_to_index = {},
    index_taken = {},
    player_to_slot_mapping = {},  -- Maps player unique_id to remapped slot (1-4)
    account_id_to_player_id = {},  -- Maps account_id to unique_id for lookups
    bot_player_ids = {},  -- Set of unique_ids that are bots
}

function ColorAllocator:reset()
    self.slot_to_index = {}
    self.index_taken = { false, false, false, false }
    self.player_to_slot_mapping = {}
    self.account_id_to_player_id = {}
    self.bot_player_ids = {}
end

local function color_for_slot(slot)
    if not slot or slot < 1 then
        return 1
    end
    return slot
end

mod._local_player_account_id = nil

local function update_local_player_id()
    local pm = Managers and Managers.player
    if pm then
        local local_player = pm:local_player_safe(1)
        if local_player then
            local success, account_id = pcall(function() return local_player:account_id() end)
            if success and account_id and account_id ~= "" then
                mod._local_player_account_id = account_id
                return true
            end
        end
    end
    return false
end

-- my_slot: in-game slot id for local player; all_slots: array of all active slot ids
function ColorAllocator:setup(my_slot, all_slots)
    -- cache configured RGBs per index (1-4)
    self.cfg_colors = {
        get_slot_rgb(1),
        get_slot_rgb(2),
        get_slot_rgb(3),
        get_slot_rgb(4),
    }
    self.bot_color = get_bot_rgb()

    if mod:get("enable_debug_mode") then
        mod:info(string.format("[SimpleColorSelector] ColorAllocator:setup - my_slot=%s, all_slots=%s", 
            tostring(my_slot), table.concat(all_slots or {}, ",")))
    end

    -- Build active slots set
    local active_slots = {}
    if my_slot and my_slot >= 1 then
        active_slots[my_slot] = true
    end
    if all_slots then
        for i = 1, #all_slots do
            local slot = all_slots[i]
            if slot and slot >= 1 then
                active_slots[slot] = true
            end
        end
    end

    -- Remove mappings for slots that are no longer active
    local slots_to_remove = {}
    for slot, idx in pairs(self.slot_to_index) do
        if not active_slots[slot] then
            slots_to_remove[#slots_to_remove + 1] = slot
        end
    end
    for i = 1, #slots_to_remove do
        local slot = slots_to_remove[i]
        local idx = self.slot_to_index[slot]
        self.slot_to_index[slot] = nil
        if idx then
            self.index_taken[idx] = false
        end
        if mod:get("enable_debug_mode") then
            mod:info(string.format("[SimpleColorSelector] Removed inactive slot %d (was index %d)", slot, idx or 0))
        end
    end

    -- Rebuild index_taken from current mappings
    self.index_taken = { false, false, false, false }
    for slot, idx in pairs(self.slot_to_index) do
        if idx >= 1 and idx <= 4 then
            self.index_taken[idx] = true
        end
    end

    -- Force local player to index 1 (may reassign if needed)
    if my_slot and my_slot >= 1 then
        if self.slot_to_index[my_slot] and self.slot_to_index[my_slot] ~= 1 then
            local old_idx = self.slot_to_index[my_slot]
            self.index_taken[old_idx] = false
            if mod:get("enable_debug_mode") then
                mod:info(string.format("[SimpleColorSelector] Moving local player from index %d to index 1", old_idx))
            end
        end
        self.slot_to_index[my_slot] = 1
        self.index_taken[1] = true
        if mod:get("enable_debug_mode") then
            mod:info(string.format("[SimpleColorSelector] Assigned local player slot %d -> color index 1", my_slot))
        end
    end

    -- Assign remaining active slots to available indices
    if all_slots then
        for i = 1, #all_slots do
            local slot = all_slots[i]
            if slot ~= my_slot and slot and slot >= 1 then
                if not self.slot_to_index[slot] then
                    -- Find first available index
                    for idx = 1, 4 do
                        if not self.index_taken[idx] then
                            self.slot_to_index[slot] = idx
                            self.index_taken[idx] = true
                            if mod:get("enable_debug_mode") then
                                mod:info(string.format("[SimpleColorSelector] Assigned slot %d -> color index %d", slot, idx))
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    if mod:get("enable_debug_mode") then
        local mapping = {}
        for slot, idx in pairs(self.slot_to_index) do
            mapping[#mapping+1] = string.format("slot%d->idx%d", slot, idx)
        end
        mod:info(string.format("[SimpleColorSelector] Final mapping: %s", table.concat(mapping, ", ")))
    end
end

function ColorAllocator:color_for(game_slot, account_id)
    game_slot = color_for_slot(game_slot)
    
    if not account_id or account_id == "" then
        if mod:get("enable_debug_mode") then
            mod:info(string.format("[SimpleColorSelector] Returning bot color for game slot %d (no account_id)", game_slot or 0))
        end
        return self.bot_color or self.cfg_colors[1]
    end
    
    if not mod._local_player_account_id then
        update_local_player_id()
    end
    
    local is_local_player = false
    if mod._local_player_account_id and mod._local_player_account_id == account_id then
        is_local_player = true
    else
        local pm = Managers and Managers.player
        if pm then
            local local_player = pm:local_player_safe(1)
            if local_player then
                local success, lp_account_id = pcall(function() return local_player:account_id() end)
                if success and lp_account_id and lp_account_id == account_id then
                    is_local_player = true
                    mod._local_player_account_id = lp_account_id
                end
            end
        end
    end
    
    if is_local_player then
        return {
            255,
            mod:get("slot1_r") or 226,
            mod:get("slot1_g") or 210,
            mod:get("slot1_b") or 117,
        }
    end
    
    if account_id and self.account_id_to_player_id[account_id] then
        local player_id = self.account_id_to_player_id[account_id]
        
        if self.bot_player_ids[player_id] then
            return self.bot_color or self.cfg_colors[1]
        end
        
        if self.player_to_slot_mapping[player_id] then
            game_slot = self.player_to_slot_mapping[player_id]
        end
    end
    
    local idx = self.slot_to_index[game_slot]
    if idx then
        if idx == 1 and not is_local_player then
            for i = 2, 4 do
                if not self.index_taken[i] then
                    self.slot_to_index[game_slot] = i
                    self.index_taken[i] = true
                    return self.cfg_colors[i]
                end
            end
            return self.cfg_colors[2]
        end
        return self.cfg_colors[idx]
    end
    
    local start_idx = is_local_player and 1 or 2
    for i = start_idx, 4 do
        if not self.index_taken[i] then
            self.slot_to_index[game_slot] = i
            self.index_taken[i] = true
            return self.cfg_colors[i]
        end
    end
    
    local fallback = is_local_player and 1 or (((game_slot - 1) % 3) + 2)
    return self.cfg_colors[fallback]
end

-- Queue system to prevent race conditions and duplicate assignments
local apply_slot_colors_internal
local color_assignment_queue = {}
local is_processing_queue = false

local function process_next_in_queue()
    if is_processing_queue or #color_assignment_queue == 0 then
        return
    end
    
    is_processing_queue = true
    local queue_size = #color_assignment_queue
    local debug_mode = mod:get("enable_debug_mode")
    
    if queue_size > 1 then
        local msg = string.format("[SimpleColorSelector] Processing queue with %d operations (RACE CONDITION PREVENTED!)", queue_size)
        mod:info(msg)
        if debug_mode then
            mod:echo(msg)
        end
    end

    local operation_count = 0
    while #color_assignment_queue > 0 do
        local operation = table.remove(color_assignment_queue, 1)
        operation_count = operation_count + 1
        
        if debug_mode then
            local msg = string.format("[SimpleColorSelector] Executing queued operation %d/%d", operation_count, queue_size)
            mod:info(msg)
        end

        operation()
    end

    is_processing_queue = false
end

local function queue_color_assignment()
    local queue_position = #color_assignment_queue + 1
    local debug_mode = mod:get("enable_debug_mode")
    
    if debug_mode then
        local msg = string.format("[SimpleColorSelector] Queueing color assignment (position %d)", queue_position)
        mod:info(msg)
    end
    
    table.insert(color_assignment_queue, function() apply_slot_colors_internal() end)
    process_next_in_queue()
end

-- Helper to get player by slot
local function get_player_by_slot(slot)
    local pm = Managers and Managers.player
    if not pm then return nil end
    local human_players = pm:human_players()
    if not human_players then return nil end
    
    for _, player in pairs(human_players) do
        local success, player_slot = pcall(function() return player:slot() end)
        if success and player_slot == slot then
            return player
        end
    end
    return nil
end

-- Internal function that does the actual work (full player reassignment)
apply_slot_colors_internal = function()
    if not UISettings then return end
    
    -- Skip if in hub
    if Managers.mechanism and Managers.mechanism:mechanism_name() == "hub" then
        return
    end
    
    if not UISettings.player_slot_colors then
        UISettings.player_slot_colors = {}
    end

    local pm = Managers and Managers.player
    if not pm then
        return
    end

    local debug_mode = mod:get("enable_debug_mode")
    
    -- Build player list and reassign slots
    local player_to_slot = ColorAllocator.player_to_slot_mapping or {}
    local used_slots = {false, false, false, false}
    local player_slots = {}
    local current_players = {}
    local local_player_id = nil
    local human_players = pm:human_players()
    local lp = pm:local_player_safe(1)
    
    if human_players then
        for unique_id, player in pairs(human_players) do
            if player then
                local human_success, is_human = pcall(function() return player:is_human_controlled() end)
                local bot_success, is_bot = pcall(function() return player:is_bot() end)
                local account_success, account_id_check = pcall(function() return player:account_id() end)
                
                -- Skip bots
                if not (human_success and is_human) then
                    goto skip_player
                end
                if bot_success and is_bot then
                    goto skip_player
                end
                if not (account_success and account_id_check and account_id_check ~= "") then
                    goto skip_player
                end
                
                local success, slot = pcall(function() return player:slot() end)
                if success and slot and slot >= 1 then
                    table.insert(player_slots, {unique_id = unique_id, slot = slot, player = player})
                    current_players[unique_id] = true
                    
                    if lp and player == lp then
                        local_player_id = unique_id
                    end
                end
                
                ::skip_player::
            end
        end
    end

    if #player_slots == 0 then
        if debug_mode then
            mod:info("[SimpleColorSelector] No players with valid slots found, skipping color application")
        end
        return
    end
    
    local local_player_has_slot = false
    if local_player_id then
        for _, data in ipairs(player_slots) do
            if data.unique_id == local_player_id then
                local_player_has_slot = true
                break
            end
        end
    end
    
    if not local_player_has_slot then
        if debug_mode then
            mod:info("[SimpleColorSelector] Local player slot not ready, skipping color application")
        end
        return
    end

    -- Remove players who left
    for player_id in pairs(player_to_slot) do
        if not current_players[player_id] then
            local old_slot = player_to_slot[player_id]
            player_to_slot[player_id] = nil
            
            if old_slot >= 1 and old_slot <= 4 then
                used_slots[old_slot] = false
            end
            
            if debug_mode then
                mod:info(string.format("[SimpleColorSelector] Removed player %s (left game)", 
                    tostring(player_id):sub(1, 8)))
            end
        end
    end

    -- Reset used_slots and rebuild from current assignments, checking for duplicates
    used_slots = {false, false, false, false}
    local slot_to_players = {}  -- Track which players are using each slot to detect duplicates
    for i = 1, 4 do
        slot_to_players[i] = {}
    end
    
    for player_id, slot in pairs(player_to_slot) do
        if player_id ~= local_player_id and slot >= 1 and slot <= 4 then
            table.insert(slot_to_players[slot], player_id)
            if #slot_to_players[slot] == 1 then
                used_slots[slot] = true
            else
                -- Duplicate detected - clear this slot assignment so it gets reassigned
                if debug_mode then
                    mod:info(string.format("[SimpleColorSelector] Duplicate detected: slot %d has %d players, clearing assignments", 
                        slot, #slot_to_players[slot]))
                end
                for _, pid in ipairs(slot_to_players[slot]) do
                    player_to_slot[pid] = nil
                end
                used_slots[slot] = false
            end
        end
    end

    -- Force local player to slot 1
    if local_player_id then
        player_to_slot[local_player_id] = 1
        used_slots[1] = true
        if debug_mode then
            mod:info(string.format("[SimpleColorSelector] Local player %s -> slot 1", 
                tostring(local_player_id):sub(1, 8)))
        end
    end

    -- Build account_id mapping and assign/reassign players
    local account_id_to_player_id = {}
    ColorAllocator.bot_player_ids = {}
    for _, data in ipairs(player_slots) do
        local unique_id = data.unique_id
        local player = data.player
        local slot = data.slot
        
        local bot_success, is_bot = pcall(function() return player:is_bot() end)
        if bot_success and is_bot then
            ColorAllocator.bot_player_ids[unique_id] = true
        end
        
        local acct_success, account_id = pcall(function() return player:account_id() end)
        if acct_success and account_id then
            account_id_to_player_id[account_id] = unique_id
        end
        
        if unique_id == local_player_id then
            goto continue
        end
        
        -- Assign or reassign players to available slots
        if not player_to_slot[unique_id] then
            local assigned = false
            for i = 2, 4 do  -- Start from 2, slot 1 is for local player
                if not used_slots[i] then
                    player_to_slot[unique_id] = i
                    used_slots[i] = true
                    if debug_mode then
                        mod:info(string.format("[SimpleColorSelector] Player %s: game slot %d → remapped slot %d", 
                            tostring(unique_id):sub(1, 8), slot, i))
                    end
                    assigned = true
                    break
                end
            end
            
            if not assigned then
                -- All slots taken, use hash-based fallback like ColorSelection
                local hash_source = account_id or unique_id
                local hash = 0
                for i = 1, #hash_source do
                    hash = hash + string.byte(hash_source, i)
                end
                local reassigned_slot = (hash % 3) + 2  -- Maps to 2, 3, or 4
                player_to_slot[unique_id] = reassigned_slot
                if debug_mode then
                    mod:info(string.format("[SimpleColorSelector] Player %s: all slots taken, using hash fallback → slot %d", 
                        tostring(unique_id):sub(1, 8), reassigned_slot))
                end
            end
        end
        
        ::continue::
    end

    -- Store mappings
    ColorAllocator.player_to_slot_mapping = player_to_slot
    ColorAllocator.account_id_to_player_id = account_id_to_player_id

    -- Debug: show final assignments
    if debug_mode then
        mod:info("[SimpleColorSelector] === Final slot assignments ===")
        for player_id, remapped_slot in pairs(player_to_slot) do
            mod:info(string.format("[SimpleColorSelector]   Player %s → slot %d", 
                tostring(player_id):sub(1, 8), remapped_slot))
        end
    end

    -- Build all_slots array from remapped slots
    local my_slot = local_player_id and player_to_slot[local_player_id] or 1
    local all_slots = {}
    for _, remapped_slot in pairs(player_to_slot) do
        if remapped_slot ~= my_slot then
            local found = false
            for i = 1, #all_slots do
                if all_slots[i] == remapped_slot then
                    found = true
                    break
                end
            end
            if not found then
                all_slots[#all_slots + 1] = remapped_slot
            end
        end
    end

    ColorAllocator:setup(my_slot, all_slots)

    -- Use metatable for dynamic color lookup
    local color_metatable = {
        __index = function(_, k)
            if type(k) ~= "number" or k < 1 then return nil end
            
            local account_id = nil
            local player = get_player_by_slot(k)
            if player then
                local success, result = pcall(function() return player:account_id() end)
                if success then
                    account_id = result
                end
            end
            return ColorAllocator:color_for(k, account_id)
        end,
    }

    UISettings.player_slot_colors = setmetatable({}, color_metatable)
    UISettings._colors_revision = (UISettings._colors_revision or 0) + 1
    
    if debug_mode then
        mod:info("[SimpleColorSelector] Applied slot colors with full reassignment, revision=" .. tostring(UISettings._colors_revision))
    end
end

-- Public wrapper that queues the assignment
local function apply_slot_colors()
    queue_color_assignment()
end

-- Track last known player count to detect new players
local last_player_count = 0
local last_player_check_time = 0
local PLAYER_CHECK_INTERVAL = 1.0

local function check_for_new_players()
    if not in_gameplay_state then
        return
    end
    
    local current_time = os.clock()
    if current_time - last_player_check_time < PLAYER_CHECK_INTERVAL then
        return
    end
    last_player_check_time = current_time
    
    local pm = Managers and Managers.player
    if not pm then
        return
    end
    
    local human_players = pm:human_players()
    if not human_players then
        return
    end
    
    local current_count = 0
    for unique_id, player in pairs(human_players) do
        if player then
            local human_success, is_human = pcall(function() return player:is_human_controlled() end)
            local bot_success, is_bot = pcall(function() return player:is_bot() end)
            local account_success, account_id = pcall(function() return player:account_id() end)
            
            if (human_success and is_human) and not (bot_success and is_bot) and (account_success and account_id and account_id ~= "") then
                current_count = current_count + 1
            end
        end
    end
    
    if current_count ~= last_player_count then
        if mod:get("enable_debug_mode") then
            mod:info(string.format("[SimpleColorSelector] Player count changed: %d -> %d, reapplying colors", 
                last_player_count, current_count))
        end
        last_player_count = current_count
        apply_slot_colors()
    end
end

local function on_player_removed(player)
    if not player then
        return
    end
    
    local success, account_id = pcall(function() return player:account_id() end)
    if success and account_id then
        if ColorAllocator.account_id_to_player_id and ColorAllocator.account_id_to_player_id[account_id] then
            local unique_id = ColorAllocator.account_id_to_player_id[account_id]
            if ColorAllocator.player_to_slot_mapping then
                ColorAllocator.player_to_slot_mapping[unique_id] = nil
            end
            ColorAllocator.account_id_to_player_id[account_id] = nil
        end
    end
    
    if in_gameplay_state then
        if mod:get("enable_debug_mode") then
            mod:info("[SimpleColorSelector] Player removed, reapplying colors")
        end
        mod:pcall(function()
            apply_slot_colors()
        end)
    end
end

-- DMF lifecycle hooks
mod.on_all_mods_loaded = function()
    if mod:get("enable_debug_mode") then
        mod:info("[SimpleColorSelector] on_all_mods_loaded called")
    end
    
    update_local_player_id()
    ColorAllocator:reset()
    
    mod:hook_safe("HumanGameplay", "on_player_removed", function(self, player)
        on_player_removed(player)
    end)
    
    mod:hook_require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler", function(H)
        if not H.__scs_hooked then
            H.__scs_hooked = true
            mod:hook_safe(H, "update", function(self)
                check_for_new_players()
            end)
        end
    end)
end

mod.on_enabled = function()
    update_local_player_id()
    if mod:get("enable_debug_mode") then
        mod:info("[SimpleColorSelector] on_enabled called, in_gameplay_state=" .. tostring(in_gameplay_state))
    end
    if in_gameplay_state then
        apply_slot_colors()
    end
end

-- Hook mission entry
mod.on_game_state_changed = function(status, state_name)
    if mod:get("enable_debug_mode") then
        mod:info(string.format("[SimpleColorSelector] on_game_state_changed: status=%s, state=%s", status, state_name))
    end
    
    update_local_player_id()
    
    if status == "enter" and state_name == "StateGameplay" then
        in_gameplay_state = true
        last_player_count = 0
        last_player_check_time = 0
        apply_slot_colors()
    elseif status == "exit" and state_name == "StateGameplay" then
        in_gameplay_state = false
        last_player_count = 0
    end
end

function mod.on_setting_changed(id)
    if mod:get("enable_debug_mode") then
        mod:info(string.format("[SimpleColorSelector] Setting changed: %s", id))
    end
    
    -- Sync preset dropdown -> sliders
    if id:match("_preset$") then
        if id == "bot_preset" then
            -- Bot preset
            local preset_id = mod:get(id)
            for _, p in ipairs(color_presets) do
                if p.id == preset_id then
                    mod:set("bot_r", p.r)
                    mod:set("bot_g", p.g)
                    mod:set("bot_b", p.b)
                    if mod:get("enable_debug_mode") then
                        mod:info(string.format("[SimpleColorSelector] Bot preset changed to '%s' (R:%d G:%d B:%d)", 
                            preset_id, p.r, p.g, p.b))
                    end
                    break
                end
            end
        else
            -- Slot preset
            local slot = tonumber(id:match("slot(%d+)_preset"))
            local preset_id = mod:get(id)
            for _, p in ipairs(color_presets) do
                if p.id == preset_id then
                    mod:set(string.format("slot%d_r", slot), p.r)
                    mod:set(string.format("slot%d_g", slot), p.g)
                    mod:set(string.format("slot%d_b", slot), p.b)
                    if mod:get("enable_debug_mode") then
                        mod:info(string.format("[SimpleColorSelector] Preset changed for slot %d to '%s' (R:%d G:%d B:%d)", 
                            slot, preset_id, p.r, p.g, p.b))
                    end
                    break
                end
            end
        end
    end
    
    if in_gameplay_state then
        apply_slot_colors()
    end
end
