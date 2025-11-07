local mod = get_mod("uptime")

function DEBUG()
    return false
end

function mod:debug(msg)
    if DEBUG() then
        mod:echo(msg)
    end
end

function mod:print_keys(table)
    for key, _ in pairs(table) do
        mod:echo(key)
    end
end

return {
    print_keys = mod.print_keys
}