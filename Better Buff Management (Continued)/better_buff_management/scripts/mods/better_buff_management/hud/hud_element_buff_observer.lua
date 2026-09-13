require('scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling')

local mod = get_mod('better_buff_management')

local VanillaDefinitions = require(
    'scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions'
)

local HudElementBuffObserver = class('HudElementBuffObserver', 'HudElementPlayerBuffs')

local function _resolve_recent_buff_name(buff_instance, buff_data)
    local buff_name = buff_data and buff_data.buff_name or nil

    if type(buff_name) ~= 'string' or buff_name == '' then
        local buff_source = buff_data and buff_data.buff_instance or buff_instance
        if buff_source ~= nil then
            local buff_template = nil
            if type(buff_source.template) == 'function' then
                buff_template = buff_source:template()
            end

            buff_name = buff_template and buff_template.name or nil

            if type(buff_name) ~= 'string' or buff_name == '' then
                buff_name = buff_source._template_name
            end

            if (type(buff_name) ~= 'string' or buff_name == '') and type(buff_source.template_name) == 'function' then
                buff_name = buff_source:template_name()
            end
        end
    end

    if type(buff_name) ~= 'string' or buff_name == '' then
        return nil
    end

    return buff_name
end

local function _record_visible_buff(buff_data)
    if buff_data == nil then
        return
    end

    local buff_name = _resolve_recent_buff_name(nil, buff_data)
    if buff_name then
        mod:record_recent_buff(buff_name)
        buff_data._bbm_recent_recorded = true
    end
end

function HudElementBuffObserver:init(parent, draw_layer, start_scale)
    HudElementBuffObserver.super.init(self, parent, draw_layer, start_scale, VanillaDefinitions)
end

function HudElementBuffObserver:event_player_buff_added(player, buff_instance)
    HudElementBuffObserver.super.event_player_buff_added(self, player, buff_instance)
end

function HudElementBuffObserver:event_player_buff_stack_added(player, buff_instance)
    HudElementBuffObserver.super.event_player_buff_stack_added(self, player, buff_instance)
end

function HudElementBuffObserver:_sync_current_active_buffs(buffs)
    HudElementBuffObserver.super._sync_current_active_buffs(self, buffs)
end

function HudElementBuffObserver:_update_buffs(t, ui_renderer)
    HudElementBuffObserver.super._update_buffs(self, t, ui_renderer)

    local active_buffs_data = self._active_buffs_data
    if not active_buffs_data then
        return
    end

    for i = 1, #active_buffs_data do
        local buff_data = active_buffs_data[i]

        if buff_data and buff_data.show then
            if not buff_data._bbm_recent_recorded then
                _record_visible_buff(buff_data)
            end
        elseif buff_data then
            buff_data._bbm_recent_recorded = nil
        end
    end
end

function HudElementBuffObserver:draw(dt, t, ui_renderer, render_settings, input_service)
end

return HudElementBuffObserver
