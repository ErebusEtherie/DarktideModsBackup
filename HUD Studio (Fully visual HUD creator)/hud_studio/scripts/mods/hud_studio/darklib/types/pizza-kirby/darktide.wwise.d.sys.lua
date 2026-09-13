---@meta

---@class Wwise
Wwise = {

    OUTPUT_DUMMY = "0",

    OUTPUT_MERGETOMAIN = "1",

    OUTPUT_MAIN = "2",

    PANNING_RULE_SPEAKERS = "0",

    PANNING_RULE_HEADPHONES = "1",

    WWISE_DURATION_ONE_SHOT = "0",

    WWISE_DURATION_INFINITE = "1",

    WWISE_DURATION_UNSUPPORTED = "2",

    WWISE_3D_SOUND = "0",

    WWISE_2D_SOUND = "1",

    WWISE_INVALID_SOUND = "2",

    WWISE_INVALID_UNIQUE_ID = "0",

    AK_SPEAKER_FRONT_LEFT = "1",

    AK_SPEAKER_FRONT_RIGHT = "2",

    AK_SPEAKER_FRONT_CENTER = "4",

    AK_SPEAKER_LOW_FREQUENCY = "8",

    AK_SPEAKER_BACK_LEFT = "16",

    AK_SPEAKER_BACK_RIGHT = "32",

    AK_SPEAKER_BACK_CENTER = "256",

    AK_SPEAKER_SIDE_LEFT = "512",

    AK_SPEAKER_SIDE_RIGHT = "1024",

    AK_SPEAKER_TOP = "2048",

    AK_SPEAKER_HEIGHT_FRONT_LEFT = "4096",

    AK_SPEAKER_HEIGHT_FRONT_CENTER = "8192",

    AK_SPEAKER_HEIGHT_FRONT_RIGHT = "16384",

    AK_SPEAKER_HEIGHT_BACK_LEFT = "32768",

    AK_SPEAKER_HEIGHT_BACK_CENTER = "65536",

    AK_SPEAKER_HEIGHT_BACK_RIGHT = "131072",

    AK_SPEAKER_SETUP_MONO = "4",

    AK_SPEAKER_SETUP_STEREO = "3",

    AK_SPEAKER_SETUP_5POINT1 = "1551",

    AK_SPEAKER_SETUP_7POINT1 = "1599",

    AK_SPEAKER_SETUP_AUTO = "-1",

    LISTENER_0 = "2048",

    LISTENER_1 = "2049",

    LISTENER_2 = "2050",

    LISTENER_3 = "2051",

    LISTENER_4 = "2052",

    LISTENER_5 = "2053",

    LISTENER_6 = "2054",

    LISTENER_7 = "2055",

    SHAPE_POINT = "0",

    SHAPE_SPHERE = "1",

    SHAPE_BOX = "2",

    POSITIONING_CLOSEST_TO_LISTENER = "0",

    POSITIONING_RANDOM_IN_SHAPE = "1",

    _name = "Wwise",

    POSITIONING_RANDOM_AROUND_LISTENER = "2",
}

---@param ... unknown
---@return any
function Wwise.wwise_world(...) end

---@param ... unknown
---@return any
function Wwise.set_language(...) end

---@param ... unknown
---@return any
function Wwise.load_bank(...) end

---@param ... unknown
---@return any
function Wwise.unload_bank(...) end

---@param ... unknown
---@return any
function Wwise.position_type(...) end

---@param ... unknown
---@return any
function Wwise.max_attenuation(...) end

---@param ... unknown
---@return any
function Wwise.duration_type(...) end

---@param ... unknown
---@return any
function Wwise.max_duration(...) end

---@param ... unknown
---@return any
function Wwise.min_duration(...) end

---@param ... unknown
---@return any
function Wwise.set_parameter(...) end

---@param ... unknown
---@return any
function Wwise.set_panning_rule(...) end

---@param ... unknown
---@return any
function Wwise.set_max_num_voices(...) end

---@param ... unknown
---@return any
function Wwise.set_volume_threshold(...) end

---@param ... unknown
---@return any
function Wwise.get_occlusion_enabled(...) end

---@param ... unknown
---@return any
function Wwise.get_timestamp(...) end

---@param ... unknown
---@return any
function Wwise.set_occlusion_enabled(...) end

---@param ... unknown
---@return any
function Wwise.set_bus_config(...) end

---@param ... unknown
---@return any
function Wwise.set_voip_sample_rate(...) end

---@param ... unknown
---@return any
function Wwise.set_actor_mixer_effect(...) end

---@param ... unknown
---@return any
function Wwise.set_rumble_enabled(...) end

---@param ... unknown
---@return any
function Wwise.has_event(...) end

---@param ... unknown
---@return any
function Wwise.set_state(...) end

---@param ... unknown
---@return any
function Wwise.get_device_list(...) end

---@param ... unknown
---@return any
function Wwise.set_active_device(...) end
