local mod = get_mod("peril_tracker")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

-- ===== Layout constants =====

-- History list occupies ~520px on the left. We anchor the chart panel
-- to the right side of the screen so it scales naturally at any resolution.
-- LEFT_MARGIN: where the chart starts (clears the history list)
-- RIGHT_MARGIN: gap from the right screen edge
-- PANEL_H and vertical layout are fixed regardless of resolution.

local LEFT_MARGIN  = 540     -- px from left screen edge
local RIGHT_MARGIN = 30      -- px from right screen edge
local PANEL_H      = 520
local CHART_H      = 280     -- chart plot area height
local base_z       = 100
local CHART_SCENE  = "peril_chart_area"
local LABEL_SCENE  = "peril_label_area"

-- We can't compute screen width at definition-load time in Lua here,
-- so we anchor using horizontal_alignment = "right" from the screen
-- with a negative position offset to pull it left by RIGHT_MARGIN,
-- and set the left edge using a "left"-anchored node offset from screen left.

-- Strategy: anchor container to RIGHT of screen, size it to fill from
-- LEFT_MARGIN to (screen_right - RIGHT_MARGIN).
-- We use horizontal_alignment="right" and position[1] = RIGHT_MARGIN
-- then set size[1] large enough to reach back to LEFT_MARGIN.
-- Since we can't know screen width, we use a generous fixed width and
-- rely on horizontal_alignment="right" to place the right edge correctly.

-- Simpler approach that works at any res:
-- Anchor to right, use a fixed panel width that fits 1080p comfortably.
-- At 1440p the history list has more space so overlap isn't an issue anyway.
-- 1080p screen width = 1920px. Available right of history = 1920-540-30 = 1350px.
-- Use that as PANEL_W so 1080p fills perfectly; on 1440p the panel is the same
-- size but there's more breathing room.

local PANEL_W  = 1350   -- fits 1080p perfectly; looks great on 1440p too
local CHART_W  = PANEL_W - 100

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,

    -- Anchor to right edge of screen, offset left by RIGHT_MARGIN
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
        position             = { 50, 90, base_z + 1 },
    },

    yaxis_scene = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { 40, CHART_H },
        position             = { 5, 90, base_z + 1 },
    },

    [LABEL_SCENE] = {
        parent               = "container",
        vertical_alignment   = "top",
        horizontal_alignment = "left",
        size                 = { PANEL_W - 50, 80 },
        position             = { 25, CHART_H + 110, base_z + 1 },
    },
}

local widget_definitions = {}

local PerilChartViewDefinitions = {
    scenegraph_definition = scenegraph_definition,
    widget_definitions    = widget_definitions,
    panel_w               = PANEL_W,
    panel_h               = PANEL_H,
    chart_scene           = CHART_SCENE,
    label_scene           = LABEL_SCENE,
    chart_w               = CHART_W,
    chart_h               = CHART_H,
}

return settings("PerilChartViewDefinitions", PerilChartViewDefinitions)
