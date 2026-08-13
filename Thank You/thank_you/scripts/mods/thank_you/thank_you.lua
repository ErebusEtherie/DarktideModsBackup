local mod = get_mod("thank_you")

local ChatManagerConstants = require("scripts/foundation/managers/chat/chat_manager_constants")
local InteractionSettings = require("scripts/settings/interaction/interaction_settings")
local NetworkLookup = require("scripts/network_lookup/network_lookup")
local Vo = require("scripts/utilities/vo")
local VoQueryConstants = require("scripts/settings/dialogue/vo_query_constants")

local BUILD = 9

-- The wheel posts its chat line to this channel. table.enum maps each name to
-- itself, so this is the string "MISSION" - builds 1-6 compared against a
-- guessed lowercase "mission", never matched, and silently posted nothing ever.
local MISSION_CHANNEL_TAG = ChatManagerConstants.ChannelTag.MISSION

local COM_WHEEL_CONCEPT = VoQueryConstants.concepts.on_demand_com_wheel
local TRIGGER_IDS = VoQueryConstants.trigger_ids
local INTERACTION_SUCCESS = InteractionSettings.results.success

-- What the dialogue system calls the wheel's thank-you rule. Rule names for wheel
-- lines are the VoQueryConstants.trigger_ids *keys*: rule_overrides.lua lists
-- "com_wheel_vo_for_the_emperor" verbatim in its rules_to_override table.
local THANKS_RULE = "com_wheel_vo_thank_you"
local ON_DEMAND_CATEGORY = "player_on_demand_vo"

-- How long after helping someone their wheel line still reads as thanking you.
local ASSIST_MEMORY = 20

-- THE ENGINE'S OWN ANTI-SPAM RULE, from dialogues/generated/on_demand_vo.lua.
-- Every comm wheel rule carries a criterion of the form
--     {"user_memory", "time_since_com_wheel_vo_<key>", OP.TIMEDIFF, OP.GT, 5}
-- and sets that same memory in its on_done. Request a line while its key is
-- under 5s old and the tag query simply produces nothing - no error, no sound,
-- the request just evaporates.
--
-- The keys are NOT one-per-line. Note especially that com_thank_you shares
-- "over_here" with location_over_here: saying "Over Here" when you go down
-- blocks "Thanks" for the next five seconds, which is exactly why being revived
-- quickly produced silence. Builds 1-6 fired straight into that window.
-- CRITICAL: the rule stamps its memory in on_done, i.e. when the line FINISHES
-- speaking, not when it starts. Build 7 stamped at request time and still lost
-- roughly half its thank-yous, because a 1-2s "Over Here" clip pushed the real
-- deadline that much later - and clip length varies per random variant, which is
-- why identical-looking 5.35s gaps succeeded or failed at random. We now watch
-- our own line actually finish (see speaking_* below) and stamp from there.
local WHEEL_VO_COOLDOWN = 5.0
local WHEEL_VO_MARGIN = 0.6

-- Rule name (what the dialogue system reports when a line plays) -> the memory
-- key that rule stamps. Straight from dialogues/generated/on_demand_vo.lua.
local RULE_MEMORY_KEY = {
    com_wheel_vo_enemy_over_here    = "enemy_over_here",
    com_wheel_vo_follow_you         = "follow_you",
    com_wheel_vo_for_the_emperor    = "for_the_emperor",
    com_wheel_vo_location_attention = "over_here",
    com_wheel_vo_location_ping      = "lets_go_this_way",
    com_wheel_vo_my_pleasure_a      = "my_pleasure",
    com_wheel_vo_need_ammo          = "need_ammo",
    com_wheel_vo_need_health        = "need_health",
    com_wheel_vo_need_that          = "need_health",
    com_wheel_vo_no                 = "no",
    com_wheel_vo_take_this_a        = "take_this",
    com_wheel_vo_thank_you          = "over_here",
    com_wheel_vo_thank_you_delayed  = "over_here",
    com_wheel_vo_yes                = "yes",
}

-- The wheel line we are currently hearing ourselves say, awaiting its on_done.
local speaking_memory_key = nil
local speaking_since = nil
local speaking_confirmed = false

