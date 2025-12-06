-- File: RingHud/scripts/mods/RingHud/compat/who_are_you_bridge.lua
local mod = get_mod("RingHud")
local WRY = get_mod("who_are_you") -- other mod (optional)

local Bridge = {}

-- Is who_are_you present and enabled for the Team Panel?
local function _enabled_for_team()
    return WRY
        and WRY.is_enabled and WRY:is_enabled()
        and WRY.get and WRY:get("enable_team_panel")
end

-- Return cached account name only; never enqueue lookups or touch Presence.
local function _cached_account_name(account_id)
    if not (WRY and WRY._account_names and account_id) then return nil end
    local key  = tostring(account_id)
    local name = WRY._account_names[key]
    if not name then return nil end

    -- Mirror who_are_you: optionally strip BattleTag / identifier suffix
    if WRY.get and WRY:get("hide_identifier_tag") then
        name = name:gsub("#%d+$", "")
    end

    -- Mirror "unknown" guard (they use "N/A" or "[unknown]")
    if WRY.is_unknown and WRY.is_unknown(name) then
        return nil
    end

    return name
end

-- Detect a private-use glyph prefix (their platform icon) + optional space.
local function _split_icon_prefix(s)
    if not s or #s < 3 then return "", s end
    local b = string.byte(s, 1)
    if b == 0xEE then
        local icon = string.sub(s, 1, 3) -- "\xEE.."
        local rest = string.sub(s, 4)
        if string.sub(rest, 1, 1) == " " then rest = string.sub(rest, 2) end
        return icon .. " ", rest
    end
    return "", s
end

-- Apply sub-name styling for the Team Panel: size/color overrides + () + {#reset()}
local function _apply_style(sub_name, ref)
    local suffix = ""
    if WRY.get and WRY:get("enable_override_" .. ref) then
        suffix = "_" .. ref
    end

    local text = " (" .. sub_name .. "){#reset()}"

    if WRY.get and WRY:get("enable_custom_size" .. suffix) then
        local size = WRY:get("sub_name_size" .. suffix)
        if size then
            text = string.format("{#size(%s)}%s", tostring(size), text)
        end
    end

    if WRY.get and WRY:get("enable_custom_color" .. suffix) then
        local color_name = WRY:get("custom_color" .. suffix)
        if color_name and Color and Color[color_name] then
            local c = Color[color_name](255, true) -- {a,r,g,b}
            text = string.format("{#color(%d,%d,%d)}%s", c[2], c[3], c[4], text)
        end
    end

    return text
end

-- ########## NEW: structured, safe getters ##########

-- Returns a table { primary, secondary_styled } or nil.
-- * primary            : plain text (no markup) chosen by WAY's display_style (character/account),
--                        with platform icon moved per setting.
-- * secondary_styled   : fully-styled substring for the "other" name (parens/size/color via WAY settings),
--                        or nil if none.
-- Uses ONLY cached data (WRY._account_names) — never triggers lookups.
function Bridge.parts_for_player(player)
    if not (_enabled_for_team() and player) then return nil end

    local profile       = player:profile()
    local character_raw = (profile and profile.name) or (player.name and player:name()) or "?"
    local account_id    = player:account_id()
    local account_name  = _cached_account_name(account_id)
    if not account_name then
        -- Not ready: tell caller to fall back to character name.
        return nil
    end

    local disp      = (WRY and (WRY.current_style or (WRY.get and WRY:get("display_style")))) or "character_first"
    local icon_mode = (WRY and WRY.get and WRY:get("platform_icon")) or "account_only"
    local show_self = (WRY and WRY.get and WRY:get("enable_display_self")) ~= false

    -- Hide secondary for self if WAY says so
    if not show_self then
        local lp = Managers.player and Managers.player:local_player_safe(1)
        if lp and (lp:account_id() == account_id) then
            -- Just return whichever is primary, no secondary.
            if disp == "account_only" or disp == "account_first" then
                local _, acc_wo = _split_icon_prefix(account_name)
                return { primary = acc_wo, secondary_styled = nil }
            else
                -- character primary
                return { primary = character_raw, secondary_styled = nil }
            end
        end
    end

    -- Platform icon relocation
    local icon, acc_wo   = _split_icon_prefix(account_name)
    local char_with_icon = character_raw
    local acc_with_icon  = account_name

    if icon_mode == "off" then
        acc_with_icon = acc_wo
        -- character stays as-is (no icon)
    elseif icon_mode == "character_only" then
        acc_with_icon  = acc_wo
        char_with_icon = (icon ~= "" and (icon .. character_raw)) or character_raw
    else
        -- account_only: keep icon inside account name
    end

    if disp == "character_only" then
        return { primary = char_with_icon, secondary_styled = nil }
    elseif disp == "account_only" then
        return { primary = acc_with_icon, secondary_styled = nil }
    elseif disp == "character_first" then
        return {
            primary = char_with_icon,
            secondary_styled = _apply_style(acc_with_icon, "team_panel"),
        }
    elseif disp == "account_first" then
        return {
            primary = acc_with_icon,
            secondary_styled = _apply_style(char_with_icon, "team_panel"),
        }
    else
        -- Fallback: character primary
        return { primary = char_with_icon, secondary_styled = nil }
    end
end

-- Convenience: return "<primary><secondary_styled or ''>" with NO RingHud tint.
-- This mirrors what WRU sets into the vanilla Team HUD `player_name` widget.
function Bridge.compose_team_panel_name(player)
    if not _enabled_for_team() then return nil end
    local p = Bridge.parts_for_player(player)
    if not p then return nil end
    local s = tostring(p.primary or "")
    if p.secondary_styled and p.secondary_styled ~= "" then
        s = s .. p.secondary_styled
    end
    return s
end

-- Convenience: return the final slot-colored string "<colored primary><secondary_styled or ''>"
function Bridge.compose_slot_tinted(player, tint_argb255)
    local p = Bridge.parts_for_player(player)
    if not p then return nil end
    local r, g, b = (tint_argb255 and tint_argb255[2] or 255), (tint_argb255 and tint_argb255[3] or 255),
        (tint_argb255 and tint_argb255[4] or 255)
    local first   = string.format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, p.primary or "")
    if p.secondary_styled and p.secondary_styled ~= "" then
        return first .. p.secondary_styled
    else
        return first
    end
