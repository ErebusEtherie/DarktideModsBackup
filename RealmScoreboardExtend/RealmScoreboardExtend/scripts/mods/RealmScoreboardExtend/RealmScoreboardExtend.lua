local mod = get_mod("RealmScoreboardExtend")
local Model = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/roster")
local Bindings = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/bindings")
local Refresh = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/refresh")
local Text = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/text")
mod.text = Text
mod.version = "0.2.3-test"
mod.model = Model
mod.bindings = Bindings
local Loadouts = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/loadout_adapter")
mod.loadouts = Loadouts
mod.roster = Model.new()
local scoreboard, installed, last_owner
local row_adapter
local register_legacy_commands
local clock, revision = 0, 0
local tracking = false
local UIFonts = require("scripts/managers/ui/ui_fonts")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local root = "scoreboard/scripts/mods/scoreboard/scoreboard/"
local history_view_path = "scoreboard/scripts/mods/scoreboard/history/scoreboard_history_view"

function mod.trace(event, format, ...)
    if mod:get("debug_logging") == false then return end
    mod:info("[RSE:%s] %s", event, string.format(format, ...))
end

local function count_keys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function view_kind(ctx)
    return ctx.history and "history" or ctx.ending and "end" or "hud"
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
mod.copy = copy

local function capture()
    if Managers.player then
        local players = Managers.player:players()
        local report = Model.capture(mod.roster, players)
        local signature = table.concat({report.live, count_keys(mod.roster.entries), report.missing, report.collisions}, ":")
        if mod.roster._signature ~= signature then
            mod.roster._signature = signature
            mod.trace("capture", "live=%d retained=%d missing_keys=%d collisions=%d", report.live,
                count_keys(mod.roster.entries), report.missing, report.collisions)
            for _, player in pairs(players) do
                mod.trace("identity", "slot=%s:%s source=%s resolved=%s name=%s human=%s",
                    tostring(Model.value(player, "peer_id")), tostring(Model.value(player, "local_player_id")),
                    tostring(Model.key(player)), tostring(Model.key(player, mod.roster)),
                    tostring(Model.value(player, "name")), tostring(Model.value(player, "is_human_controlled")))
            end
        end
        if clock >= (mod.next_loadout_capture or 0) then
            Loadouts.capture(players)
            mod.next_loadout_capture = clock + 1
        end
    end
end
function mod.all_players(rows)
    return Model.list(mod.roster, rows or (scoreboard and scoreboard.registered_scoreboard_rows))
end

local function resolution(renderer)
    local lookup = RESOLUTION_LOOKUP or {}
    local w, h = lookup.res_w or lookup.width or 1920, lookup.res_h or lookup.height or 1080
    return w, h, renderer and renderer.scale or h / 1080
end

local function voting_space()
    local ui = Managers.ui
    local picker = ui and ui:view_instance("chaos_wastes_run_select_view")
    if not picker then return 0 end
    local _,h = resolution()
    -- CW's picker is a 420-unit right column with a 70-unit right margin.
    -- Include a gap and convert using that view's renderer, not our UI scale.
    return 560 * (picker._ui_renderer and picker._ui_renderer.scale or h / 1080)
end

