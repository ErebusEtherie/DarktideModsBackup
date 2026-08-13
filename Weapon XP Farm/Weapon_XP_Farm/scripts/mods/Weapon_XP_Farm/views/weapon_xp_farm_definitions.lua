local mod      = get_mod("Weapon_XP_Farm")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

-- â"€â"€ Layout constants â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local W, H      = 1060, 790
local TITLE_H   = 50
local FOOTER_H  = 54
local CONTENT_Y = TITLE_H + 8
local CONTENT_H = H - TITLE_H - FOOTER_H - 16  -- 670

local NUM_ROWS = 10
local ROW_H    = 64
local ROW_PAD  = 2
local BAR_H    = 54   -- resource bar height + gap; cfg_area offset from content_area

-- â"€â"€ Colour palette â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
-- All colours are {alpha, R, G, B}
local C = {
    panel   = Color.terminal_grid_background(255, true),
    frame   = Color.terminal_frame(255, true),
    accent  = Color.terminal_text_header(255, true),
    body    = Color.terminal_text_body(255, true),
    white   = { 255, 255, 255, 255 },
    dim     = Color.gray(120, true),
    trans   = Color.black(0, true),
    dd_bg   = Color.terminal_grid_background(245, true),
    red     = { 200, 160,  40,  40 },   -- EXIT button background
    -- Resource cost colours
    gold    = { 255, 255, 195,  50 },   -- Credits
    violet  = { 255, 185, 120, 255 },   -- Plasteel
    lt_blue = { 255,  80, 185, 255 },   -- Diamantine
}

-- Dropdown option colours: background tint (semi-transparent) and text
-- Index 0=Profane (gray), 1-4=Steps
local DD_BG = {
    [0] = {  70, 100, 100, 100 },   -- gray  (Profane)
    [1] = {  70,  45, 155,  45 },   -- green (Step 1)
    [2] = {  70,  45, 130, 210 },   -- light blue (Step 2)
    [3] = {  70, 135,  65, 195 },   -- violet (Step 3)
    [4] = {  70, 195, 155,  20 },   -- gold   (Step 4)
}
local DD_TEXT = {
    [0] = { 255, 160, 160, 160 },   -- gray text (Profane)
    [1] = { 255,  90, 230,  90 },   -- green
    [2] = { 255,  90, 200, 255 },   -- light blue
    [3] = { 255, 210, 140, 255 },   -- violet
    [4] = { 255, 255, 215,  70 },   -- gold
}

-- â"€â"€ Scenegraph â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    panel = {
        parent               = "screen",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        size     = { W, H },
        position = { 0, 0, 50 },
    },
    title_bar = {
        parent               = "panel",
        horizontal_alignment = "left",
        vertical_alignment   = "top",
        size     = { W, TITLE_H },
        position = { 0, 0, 1 },
    },
    content_area = {
        parent               = "panel",
        horizontal_alignment = "left",
        vertical_alignment   = "top",
        size     = { W, CONTENT_H },
        position = { 0, CONTENT_Y, 1 },
    },
    footer = {
        parent               = "panel",
        horizontal_alignment = "left",
        vertical_alignment   = "bottom",
        size     = { W, FOOTER_H },
        position = { 0, 0, 1 },
    },
    cfg_area = {
        parent               = "content_area",
        horizontal_alignment = "left",
        vertical_alignment   = "top",
        size     = { W, CONTENT_H - BAR_H },
        position = { 0, BAR_H, 1 },
    },
}

-- â"€â"€ Pass helpers â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local function rect(sg, color, size, offset)
    return UIWidget.create_definition({
        { pass_type = "rect", style_id = "rect",
          style = { color = color, size = size, offset = offset or { 0, 0, 0 } } },
    }, sg)
end

local function label(sg, default_text, color, font_size, size, offset, ha, va)
    return UIWidget.create_definition({
        { pass_type = "text", value_id = "text", style_id = "text",
          style = {
              font_type  = "proxima_nova_bold",
              font_size  = font_size or 18,
              text_color = color,
              text_horizontal_alignment = ha or "left",
              text_vertical_alignment   = va or "center",
              size   = size,
              offset = offset or { 0, 0, 0 },
          } },
    }, sg, { text = default_text or "" })
end

local function btn(sg, caption, size, offset, bg_color, txt_color)
    local ox, oy = offset[1], offset[2]
    local bg  = bg_color  or C.dim
    local txt = txt_color or C.accent
    return UIWidget.create_definition({
        { pass_type = "rect",    style_id = "bg",
          style = { color = bg, size = size, offset = { ox, oy, 1 } } },
        -- Hover/press overlay: alpha driven at runtime via _tick_hover
        { pass_type = "rect",    style_id = "hover_overlay",
          style = { color = { 0, 255, 255, 255 }, size = size, offset = { ox, oy, 2 } } },
        { pass_type = "text",    value_id = "text", style_id = "text",
          style = { font_type = "proxima_nova_bold", font_size = 18,
                    text_color = txt,
                    text_horizontal_alignment = "center",
                    text_vertical_alignment   = "center",
                    size   = size, offset = { ox, oy, 3 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = size, offset = { ox, oy, 4 } } },
    }, sg, { text = caption, hotspot = {} })
end

-- â"€â"€ Widget definitions â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local widget_definitions = {}

-- â"€â"€â"€ Panel background â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.bg = UIWidget.create_definition({
    { pass_type = "texture",
      value = "content/ui/materials/frames/inner_shadow_medium",
      style = { horizontal_alignment = "center", vertical_alignment = "center",
                scale_to_material = true,
                color  = Color.terminal_grid_background(255, true),
                offset = { 0, 0, 0 } } },
    { pass_type = "texture",
      value = "content/ui/materials/backgrounds/terminal_basic",
      style = { horizontal_alignment = "center", vertical_alignment = "center",
                scale_to_material = true,
                color  = Color.terminal_grid_background(200, true),
                offset = { 0, 0, -1 } } },
}, "panel")