-- CONFIRM-OR-RETRY. There are several ways the dialogue system can bin a request
-- without a word of complaint, and predicting all of them has failed repeatedly:
--   * the 5s shared user_memory gate (above)
--   * DialogueSystem._can_query_play: player_on_demand_vo has interrupt_self
--     unset, so ANY line our character is already speaking - including ordinary
--     vanilla barks in other categories, which this log never sees - drops it
--   * plain network latency between our request and the server evaluating it
-- So rather than model every rule perfectly, watch for our own line coming back
-- and simply ask again if it never arrives. This is self-correcting: it does not
-- need to know WHY a request was refused.
local VO_RULE_NAME = {
    location_enemy_there  = "com_wheel_vo_enemy_over_here",
    answer_following      = "com_wheel_vo_follow_you",
    com_cheer             = "com_wheel_vo_for_the_emperor",
    location_over_here    = "com_wheel_vo_location_attention",
    location_this_way     = "com_wheel_vo_location_ping",
    com_my_pleasure       = "com_wheel_vo_my_pleasure_a",
    com_need_ammo         = "com_wheel_vo_need_ammo",
    com_need_health       = "com_wheel_vo_need_health",
    answer_need           = "com_wheel_vo_need_that",
    answer_no             = "com_wheel_vo_no",
    com_take_this         = "com_wheel_vo_take_this_a",
    com_thank_you         = "com_wheel_vo_thank_you",
    com_thank_you_delayed = "com_wheel_vo_thank_you_delayed",
    answer_yes            = "com_wheel_vo_yes",
}

local CONFIRM_TIMEOUT = 1.5
local MAX_ATTEMPTS = 4
local RETRY_DELAY = 0.5

-- The request we have sent and not yet heard come back.
local awaiting = nil

local VO_MEMORY_KEY = {
    location_enemy_there  = "enemy_over_here",
    answer_following      = "follow_you",
    com_cheer             = "for_the_emperor",
    location_over_here    = "over_here",
    location_this_way     = "lets_go_this_way",
    com_my_pleasure       = "my_pleasure",
    com_need_ammo         = "need_ammo",
    com_need_health       = "need_health",
    answer_need           = "need_health",
    answer_no             = "no",
    com_take_this         = "take_this",
    com_thank_you         = "over_here",
    com_thank_you_delayed = "over_here",
    answer_yes            = "yes",
}

-- When we last drove each memory key, so a queued callout can wait for its
-- window instead of being swallowed.
local wheel_memory_set_at = {}

-- A callout held this long has outlived the moment it was reacting to.
local PENDING_MAX_AGE = 12.0

-- Setting value -> the vanilla comm wheel VO it maps to. These keys are what get
-- written into saved settings, so they must stay stable across versions.
-- thank_you_delayed has its own trigger_id ("com_thank_you_delayed") and a 0.7s
-- delay_vo built into its dialogue rule, so it clears the get-up grunt on its own -
-- ideal default for revived/rescued/ledge_saved.
local LINES = {
    thank_you         = TRIGGER_IDS.com_wheel_vo_thank_you,
    thank_you_delayed = "com_thank_you_delayed",
    my_pleasure       = TRIGGER_IDS.com_wheel_vo_my_pleasure,
    for_the_emperor   = TRIGGER_IDS.com_wheel_vo_for_the_emperor,
    yes               = TRIGGER_IDS.com_wheel_vo_yes,
    no                = TRIGGER_IDS.com_wheel_vo_no,
    need_health       = TRIGGER_IDS.com_wheel_vo_need_health,
    need_ammo         = TRIGGER_IDS.com_wheel_vo_need_ammo,
    need_that         = TRIGGER_IDS.com_wheel_vo_need_that,
    take_this         = TRIGGER_IDS.com_wheel_vo_take_this,
    following         = TRIGGER_IDS.com_wheel_vo_follow_you,
    over_here         = TRIGGER_IDS.com_wheel_vo_over_here,
    this_way          = TRIGGER_IDS.com_wheel_vo_lets_go_this_way,
    enemy_there       = TRIGGER_IDS.com_wheel_vo_enemy_over_here,
}

-- Only these three carry a chat string on the real wheel. The rest are VO-only
-- there too, so we stay out of chat for them rather than inventing text.
local CHAT_TEXT = {
    thank_you   = "loc_communication_wheel_thanks",
    need_health = "loc_communication_wheel_need_health",
    need_ammo   = "loc_communication_wheel_need_ammo",
}

-- Per-trigger head start, added to the user's global delay. Gratitude waits out
-- the get-up grunt so the two don't talk over each other; calls for help go fast.
local BASE_DELAY = {
    revived       = 0.6,
    rescued       = 0.6,
    ledge_saved   = 0.5,
    assisted_ally = 0.3,
    thanked       = 0.7,
    went_down     = 0.3,
    disabled      = 0.5,
    low_health    = 0.0,
    out_of_ammo   = 0.1,
}

