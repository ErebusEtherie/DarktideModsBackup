-- File: RingHud/scripts/mods/RingHud/systems/constants.lua
local mod = get_mod("RingHud")
if not mod then return end

if mod.constants then
    return mod.constants
end

-- Centralised colours (RingHud_colors.lua)
local Colors                   = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")

local C                        = {}

mod.constants                  = C

-- Pull current scale from settings (defaults to 1)
local SCALE                    = (mod._settings and mod._settings.team_tiles_scale) or 1

-- =========================
-- Tile sizing & layout (base)
-- =========================
C.START_X, C.START_Y           = 80, 650 -- unchanged anchor

-- These are (re)computed below so every derivative stays consistent with TILE_SIZE.
C.TILE_SIZE                    = 192 * SCALE
C.ARC_MIN, C.ARC_MAX           = -0.40, 0.40
C.SEGMENT_GAP                  = 0.02
C.MAX_WOUNDS_CAP               = 11
C.ARC_SIZE                     = C.TILE_SIZE + 14

-- Minimum visible gap between corruption and health (π-radians).
C.MIN_CORR_HEALTH_GAP_PI       = 0.010

-- health-edge split support
C.HP_LEADING_EDGE_GAP          = 0.01
C.MAX_HP_SEGMENTS              = C.MAX_WOUNDS_CAP + 1

-- =========================
-- HUD icon sizes (derived from TILE_SIZE)
-- =========================
C.CRATE_ICON_SIZE              = C.TILE_SIZE / 16
C.STIMM_ICON_SIZE              = C.TILE_SIZE / 15
C.THROWABLE_ICON_SIZE          = C.TILE_SIZE / 10 -- keep this larger than crate/stimm by design

-- =========================
-- Floating teammate tiles
-- =========================

-- Base visual size of the floating teammate tile (must match template.size).
C.MARKER_SIZE_BASE             = { 220, 140 }

-- =========================
-- Live recompute helpers (keep TILE_SIZE and all derivatives in sync)
-- =========================

-- Recompute tile-size–derived scalars (TILE_SIZE, ARC_SIZE, icon sizes).
function C.recompute_tile_scalars(s)
    local scale           = s or ((mod._settings and mod._settings.team_tiles_scale) or 1)

    C.TILE_SIZE           = 240 * scale
    C.ARC_SIZE            = C.TILE_SIZE + 14

    -- Icon sizes always derive from TILE_SIZE
    C.CRATE_ICON_SIZE     = C.TILE_SIZE / 16
    C.STIMM_ICON_SIZE     = C.TILE_SIZE / 15
    C.THROWABLE_ICON_SIZE = C.TILE_SIZE / 10

    return C.TILE_SIZE
end

-- Expose recompute helper on mod.* for cross-file callers.
mod.recompute_tile_scalars = mod.recompute_tile_scalars or C.recompute_tile_scalars

-- Initial pass to ensure everything matches current settings on load.
C.recompute_tile_scalars(SCALE)

-- =========================
-- Status / timing
-- =========================

-- Total ledge-hang window used for the countdown fraction in the RingHud_state_team.
C.LEDGE_TOTAL_WINDOW                   = PlayerCharacterConstants.time_until_fall_down_from_hang_ledge or 2.5

-- =========================
-- Pocketables context tunables
-- =========================
-- How long a *teammate* stimm/ crate stays highlighted after their carried item changes.
C.STIMM_PICKUP_LATCH_SEC               = 10 -- used for per-peer stimm_show_until
C.CRATE_PICKUP_LATCH_SEC               = 10 -- used for per-peer crate_show_until

-- HP threshold where corruption stimms start to fade in (player + team variable-opacity).
C.STIMM_CORRUPTION_HP_THRESHOLD        = 0.75

-- Heal-tool reassurance latch (local-only): wielding corruption stimm / med crate → brief HUD nudge.
C.LOCAL_WIELD_LATCH_SEC                = 10

-- Any stimm/crate wield latch (player → team full-opacity pockets for a short time).
C.WIELD_POCKETABLE_LATCH_SEC           = 10

-- =========================
-- Status icons (materials / priority)
-- =========================
C.STATUS_ICON_MATERIALS                = C.STATUS_ICON_MATERIALS or {}

-- Override icons
C.STATUS_ICON_MATERIALS.pounced        =
"content/ui/materials/mission_board/circumstances/hunting_grounds_01" -- hound, glowing
-- "content/ui/materials/icons/circumstances/hunting_grounds_01"                    -- hound, plain

C.STATUS_ICON_MATERIALS.warp_grabbed   =
-- "content/ui/materials/icons/pocketables/hud/grimoire" -- grimoire, easter egg
"content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals" -- daemonhost, plain

C.STATUS_ICON_MATERIALS.consumed       =
"content/ui/materials/mission_board/circumstances/nurgle_manifestation_01" -- nurgle trefoil, glowing
-- "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rampaging_enemies" -- nurgle trefoil with skull, plain

C.STATUS_ICON_MATERIALS.grabbed        =
"content/ui/materials/mission_board/circumstances/nurgle_manifestation_01" -- nurgle trefoil, glowing
-- "content/ui/materials/icons/circumstances/nurgle_manifestation_01"               -- nurgle trefoil, plain

C.STATUS_ICON_MATERIALS.knocked_down   =
"content/ui/materials/mission_board/circumstances/maelstrom_01" -- maelstrom skull, glowing
-- "content/ui/materials/icons/presets/preset_05" -- skull, gradient

C.STATUS_ICON_MATERIALS.netted         =
"content/ui/materials/mission_board/circumstances/special_waves_03" -- low int stg chevron, glowing
-- "content/ui/materials/mission_board/circumstances/special_waves_01" -- histg skull, glowing
-- "content/ui/materials/icons/presets/preset_17" -- grid globe, gradient

C.STATUS_ICON_MATERIALS.ledge_hanging  =
"content/ui/materials/mission_board/circumstances/maelstrom_01" -- maelstrom skull, glowing
-- "content/ui/materials/icons/presets/preset_05" -- skull, gradient

C.STATUS_ICON_MATERIALS.mutant_charged =
"content/ui/materials/mission_board/circumstances/less_resistance_01" -- downward chevron, glowing
-- "content/ui/materials/icons/presets/preset_18" -- fist, gradient

C.STATUS_ICON_MATERIALS.dead           =
"content/ui/materials/mission_board/circumstances/maelstrom_02" -- maelstrom winged skull, glowing
-- "content/ui/materials/icons/player_states/dead" -- default skull & crossbones, plain

C.STATUS_ICON_MATERIALS.hogtied        =
"content/ui/materials/mission_board/circumstances/maelstrom_02" -- maelstrom winged skull, glowing
-- "content/ui/materials/icons/player_states/dead" -- default skull & crossbones, plain

C.STATUS_ICON_MATERIALS.auspex         =
"content/ui/materials/icons/pocketables/hud/auspex_scanner"

C.STATUS_ICON_MATERIALS.luggable       =
"content/ui/materials/icons/player_states/lugged" -- default luggable status icon, included for completeness

return C