-- â"€â"€â"€ Panel border frame (always visible) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.frame_top    = rect("panel", C.frame, { W,     3 }, { 0,     0,     5 })
widget_definitions.frame_bottom = rect("panel", C.frame, { W,     3 }, { 0,     H - 3, 5 })
widget_definitions.frame_left   = rect("panel", C.frame, { 3,     H }, { 0,     0,     5 })
widget_definitions.frame_right  = rect("panel", C.frame, { 3,     H }, { W - 3, 0,     5 })

-- â"€â"€â"€ Tab geometry (declared here â€" used by title bar AND tabs section below) â"€â"€
local TAB_W, TAB_H   = 140, 26
-- TAB_Y=14: sits ~11px below the 3px top-frame, ~8px above the title separator
local TAB_Y          = 18
local C_TAB_INACTIVE = { 255, 38, 52, 38 }   -- slightly brighter than C.panel

-- â"€â"€â"€ Title bar â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.title_line = rect("title_bar", C.frame, { W, 2 }, { 0, TITLE_H - 2, 2 })
-- Title: positioned between the tabs and EXIT button, at same vertical inset as tabs
-- Tabs occupy x=20..308, EXIT starts at x=930 â†’ title fills x=320..920
widget_definitions.title_text = label("title_bar", mod:localize("title"),
    C.gold, 20, { 600, TAB_H }, { 320, TAB_Y, 2 }, "center", "center")
-- EXIT button: red background, white text; y=TAB_Y aligns it with the tabs
widget_definitions.exit_btn = btn("title_bar", mod:localize("btn_exit"), { 120, TAB_H }, { W - 138, TAB_Y }, C.red, C.white)

-- â"€â"€â"€ Status text â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.status_text = label("content_area", mod:localize("loading_short"),
    C.body, 20, { W - 40, CONTENT_H }, { 20, 0, 1 }, "center", "center")

-- â"€â"€â"€ Footer â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.footer_line    = rect("footer", C.frame, { W, 2 }, { 0, 0, 1 })
-- y=12, height=30: centered in FOOTER_H=54.
--   gap from separator line (y=0): 12px
--   gap from frame_bottom (footer yâ‰ˆ51): 51 - (12+30) = 9px
widget_definitions.footer_next    = btn("footer", mod:localize("btn_next"),  { 180, 30 }, { W - 200, 6 })
widget_definitions.footer_back    = btn("footer", mod:localize("btn_back"),  { 140, 30 }, { 20,      6 })
widget_definitions.footer_proceed = btn("footer", mod:localize("btn_proceed"),     { 180, 30 }, { W - 200, 6 })
widget_definitions.footer_close    = btn("footer", mod:localize("btn_close"),   { 180, 30 }, { W/2-90,  6 })
-- Hint shown on weapon-select screen when nothing is selected
widget_definitions.footer_hint = label("footer",
    mod:localize("select_one_hint"),
    { 255, 180, 180, 180 }, 15,
    { 280, 30 },
    { W - 200 - 300, 12, 1 }, "right", "center")
-- Hint shown on configure screen when checkbox is not ticked.
widget_definitions.footer_proceed_hint = label("footer",
    mod:localize("hint_tick_checkbox"),
    { 255, 220, 130, 130 }, 15,
    { 220, 30 },
    { 465, 12, 1 }, "right", "center")
-- Page-1 footer: current wallet amounts (shown on weapon-select screen only)
-- "Current resources:" label (w=170) + Cr / Pl / Di spaced to the right
widget_definitions.footer_res_lbl = label("footer", mod:localize("current_resources"),
    C.white,   14, { 170, 30 }, { 20,  12, 1 }, "left", "center")
widget_definitions.footer_res_cr = label("footer", "Cr: ...",
    C.gold,    14, { 155, 30 }, { 198, 12, 1 }, "left", "center")
widget_definitions.footer_res_pl = label("footer", "Pl: ...",
    C.violet,  14, { 165, 30 }, { 368, 12, 1 }, "left", "center")
widget_definitions.footer_res_di = label("footer", "Di: ...",
    C.lt_blue, 14, { 185, 30 }, { 548, 12, 1 }, "left", "center")

