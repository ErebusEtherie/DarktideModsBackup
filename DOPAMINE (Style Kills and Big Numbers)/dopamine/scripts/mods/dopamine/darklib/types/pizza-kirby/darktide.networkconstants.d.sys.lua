---@meta
---@class NetworkConstants
NetworkConstants = {}
NetworkConstants.weapon_input_queue_hierarchy_position = {
    element_type_info = {

        bits = "5",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "32",
    },

    max_size = "4",
    ---@type boolean
    interpolated = false,

    element = "204",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_queue_produced_by_hierarchy = {
    element_type_info = {

        type = "bool",
        ---@type boolean
        optional = false,
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "40",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_queue_raw_input = {
    element_type_info = {

        bits = "5",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "32",
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "204",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_queue_action_input = {
    element_type_info = {

        bits = "5",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "32",
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "204",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_sequence_element_start_t = {
    element_type_info = {

        bits = "9",

        min = "-255",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "256",
    },

    max_size = "32",
    ---@type boolean
    interpolated = false,

    element = "121",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_sequence_current_element_index = {
    element_type_info = {

        bits = "2",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "4",
    },

    max_size = "32",
    ---@type boolean
    interpolated = false,

    element = "198",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_input_sequence_is_running = {
    element_type_info = {

        type = "bool",
        ---@type boolean
        optional = false,
    },

    max_size = "32",
    ---@type boolean
    interpolated = false,

    element = "40",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.weapon_charge_level = {

    bits = "11",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.00049975584261119",

    type = "float",

    max = "2.0469999313354",
}

NetworkConstants.max_projectile_locomotion_snapshot_id = "16"

NetworkConstants.max_game_mode_state_id = "8"

NetworkConstants.short_time_index = "367"
NetworkConstants.anim_variable_float = {

    bits = "9",

    min = "-12.800000190735",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.025000000372529",

    type = "float",

    max = "12.800000190735",
}

NetworkConstants.max_anim_variable = "32"
NetworkConstants.action_combo_count = {

    bits = "3",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "7",
}
NetworkConstants.move_speed = {

    bits = "10",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.0390625",

    type = "float",

    max = "80",
}
NetworkConstants.fixed_frame_offset_end_t_4bit = {

    bits = "4",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "15",
}

NetworkConstants.max_minion_anim_event = "512"
NetworkConstants.toughness = {

    bits = "14",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "16383",
}
NetworkConstants.health_large = {

    bits = "17",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "131071",
}
NetworkConstants.health_small = {

    bits = "12",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "4095",
}

NetworkConstants.max_consecutive_dodges = "15"

NetworkConstants.invalid_level_unit_id = "0"
NetworkConstants.level_unit_id = {

    bits = "16",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "65535",
}
NetworkConstants.story_speed = {

    bits = "12",

    min = "-2",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.00048816204071045",

    type = "float",

    max = "1.9990234375",
}

NetworkConstants.max_position = "511.9990234375"

NetworkConstants.min_position = "-512"
NetworkConstants.health_medium = {

    bits = "14",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "16383",
}
NetworkConstants.flow_state_id = {

    bits = "8",

    min = "1",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "256",
}
NetworkConstants.mission_objective_max_increment = {

    bits = "12",

    min = "-1",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "4094",
}

NetworkConstants.particle_index_max = "128"

NetworkConstants.particle_index_min = "1"
NetworkConstants.clips_in_use = {
    element_type_info = {

        type = "bool",
        ---@type boolean
        optional = false,
    },

    max_size = "2",
    ---@type boolean
    interpolated = false,

    element = "40",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}

NetworkConstants.max_prd_state = "254"
NetworkConstants.ammunition_clip_array = {
    element_type_info = {

        bits = "9",

        min = "0",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "511",
    },

    max_size = "2",
    ---@type boolean
    interpolated = false,

    element = "25",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.fixed_frame_offset_end_t_7bit = {

    bits = "7",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "127",
}
NetworkConstants.fixed_frame_offset_start_t_9bit = {

    bits = "9",

    min = "-511",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "0",
}
NetworkConstants.fixed_frame_offset_start_t_7bit = {

    bits = "7",

    min = "-127",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "0",
}
NetworkConstants.fixed_frame_offset_start_t_5bit = {

    bits = "5",

    min = "-31",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "0",
}
NetworkConstants.fixed_frame_offset_small = {

    bits = "9",

    min = "-255",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "256",
}
NetworkConstants.fixed_frame_offset = {

    bits = "12",

    min = "-495",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "3600",
}
---@param arg0 unknown
---@param arg1 unknown
---@return any
function NetworkConstants.check_network_lookup_boundaries(arg0, arg1) end

NetworkConstants.max_template_effect_buffer_index = "64"
NetworkConstants.ammunition_large = {

    bits = "12",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "4095",
}
NetworkConstants.story_time = {

    bits = "20",

    min = "-3600",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.0034332275390625",

    type = "float",

    max = "3600",
}

NetworkConstants.max_player_anim_event = "512"
NetworkConstants.fixed_frame_offset_end_t_9bit = {

    bits = "9",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "511",
}

NetworkConstants.max_hit_zone_actor_index = "63"
NetworkConstants.fixed_frame_offset_start_t_6bit = {

    bits = "6",

    min = "-63",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "0",
}

NetworkConstants.invalid_game_object_id = "-1"

NetworkConstants.max_nav_tag_layer_id = "2147483647"

NetworkConstants.max_time_offset = "2"

NetworkConstants.max_fixed_frame_time = "2147483647"

NetworkConstants.invalid_player_anim_time = "15.984375"
NetworkConstants.fixed_frame_offset_end_t_6bit = {

    bits = "6",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "63",
}

NetworkConstants.invalid_player_anim = "-1"

NetworkConstants.max_mover_frames = "31"

NetworkConstants.invalid_player_anim_state = "511"

NetworkConstants.max_movement_settings = "31.75"
NetworkConstants.action_time_scale = {

    bits = "8",

    min = "0.10000000149012",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0.004980469122529",

    type = "float",

    max = "2.6500000953674",
}

NetworkConstants.invalid_hit_zone_actor_index = "0"
NetworkConstants.game_object_id = {

    bits = "16",

    min = "-1",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "65534",
}

NetworkConstants.liquid_real_index_array_max_size = "32"

NetworkConstants.invalid_level_name_hash = "0"

NetworkConstants.action_input_hierarchy_position_max_size = "4"
NetworkConstants.ammunition_small = {

    bits = "9",

    min = "0",
    ---@type boolean
    interpolated = false,
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "int",

    max = "511",
}
NetworkConstants.ability_input_queue_hierarchy_position = {
    element_type_info = {

        bits = "2",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "4",
    },

    max_size = "2",
    ---@type boolean
    interpolated = false,

    element = "198",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_queue_raw_input = {
    element_type_info = {

        bits = "5",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "32",
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "204",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_queue_action_input = {
    element_type_info = {

        bits = "2",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "4",
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "198",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_sequence_element_start_t = {
    element_type_info = {

        bits = "9",

        min = "-255",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "256",
    },

    max_size = "4",
    ---@type boolean
    interpolated = false,

    element = "121",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_queue_produced_by_hierarchy = {
    element_type_info = {

        type = "bool",
        ---@type boolean
        optional = false,
    },

    max_size = "8",
    ---@type boolean
    interpolated = false,

    element = "40",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_sequence_current_element_index = {
    element_type_info = {

        bits = "2",

        min = "1",
        ---@type boolean
        interpolated = false,
        ---@type boolean
        optional = false,

        tolerance = "0",

        type = "int",

        max = "4",
    },

    max_size = "4",
    ---@type boolean
    interpolated = false,

    element = "198",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
NetworkConstants.ability_input_sequence_is_running = {
    element_type_info = {

        type = "bool",
        ---@type boolean
        optional = false,
    },

    max_size = "4",
    ---@type boolean
    interpolated = false,

    element = "40",
    ---@type boolean
    optional = false,

    tolerance = "0",

    type = "array",

    bits = "0",
}
