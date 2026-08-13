function migrate_v1_to_v2(entry_v1, current_date)
    for buff_name, buff in ipairs(entry_v1.buffs) do
        buff.name = buff_name
    end
    entry_v1.meta_data.date = current_date
end

return migrate_v1_to_v2