-- â"€â"€â"€ Tabs â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
-- (TAB_W, TAB_H, TAB_Y, C_TAB_INACTIVE declared above near title bar)
for i = 0, 1 do
    local ox = 20 + i * (TAB_W + 8)
    widget_definitions["tab_" .. i] = UIWidget.create_definition({
        -- bg: distinctly lighter than panel so the gap above it is visible
        { pass_type = "rect",    style_id = "bg",
          style = { color = C_TAB_INACTIVE, size = { TAB_W, TAB_H }, offset = { ox, TAB_Y, 1 } } },
        -- underline bar shown on active tab
        { pass_type = "rect",    style_id = "line",
          style = { color = C.trans, size = { TAB_W, 2 }, offset = { ox, TAB_H + TAB_Y, 2 } } },
        { pass_type = "text",    value_id = "text", style_id = "text",
          style = { font_type = "proxima_nova_bold", font_size = 15,
                    text_color = C.body,
                    text_horizontal_alignment = "center",
                    text_vertical_alignment   = "center",
                    size = { TAB_W, TAB_H }, offset = { ox, TAB_Y, 3 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = { TAB_W, TAB_H }, offset = { ox, TAB_Y, 4 } } },
    }, "title_bar", { text = "", hotspot = {} })
end

-- â"€â"€â"€ Weapon rows (page 1) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local RW     = W - 60    -- 1000  (row bg: x=20 to x=1020)
local ICON_W = 200       -- was 160, +40 (half of the previous half: 160 + 80/2)
local ICON_H = 60

-- Name: centered in the full row (x=20 to x=1020, center=520)
-- NAME_X = row_center - NAME_W/2
local NAME_W = 440
local NAME_X = (20 + RW / 2) - NAME_W / 2   -- 520 - 220 = 300

-- Mastery: right side of the row, after the name
local MAST_W = 210
local MAST_X = (20 + RW) - MAST_W - 20      -- 1020 - 210 - 20 = 790

-- Cost-info colours for the bottom strip of each row
local C_ROW_RAR = { 255,  90, 220,  90 }   -- green      (Redeemed label)
local C_ROW_CR  = { 255, 255, 195,  50 }   -- gold       (Credits)
local C_ROW_PL  = { 255, 185, 120, 255 }   -- violet     (Plasteel)
local C_ROW_CNT = { 255, 170, 210, 210 }   -- soft teal  (copy count)

-- Bottom strip layout: 4 items centered so midpoint of (Cr start, Pl start) = 520 (name center)
-- (RS_CR_X + RS_PL_X) / 2 = 520  ->  RS_CR_X=452, RS_PL_X=588
-- rar(120) + gap(6) + cr(130) + gap(6) + pl(120) + gap(6) + cnt(110) = 498px
local RS_RAR_X = 326
local RS_CR_X  = 326 + 120 + 6   -- 452
local RS_PL_X  = 452 + 130 + 6   -- 588
local RS_CNT_X = 588 + 120 + 6   -- 714

for i = 0, NUM_ROWS - 1 do
    local ry  = i * (ROW_H + ROW_PAD)
    local icy = ry + (ROW_H - ICON_H) / 2
    local cy  = ry + 44   -- y of the bottom cost-info strip
    widget_definitions[string.format("row_%02d", i)] = UIWidget.create_definition({
        { pass_type = "rect",    style_id = "bg",
          style = { color = C.panel, size = { RW, ROW_H }, offset = { 20, ry, 1 } } },
        { pass_type = "rect",    style_id = "sel",
          style = { color = C.trans, size = { 8, ROW_H }, offset = { 20, ry, 2 } } },
        { pass_type = "texture", value_id = "icon", style_id = "icon",
          style = { horizontal_alignment = "left", vertical_alignment = "top",
                    color  = { 255, 255, 255, 255 },
                    size   = { ICON_W, ICON_H },
                    offset = { 26, icy, 3 } } },
        -- Name: centered in the upper 40 px of the row
        { pass_type = "text",    value_id = "name", style_id = "name",
          style = { font_type = "proxima_nova_bold", font_size = 19,
                    text_color = { 255, 255, 255, 255 },
                    text_horizontal_alignment = "center",
                    text_vertical_alignment   = "center",
                    size = { NAME_W, 40 }, offset = { NAME_X, ry, 4 } } },
        -- Mastery: right side, upper portion
        { pass_type = "text",    value_id = "mast", style_id = "mast",
          style = { font_type = "proxima_nova_bold", font_size = 15,
                    text_color = { 255, 255, 255, 255 },
                    text_horizontal_alignment = "right",
                    text_vertical_alignment   = "center",
                    size = { MAST_W, 40 }, offset = { MAST_X, ry, 4 } } },
        -- Bottom strip: 4 items centered at x=520
        { pass_type = "text",    value_id = "rar", style_id = "rar",
          style = { font_type = "proxima_nova_bold", font_size = 12,
                    text_color = C_ROW_RAR,
                    text_horizontal_alignment = "left",
                    text_vertical_alignment   = "center",
                    size = { 120, 18 }, offset = { RS_RAR_X, cy, 4 } } },
        { pass_type = "text",    value_id = "cr",  style_id = "cr",
          style = { font_type = "proxima_nova_bold", font_size = 12,
                    text_color = C_ROW_CR,
                    text_horizontal_alignment = "left",
                    text_vertical_alignment   = "center",
                    size = { 130, 18 }, offset = { RS_CR_X, cy, 4 } } },
        { pass_type = "text",    value_id = "pl",  style_id = "pl",
          style = { font_type = "proxima_nova_bold", font_size = 12,
                    text_color = C_ROW_PL,
                    text_horizontal_alignment = "left",
                    text_vertical_alignment   = "center",
                    size = { 120, 18 }, offset = { RS_PL_X, cy, 4 } } },
        { pass_type = "text",    value_id = "cnt", style_id = "cnt",
          style = { font_type = "proxima_nova_bold", font_size = 12,
                    text_color = C_ROW_CNT,
                    text_horizontal_alignment = "left",
                    text_vertical_alignment   = "center",
                    size = { 110, 18 }, offset = { RS_CNT_X, cy, 4 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = { RW, ROW_H }, offset = { 20, ry, 5 } } },
    }, "content_area", { name = "", mast = "", icon = "", hotspot = {},
                         rar = "", cr = "", pl = "", cnt = "" })
end

-- â"€â"€â"€ Scroll bar (right edge of content_area, page 1) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local SB_X       = W - 38             -- 1022
local SB_W       = 18
local SB_BTN_H   = 26
local SB_TRACK_Y = SB_BTN_H + 2      -- 28
local SB_TRACK_H = CONTENT_H - SB_BTN_H * 2 - 4  -- 614

widget_definitions.scroll_up = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = C.dim, size = { SB_W, SB_BTN_H }, offset = { SB_X, 0, 1 } } },
    { pass_type = "text",    value_id = "text", style_id = "text",
      style = { font_type = "proxima_nova_bold", font_size = 14, text_color = C.white,
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                size = { SB_W, SB_BTN_H }, offset = { SB_X, 0, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { SB_W, SB_BTN_H }, offset = { SB_X, 0, 3 } } },
}, "content_area", { text = "^", hotspot = {} })

