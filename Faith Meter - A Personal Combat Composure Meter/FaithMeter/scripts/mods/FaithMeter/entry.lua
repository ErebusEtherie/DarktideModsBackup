local mod = get_mod("FaithMeter")

-- Thin entrypoint to reduce DMF init fragility.
-- If a downstream file has an encoding/syntax issue, we log it instead of failing in DMF's loader.
local ok, err = pcall(function()
    require("scripts/mods/FaithMeter/FaithMeter")
end)

if not ok then
    mod:echo("[FaithMeter] Failed to load main script. Please reinstall the mod (avoid editing with Notepad).")
    mod:echo(tostring(err))
end
