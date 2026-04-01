local mod = get_mod("cooldown_analysis")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

-- ===== Layout constants =====
-- The stats panel sits to the right of the history list (which is ~520px wide).
-- We anchor to the right edge of the screen, matching the peril tracker approach.

local RIGHT_MARGIN = 30
local PANEL_W      = 1350    -- fits 1080p (1920 - 540 - 30 = 1350)
local PANEL_H      = 520
local CHART_H      = 300
local CHART_W      = PANEL_W - 100
local base_z       = 100

local CHART_SCENE = "cooldown_chart_area"
local LABEL_SCENE = "cooldown_label_area"

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,

    container = {
        parent               = "screen",
        vertical_alignment   = "center",
        horizontal_alignment = "right",
        size                 = { PANEL_W, PANEL_H },
        position             = { -RIGHT_MARGIN, 0, base_z },
    },

    title_area = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { PANEL_W - 50, 50 },
        position             = { 25, 20, base_z + 1 },
    },

    [CHART_SCENE] = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { CHART_W, CHART_H },
        position             = { 50, 80, base_z + 1 },
    },

    yaxis_scene = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { 40, CHART_H },
        position             = { 5, 80, base_z + 1 },
    },

    [LABEL_SCENE] = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { PANEL_W - 50, 120 },
        position             = { 25, CHART_H + 100, base_z + 1 },
    },
}

local widget_definitions = {}

local CooldownViewDefinitions = {
    scenegraph_definition = scenegraph_definition,
    widget_definitions    = widget_definitions,
    panel_w               = PANEL_W,
    panel_h               = PANEL_H,
    chart_scene           = CHART_SCENE,
    label_scene           = LABEL_SCENE,
    chart_w               = CHART_W,
    chart_h               = CHART_H,
}

return settings("CooldownViewDefinitions", CooldownViewDefinitions)
