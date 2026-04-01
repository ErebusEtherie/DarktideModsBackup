-- File: Targeter/scripts/mods/Targeter/core/templates.lua
-- Registers Targeter (and other mods') extra crosshair templates with the HUD.

local mod = get_mod("Targeter")
if not mod then return end

mod._default_crosshair_settings = mod._default_crosshair_settings or {}

local function _crosshair_name_from_path(path)
    if type(path) ~= "string" then
        return nil
    end

    return string.match(path, "crosshairs/([^/]+)$")
        or string.match(path, "([^/]+)$")
end

local function _load_template(path)
    local tpl = mod:io_dofile(path)

    if type(tpl) ~= "table" then
        mod:error("Template at %s did not return a table", path)
        return nil
    end

    local factory = tpl.create_widget_definition or tpl.create_widget_defintion
    if not factory then
        for k, v in pairs(tpl) do
            if type(v) == "function" and string.find(k, "create_widget_def") then
                factory = v
                break
            end
        end
    end

    if not factory then
        mod:error("Template at %s is missing create_widget_definition/defintion", path)
        return nil
    end

    return tpl, factory
end

local function _gather_template_sources()
    local sources = {}

    if mod.custom_crosshair_templates then
        for name, path in pairs(mod.custom_crosshair_templates) do
            sources[#sources + 1] = { name = name, path = path }
        end
    end

    local targeter_paths = mod.get_targeter_template_paths and mod.get_targeter_template_paths()
    if targeter_paths then
        for _, path in ipairs(targeter_paths) do
            sources[#sources + 1] = {
                name = _crosshair_name_from_path(path),
                path = path,
            }
        end
    end

    return sources
end

mod:hook_safe(CLASS.HudElementCrosshair, "init", function(self, ...)
    local templates_tbl   = self._crosshair_templates
    local widget_defs_tbl = self._crosshair_widget_definitions
    local scenegraph_id   = (self._definitions and self._definitions.scenegraph_id) or "screen"

    if not (templates_tbl and widget_defs_tbl) then
        return
    end

    for _, entry in ipairs(_gather_template_sources()) do
        local path = entry.path
        local tpl, factory = _load_template(path)

        if tpl and factory then
            local name = entry.name or tpl.name or _crosshair_name_from_path(path)

            if name and not templates_tbl[name] then
                local widget_def = factory(tpl, scenegraph_id)

                if widget_def then
                    templates_tbl[name]   = tpl
                    widget_defs_tbl[name] = widget_def
                else
                    mod:error("Factory returned nil for template '%s' from %s", tostring(name), path)
                end
            end
        end
    end

    for name, tpl in pairs(templates_tbl) do
        if type(tpl.update_function) == "function" and not tpl._targeter_wrapped then
            local original_update = tpl.update_function
            tpl.update_function = function(parent, ui_renderer, widget, template_data, crosshair_settings, dt, t,
                                           draw_hit_indicator)
                crosshair_settings = crosshair_settings or mod._default_crosshair_settings
                return original_update(parent, ui_renderer, widget, template_data, crosshair_settings, dt, t,
                    draw_hit_indicator)
            end
            tpl._targeter_wrapped = true
        end
    end
end)
