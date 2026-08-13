-- File: scripts/mods/SimpleBuffFilter/runtime/misc.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
misc.lua – resolver for miscellaneous buffs.
Returns the group ("misc") and localization key if the buff is identified.
]]

-- Depends on:
--   • runtime/buff_introspect.lua (mod.tbf_buff.*)
--   • runtime/context.lua         (mod.tbf_ctx.*)
--   • util/resolve.lua            (mod.resolve.*)

mod.tbf_misc = mod.tbf_misc or {}

-- Small helper: fetch (or create) the per-buff memo cache
local function _cache_for(buff)
    local c = rawget(buff, "_tbf_misc_cache")
    if not c then
        c = {}
        rawset(buff, "_tbf_misc_cache", c)
    end
    return c
end

-- ----------------------------------------------------------------------------
-- ID + label token resolution (breed/prop/hazard-group + syringe-aware + display_title)
-- ----------------------------------------------------------------------------
-- Returns: id (string), loc_token (string) -- or nil, nil
function mod.tbf_misc.id_and_label(buff)
    local t  = mod.tbf_buff.template_from(buff)
    local id = mod.tbf_buff and mod.tbf_buff.template_name and mod.tbf_buff.template_name(buff)
    if not id then return nil, nil end

    local Resolve = mod.resolve or mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/resolve")
    local cache   = _cache_for(buff)

    -- Breed-group override (memoized)
    do
        local breed_loc = cache.breed_loc
        if breed_loc == nil and Resolve and Resolve.breed_loc_key_from_buff_template then
            breed_loc = Resolve.breed_loc_key_from_buff_template(t)
            cache.breed_loc = breed_loc or false
        end
        if breed_loc == false then breed_loc = nil end
        if breed_loc then
            return id, breed_loc
        end
    end

    -- prop_* group (negative + hud_icon, no breed match) (memoized)
    do
        local prop_loc = cache.prop_loc
        if prop_loc == nil and Resolve and Resolve.prop_group_loc_key_from_buff_template then
            prop_loc = Resolve.prop_group_loc_key_from_buff_template(t)
            cache.prop_loc = prop_loc or false
        end
        if prop_loc == false then prop_loc = nil end
        if prop_loc then
            return id, prop_loc
        end
    end

    -- toxic-gas hazard group (negative + hud_icon; *_toxic_gas) (memoized)
    do
        local hazard_loc = cache.hazard_loc
        if hazard_loc == nil and Resolve and Resolve.hazard_group_loc_key_from_buff_template then
            hazard_loc = Resolve.hazard_group_loc_key_from_buff_template(t, id)
            cache.hazard_loc = hazard_loc or false
        end
        if hazard_loc == false then hazard_loc = nil end
        if hazard_loc then
            return id, hazard_loc
        end
    end

    -- knocked_down_* group (hud_icon) (memoized)
    do
        local kd_loc = cache.knocked_down_loc
        if kd_loc == nil and Resolve and Resolve.knocked_down_group_loc_key_from_buff_template then
            kd_loc = Resolve.knocked_down_group_loc_key_from_buff_template(t)
            cache.knocked_down_loc = kd_loc or false
        end
        if kd_loc == false then kd_loc = nil end
        if kd_loc then
            return id, kd_loc
        end
    end

    -- Explicit per-template hardcoded loc (from Resolve) with MISSING-LOC FALLBACK
    do
        local forced = cache.static_loc_from_id
        if forced == nil and Resolve and Resolve.static_misc_loc_key_for_template then
            forced = Resolve.static_misc_loc_key_for_template(id)
            cache.static_loc_from_id = forced or false
        end
        if forced and forced ~= false then
            local s = _G.Localize and _G.Localize(forced)
            if type(s) == "string" and s ~= ("<" .. forced .. ">") then
                return id, forced
            end
        end

        local tkey = t and t.name
        local forced2 = cache.static_loc_from_tkey
        if forced2 == nil and type(tkey) == "string" and tkey ~= "" and Resolve and Resolve.static_misc_loc_key_for_template then
            forced2 = Resolve.static_misc_loc_key_for_template(tkey)
            cache.static_loc_from_tkey = forced2 or false
        end
        if forced2 and forced2 ~= false then
            local s2 = _G.Localize and _G.Localize(forced2)
            if type(s2) == "string" and s2 ~= ("<" .. forced2 .. ">") then
                return id, forced2
            end
        end
    end

    -- Player-buff templates with hud_icon + display_title → use display_title (loc_*) (memoized)
    do
        local disp_loc = cache.display_title_loc
        if disp_loc == nil then
            local is_arch_prefixed = Resolve and Resolve.is_archetype_prefixed_name and
                Resolve.is_archetype_prefixed_name(id)
            if t and t.hud_icon and not is_arch_prefixed then
                disp_loc = Resolve and Resolve.player_buff_display_title_loc and
                    Resolve.player_buff_display_title_loc(id)
                cache.display_title_loc = disp_loc or false
            else
                cache.display_title_loc = false
            end
        end
        if disp_loc == false then disp_loc = nil end
        if disp_loc then
            return id, disp_loc
        end
    end

    -- Syringe override: prefer proper pickup loc_* if available (memoized)
    do
        local s_loc = cache.syringe_loc
        if s_loc == nil then
            s_loc = mod.syringe_loc_for_buff and mod.syringe_loc_for_buff(id, nil)
            cache.syringe_loc = s_loc or false
        end
        if s_loc == false then s_loc = nil end
        if s_loc and type(s_loc) == "string" and s_loc:find("^loc_") then
            return id, s_loc
        end
    end

    -- Fallback: raw id as label token if it has a hud_icon
    if t and t.hud_icon then
        return id, id
    end

    return nil, nil
end

-- ----------------------------------------------------------------------------
-- Public Resolver
-- ----------------------------------------------------------------------------
-- Returns: group (string), loc_key (string) -- or nil, nil
function mod.tbf_misc.resolve(buff)
    local id, loc_token = mod.tbf_misc.id_and_label(buff)
    if id and loc_token then
        -- For miscellaneous buffs, the group is simply "misc"
        return "misc", loc_token
    end
    return nil, nil
end