widget_definitions.scroll_dn = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = C.dim, size = { SB_W, SB_BTN_H },
                offset = { SB_X, CONTENT_H - SB_BTN_H, 1 } } },
    { pass_type = "text",    value_id = "text", style_id = "text",
      style = { font_type = "proxima_nova_bold", font_size = 14, text_color = C.white,
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                size = { SB_W, SB_BTN_H },
                offset = { SB_X, CONTENT_H - SB_BTN_H, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { SB_W, SB_BTN_H },
                offset = { SB_X, CONTENT_H - SB_BTN_H, 3 } } },
}, "content_area", { text = "v", hotspot = {} })

widget_definitions.scroll_track = rect("content_area",
    { 120, 40, 40, 40 }, { SB_W, SB_TRACK_H }, { SB_X, SB_TRACK_Y, 1 })
widget_definitions.scroll_fill  = rect("content_area",
    Color.terminal_text_header(200, true),
    { SB_W - 4, SB_TRACK_H - 4 }, { SB_X + 2, SB_TRACK_Y + 2, 2 })
-- Invisible hotspot covering the track area â€" used for click-and-drag scrolling.
-- Covers only the track (SB_TRACK_Y..SB_TRACK_Y+SB_TRACK_H) so it never overlaps
-- the â–²/â–¼ button hotspots above/below it.
widget_definitions.scroll_zone = UIWidget.create_definition({
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { SB_W + 8, SB_TRACK_H }, offset = { SB_X - 4, SB_TRACK_Y, 2 } } },
}, "content_area", { hotspot = {} })

-- â"€â"€â"€ Resource bar (configure screen top strip, lives in content_area) â"€â"€â"€â"€â"€â"€â"€â"€
-- Visible at y=0..BAR_H-1; cfg_area (all other configure widgets) starts at y=BAR_H.
local RB_C1 = 20    -- Credits column left edge
local RB_C2 = 373   -- Plasteel column left edge
local RB_C3 = 726   -- Diamantine column left edge

local C_BAR_LBL = { 255, 165, 165, 165 }   -- brighter gray so column names are readable

widget_definitions.cfg_res_bg   = rect("content_area", C.panel, { W, BAR_H - 5 }, { 0, 0, 0 })
widget_definitions.cfg_res_sep  = rect("content_area", C.frame, { W, 1 }, { 0, BAR_H - 6, 1 })
widget_definitions.cfg_res_div1 = rect("content_area", C_BAR_LBL, { 1, BAR_H - 14 }, { RB_C2 - 14, 7, 1 })
widget_definitions.cfg_res_div2 = rect("content_area", C_BAR_LBL, { 1, BAR_H - 14 }, { RB_C3 - 14, 7, 1 })

local RB_LY  = 5     -- label row y
local RB_VY  = 24    -- value row y
local RB_VH  = 20    -- value row height
local RB_HW  = 175   -- "have" widget width
local RB_CX  = 12    -- x offset of cost label from column start + RB_HW

widget_definitions.cfg_res_lbl_cr  = label("content_area", mod:localize("res_credits"),
    C.gold, 13, { 160, 18 }, { RB_C1, RB_LY, 1 }, "left", "center")
widget_definitions.cfg_res_have_cr = label("content_area", "...",
    C.gold, 18, { RB_HW, RB_VH }, { RB_C1, RB_VY, 1 }, "left", "center")
widget_definitions.cfg_res_cst_cr  = label("content_area", "",
    { 255, 220, 70, 70 }, 13, { 150, RB_VH }, { RB_C1 + RB_HW + RB_CX, RB_VY + 1, 1 }, "left", "center")

widget_definitions.cfg_res_lbl_pl  = label("content_area", mod:localize("res_plasteel"),
    C.violet, 13, { 160, 18 }, { RB_C2, RB_LY, 1 }, "left", "center")
widget_definitions.cfg_res_have_pl = label("content_area", "...",
    C.violet, 18, { RB_HW, RB_VH }, { RB_C2, RB_VY, 1 }, "left", "center")
widget_definitions.cfg_res_cst_pl  = label("content_area", "",
    { 255, 220, 70, 70 }, 13, { 150, RB_VH }, { RB_C2 + RB_HW + RB_CX, RB_VY + 1, 1 }, "left", "center")

widget_definitions.cfg_res_lbl_di  = label("content_area", mod:localize("res_diamantine"),
    C.lt_blue, 13, { 160, 18 }, { RB_C3, RB_LY, 1 }, "left", "center")
