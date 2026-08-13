---@meta

---@class HealthBar
---@field _dead boolean
---@field _health_bar_segment_widgets table
---@field _knocked_down boolean
---@field _hogtied boolean
---@field _health_max_wounds integer
---@field _previously_drawn_health_segments integer
---@field _health_fraction number
---@field _draw_health_segments boolean
---@field _max_health integer
---@field _health_ghost_fraction number
---@field _health_max_fraction number
---@field _player_slot integer
HealthBar = {}

---@param scenegraph string
---@return number
HealthBar.scenegraph_size = function(self,scenegraph) end

---@class HealthBarData
---@field is_my_player boolean
---@field unique_id string
---@field player Player
HealthBar._data = {}

---@class HealthBarPlayer
---@field _slot integer
---@field player_unit Unit
HealthBar._player = {}

---@class StateManagers
Managers.state = {}

---@class MissionObjectiveSystem : DarktideClass
Managers.mission_objective_system = {}

---@class GameModeManager : DarktideClass
---@field game_mode_name fun(): string
Managers.state.game_mode = {}

---@class MissionManager : DarktideClass
---@field _side_mission_name string
Managers.state.mission = {}

---@class WCPlayerState
---@field panel table
---@field corruption_taken_mult number
---@field max_health number
---@field grim_reserved number
---@field unique_id string
---@field data table
---@field player Player
---@field unit Unit

---@class WCState
---@field grimoires integer
---@field mission_has_grims boolean
---@field has_med_stimm boolean
---@field holding_med_stimm boolean
---@field mission_objective_system table
---@field show_self_grim_reserve boolean
---@field show_other_grim_reserve boolean
---@field bot_health integer
---@field reloading boolean
---@field players WCPlayerState[]
---@field my_player WCPlayerState

---@alias StateEvent

