---@alias use_migrations_r {
---run_setting_migrations: run_setting_migrations,}
---@alias use_migrations fun() : use_migrations_r

---@type use_migrations
local function use_migrations()
    ---@param updates table
    ---@return integer
    local function get_latest_version(updates)
        return #updates
    end

    ---@alias run_setting_migrations fun(mod: dmf_mod)
    ---@type run_setting_migrations
    local function run_setting_migrations(mod)
        local updates = {
            {
                nexus_version = '1',
                changes = function()

                end
            },
            {
                nexus_version = '1.1',
                changes = function()
                    local display_mode_setting_id = "select_display_mode"
                    local current = mod:get(display_mode_setting_id)
                    if current == "class_then_talent" then
                        mod:set(display_mode_setting_id, "class_talent")
                    elseif current == "talent_then_class" then
                        mod:set(display_mode_setting_id, "talent_class")
                    elseif current == "class_only" then
                        mod:set(display_mode_setting_id, "class")
                    elseif current == "talent_only" then
                        mod:set(display_mode_setting_id, "talent")
                    end
                end
            }
        }

        local latest_version = get_latest_version(updates)

        for version = 1, latest_version do
            updates[version].changes()
        end
    end

    return {
        run_setting_migrations = run_setting_migrations
    }
end

return use_migrations