widget_definitions.cfg_res_have_di = label("content_area", "...",
    C.lt_blue, 18, { RB_HW, RB_VH }, { RB_C3, RB_VY, 1 }, "left", "center")
widget_definitions.cfg_res_cst_di  = label("content_area", "",
    { 255, 220, 70, 70 }, 13, { 150, RB_VH }, { RB_C3 + RB_HW + RB_CX, RB_VY + 1, 1 }, "left", "center")

-- â"€â"€â"€ Configure screen (page 2) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
-- Two-column layout below the weapon header.
-- LEFT (x=20..460): mode selection, auto info, amount controls, slider
-- RIGHT (x=480..1040): consecrate dropdown, order summary
local LX      = 20           -- left margin / left column start
local LW2     = 440          -- left column width  (x=20..460)
local RX      = 480          -- right column x start
local RW      = W - RX - 20 -- right column width  (560)
local SPLIT_Y = 132          -- y where two-column section begins (96+28+8 for mode toggle bar)

-- Icon in header
local CFG_ICON_W = ICON_W
local CFG_ICON_H = ICON_H
local CFG_ICON_X = 840
local CFG_ICON_Y = 16
local HDR_TXT_W  = CFG_ICON_X - LX - 20  -- 800

-- ─ Weapon header (full width) ──────────────────────────────────────────────
widget_definitions.cfg_weapon_name = label("cfg_area", "",
    { 255, 220, 70, 70 }, 26, { HDR_TXT_W, 46 }, { LX, 4, 1 }, "left", "center")
local MAST_LBL_W = 160
widget_definitions.cfg_weapon_mast = label("cfg_area", "",
    { 255, 255, 255, 255 }, 18, { MAST_LBL_W, 30 }, { LX, 54, 1 }, "left", "center")
local BASE_RAR_PREFIX_W = 148
widget_definitions.cfg_weapon_sub  = label("cfg_area", "",
    { 255, 255, 255, 255 }, 18, { BASE_RAR_PREFIX_W, 30 },
    { LX + MAST_LBL_W + 5, 54, 1 }, "left", "center")
widget_definitions.cfg_weapon_sub_rar = label("cfg_area", mod:localize("rarity_2"),
    { 255, 90, 230, 90 }, 18, { 120, 30 },
    { LX + MAST_LBL_W + 5 + BASE_RAR_PREFIX_W, 54, 1 }, "left", "center")
widget_definitions.cfg_icon = UIWidget.create_definition({
    { pass_type = "texture", value_id = "icon", style_id = "icon",
      style = { horizontal_alignment = "left", vertical_alignment = "top",
                color  = { 255, 255, 255, 255 },
                size   = { CFG_ICON_W, CFG_ICON_H },
                offset = { CFG_ICON_X, CFG_ICON_Y, 2 } } },
}, "cfg_area", { icon = "" })
widget_definitions.cfg_header_line = rect("cfg_area", C.dim, { W - LX - 10, 1 }, { LX, 92, 1 })

-- Mode toggle bar (y=96..124, between header line at y=92 and SPLIT_Y=132)
local TOG_BTN_W = math.floor((W - LX * 2 - 4) / 2)  -- 508 each
widget_definitions.cfg_mode_store_btn = btn("cfg_area", mod:localize("mode_store"),
    { TOG_BTN_W, 28 }, { LX, 96 })
widget_definitions.cfg_mode_inv_btn   = btn("cfg_area", mod:localize("mode_inventory"),
    { TOG_BTN_W, 28 }, { LX + TOG_BTN_W + 4, 96 })

-- Vertical column divider (spans from two-col section to just above confirm checkbox)
widget_definitions.cfg_col_div = rect("cfg_area", C.dim, { 1, 476 }, { RX - 12, SPLIT_Y, 1 })

-- ─ LEFT COLUMN: Mode selection → auto info → amount controls → slider ──────
local AUTO_CHK_Y   = SPLIT_Y         -- 132
local MANUAL_CHK_Y = AUTO_CHK_Y + 88 -- 220  (block=44px + 44px breathing room)

local HINT_X  = LX + 34
local HINT_W2 = LW2 - 34 - 10       -- 396

