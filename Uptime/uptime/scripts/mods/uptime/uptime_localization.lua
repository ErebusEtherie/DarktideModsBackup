local mod = get_mod("uptime")
mod:add_global_localize_strings({
    loc_delete_entry = {
        en = "Delete entry",
        ["zh-cn"] = "删除条目",
        ["zh-tw"] = "刪除項目",
    },
    loc_scan_folder = {
        en = "Scan directory for files",
        ["zh-cn"] = "扫描目录中的文件",
        ["zh-tw"] = "掃描目錄中的檔案",
    },
})

return {
    mission_duration = {
        -- first %s: mission time (format mm:ss)
        -- second %s: combat time (format mm:ss)
        -- third %s: combat percentage
        en = "Mission duration: %s - Combat duration: %s (%s)",
        ["zh-cn"] = "任务时长: %s - 战斗时长: %s (%s)",
        ["zh-tw"] = "任務總時: %s - 戰鬥時間: %s (%s)",
    },
    mod_description = {
        en = "Tracks uptime of buffs.",
        ["zh-cn"] = "追踪增益效果的持续时间",
        ["zh-tw"] = "追蹤增益效果的持續時間"
    },
    loc_uptime_header = {
        en = "uptime",
        ["zh-cn"] = "持续时间",
        ["zh-tw"] = "持續時間",
    },
    loc_avg_stacks_header = {
        en = "Avg Stacks",
        ["zh-cn"] = "平均层数",
        ["zh-tw"] = "平均層數",
    },
    loc_percentage_at_max_stacks_header = {
        en = "Max stacks",
        ["zh-cn"] = "最大层数",
        ["zh-tw"] = "最大層數",
    },
    loc_talent_header = {
        en = "From talent",
        ["zh-cn"] = "天赋来源",
        ["zh-tw"] = "天賦來源",
    },
    loc_percentage_per_stack = {
        en = "Uptime (by Stack)",
        ["zh-cn"] = "持续时间(按层数)",
        ["zh-tw"] = "持續時間(按層數)",
    },

    -- general settings
    open_uptime_history = {
        en = "Open Uptime History",
        ["zh-cn"] = "打开持续时间记录",
        ["zh-tw"] = "打開持續時間記錄",
    },
    track_meat_grinder = {
        en = "Track Uptime in Meat Grinder / Psykanium"
    },
    save_files_options = {
        en = "Save Files",
    },
    delete_old_entries = {
        en = "Automatically delete old files",
    },
    number_of_save_files = {
        en = "Number of save files to keep"
    },
    data_display_settings = {
        en = "Data columns",
        ["zh-cn"] = "数据列设置",
        ["zh-tw"] = "數據列設置",
    },
    -- table columns & their settings

    show_uptime = {
        en = "Total uptime",
        ["zh-cn"] = "总持续时间",
        ["zh-tw"] = "總持續時間",
    },
    show_uptime_percentage = {
        en = "uptime percentage",
        ["zh-cn"] = "持续时间百分比",
        ["zh-tw"] = "持續時間百分比",
    },
    loc_uptime_percentage_header = {
        en = "uptime",
        ["zh-cn"] = "持续时间",
        ["zh-tw"] = "持續時間",
    },

    show_uptime_combat = {
        en = "Total uptime during combat",
        ["zh-cn"] = "战斗总持续时间",
        ["zh-tw"] = "戰鬥總持續時間",
    },
    loc_uptime_combat_header = {
        en = "uptime (combat)",
        ["zh-cn"] = "持续时间(战斗)",
        ["zh-tw"] = "持續時間(戰鬥)",
    },

    show_uptime_combat_percentage = {
        en = "Uptime percentage during combat",
        ["zh-cn"] = "战斗持续时间百分比",
        ["zh-tw"] = "戰鬥持續時間百分比",
    },
    loc_uptime_combat_percentage_header = {
        en = "uptime (combat)",
        ["zh-cn"] = "持续时间(战斗)",
        ["zh-tw"] = "持續時間(戰鬥)",
    },

    show_combat_percentage_per_stack = {
        en = "Stack distribution during combat",
        ["zh-cn"] = "战斗中层数分布",
        ["zh-tw"] = "戰鬥中層數分布",
    },
    loc_combat_percentage_per_stack_header = {
        en = "Uptime (combat) by stack",
        ["zh-cn"] = "战斗持续时间(按层数)",
        ["zh-tw"] = "戰鬥持續時間(按層數)",
    },

    show_combat_time_at_max_stack = {
        en = "Total time at max stacks during combat",
        ["zh-cn"] = "战斗期间处于最大层数的总时间",
        ["zh-tw"] = "戰鬥期間處於最大層數的總時間",
    },
    loc_combat_time_at_max_stack_header = {
        en = "Time at max (combat)",
        ["zh-cn"] = "最大层数时间(战斗)",
        ["zh-tw"] = "最大層數時間(戰鬥)",
    },

    show_combat_percentage_at_max_stack = {
        en = "Percentage of uptime during combat at max stack",
        ["zh-cn"] = "战斗期间处于最大层数的持续时间百分比",
        ["zh-tw"] = "戰鬥期間處於最大層數的持續時間百分比",
    },
    loc_combat_percentage_at_max_stack_header = {
        en = "Percentage at max (combat)",
        ["zh-cn"] = "最大层数百分比(战斗)",
        ["zh-tw"] = "最大層數百分比(戰鬥)",
    },

    show_average_stacks_combat = {
        en = "Average stack count during combat",
        ["zh-cn"] = "战斗期间平均层数",
        ["zh-tw"] = "戰鬥期間平均層數",
    },
    loc_average_stacks_combat_header = {
        en = "Average stack (combat)",
        ["zh-cn"] = "平均层数(战斗)",
        ["zh-tw"] = "平均層數(戰鬥)",
    },

    loc_unknown_blessing = {
        en = "Unkown blessing",
        ["zh-cn"] = "未知祝福",
        ["zh-tw"] = "未知祝福",
    }
}