local function input_stamp(owner, rows, renderer)
    local w,h,scale = resolution(renderer)
    local players = owner.is_history and owner.loaded_players or mod.all_players(rows)
    local list = {}
    for _, player in pairs(players or {}) do list[#list+1] = player end
    table.sort(list, function(a,b) return tostring(Model.key(a)) < tostring(Model.key(b)) end)
    local options = {w=w,h=h,scale=scale,revision=revision,loadouts=owner.is_history and 0 or Loadouts.revision,
        loadout_settings=Loadouts.settings_stamp(),voting_space=voting_space(),language=Text.language()}
    for _, key in ipairs({"generate_scores","zero_values","worst_values","scoreboard_panel_height"}) do
        options[key] = scoreboard:get(key)
    end
    return Refresh.stamp(rows,list,options,Model)
end

local function needs_refresh(owner, rows, renderer)
    if owner._sr_revision ~= revision then return true end
    if clock < (owner._sr_refresh or 0) then return false end
    owner._sr_refresh = clock + 0.5
    return owner._sr_input_stamp ~= input_stamp(owner,rows,renderer)
end

local function copied_rows(rows, history)
    -- Historical records belong to their saved mission, never to live aliases.
    return Model.project_rows(history and Model.new() or mod.roster, rows, copy)
end

function mod.prepare(owner, players, rows, history, ending, renderer)
    local all
    if history then
        -- Historical players must never be mixed with the current mission roster.
        all = {}
        for _, player in pairs(players or {}) do all[#all + 1] = player end
        local function rank(player)
            return Text.history_rank(Model.value(player, "name"))
        end
        table.sort(all, function(a, b)
            if rank(a) ~= rank(b) then return rank(a) < rank(b) end
            return tostring(Model.key(a)) < tostring(Model.key(b))
        end)
    else
        if tracking and not ending then capture() end
        all = mod.all_players(rows)
    end
    local limit = mod:get(history and "history_players" or ending and "end_players" or "max_players") or 8
    local page, index, pages = Model.page(all, limit, owner._sr_page or 1)
    owner._sr_page = index
    local w, h, scale = resolution(renderer)
    -- History is a detail page; the list stays alive underneath for Back.
    local reserve = ending and voting_space() or 0
    local layout = Model.layout(#page, limit, w-reserve, h, scale, mod:get("width_percent") or 100)
    local context = {all = all, players = page, page = index, pages = pages, layout = layout,
        owner = owner, history = history, ending = ending, center = -reserve / scale / 2,
        width = w, height = h, scale = scale, limit = limit}
    owner._sr_context = context
    owner._sr_revision = revision
    last_owner = owner
    local signature = table.concat({view_kind(context),#all,#page,index,pages,limit,w,h,scale,math.floor(layout.width),math.floor(layout.label)}, ":")
    if owner._sr_signature ~= signature then
        owner._sr_clipped_labels = {}
        mod.trace("layout", "%s all=%d visible=%d page=%d/%d limit=%d resolution=%dx%d scale=%.3f panel=%.1f label=%.1f column=%.1f supplied=%d tracking=%s",
            view_kind(context), #all, #page, index, pages, limit, w, h, scale, layout.width, layout.label, layout.column,
            count_keys(players), tostring(tracking))
        owner._sr_signature = signature
    end
    return context
end

function mod.mark_history_values(row, players)
    local validation = row.validation
    if row.name == "header" or not row.data or type(validation) ~= "table" then return end
    if not validation.is_best or not validation.is_worst then return end
    -- Compare the complete saved roster, including players on other pages.
    -- Only flags on the rendering copy change; never normalize saved scores.
    local comparison = {}
    for _, player in ipairs(players) do
        local key = Model.key(player)
        if key then
            row.data[key] = row.data[key] or {score = 0}
            comparison[key] = copy(row.data[key])
            comparison[key].score = tonumber(comparison[key].score) or 0
        end
    end
    for key in pairs(comparison) do
        row.data[key].is_best = validation.is_best(comparison, key)
        row.data[key].is_worst = validation.is_worst(comparison, key)
    end
end

function mod.blueprint(source, context)
    local layout = context.layout
    local template = copy(source)
    local original = template.pass_template
    local passes, texts, icons, backgrounds = {copy(original[1])}, {}, {}, {}
    passes[1].style.size[1] = layout.label - 30
    for i = 1, layout.columns do
        local x = layout.label + (i - 1) * layout.column
        local icon = copy(original[2])
        icon.value_id, icon.style_id = "icon_" .. i, "sr_icon_" .. i
        icon.style.offset[1] = x
        passes[#passes + 1] = icon
        local icon_index = #passes
        local text = copy(original[3])
        text.value_id, text.style_id = "text" .. i, nil
        text.style.offset[1], text.style.size[1] = x, layout.column
        passes[#passes + 1] = text
        texts[i], icons[tostring(#passes)] = #passes, icon_index
        if i % 2 == 1 then
            local bg = copy(original[4])
            bg.value_id = "bg" .. i
            bg.style.offset[1], bg.style.size[1] = x, layout.column
            passes[#passes + 1] = bg
            backgrounds[tostring(texts[i])] = #passes
        end
    end
    local background = copy(original[#original])
    background.style.size[1] = layout.width - 32
    passes[#passes + 1] = background
    template.pass_template, template.size = passes, {layout.width, template.size[2]}
    return template, texts, icons, backgrounds
end

function mod.fit_text(text, style, width, renderer)
    if not renderer or not style then return end
    text = tostring(text or "")
    local minimum = 12
    local function measured()
        -- UIRenderer.text_size accepts logical font size (as used by DMF's UI).
        -- Applying UIFonts.scaled_size here a second time inflated measurements
        -- at higher UI scales and prematurely ellipsized Chinese row labels.
        return UIRenderer.text_size(renderer, text, style.font_type,
            style.font_size, nil, UIFonts.get_font_options_by_style and UIFonts.get_font_options_by_style(style))
    end
    while style.font_size > minimum and measured() > width - 10 do style.font_size = style.font_size - 1 end
    return measured() > width - 10
end

local function page_key(setting, default, label)
    local keys = mod:get(setting) or {default}
    if #keys == 0 then return mod:localize("key_unbound") end
    local result = {}
    for _, key in ipairs(keys) do
        result[#result + 1] = key == default and mod:localize(label) or string.upper(key)
    end
    return table.concat(result, "+")
end
function mod.decorate(widget, text_map, header, ctx, renderer)
    if not widget then return end
    -- Refreshes replace rows; replaying the original fade would blink every tick.
    widget.alpha_multiplier = 1
    widget._sr_label_x = widget.style.style_id_1.offset[1]
    if header then
        widget.content.text = mod:localize("page_hint", ctx.page, ctx.pages,
            page_key("previous_page", "page up", "key_page_up"), page_key("next_page", "page down", "key_page_down"))
    end
    local percent = (mod:get("font_percent") or 100) / 100
    local function fit(key, style)
        if not style or not style.font_size then return end
        style.font_size = math.max(12, math.floor(style.font_size * percent))
        local width = style.size and style.size[1] or ctx.layout.column
        if mod.fit_text(widget.content[key], style, width, renderer) then
            if key == "text" and not header then
                local original = tostring(widget.content[key] or "")
                local clipped = ctx.owner._sr_clipped_labels or {}
                ctx.owner._sr_clipped_labels = clipped
                if not clipped[original] then
                    clipped[original] = true
                    mod.trace("text_clip", "%s label_width=%.1f font=%.1f text=%s", view_kind(ctx), width, style.font_size, original)
                end
            end
            -- Only ellipsize after reaching the minimum font size. Remove markup
            -- first so truncation cannot split a color tag or UTF-8 character.
            local text = tostring(widget.content[key] or ""):gsub("{#.-}", "")
            local chars = {}
            for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
            while #chars > 0 do
                chars[#chars] = nil
                text = table.concat(chars) .. "…"
                if not mod.fit_text(text, style, width, renderer) then break end
            end
            widget.content[key] = text
        end
    end
    fit("text", widget.style.style_id_1)
    for i, pass in ipairs(text_map) do fit("text" .. i, widget.style["style_id_" .. pass]) end
    if header then
        local filled, visible = 0, 0
        for i, pass in ipairs(text_map) do
            local text, style = widget.content["text" .. i], widget.style["style_id_" .. pass]
            if text and text ~= "" then filled = filled + 1 end
            if style and style.visible ~= false then visible = visible + 1 end
        end
        local signature = table.concat({ctx.page, #ctx.players, #text_map, filled, visible}, ":")
        if ctx.owner._sr_columns_signature ~= signature then
            ctx.owner._sr_columns_signature = signature
            mod.trace("columns", "%s page=%d players=%d passes=%d named=%d visible=%d", view_kind(ctx),
                ctx.page, #ctx.players, #text_map, filled, visible)
        end
    end
end

local function position(owner)
    local ctx = owner._sr_context
    if not ctx then return end
    local widget = owner._widgets_by_name and owner._widgets_by_name.scoreboard
    local graph = owner._ui_scenegraph
    if not widget or not graph or not graph.scoreboard then return end
    local layout = ctx.layout
    for i, delta in ipairs({-4, -24, -4, 0, 50}) do
        local style = widget.style["style_id_" .. i]
        if style and style.size then
            style.size[1] = layout.width + delta
            style.offset[1] = 0
            style.original_offset = nil
        end
    end
    widget.offset[1], widget.offset[2] = 0, 0
    graph.scoreboard.size[1] = layout.width
    graph.scoreboard.position[1] = ctx.center
    graph.scoreboard_rows.size[1] = layout.width
    graph.scoreboard_rows.position[1] = 0
    for _, row in ipairs(owner.row_widgets or {}) do
        row.offset[1] = 0
        row._sr_y = row._sr_y or row.offset[2]
        local factor = ctx.row_scale or 1
        row.offset[2] = (row._sr_y + (ctx.ending and 100 or 0)) * factor
        if factor < 1 then
            row._sr_dimensions = row._sr_dimensions or {}
            for key, style in pairs(row.style) do
                if type(style) == "table" then
                    local original = row._sr_dimensions[key]
                    if not original then
                        original = {font=style.font_size, height=style.size and style.size[2], y=style.offset and style.offset[2]}
                        row._sr_dimensions[key] = original
                    end
                    if original.font then style.font_size = original.font * factor end
                    if original.height then style.size[2] = original.height * factor end
                    if original.y then style.offset[2] = original.y * factor end
                end
            end
        end
        -- Base scoreboard bends bottom row labels to the right. On a dense
        -- eight-column panel that pushes the labels into the player columns.
        if row._sr_label_x then row.style.style_id_1.offset[1] = row._sr_label_x end
    end
    owner._update_scenegraph = true
end

local function remove_rows(owner)
    for _, widget in ipairs(owner.row_widgets or {}) do
        owner._widgets_by_name[widget.name] = nil
        owner:_unregister_widget_name(widget.name)
    end
    owner.row_widgets = {}
end

local function change_page(delta)
    if not installed then mod.trace("page", "ignored: not installed") return end
    local view = Managers.ui and Managers.ui:view_instance("scoreboard_view")
    local owner = view or last_owner
    if not owner or not owner._sr_context or (not view and not owner._active) then
        mod.trace("page", "ignored: view=%s owner=%s context=%s", tostring(view ~= nil), tostring(owner ~= nil), tostring(owner and owner._sr_context ~= nil))
        return
    end
    local ctx = owner._sr_context
    owner._sr_page = ((ctx.page - 1 + delta) % ctx.pages) + 1
    revision = revision + 1
    mod.trace("page", "%s delta=%d %d->%d pages=%d", view_kind(ctx), delta, ctx.page, owner._sr_page, ctx.pages)
end
function mod.next_page() change_page(1) end
function mod.previous_page() change_page(-1) end
function mod.on_setting_changed() revision = revision + 1 end

function mod.install_view(view, reason)
    if not row_adapter then return end
    local changes = 0
    local function bind(target, key, handler)
        if Bindings.wrap(target, key, handler) then changes = changes + 1 end
    end
    for _, key in ipairs({"create_row_widget", "update_row_values", "normalize_values"}) do
        local adapter = row_adapter[key]
        bind(scoreboard, key, function(func, self, ...)
            if not mod.context then return func(self, ...) end
            return adapter(self, ...)
        end)
    end
    bind(scoreboard, "get_rows_in_groups", function(func, self, rows)
        local sorted = func(self, rows)
        local ctx = mod.context
        if ctx then return Loadouts.append(sorted, ctx.all, ctx.history, false) end
        return sorted
    end)
    bind(scoreboard, "setup_row_widgets", function(func, self, rows, groups, widgets, by_name, players, history, ending, owner, callback, renderer)
        local ctx = mod.prepare(owner, players, rows, history, ending, renderer)
        local previous = mod.context
        mod.context = ctx
        local ok, sorted, height = pcall(func, self, copied_rows(rows, history), groups, widgets, by_name, ctx.players, history, ending, owner, callback, renderer)
        mod.context = previous
        if not ok then
            mod.trace("render_error", "%s: %s", view_kind(ctx), tostring(sorted))
            error(sorted)
        end
        owner._sr_input_stamp = input_stamp(owner,rows,renderer)
        position(owner)
        return sorted, height
    end)
    bind(scoreboard, "adjust_size", function(func, self, height, widget, graph, rows)
        local ctx = last_owner and last_owner._ui_scenegraph == graph and last_owner._sr_context
        if ctx then
            local available = math.min(ctx.layout.height, tonumber(scoreboard:get("scoreboard_panel_height")) or ctx.layout.height) - 75
            ctx.row_scale = math.min(1, math.max(1, available) / math.max(1, height))
            height = height * ctx.row_scale
        end
        local result = func(self, height, widget, graph, rows)
        if last_owner and last_owner._ui_scenegraph == graph then position(last_owner) end
        return result
    end)
    bind(view, "init", function(func, self, ...)
        local result = func(self, ...)
        if self.is_history then self._pass_input, self._pass_draw = false, false end
        return result
    end)
    bind(view, "update", function(func, self, ...)
        -- BaseView returns TWO values. Dropping pass_draw disables underlying
        -- views and their registered worlds, including the EndView background.
        local pass_input, pass_draw = func(self, ...)
        if needs_refresh(self, self.loaded_rows, self._ui_renderer) then
            self:setup_row_widgets()
            self._sr_refresh = clock + 0.5
        end
        position(self)
        local signature = tostring(pass_input) .. ":" .. tostring(pass_draw)
        if self._sr_pass_signature ~= signature then
            mod.trace("view_pass", "history=%s end=%s input=%s draw=%s",
                tostring(self.is_history), tostring(self.end_view), tostring(pass_input), tostring(pass_draw))
            self._sr_pass_signature = signature
        end
        return pass_input, pass_draw
    end)
    bind(view, "move_scoreboard", function(func, self, from, to, callback)
        if callback then callback() end
    end)
    bind(view, "on_enter", function(func, self, ...)
        if self.is_history then
            -- A detail page consumes its input. The same Esc must not reach
            -- the history list's Back callback and close both views.
            self._pass_input, self._pass_draw = false, false
        end
        mod.trace("view_enter", "history=%s end=%s loaded_players=%d live=%d retained=%d",
            tostring(self.is_history), tostring(self.end_view), count_keys(self.loaded_players),
            Managers.player and count_keys(Managers.player:players()) or 0, count_keys(mod.roster.entries))
        local result = func(self, ...)
        if self.is_history then
            self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
            self._input_legend_element:add_entry("sr_history_back", "back", nil, function()
                local ui = Managers.ui
                if not self._sr_returning and ui:view_instance("scoreboard_view") == self
                    and not ui:is_view_closing("scoreboard_view") then
                    self._sr_returning = true
                    mod.trace("history_back", "return_to_list=%s page=%d",
                        tostring(ui:view_instance("scoreboard_history_view") ~= nil), self._sr_page or 1)
                    -- Defer destruction until after this update; retain the
                    -- original list, selected entry and grid scroll position.
                    ui:close_view("scoreboard_view")
                end
            end, "left_alignment")
        end
        return result
    end)
    if changes > 0 then mod.trace("bind", "reason=%s changed=%d view=%s", reason or "unknown", changes, tostring(view)) end
end

function mod.install_history_view(view)
    -- The original list also presents on focus/hover. With a separate detail
    -- page that could reopen it immediately after Back. Open on activation.
    Bindings.wrap(view, "cb_on_category_pressed", function(func, self, ...)
        self._sr_open_detail = true
        local ok, result = pcall(func, self, ...)
        self._sr_open_detail = nil
        if not ok then error(result) end
        return result
    end)
    Bindings.wrap(view, "present_category_widgets", function(func, self, ...)
        if self._sr_open_detail then return func(self, ...) end
    end)
end

function mod.on_all_mods_loaded()
    local previous = get_mod("ScoreboardRoster")
    if previous and (not previous.is_enabled or previous:is_enabled()) then
        mod:echo("%s", mod:localize("error_previous_mod"))
        return
    end
    scoreboard = get_mod("scoreboard")
    if not scoreboard then mod:echo("%s", mod:localize("error_missing_scoreboard")) return end
    local legacy = get_mod("RealmsScoreboard8")
    if legacy and (not legacy.is_enabled or legacy:is_enabled()) then
        mod:echo("%s", mod:localize("error_legacy_mod"))
        return
    end
    if not scoreboard.create_row_widget or not scoreboard.setup_row_widgets then
        mod:echo("%s", mod:localize("error_scoreboard_api")) return
    end
    row_adapter = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/row_adapter")
    Loadouts.install()
    mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/history_adapter")
    mod:hook(scoreboard, "io_dofile", function(func, self, path, ...)
        local ctx = mod.context
        local resource = ctx and (path == root.."scoreboard_view_settings" or path == root.."scoreboard_view_definitions"
            or path == root.."scoreboard_view_blueprints")
        if resource and ctx.resources and ctx.resources[path] then return ctx.resources[path] end
        local result = func(self, path, ...)
        if path == root .. "scoreboard_view" then mod.install_view(result, "scoreboard.io_dofile") end
        if path == history_view_path then mod.install_history_view(result) end
        if path == root .. "scoreboard_view_settings" and mod.context then
            result = copy(result)
            local layout = mod.context.layout
            result.scoreboard_size[1] = layout.width
            result.scoreboard_column_width = layout.column
            result.scoreboard_column_header_width = layout.label
        end
        if resource then ctx.resources = ctx.resources or {}; ctx.resources[path] = result end
        return result
    end)
    -- Registered require paths are executed by DMF:io_dofile, not by the
    -- scoreboard mod object. Observe both routes, after assignments finish.
    mod:hook(get_mod("DMF"), "io_dofile", function(func, self, path, ...)
        local result = func(self, path, ...)
        if path == root .. "scoreboard_view" then mod.install_view(result, "DMF.io_dofile") end
        if path == history_view_path then mod.install_history_view(result) end
        return result
    end)
    mod:hook(scoreboard, "clear", function(func, self, ...)
        mod.trace("clear", "retained=%d tracking=%s", count_keys(mod.roster.entries), tostring(tracking))
        mod.roster = Model.new()
        Loadouts.clear()
        mod.next_loadout_capture = nil
        revision = revision + 1
        return func(self, ...)
    end)
    mod:hook(CLASS.HudElementTacticalOverlay, "update", function(func, self, dt, t, renderer, settings, input, ...)
        if self._active and needs_refresh(self, scoreboard.registered_scoreboard_rows, renderer) then
            remove_rows(self)
            scoreboard.hud_active = false
            self._sr_refresh = clock + 0.5
        end
        local result = func(self, dt, t, renderer, settings, input, ...)
        if self._active then position(self) end
        return result
    end)
    mod.install_view(CLASS.ScoreboardView, "startup")
    mod.install_history_view(CLASS.ScoreboardHistoryView)
    installed = true
    -- Commands are globally named in DMF. Wait until every mod is loaded so an
    -- accidentally co-enabled old version cannot collide with these aliases.
    if not previous then register_legacy_commands() end
    mod:info("RealmScoreboardExtend %s loaded", mod.version)
end

function mod.update(dt)
    clock = clock + dt
    if installed and clock >= (mod.next_capture or 0) then
        local mission = Managers.state and Managers.state.mission
        if tracking and mission then
            local data = mission:mission()
            if data and data.name ~= "hub_ship" and data.name ~= "prologue_hub" then capture() end
        end
        mod.next_capture = clock + 0.25
    end
end
function mod.on_game_state_changed(status, state)
    if state == "GameplayStateRun" or state == "StateGameplay" then
        mod.trace("state", "%s %s retained=%d", tostring(state), tostring(status), count_keys(mod.roster.entries))
    end
    if state == "GameplayStateRun" then
        tracking = status == "enter"
        if tracking and installed then capture() end
    elseif state == "StateGameplay" and status == "exit" then
        tracking = false
    end
end
local function status()
    local view = Managers.ui and Managers.ui:view_instance("scoreboard_view")
    local owner = view or last_owner
    local ctx = owner and owner._sr_context
    local summary = string.format("RealmScoreboardExtend %s: retained=%d live=%d view=%s context=%s",
        mod.version, count_keys(mod.roster.entries), Managers.player and count_keys(Managers.player:players()) or 0,
        tostring(view ~= nil), tostring(ctx ~= nil))
    local function yes(value) return mod:localize(value and "status_yes" or "status_no") end
    mod:echo("%s", mod:localize("status_summary", mod.version, count_keys(mod.roster.entries),
        Managers.player and count_keys(Managers.player:players()) or 0, yes(view ~= nil), yes(ctx ~= nil)))
    mod:info("[RSE:status] %s", summary)
    mod:info("[RSE:equipment] enabled=%s snapshots=%d perk_limit=%s blessing_limit=%s",
        tostring(Loadouts.enabled()), count_keys(Loadouts.snapshots), tostring(mod:get("equipment_perk_limit") or 2),
        tostring(mod:get("equipment_blessing_limit") or 2))
    for _, key in ipairs({"setup_row_widgets", "create_row_widget", "update_row_values", "normalize_values", "adjust_size"}) do
        mod:info("[RSE:status] binding %s=%s", key, tostring(scoreboard and Bindings.active(scoreboard, key)))
    end
    if ctx then
        local details = string.format("%s page=%d/%d visible=%d/%d columns=%d panel=%.0f label=%.0f scale=%.3f",
            view_kind(ctx), ctx.page, ctx.pages, #ctx.players, #ctx.all, ctx.layout.columns, ctx.layout.width, ctx.layout.label, ctx.scale)
        mod:echo("%s", mod:localize("status_layout", mod:localize("view_" .. view_kind(ctx)),
            ctx.page, ctx.pages, #ctx.players, #ctx.all, ctx.layout.columns, ctx.layout.width, ctx.layout.label, ctx.scale))
        mod:info("[RSE:status] %s", details)
        if view then
            mod:info("[RSE:status] pass_input=%s pass_draw=%s returned=%s history_list=%s",
                tostring(view._pass_input), tostring(view._pass_draw), tostring(view._sr_pass_signature),
                tostring(Managers.ui:view_instance("scoreboard_history_view") ~= nil))
        end
        for i, player in ipairs(ctx.all) do
            mod:info("[RSE:roster] %d key=%s name=%s human=%s", i, tostring(Model.key(player)),
                tostring(Model.value(player, "name")), tostring(Model.value(player, "is_human_controlled")))
        end
    end
end
mod:command("rse_status", mod:localize("command_status"), status)
mod:command("rse_next", mod:localize("command_next"), mod.next_page)
mod:command("rse_prev", mod:localize("command_previous"), mod.previous_page)
-- Keep existing diagnostic instructions usable during the rename transition.
register_legacy_commands = function()
    mod:command("sr_status", mod:localize("command_alias", "/rse_status"), status)
    mod:command("sr_next", mod:localize("command_alias", "/rse_next"), mod.next_page)
    mod:command("sr_prev", mod:localize("command_alias", "/rse_prev"), mod.previous_page)
end