local function mode_chk(box_name, lbl_name, hint_name, oy, lbl_text, hint_text)
    widget_definitions[box_name] = UIWidget.create_definition({
        { pass_type = "rect",    style_id = "bg",
          style = { color = C.panel, size = { 28, 28 }, offset = { LX, oy, 1 } } },
        { pass_type = "rect",    style_id = "check",
          style = { color = C.trans, size = { 18, 18 }, offset = { LX + 5, oy + 5, 2 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = { 28, 28 }, offset = { LX, oy, 3 } } },
    }, "cfg_area", { hotspot = {} })
    widget_definitions[lbl_name] = label("cfg_area", lbl_text,
        C.accent, 17, { LW2 - 38, 28 }, { LX + 38, oy, 1 }, "left", "center")
    widget_definitions[hint_name] = label("cfg_area", hint_text,
        { 255, 140, 140, 140 }, 13, { HINT_W2, 16 }, { HINT_X, oy + 32, 1 }, "left", "top")
end

mode_chk("cfg_auto_chk_box",   "cfg_auto_chk_lbl",   "cfg_auto_chk_hint",
         AUTO_CHK_Y,
         mod:localize("auto_max_mastery"),
         mod:localize("auto_max_mastery_hint"))
mode_chk("cfg_manual_chk_box", "cfg_manual_chk_lbl", "cfg_manual_chk_hint",
         MANUAL_CHK_Y,
         mod:localize("manual_amount"),
         mod:localize("manual_amount_hint"))

-- Auto info (3 lines, left column, below mode checkboxes)
local INFO_TOP = MANUAL_CHK_Y + 62  -- 262
local INFO_Y1  = INFO_TOP           -- 262
local INFO_Y2  = INFO_Y1 + 30      -- 312
local INFO_Y3  = INFO_Y2 + 30      -- 342

widget_definitions.cfg_auto_info1 = label("cfg_area", "",
    { 255, 140, 220, 140 }, 17, { LW2, 22 }, { LX, INFO_Y1, 1 }, "left", "center")
widget_definitions.cfg_auto_info2 = label("cfg_area", "",
    { 255, 140, 180, 255 }, 17, { LW2, 22 }, { LX, INFO_Y2, 1 }, "left", "center")
widget_definitions.cfg_auto_info3 = label("cfg_area", "",
    { 255, 255, 215,  70 }, 17, { LW2, 22 }, { LX, INFO_Y3, 1 }, "left", "center")

-- Inventory-mode min-rarity filter dropdown + store-mode inventory notice
-- Header label is 22px tall; DD starts at +24 (2px gap); DD bottom = 434 = AMT_Y (flush).
local INV_FILT_LBL_Y = INFO_Y3 + 30   -- 372: clears info3 bottom (342+22=364) by 8px
local INV_FILT_DD_Y  = INV_FILT_LBL_Y + 24  -- label 22px + 2px gap
local INV_FILT_DD_H  = 38
widget_definitions.cfg_inv_filt_lbl = label("cfg_area", mod:localize("inv_filter_label"),
    C.gold, 20, { LW2, 26 }, { LX, INV_FILT_LBL_Y, 1 }, "left", "center")
widget_definitions.cfg_inv_filt_dd = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = DD_BG[0], size = { LW2, INV_FILT_DD_H }, offset = { LX, INV_FILT_DD_Y, 1 } } },
    { pass_type = "text",    value_id = "text", style_id = "text",
      style = { font_type = "proxima_nova_bold", font_size = 16, text_color = DD_TEXT[0],
                text_horizontal_alignment = "left", text_vertical_alignment = "center",
                size = { LW2 - 12, INV_FILT_DD_H }, offset = { LX + 12, INV_FILT_DD_Y, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { LW2, INV_FILT_DD_H }, offset = { LX, INV_FILT_DD_Y, 3 } } },
}, "cfg_area", { text = "\xe2\x96\xbc  " .. mod:localize("filter_any"), hotspot = {} })
local FILT_OPT_H  = 34
local FILT_OPT_Y0 = INV_FILT_DD_Y + INV_FILT_DD_H + 2
widget_definitions.cfg_inv_filt_dd_bg = rect("cfg_area", C.dd_bg,
    { LW2, FILT_OPT_H * 5 }, { LX, FILT_OPT_Y0, 18 })
local _FILT_OPTS = { mod:localize("filter_any"), mod:localize("filter_redeemed_plus"),
    mod:localize("filter_anointed_plus"), mod:localize("filter_exalted_plus"),
    mod:localize("filter_transcendent_only") }
for _fi = 0, 4 do
    local oy = FILT_OPT_Y0 + _fi * FILT_OPT_H
    widget_definitions["cfg_inv_filt_opt_" .. _fi] = UIWidget.create_definition({
        { pass_type = "rect",    style_id = "bg",
          style = { color = DD_BG[_fi],  size = { LW2, FILT_OPT_H }, offset = { LX, oy, 19 } } },
        { pass_type = "rect",    style_id = "hi",
          style = { color = C.trans, size = { LW2, FILT_OPT_H }, offset = { LX, oy, 20 } } },
        { pass_type = "text",    value_id = "text", style_id = "text",
          style = { font_type = "proxima_nova_bold", font_size = 15,
                    text_color = DD_TEXT[_fi],
                    text_horizontal_alignment = "left", text_vertical_alignment = "center",
                    size = { LW2 - 20, FILT_OPT_H }, offset = { LX + 14, oy, 21 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = { LW2, FILT_OPT_H }, offset = { LX, oy, 22 } } },
    }, "cfg_area", { text = _FILT_OPTS[_fi + 1], hotspot = {} })
end
-- Store mode: inventory notice (shown at same position as filter label, in place of it)
widget_definitions.cfg_store_inv_notice = label("cfg_area", "",
    { 255, 140, 200, 255 }, 13, { LW2, 22 }, { LX, INV_FILT_LBL_Y, 1 }, "left", "center")

-- Amount controls (left column, below auto info)
local AMT_Y  = INFO_Y3 + 112  -- 454: dropdown bottom at 434 + 20px gap
local AMT_BH = 36

widget_definitions.cfg_amt_lbl = label("cfg_area", mod:localize("amount_short"),
    C.gold, 17, { 80, AMT_BH }, { LX, AMT_Y, 1 }, "left", "center")
local AX = LX + 84  -- 104: button group start (keeps +37 right edge at 456, clear of divider)
widget_definitions.cfg_amt_m5   = btn("cfg_area", "-5",  { 52, AMT_BH }, { AX,       AMT_Y })
widget_definitions.cfg_amt_m1   = btn("cfg_area", "-1",  { 42, AMT_BH }, { AX + 56,  AMT_Y })
widget_definitions.cfg_amt_disp = label("cfg_area", "1",
    C.accent, 28, { 78, AMT_BH }, { AX + 102, AMT_Y, 1 }, "center", "center")
widget_definitions.cfg_amt_p1   = btn("cfg_area", "+1",  { 42, AMT_BH }, { AX + 184, AMT_Y })
widget_definitions.cfg_amt_p5   = btn("cfg_area", "+5",  { 52, AMT_BH }, { AX + 230, AMT_Y })
widget_definitions.cfg_amt_max  = btn("cfg_area", "+37", { 66, AMT_BH }, { AX + 286, AMT_Y },
    { 180, 160, 40, 40 }, C.white)

-- Slider (left column; SW=420 so right edge=440, giving 28px clearance before the divider)
local SX = LX
local SW = 420
local SY = AMT_Y + AMT_BH + 16   -- 506  (AMT_Y=454, AMT_BH=36; hint moved to right column)
widget_definitions.cfg_slider_track  = rect("cfg_area", C.panel,  { SW, 12 }, { SX, SY,     1 })
widget_definitions.cfg_slider_fill   = rect("cfg_area", C.accent, { 2,  12 }, { SX, SY,     2 })
widget_definitions.cfg_slider_handle = rect("cfg_area", C.accent, { 14, 28 }, { SX, SY - 9, 3 })

-- "Count inventory toward mastery goal" checkbox (store mode only, left column)
local INV_CALC_Y = SY + 14   -- 500: slider track ends at SY+12=498, small gap
widget_definitions.cfg_inv_calc_chk_box = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = C.panel, size = { 28, 28 }, offset = { LX, INV_CALC_Y, 1 } } },
    { pass_type = "rect",    style_id = "check",
      style = { color = C.trans, size = { 18, 18 }, offset = { LX + 5, INV_CALC_Y + 5, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { 28, 28 }, offset = { LX, INV_CALC_Y, 3 } } },
}, "cfg_area", { hotspot = {} })
widget_definitions.cfg_inv_calc_chk_lbl = label("cfg_area",
    mod:localize("inv_calc_q"),
    C.accent, 14, { LW2 - 38, 28 }, { LX + 38, INV_CALC_Y, 1 }, "left", "center")
