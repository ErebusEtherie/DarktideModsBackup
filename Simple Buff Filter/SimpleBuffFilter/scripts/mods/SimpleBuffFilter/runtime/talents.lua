-- File: scripts/mods/SimpleBuffFilter/runtime/talents.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
talents.lua — resolver for talent buffs.
Returns the group (archetype) and localization key if the buff matches a talent.

Updated:
• Use mod.tbf_buff.template_name_for_talent() (Option B) for talent lookup,
  while keeping the raw template identity intact for other systems.
• Hardcoded overrides checked against both raw and aliased ids (raw first).
]]

mod.tbf_talents = mod.tbf_talents or {}

-- Returns: group (string), loc_key (string) -- or nil, nil
function mod.tbf_talents.resolve(buff)
    local t = mod.tbf_buff.template_from(buff)

    -- Raw identity (prefs/rules/etc.)
    local tname_raw = mod.tbf_buff.template_name(buff)

    -- FALLBACK: If introspect failed (no hud_icon), use raw template name.
    -- This is critical for resolving "parent" buffs that have no icon but hold the talent link.
    if not tname_raw and t and type(t.name) == "string" then
        tname_raw = t.name
    end

    -- Talent-resolution identity (Option B normalization)
    local tname = tname_raw
    if mod.tbf_buff.template_name_for_talent then
        tname = mod.tbf_buff.template_name_for_talent(buff) or tname_raw
    end

    local Resolve = mod.resolve or mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/resolve")
    if not Resolve then return nil, nil end

    -- 0. Check hardcoded overrides first (raw first, then alias if different)
    if Resolve.static_misc_loc_key_for_template then
        local override_loc = nil
        local override_id = nil

        if tname_raw then
            override_loc = Resolve.static_misc_loc_key_for_template(tname_raw)
            override_id = tname_raw
        end

        if not override_loc and tname and tname ~= tname_raw then
            override_loc = Resolve.static_misc_loc_key_for_template(tname)
            override_id = tname
        end

        if override_loc and override_id then
            local arch = Resolve.archetype_from_talent_id(override_id)
            if arch then
                return arch, override_loc
            end
        end
    end

    -- 1. Check template for explicit related_talents
    local rel = t and (t.related_talents or t.realted_talents or t.related_talent)
    local talent_id = (type(rel) == "table" and rel[1]) or (type(rel) == "string" and rel) or nil

    if talent_id then
        local arch = Resolve.archetype_from_talent_id(talent_id)
        local disp = Resolve.talent_display_name_loc(arch, talent_id)
        if arch and disp then
            return arch, disp
        end
    end

    -- 2. Check for parent buff (Internally Controlled Buff relationship)
    -- Some buffs are children of another buff which holds the talent link.
    -- We try to resolve the parent recursively.
    if type(buff) == "table" then
        local parent_index = buff._parent_buff_index
        if parent_index then
            -- Use the unit on the buff instance to find the extension.
            local unit = buff._unit
            if unit and ScriptUnit.has_extension(unit, "buff_system") then
                local buff_ext = ScriptUnit.extension(unit, "buff_system")
                local buffs = buff_ext._buffs -- Standard engine access
                if buffs then
                    local parent = buffs[parent_index]
                    -- Ensure we found a buff and avoid infinite recursion
                    if parent and parent ~= buff then
                        local p_arch, p_disp = mod.tbf_talents.resolve(parent)
                        if p_arch and p_disp then
                            return p_arch, p_disp
                        end
                    end
                end
            end
        end
    end

    -- 3. Fallback: Try to match the template name to a talent ID
    -- Prefer the talent-normalized id (Option B), but also try raw if different.
    if tname then
        local arch, tid, disp = Resolve.talent_from_template_key(t, tname)
        if arch and tid and disp then
            return arch, disp
        end
    end

    if tname_raw and tname_raw ~= tname then
        local arch, tid, disp = Resolve.talent_from_template_key(t, tname_raw)
        if arch and tid and disp then
            return arch, disp
        end
    end

    return nil, nil
end
