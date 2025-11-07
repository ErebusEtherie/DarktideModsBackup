local mod = get_mod("MoreGraphicsOptions")

mod:add_global_localize_strings({
    loc_settings_menu_very_low = {
        en = "Very Low",
        ["zh-cn"] = "非常低",
        ru = "Очень низкие",
    },
})

return {
    mod_description = {
        -- en = "MoreGraphicsOptions",
    },
    apply = {
        en = "Apply changes"
    },
    meshquality = {
        en = "Mesh Quality",
        ["zh-cn"] = "网格质量",
    },
    particles_capacity_multiplier = {
        en = "Particles Capacity Multiplier",
        ["zh-cn"] = "粒子容量倍数",
    },
    maxragdolls = {
        en = "Max Ragdolls",
        ["zh-cn"] = "最大布娃娃数量",
    },
    maximpactdecals = {
        en = "Max Impact Decals",
        ["zh-cn"] = "最大弹痕贴花数量",
    },
    maxblooddecals = {
        en = "Max Blood Decals",
        ["zh-cn"] = "最大血迹贴花数量",
    },
    decallifetime = {
        en = "Decal Lifetime",
        ["zh-cn"] = "贴花持续时间",
    },
    keybinds = {
        en = "Keybinds",
        ["zh-cn"] = "快捷键",
    },
    performancesettings = {
        en = "Performance Settings",
        ["zh-cn"] = "性能设置",
    },
    rendersettings = {
        en = "Render Settings",
        ["zh-cn"] = "渲染设置",
    },
    lightquality = {
        en = "Light Quality",
        ["zh-cn"] = "照明质量",
    },
    sunshadows = {
        en = "Sun Shadows",
        ["zh-cn"] = "日光阴影",
    },
    local_lights_shadows_enabled = {
        en = "Local Light Shadows",
        ["zh-cn"] = "局部光照阴影",
    },
    static_sun_shadows = {
        en = "Static Sun Shadows",
        ["zh-cn"] = "静态日光阴影",
    },
    sun_shadow_map_size = {
        en = "Sun Shadows Map Size",
        ["zh-cn"] = "日光阴影映射大小",
    },
    static_sun_shadow_map_size = {
        en = "Static Sun Shadows Map Size",
        ["zh-cn"] = "静态日光阴影映射大小",
    },
    local_lights_shadow_atlas_size = {
        en = "Local Lights Shadows Atlas Size"
    },
    four = {
        en = "4"
    },
    two56 = {
        en = "256"
    },
    five12 = {
        en = "512"
    },
    one024 = {
        en = "1024"
    },
    two048 = {
        en = "2048"
    },
    volumetricfogquality = {
        en = "Volumetric Fog Quality",
        ["zh-cn"] = "体积雾质量",
    },
    Volenabled = {
        en = "Enabled",
        ["zh-cn"] = "启用",
    },
    high_quality = {
        en = "High Quality",
        ["zh-cn"] = "高质量",
    },
    volumetric_shadows = {
        en = "Volumetric Shadows",
        ["zh-cn"] = "体积阴影",
    },
    light_shafts = {
        en = "Light Shafts",
        ["zh-cn"] = "光轴渲染",
    },
    volumetric_local_lights = {
        en = "Volumetric Local Lights",
        ["zh-cn"] = "体积局部光照",
    },
    GIenabled = {
        en = "Enabled",
        ["zh-cn"] = "启用",
    },
    globalillumination = {
        en = "Global Illumination",
        ["zh-cn"] = "全局照明",
    },
    rtxgi_scale = {
        en = "RTXGI Scale",
        ["zh-cn"] = "RTXGI 比例",
    },
}