widget_definitions.cfg_inv_calc_chk_hint = label("cfg_area",
    mod:localize("inv_calc_hint"),
    { 255, 140, 140, 140 }, 12, { LW2 - 38, 16 },
    { LX + 38, INV_CALC_Y + 30, 1 }, "left", "top")

-- ─ RIGHT COLUMN: Consecrate dropdown + Order Summary ───────────────────────
local CW2 = RW  -- 560

local DD_HINT_Y = SPLIT_Y          -- 112
local DD_LBL_Y  = DD_HINT_Y + 26  -- 138
local DD_BTN_Y  = DD_LBL_Y  + 42  -- 180
local DD_BTN_H  = 48

widget_definitions.cfg_upg_hint = label("cfg_area",
    mod:localize("upg_hint_fmt", mod:localize("rarity_2")),
    { 255, 140, 140, 140 }, 13, { CW2, 22 },
    { RX, DD_HINT_Y, 1 }, "left", "center")
widget_definitions.cfg_upg_lbl = label("cfg_area", mod:localize("upgrade_label") .. ":",
    C.white, 19, { CW2, 38 }, { RX, DD_LBL_Y, 1 }, "left", "center")
widget_definitions.cfg_upg_dd = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = DD_BG[0], size = { CW2, DD_BTN_H }, offset = { RX, DD_BTN_Y, 1 } } },
    { pass_type = "text",    value_id = "text", style_id = "text",
      style = { font_type = "proxima_nova_bold", font_size = 20, text_color = DD_TEXT[0],
                text_horizontal_alignment = "left", text_vertical_alignment = "center",
                size = { CW2 - 12, DD_BTN_H }, offset = { RX + 12, DD_BTN_Y, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { CW2, DD_BTN_H }, offset = { RX, DD_BTN_Y, 3 } } },
}, "cfg_area", { text = "\xe2\x96\xbc  " .. mod:localize("rarity_1"), hotspot = {} })

-- Dropdown popup (opens downward from button, overlays order summary at higher z)
local DD_Y0    = DD_BTN_Y + DD_BTN_H + 4  -- 232
local DD_H     = 40
local NUM_OPTS = 5

widget_definitions.cfg_dd_bg = rect("cfg_area", C.dd_bg,
    { CW2, DD_H * NUM_OPTS }, { RX, DD_Y0, 8 })

for i = 0, NUM_OPTS - 1 do
    local oy = DD_Y0 + i * DD_H
    widget_definitions["cfg_upg_opt_" .. i] = UIWidget.create_definition({
        { pass_type = "rect",    style_id = "bg",
          style = { color = DD_BG[i],  size = { CW2, DD_H }, offset = { RX, oy, 9 } } },
        { pass_type = "rect",    style_id = "hi",
          style = { color = C.trans, size = { CW2, DD_H }, offset = { RX, oy, 10 } } },
        { pass_type = "text",    value_id = "text", style_id = "text",
          style = { font_type = "proxima_nova_bold", font_size = 18,
                    text_color = DD_TEXT[i],
                    text_horizontal_alignment = "left", text_vertical_alignment = "center",
                    size = { CW2 - 20, DD_H }, offset = { RX + 14, oy, 11 } } },
        { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
          style = { size = { CW2, DD_H }, offset = { RX, oy, 12 } } },
    }, "cfg_area", { text = "", hotspot = {} })
end

