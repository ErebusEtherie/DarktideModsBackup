---@meta

---@class GameSessionManager
GameSessionManager = {
    __class_name = "GameSessionManager",
    DELAYED_DISCONNECT_TIME = "1",
}

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.update(arg0, arg1) end

---@param arg0 unknown
---@return any
function GameSessionManager.joined_peers(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager._member_joined(arg0, arg1, arg2) end

---@param arg0 unknown
---@return any
function GameSessionManager.is_host(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager._client_joined(arg0, arg1, arg2) end

---@param arg0 unknown
---@param ... unknown
---@return any
function GameSessionManager.new(arg0, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.channel_to_peer(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.connected_to_client(arg0, arg1) end

---@param arg0 unknown
---@return any
function GameSessionManager.can_send_session_bound_rpcs(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.connected_to_host(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager._set_session_channel_on_player(arg0, arg1, arg2) end

---@param arg0 unknown
---@return any
function GameSessionManager.game_session(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.host(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.is_server(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager._session_joined(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager._session_left(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param ... unknown
---@return any
function GameSessionManager.send_rpc_clients_list(arg0, arg1, arg2, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.set_session_host(arg0, arg1) end

GameSessionManager.__interfaces = {}

---@param arg0 unknown
---@return any
function GameSessionManager.game_session_disconnect(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager.game_object_destroyed(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager.game_object_created(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.game_object_migrated_to_me(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.set_session_client(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.delayed_disconnects(arg0, arg1) end

---@param arg0 unknown
---@return any
function GameSessionManager.num_clients_in_session(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager._update_host(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager._update_client(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param ... unknown
---@return any
function GameSessionManager.send_rpc_client(arg0, arg1, arg2, ...) end

---@param arg0 unknown
---@return any
function GameSessionManager.num_clients(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.destroy(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@return any
function GameSessionManager._client_left(arg0, arg1, arg2, arg3, arg4) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager._update_delayed_disconnects(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function GameSessionManager._handle_host_event(arg0, arg1, arg2) end

---@param arg0 unknown
---@param arg1 unknown
---@param ... unknown
---@return any
function GameSessionManager.send_rpc_server(arg0, arg1, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param ... unknown
---@return any
function GameSessionManager.send_rpc_clients_except(arg0, arg1, arg2, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@param ... unknown
---@return any
function GameSessionManager.send_rpc_clients(arg0, arg1, ...) end

---@param arg0 unknown
---@return any
function GameSessionManager.currently_lowest_reliable_send_buffer_size(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.game_session_disconnected(arg0) end

---@param arg0 unknown
---@param ... unknown
---@return any
function GameSessionManager.delete(arg0, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.add_peer(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.remove_peer(arg0, arg1) end

---@param arg0 unknown
---@return any
function GameSessionManager.leave(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.init(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function GameSessionManager.peer_to_channel(arg0, arg1) end

---@param arg0 unknown
---@return any
function GameSessionManager.is_client(arg0) end

---@param arg0 unknown
---@return any
function GameSessionManager.disconnect(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@return any
function GameSessionManager._member_left(arg0, arg1, arg2, arg3, arg4) end
