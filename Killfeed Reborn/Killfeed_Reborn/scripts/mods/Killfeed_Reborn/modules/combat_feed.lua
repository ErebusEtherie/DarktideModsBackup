local combat_feed = {}

-- Feed Settings (runtime apply)
function combat_feed.apply_timing(feed, settings)
    if not feed then
        return
    end

    local fade_out = settings.fade_out or 1
    local visible_duration = settings.message_duration or 5

    feed._message_duration = visible_duration + fade_out

    local default_template = feed._notification_templates and feed._notification_templates.default
    if default_template then
        default_template.fade_out = fade_out
    end

    local notifications = feed._notifications
    if notifications then
        for i = 1, #notifications do
            notifications[i].fade_out = fade_out
        end
    end
end

function combat_feed.apply_message_limit(feed, settings)
    if not feed then
        return
    end

    feed._max_messages = settings.max_messages or 8
end

function combat_feed.apply_settings(feed, settings)
    combat_feed.apply_timing(feed, settings)
    combat_feed.apply_message_limit(feed, settings)
end

-- Feed (message dispatch)
function combat_feed.add_message(text, active_feed)
    if Managers.event then
        Managers.event:trigger("event_add_combat_feed_message", text)
    elseif active_feed and active_feed._add_combat_feed_message then
        active_feed:_add_combat_feed_message(text)
    end
end

return combat_feed