-- Leaving one of these for the listed state means somebody got you out of it.
-- The target state matters: ledge_hanging -> ledge_hanging_pull_up is a rescue,
-- ledge_hanging -> ledge_hanging_falling is you dropping to your death.
local RECOVERY = {
    knocked_down   = { trigger = "revived",     to = { walking = true } },
    -- Polling at frame rate can skip straight past the brief pull_up state, so
    -- walking counts too. Falling and dead are deliberately absent: those are you
    -- losing your grip, not somebody saving you.
    ledge_hanging  = { trigger = "ledge_saved", to = { ledge_hanging_pull_up = true, walking = true } },
    netted         = { trigger = "rescued",     to = { walking = true } },
    hogtied        = { trigger = "rescued",     to = { walking = true } },
    pounced        = { trigger = "rescued",     to = { walking = true } },
    mutant_charged = { trigger = "rescued",     to = { walking = true } },
    consumed       = { trigger = "rescued",     to = { walking = true } },
    warp_grabbed   = { trigger = "rescued",     to = { walking = true } },
    grabbed        = { trigger = "rescued",     to = { walking = true } },
}

-- Entering one of these is worth shouting about.
local ENTRY = {
    knocked_down   = "went_down",
    ledge_hanging  = "disabled",
    netted         = "disabled",
    hogtied        = "disabled",
    pounced        = "disabled",
    mutant_charged = "disabled",
    consumed       = "disabled",
    warp_grabbed   = "disabled",
    grabbed        = "disabled",
}

local clock = 0
local pending = {}
local last_queue_at = {}
local last_fire_time = -math.huge
local last_state = nil
local watched_unit = nil
local health_was_low = false
local assisted = {}

-- ---------------------------------------------------------------------------
-- File log. DMF's own error output is configurable and commonly off, which is
-- how build 2 shipped with every hook dead and not one visible symptom. This
-- writes what the mod actually did to
--   %APPDATA%/Fatshark/Darktide/thank_you_log.txt
-- one short line per event (never per frame), fresh file each session.
-- ---------------------------------------------------------------------------
local log_path
do
    local ok, appdata = pcall(function()
        local mods = rawget(_G, "Mods")
        local os_lib = (mods and mods.lua and mods.lua.os) or rawget(_G, "_os") or os

        return os_lib and os_lib.getenv and os_lib.getenv("APPDATA") or nil
    end)

    if ok and type(appdata) == "string" and appdata ~= "" then
        log_path = appdata:gsub("\\", "/"):gsub("/+$", "") .. "/Fatshark/Darktide/thank_you_log.txt"
    end
end

local log_started = false

-- Decisions, fires and errors ALWAYS log: three live sessions were lost to
-- having no record of what the mod did. The file_log setting gates only the
-- chatty per-state-change lines (see flog_state), never these.
local function flog(fmt, ...)
    if not log_path then
        return
    end

    local line = string.format("[%9.2f] ", clock) .. string.format(fmt, ...)

    pcall(function()
        local mods = rawget(_G, "Mods")
        local io_lib = (mods and mods.lua and mods.lua.io) or rawget(_G, "_io") or io
        local file = io_lib.open(log_path, log_started and "a" or "w")

        if file then
            log_started = true

            file:write(line .. "\n")
            file:close()
        end
    end)
end

-- Every locomotion change (walk/sprint/dodge/slide) hits this, so it is the one
-- category worth muting once the mod is behaving.
local function flog_state(fmt, ...)
    local ok, setting = pcall(mod.get, mod, "file_log")

    if ok and setting == false then
        return
    end

    flog(fmt, ...)
end

local function local_player()
    local player_manager = Managers.player

    if not player_manager then
        return nil
    end

    if player_manager.local_player_safe then
        return player_manager:local_player_safe(1)
    end

    local connection_manager = Managers.connection

    if not connection_manager or not connection_manager:is_initialized() then
        return nil
    end

    -- boot-safe: the check above is what local_player_safe does internally
    return player_manager:local_player(1)
end

local function local_player_unit()
    local player = local_player()
    local unit = player and player.player_unit

    if not unit or not ALIVE[unit] then
        return nil
    end

    return unit
end

local function is_local_player_unit(unit)
    local player = local_player()

    return player ~= nil and player.player_unit == unit
end

