---@meta

---@class HealthExtension
---@field _health number
---@field _unit Unit
---@field _is_unkillable boolean
---@field _last_hit_was_critical boolean
---@field _was_hit_by_critical_hit_this_render_frame boolean
---@field _damage number
---@field _hit_mass number
---@field _is_dead boolean
HealthExtension = {}

HealthExtension.init = function(self, extension_init_context, unit, extension_init_data, game_object_data) end
HealthExtension.game_object_initialized = function(self, session, object_id) end
HealthExtension.pre_update = function(self, unit, dt, t) end
HealthExtension.is_alive = function(self) end
HealthExtension.is_unkillable = function(self) end
HealthExtension.is_invulnerable = function(self) end
HealthExtension.current_health = function(self) end
HealthExtension.current_health_percent = function(self) end
HealthExtension.damage_taken = function(self) end
HealthExtension.has_taken_damage_over_percentage = function(self, optional_target_percentage) end
HealthExtension.permanent_damage_taken = function(self) end
HealthExtension.permanent_damage_taken_percent = function(self) end
HealthExtension.total_damage_taken = function(self) end
HealthExtension.max_health = function(self) end
HealthExtension.add_heal = function(self, heal_amount, heal_type) end
HealthExtension.last_damaging_unit = function(self) end
HealthExtension.last_hit_zone_name = function(self) end
HealthExtension.last_hit_was_critical = function(self) end
HealthExtension.last_hit_world_position = function(self) end
HealthExtension.was_hit_by_critical_hit_this_render_frame = function(self) end
HealthExtension.health_depleted = function(self) end
HealthExtension.set_unkillable = function(self, should_be_unkillable) end
HealthExtension.set_invulnerable = function(self, should_be_invulnerable) end
HealthExtension.kill = function(self) end
HealthExtension.num_wounds = function(self) end
HealthExtension.max_wounds = function(self) end
HealthExtension.damaging_players = function(self) end
HealthExtension.hit_mass = function(self) end
HealthExtension.set_hit_mass = function(self, hit_mass) end