-- Order Summary panel (right column, below dropdown button)
local ORD_Y  = DD_BTN_Y + DD_BTN_H + 26  -- 254
local ORD_VW = CW2 - 10                  -- 550

widget_definitions.cfg_ord_hdr = label("cfg_area", mod:localize("order_summary"),
    C.accent, 18, { ORD_VW, 30 }, { RX, ORD_Y, 1 }, "left", "center")
widget_definitions.cfg_ord_sep = rect("cfg_area", C.dim,
    { CW2 - 10, 1 }, { RX, ORD_Y + 36, 1 })
widget_definitions.cfg_ord_wpn = label("cfg_area", mod:localize("ord_weapons_fmt", "--"),
    C.white, 20, { ORD_VW, 32 }, { RX, ORD_Y + 46, 1 }, "left", "center")
widget_definitions.cfg_ord_cst_hdr = label("cfg_area", mod:localize("estimated_cost"),
    { 255, 180, 180, 180 }, 16, { ORD_VW, 26 }, { RX, ORD_Y + 100, 1 }, "left", "center")
widget_definitions.cfg_ord_cr = label("cfg_area", mod:localize("ord_credits_fmt", "0"),
    C.gold,    20, { ORD_VW, 32 }, { RX, ORD_Y + 134, 1 }, "left", "center")
widget_definitions.cfg_ord_pl = label("cfg_area", mod:localize("ord_plasteel_fmt", "0"),
    C.violet,  20, { ORD_VW, 32 }, { RX, ORD_Y + 174, 1 }, "left", "center")
widget_definitions.cfg_ord_di = label("cfg_area", mod:localize("ord_diamantine_fmt", "0"),
    C.lt_blue, 20, { ORD_VW, 32 }, { RX, ORD_Y + 214, 1 }, "left", "center")
-- Mastery-target hint (moved here from left column so it sits in the order summary context)
widget_definitions.cfg_amt_hint = label("cfg_area", "",
    { 255, 140, 140, 140 }, 13, { ORD_VW, 18 }, { RX, ORD_Y + 258, 1 }, "left", "center")
widget_definitions.cfg_ord_note = label("cfg_area",
    mod:localize("cost_note"),
    { 255, 140, 140, 140 }, 13, { ORD_VW, 18 }, { RX, ORD_Y + 278, 1 }, "left", "center")

-- ─ Confirm checkbox (full width, below both columns) ───────────────────────
local CHK_Y = 578   -- right col note at ORD_Y+278, bottom=552+18=570 (SPLIT_Y=132); +8 gap
local CONFIRM_LBL_W = 500
widget_definitions.cfg_chk_box = UIWidget.create_definition({
    { pass_type = "rect",    style_id = "bg",
      style = { color = C.panel, size = { 30, 30 }, offset = { LX, CHK_Y, 1 } } },
    { pass_type = "rect",    style_id = "check",
      style = { color = C.trans,  size = { 20, 20 }, offset = { LX + 5, CHK_Y + 5, 2 } } },
    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
      style = { size = { 30, 30 }, offset = { LX, CHK_Y, 3 } } },
}, "cfg_area", { hotspot = {} })
widget_definitions.cfg_chk_lbl = label("cfg_area", mod:localize("confirm_label"),
    { 255, 220, 70, 70 }, 22, { CONFIRM_LBL_W, 34 }, { LX + 38, CHK_Y, 1 }, "left", "center")

-- â"€â"€â"€ Processing screen â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
widget_definitions.proc_hdr    = label("content_area", mod:localize("processing_header"),
    C.accent, 26, { W - 40, 60  }, { 20, CONTENT_H/2 - 90, 1 }, "center", "center")
widget_definitions.proc_status = label("content_area", "",
    C.white,  19, { W - 40, 40  }, { 20, CONTENT_H/2 - 30, 1 }, "center", "center")
widget_definitions.proc_errors = label("content_area", "",
    C.body,   15, { W - 40, 200 }, { 20, CONTENT_H/2 + 20, 1 }, "center", "top")
-- Shown on successful purchase: prompt to open Crafting Station
widget_definitions.proc_craft_hint = label("content_area",
    mod:localize("craft_hint1"),
    { 255, 200, 220, 255 }, 15,
    { W - 40, 24 }, { 20, CONTENT_H/2 + 22, 1 }, "center", "center")
widget_definitions.proc_craft_hint2 = label("content_area",
    mod:localize("craft_hint2"),
    { 180, 160, 160, 160 }, 13,
    { W - 40, 22 }, { 20, CONTENT_H/2 + 48, 1 }, "center", "center")
widget_definitions.proc_craft_btn = btn("content_area", mod:localize("btn_open_select"),
    { 200, 36 }, { W/2 - 100, CONTENT_H/2 + 76 },
    { 180, 40, 120, 100 }, C.white)

-- â"€â"€ Return â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
return {
    scenegraph_definition = scenegraph_definition,
    widget_definitions    = widget_definitions,
    legend_inputs         = {},
    slider_sx    = SX,
    slider_sy    = SY,
    slider_sw    = SW,
    num_rows     = NUM_ROWS,
    -- Exported colour tables so view.lua can apply them dynamically
    dd_text_colours = DD_TEXT,
    dd_bg_colours   = DD_BG,
    -- Scroll-bar geometry (view.lua uses these to update the fill indicator)
    sb_x       = SB_X,
    sb_w       = SB_W,
    sb_btn_h   = SB_BTN_H,
    sb_track_y = SB_TRACK_Y,
    sb_track_h = SB_TRACK_H,
}