-- Read the character state off the unit's own networked component rather than
-- hooking the state machine. Hooking CharacterStateMachine._change_state looked
-- right and silently never fired; this is what the shipped mods do and it needs
-- nothing resolved by name.
local function current_state_name(unit)
    local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")

    if not unit_data or not unit_data.read_component then
        return nil
    end

    local character_state = unit_data:read_component("character_state")

    return character_state and character_state.state_name or nil
end

local function clear_pending(reason)
    if #pending > 0 then
        flog("pending cleared (%d dropped): %s", #pending, reason)
    end

    for i = #pending, 1, -1 do
        pending[i] = nil
    end
end

local function reset(reason)
    clear_pending(reason or "reset")

    last_queue_at = {}
    last_fire_time = -math.huge
    last_state = nil
    watched_unit = nil
    health_was_low = false
    assisted = {}
    wheel_memory_set_at = {}
    speaking_memory_key = nil
    speaking_since = nil
    speaking_confirmed = false
    awaiting = nil
end

-- Earliest time this line's dialogue rule will accept a request, per the engine's
-- own user_memory criterion. Returns nil when it is clear to speak now.
local function blocked_until(vo_id)
    local key = VO_MEMORY_KEY[vo_id]
    local set_at = key and wheel_memory_set_at[key]

    if not set_at then
        return nil
    end

    local ready_at = set_at + WHEEL_VO_COOLDOWN + WHEEL_VO_MARGIN

    if clock >= ready_at then
        return nil
    end

    return ready_at, key
end

-- The RPC encodes trigger_id through a fixed lookup table; a value missing from
-- it makes trigger_networked_dialogue_event bail before sending anything at all.
-- Check the LIVE table rather than trusting the source dump, which is a build or
-- two behind and has already disagreed with the running game once.
local function trigger_id_is_sendable(vo_id)
    local extension_manager = Managers.state and Managers.state.extension

    if not extension_manager then
        return true
    end

    local ok, dialogue_system = pcall(extension_manager.system, extension_manager, "dialogue_system")

    if not ok or not dialogue_system then
        return true
    end

    local contexts = dialogue_system.dialogueLookupContexts
    local trigger_ids = contexts and contexts.trigger_id

    if not trigger_ids then
        return true
    end

    return trigger_ids[vo_id] ~= nil
end

-- Posts the same localized string the communication wheel posts, to the same
-- channel, via the same manager call. Only the lines the wheel itself puts in
-- chat are listed in CHAT_TEXT; the rest are voice-only on the real wheel too.
local function send_chat(line_key)
    local text = CHAT_TEXT[line_key]

    if not text then
        flog("chat: '%s' has no chat line on the real wheel either, voice only", tostring(line_key))

        return
    end

    local chat_manager = Managers.chat

    if not chat_manager then
        flog("chat: DROPPED, no chat manager")

        return
    end

    local channels = chat_manager:connected_chat_channels()

    if not channels then
        flog("chat: DROPPED, not connected to any channel")

        return
    end

    local seen = {}

    for channel_handle, channel in pairs(channels) do
        if channel.tag == MISSION_CHANNEL_TAG then
            chat_manager:send_loc_channel_message(channel_handle, text, nil)
            flog("chat: posted '%s' to the mission channel", text)

            return
        end

        seen[#seen + 1] = tostring(channel.tag)
    end

    flog("chat: DROPPED, no channel tagged %s (connected: %s)",
        tostring(MISSION_CHANNEL_TAG), table.concat(seen, ", "))
end

local function fire(trigger_id, attempts, queued_at)
    local unit = local_player_unit()

    if not unit then
        flog("fire %s: DROPPED, no player unit", trigger_id)

        return
    end

    local line_key = mod:get(trigger_id .. "_line")
    local vo_id = line_key and LINES[line_key]

    if not vo_id then
        flog("fire %s: DROPPED, no line mapped for '%s'", trigger_id, tostring(line_key))

        return
    end

    if not trigger_id_is_sendable(vo_id) then
        flog("fire %s: DROPPED, the game cannot network trigger_id '%s' (line '%s' " ..
            "is not in dialogueLookupContexts.trigger_id, so the request would be " ..
            "discarded before sending) - pick a different line for this trigger",
            trigger_id, vo_id, line_key)

        return
    end

    -- Arm the confirmation watch BEFORE asking, never after: the line can come
    -- back on the very same frame, and if there were nothing to match it against
    -- we would count a success as a miss and say the whole thing twice.
    --
    -- Deliberately NOT stamping the cooldown memory here. The engine stamps in
    -- on_done, and only if the line actually played - stamping on a request that
    -- gets refused would make us sit out a cooldown the game never started, and
    -- block our own retry. The stamp happens when we hear it (see below).
    local attempt = attempts or 1

    awaiting = {
        trigger = trigger_id,
        rule = VO_RULE_NAME[vo_id],
        fired_at = clock,
        attempts = attempt,
        queued_at = queued_at or clock,
    }

    flog("fire %s -> '%s' (attempt %d, state %s)",
        trigger_id, line_key, attempt, tostring(last_state))

    local ok, err = pcall(Vo.on_demand_vo_event, unit, COM_WHEEL_CONCEPT, vo_id)

    if not ok then
        awaiting = nil

        flog("fire %s: VO CALL FAILED: %s", trigger_id, tostring(err))
        mod:error("could not play '%s' for '%s': %s", tostring(line_key), trigger_id, tostring(err))

        return
    end

    if mod:get("send_chat") then
        pcall(send_chat, line_key)
    end

    if mod:get("debug_echo") then
        mod:echo(string.format("[Thank You] %s -> %s", trigger_id, tostring(line_key)))
    end
end

local function queue(trigger_id)
    if not mod:get(trigger_id .. "_enabled") then
        flog("queue %s: skipped, trigger disabled", trigger_id)

        return
    end

    local line_key = mod:get(trigger_id .. "_line")

    if not line_key or line_key == "off" then
        flog("queue %s: skipped, line is off", trigger_id)

        return
    end

    -- Cooldown is per trigger: a repeat of the SAME callout is suppressed, but
    -- one callout never blocks a different one. Claimed at queue time so a burst
    -- of identical events can't stack while they sit in the delay queue.
    local cooldown = mod:get("cooldown") or 8
    local last = last_queue_at[trigger_id]

    if last and clock - last < cooldown then
        flog("queue %s: skipped, on cooldown for %.1fs more", trigger_id, cooldown - (clock - last))

        return
    end

    last_queue_at[trigger_id] = clock

    local delay = (BASE_DELAY[trigger_id] or 0) + (mod:get("delay") or 1.0)

    -- Everyone in the squad running this mod hears the same thanks at the same
    -- instant, so stagger the reply rather than answering in chorus.
    if trigger_id == "thanked" then
        delay = delay + math.random() * 0.8
    end

    pending[#pending + 1] = {
        trigger = trigger_id,
        at = clock + delay,
        queued_at = clock,
    }

    flog("queue %s: firing in %.1fs as '%s'", trigger_id, delay, line_key)
end

local function update_health_watch(unit)
    if not mod:get("low_health_enabled") then
        health_was_low = false

        return
    end

    -- Downed and disabled players read as near-zero health; that is what the
    -- went_down and disabled triggers are for.
    if last_state and (ENTRY[last_state] or last_state == "dead") then
        return
    end

    local health_extension = ScriptUnit.has_extension(unit, "health_system")

    if not health_extension then
        return
    end

    local threshold = (mod:get("low_health_threshold") or 35) / 100
    local percent = health_extension:current_health_percent()

    if not health_was_low and percent <= threshold then
        health_was_low = true

        queue("low_health")
    elseif health_was_low and percent > threshold + 0.1 then
        -- Re-arm only after healing clear of the line, so hovering on the
        -- threshold doesn't retrigger every time a poxwalker clips you.
        health_was_low = false
    end
end

local function update_state_watch(unit)
    local state = current_state_name(unit)

    if not state or state == last_state then
        return
    end

    local previous = last_state

    last_state = state

    -- First reading after a spawn is a baseline, not a transition.
    if not previous then
        flog_state("state baseline: %s", state)

        return
    end

    -- Transitions into or out of a disable are the ones a bug report hinges on,
    -- so they always log; only locomotion noise respects the setting.
    if ENTRY[state] or ENTRY[previous] or RECOVERY[previous] then
        flog("state %s -> %s", previous, state)
    else
        flog_state("state %s -> %s", previous, state)
    end

    if mod:get("debug_echo") then
        mod:echo(string.format("[Thank You] state %s -> %s", previous, state))
    end

    local entry_trigger = ENTRY[state]

    if entry_trigger then
        -- Getting grabbed cancels anything queued but unspoken; the situation
        -- it belonged to is over.
        clear_pending("entered " .. state)
        queue(entry_trigger)

        return
    end

    local recovery = RECOVERY[previous]

    if recovery and recovery.to[state] then
        -- You are saved, so an unspoken distress call is moot - and it must not
        -- stand in the thank-you's way.
        clear_pending("recovered to " .. state)
        queue(recovery.trigger)
    end
end

local function update_body(dt)
    local unit = local_player_unit()

    if not unit then
        if watched_unit then
            reset("player unit gone")
        end

        return
    end

    if unit ~= watched_unit then
        reset("new player unit")

        watched_unit = unit

        flog("watching new player unit")
    end

    clock = clock + dt

    update_state_watch(unit)

    -- The dialogue system SILENTLY drops a player_on_demand_vo query if our
    -- character is still playing another line (see DialogueSystem._can_query_play:
    -- the category has no interrupt_self, so currently_playing_unit == our unit
    -- means will_play = false, no error anywhere). Downed/grabbed/get-up screams
    -- and grunts are exactly such lines, and this mod's whole job is talking right
    -- after those moments - so a pending callout waits for actual silence instead
    -- of firing on a fixed timer into an active bark. This is THE fix for build 4
    -- firing every trigger and playing nothing.
    local dialogue_extension = ScriptUnit.has_extension(unit, "dialogue_system")
    local is_talking = dialogue_extension and dialogue_extension:is_currently_playing_dialogue()

    -- A request we never heard come back was refused for one of several silent
    -- reasons. Ask again rather than trying to divine which.
    if awaiting and clock - awaiting.fired_at > CONFIRM_TIMEOUT then
        local stale = awaiting

        awaiting = nil

        if stale.attempts >= MAX_ATTEMPTS then
            flog("give up on %s: %d attempts, never heard it play",
                stale.trigger, stale.attempts)
        elseif clock - stale.queued_at > PENDING_MAX_AGE then
            flog("give up on %s: the moment has passed (%.0fs since the event)",
                stale.trigger, clock - stale.queued_at)
        else
            flog("retry %s: attempt %d was never spoken, trying again",
                stale.trigger, stale.attempts)

            pending[#pending + 1] = {
                trigger = stale.trigger,
                at = clock + RETRY_DELAY,
                queued_at = stale.queued_at,
                attempts = stale.attempts + 1,
            }
        end
    end

    -- Mirror the rule's on_done. The engine starts the 5s clock when our line
    -- stops speaking, so wait for it to actually stop before starting ours.
    if speaking_memory_key then
        if is_talking then
            speaking_confirmed = true
        end

        local finished = speaking_confirmed and not is_talking
        local timed_out = clock - speaking_since > 6.0

        if finished or timed_out then
            wheel_memory_set_at[speaking_memory_key] = clock

            flog("wheel timer '%s' starts now, %.1fs after the line began%s",
                speaking_memory_key, clock - speaking_since,
                timed_out and " (timed out waiting for it to end)" or "")

            speaking_memory_key = nil
            speaking_since = nil
            speaking_confirmed = false
        end
    end

    for i = #pending, 1, -1 do
        local entry = pending[i]

        if clock >= entry.at then
            local line_key = mod:get(entry.trigger .. "_line")
            local vo_id = line_key and LINES[line_key]
            local ready_at, blocking_key = nil, nil

            if vo_id then
                ready_at, blocking_key = blocked_until(vo_id)
            end

            if clock - (entry.queued_at or clock) > PENDING_MAX_AGE then
                table.remove(pending, i)

                flog("drop %s: waited %.0fs for a chance to speak, the moment has passed",
                    entry.trigger, PENDING_MAX_AGE)
            elseif is_talking then
                -- Character is mid-bark; hold the line until it goes quiet. Not
                -- dropped: it stays queued and fires the moment we fall silent.
                entry.at = clock + 0.1
            elseif ready_at then
                -- The line's own dialogue rule will refuse until its wheel timer
                -- clears. Wait for the window instead of firing into a rejection.
                if not entry.held then
                    entry.held = true

                    flog("hold %s: '%s' needs %.1fs more on the shared '%s' wheel timer",
                        entry.trigger, line_key, ready_at - clock, tostring(blocking_key))
                end

                entry.at = ready_at
            elseif awaiting then
                -- One request in flight at a time; wait for it to confirm or
                -- time out before adding another voice line on top.
                entry.at = clock + 0.2
            else
                table.remove(pending, i)

                last_fire_time = clock

                fire(entry.trigger, entry.attempts, entry.queued_at)
            end
        end
    end

    update_health_watch(unit)

    -- Don't hold references to teammates we helped a while ago, or to units that
    -- have since been despawned.
    for assisted_unit, assisted_at in pairs(assisted) do
        if clock - assisted_at > ASSIST_MEMORY or not ALIVE[assisted_unit] then
            assisted[assisted_unit] = nil
        end
    end
end

-- An error anywhere in the update would otherwise vanish into DMF's optional
-- output and kill every trigger for the rest of the session. Catch it, log it
-- once, keep running.
local last_update_error = nil

mod.update = function(dt)
    local ok, err = pcall(update_body, dt)

    if not ok and err ~= last_update_error then
        last_update_error = err

        flog("UPDATE ERROR: %s", tostring(err))
        mod:error("update error: %s", tostring(err))
    end
end

mod.test_callout = function()
    local unit = local_player_unit()

    if not unit then
        mod:echo("[Thank You] no player unit - join a mission or the Mourningstar first.")

        return
    end

    local line_key = mod:get("test_line") or "thank_you"
    local vo_id = LINES[line_key]

    if not vo_id then
        mod:echo("[Thank You] test line is set to none.")

        return
    end

    local ok, err = pcall(Vo.on_demand_vo_event, unit, COM_WHEEL_CONCEPT, vo_id)

    if ok then
        flog("test key -> '%s'", line_key)
        mod:echo(string.format("[Thank You] test: %s", line_key))
    else
        flog("test key FAILED: %s", tostring(err))
        mod:error("test failed: %s", tostring(err))
    end
end

local function on_assist_stop(self, world, interactor_unit, unit_data_component, t, result)
    if result ~= INTERACTION_SUCCESS then
        return
    end

    if not is_local_player_unit(interactor_unit) then
        return
    end

    flog("assist interaction succeeded (%s)", tostring(self and self.__class_name or "?"))

    -- Remember who we helped even when the callout itself is off, so a thank-you
    -- coming back can still be matched to us.
    local target_unit = unit_data_component and unit_data_component.target_unit

    if target_unit then
        assisted[target_unit] = clock
    end

    queue("assisted_ally")
end

-- Hook by table reference out of _G.CLASS rather than by name. A name that fails
-- to resolve is silently deferred by DMF and may never bind, which is how the
-- first build shipped with every trigger dead and no error anywhere.
-- Used only for DialogueSystem here; the assist interactions use hook_require above.
local hook_report = {}

local function hook_class(class_name, method, handler)
    local class_table = rawget(_G, "CLASS")

    class_table = class_table and class_table[class_name] or rawget(_G, class_name)

    if type(class_table) ~= "table" then
        hook_report[#hook_report + 1] = string.format("%s.%s MISSING (class not found)", class_name, method)

        return false
    end

    if type(class_table[method]) ~= "function" then
        hook_report[#hook_report + 1] = string.format("%s.%s MISSING (no such method)", class_name, method)

        return false
    end

    mod:hook_safe(class_table, method, handler)
    hook_report[#hook_report + 1] = string.format("%s.%s ok", class_name, method)

    return true
end

mod.hook_report = function()
    for i = 1, #hook_report do
        mod:echo("[Thank You] " .. hook_report[i])
    end

    mod:echo(string.format("[Thank You] build %d; state polling active; current state: %s",
        BUILD, tostring(last_state or "none")))

    if log_path then
        mod:echo("[Thank You] log file: " .. log_path)
    end
end

-- The assist classes (Revive/Rescue/RemoveNet/PullUp) are only registered in CLASS
-- when scripts/settings/interaction/interactions.lua is required - which happens
-- lazily, AFTER mod init. Grabbing CLASS at file scope (build 4) therefore finds
-- nothing and every assist hook silently misses. hook_require patches the class
-- module table the instant it is required, before the settings file runs, so the
-- hook binds no matter when the game loads it. THIS is why "saving an ally" and
-- being "thanked" never fired.
mod:hook_require("scripts/extension_systems/interaction/interactions/revive_interaction", function(instance)
    hook_report[#hook_report + 1] = "ReviveInteraction.stop ok (hook_require)"
    flog("hook ReviveInteraction.stop ok (hook_require)")

    if mod.hook_safe then
        mod:hook_safe(instance, "stop", on_assist_stop)
    else
        mod:hook(instance, "stop", function(func, ...)
            on_assist_stop(...)

            return func(...)
        end)
    end
end)
mod:hook_require("scripts/extension_systems/interaction/interactions/rescue_interaction", function(instance)
    hook_report[#hook_report + 1] = "RescueInteraction.stop ok (hook_require)"
    flog("hook RescueInteraction.stop ok (hook_require)")

    if mod.hook_safe then
        mod:hook_safe(instance, "stop", on_assist_stop)
    else
        mod:hook(instance, "stop", function(func, ...)
            on_assist_stop(...)

            return func(...)
        end)
    end
end)
mod:hook_require("scripts/extension_systems/interaction/interactions/remove_net_interaction", function(instance)
    hook_report[#hook_report + 1] = "RemoveNetInteraction.stop ok (hook_require)"
    flog("hook RemoveNetInteraction.stop ok (hook_require)")

    if mod.hook_safe then
        mod:hook_safe(instance, "stop", on_assist_stop)
    else
        mod:hook(instance, "stop", function(func, ...)
            on_assist_stop(...)

            return func(...)
        end)
    end
end)
mod:hook_require("scripts/extension_systems/interaction/interactions/pull_up_interaction", function(instance)
    hook_report[#hook_report + 1] = "PullUpInteraction.stop ok (hook_require)"
    flog("hook PullUpInteraction.stop ok (hook_require)")

    if mod.hook_safe then
        mod:hook_safe(instance, "stop", on_assist_stop)
    else
        mod:hook(instance, "stop", function(func, ...)
            on_assist_stop(...)

            return func(...)
        end)
    end
end)

-- Every dialogue line played on this machine passes through here, teammates'
-- included, which is how we hear somebody thank us.
hook_class("DialogueSystem", "_play_dialogue_event_implementation", function(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index, dialogue_rule_index, optional_query)
    local rule_name = NetworkLookup.dialogue_names[dialogue_id]

    if not rule_name then
        return
    end

    local unit_spawner = Managers.state.unit_spawner

    if not unit_spawner then
        return
    end

    local speaker = unit_spawner:unit(go_id, is_level_unit, level_name_hash)

    if not speaker then
        return
    end

    -- Our own line arriving back from the server is the ONLY proof the request
    -- was accepted and actually spoken out loud. A "fire" line with no matching
    -- "SPOKEN" line means the dialogue system swallowed it - the request left
    -- fine and the tag query declined to produce a line.
    if is_local_player_unit(speaker) then
        local own = self._dialogue_templates and self._dialogue_templates[rule_name]

        if own and own.category == ON_DEMAND_CATEGORY then
            if awaiting and awaiting.rule == rule_name then
                flog("SPOKEN by us: '%s' - confirms %s%s", rule_name, awaiting.trigger,
                    awaiting.attempts > 1 and string.format(" (took %d attempts)", awaiting.attempts) or "")

                awaiting = nil
            else
                flog("SPOKEN by us: '%s'", rule_name)
            end

            -- Start watching for this line to finish; its rule stamps the shared
            -- memory only then, and that is the deadline everything else waits on.
            local key = RULE_MEMORY_KEY[rule_name]

            if key then
                speaking_memory_key = key
                speaking_since = clock
                speaking_confirmed = false
            end
        end

        return
    end

    local template = self._dialogue_templates and self._dialogue_templates[rule_name]

    if template and template.category == ON_DEMAND_CATEGORY then
        flog("heard wheel line '%s' from a teammate", rule_name)

        if mod:get("debug_echo") then
            mod:echo(string.format("[Thank You] heard wheel line '%s'", rule_name))
        end
    end

    if not mod:get("thanked_enabled") or rule_name ~= THANKS_RULE then
        return
    end

    if mod:get("thanked_scope") == "helped" then
        local assisted_at = assisted[speaker]

        if not assisted_at or clock - assisted_at > ASSIST_MEMORY then
            flog("thanks heard but not for us (no recent assist of that player)")

            return
        end

        -- One reply per rescue; a second thanks is not a second favour.
        assisted[speaker] = nil
    end

    queue("thanked")
end)

-- Fatshark calls this on any failed reload; an empty reserve is the case worth
-- announcing. Vo is a plain module table, so it is hooked by reference.
mod:hook_safe(Vo, "out_of_ammo_event", function(inventory_slot_component, visual_loadout_extension)
    local player = visual_loadout_extension and visual_loadout_extension._player

    if not player or player ~= local_player() then
        return
    end

    if not inventory_slot_component or inventory_slot_component.current_ammunition_reserve ~= 0 then
        return
    end

    queue("out_of_ammo")
end)

flog("thank_you build %d loaded", BUILD)

for i = 1, #hook_report do
    flog("hook %s", hook_report[i])
end
