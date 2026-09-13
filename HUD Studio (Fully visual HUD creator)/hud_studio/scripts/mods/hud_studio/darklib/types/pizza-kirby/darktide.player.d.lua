---@meta

---@class Player
Player = {}

---@return integer slot
function Player:slot() end
function Player:profile() end
---@return string id
function Player:account_id() end
---@return boolean human
function Player:is_human_controlled() end
function Player:character_id() end
function Player:telemetry_game_session() end
function Player:telemetry_current_instance() end
---@return string name
function Player:name() end
function Player:set_slot(slot) end
function Player:local_player_id() end
function Player:peer_id() end
function Player:channel_id() end
---@return string unique_id
function Player:unique_id() end
function Player:session_id() end
function Player:delete() end
function Player:set_wanted_spawn_point(spawnpoint) end