end

-- ########## Back-compat API you already had ##########

-- Public: build the decorated name for Team HUD using who_are_you’s cache only.
-- Returns nil if we should fall back to the base character name (e.g., cache not ready).
function Bridge.decorate(player, base_character_name)
    if not _enabled_for_team() or not player then return nil end

    local account_id   = player:account_id()
    local account_name = _cached_account_name(account_id)
    if not account_name then return nil end

    local name      = base_character_name or (player.name and player:name()) or "?"
    local disp      = (WRY and (WRY.current_style or (WRY.get and WRY:get("display_style")))) or "character_first"
    local icon_mode = (WRY and WRY.get and WRY:get("platform_icon")) or "account_only"
    local show_self = (WRY and WRY.get and WRY:get("enable_display_self")) ~= false

    -- Move/remove platform icon per setting
    do
        local icon, acc_wo = _split_icon_prefix(account_name)
        if icon_mode == "off" then
            account_name = acc_wo
        elseif icon_mode == "character_only" then
            account_name = acc_wo
            if icon ~= "" then name = icon .. name end
        else
            -- account_only: keep icon in account_name
        end
    end

    -- Hide self if who_are_you says so
    if not show_self then
        local lp = Managers.player and Managers.player:local_player_safe(1)
        if lp and (lp:account_id() == account_id) then
            return name
        end
    end

    -- Compose per display style
    if disp == "character_only" then
        return name
    elseif disp == "account_only" then
        return account_name
    elseif disp == "character_first" then
        return name .. _apply_style(account_name, "team_panel")
    elseif disp == "account_first" then
        return account_name .. _apply_style(name, "team_panel")
    else
        return name
    end
end

-- Expose on the mod namespace for cross-file access (and also return it)
mod.who_are_you_bridge = Bridge
return Bridge
