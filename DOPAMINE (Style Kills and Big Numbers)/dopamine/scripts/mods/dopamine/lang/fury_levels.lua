---@type mod
local mod = get_mod("dopamine")

local function fury_rank_color(rank)
	return mod.constants.COLOR.FURY_RANK[rank] or mod.constants.COLOR.UI_FOREGROUND
end

local function color_letters(rank, text)
	return (text and rank and mod.dl.str.rich_text(rank, { color = fury_rank_color(rank) }) .. text:sub(#rank + 1))
		or text
end

local function prefix(rank, text)
	return (text and rank and mod.dl.str.rich_text(rank .. " - ", { color = fury_rank_color(rank) }) .. text) or text
end

return {

	fury_level_D = {
		en = color_letters("D", "DEVOUT"),
		["zh-cn"] = prefix("D", "虔诚者"),
	},
	fury_level_C = {
		en = color_letters("C", "CONVICTED"),
		["zh-cn"] = prefix("C", "罪罚者"),
	},
	fury_level_B = {
		en = color_letters("B", "BLESSED"),
		["zh-cn"] = prefix("B", "受福者"),
	},
	fury_level_A = {
		en = color_letters("A", "ANOINTED"),
		["zh-cn"] = prefix("A", "受膏者"),
	},
	fury_level_S = {
		en = color_letters("S", "SANCTIFIED"),
		["zh-cn"] = prefix("S", "圣洁者"),
	},
	fury_level_SS = {
		en = color_letters("SS", "SSERAPHIC"),
		["zh-cn"] = prefix("SS", "炽天使"),
	},
	fury_level_SSS = {
		en = color_letters("SSS", "SSSAINTED"),
		["zh-cn"] = prefix("SSS", "至圣者"),
	},
	fury_level_X = {
		en = "E" .. color_letters("X", "XALTED"),
		["zh-cn"] = prefix("X", "至高者"),
	},
	fury_level_XX = {
		en = "E" .. color_letters("XX", "XXCISED"),
		["zh-cn"] = prefix("XX", "净化者"),
	},

	fury_level_D_veteran = {
		en = color_letters("D", "DISCIPLINED"),
		["zh-cn"] = prefix("D", "自律者"),
	},
	fury_level_C_veteran = {
		en = color_letters("C", "COMBATANT"),
		["zh-cn"] = prefix("C", "战斗员"),
	},
	fury_level_B_veteran = {
		en = color_letters("B", "BATTLE-HARDENED"),
		["zh-cn"] = prefix("B", "久经沙场"),
	},
	fury_level_A_veteran = {
		en = color_letters("A", "ACE"),
		["zh-cn"] = prefix("A", "王牌"),
	},
	fury_level_S_veteran = {
		en = color_letters("S", "SHARPSHOOTER"),
		["zh-cn"] = prefix("S", "神射手"),
	},
	fury_level_SS_veteran = {
		en = color_letters("SS", "SSEASONED"),
		["zh-cn"] = prefix("SS", "沙场老手"),
	},
	fury_level_SSS_veteran = {
		en = color_letters("SSS", "SSSUPREME"),
		["zh-cn"] = prefix("SSS", "无双战将"),
	},
	fury_level_X_veteran = {
		en = "E" .. color_letters("X", "XEMPLARY"),
		["zh-cn"] = prefix("X", "典范"),
	},
	fury_level_XX_veteran = {
		en = "E" .. color_letters("XX", "XXECUTIONER"),
		["zh-cn"] = prefix("XX", "行刑官"),
	},

	fury_level_D_zealot = {
		en = color_letters("D", "DEVOUT"),
		["zh-cn"] = prefix("D", "虔诚者"),
	},
	fury_level_C_zealot = {
		en = color_letters("C", "CONVICTED"),
		["zh-cn"] = prefix("C", "罪罚者"),
	},
	fury_level_B_zealot = {
		en = color_letters("B", "BLESSED"),
		["zh-cn"] = prefix("B", "受福者"),
	},
	fury_level_A_zealot = {
		en = color_letters("A", "ANOINTED"),
		["zh-cn"] = prefix("A", "受膏者"),
	},
	fury_level_S_zealot = {
		en = color_letters("S", "SANCTIFIED"),
		["zh-cn"] = prefix("S", "圣洁者"),
	},
	fury_level_SS_zealot = {
		en = color_letters("SS", "SSERAPHIC"),
		["zh-cn"] = prefix("SS", "炽天使"),
	},
	fury_level_SSS_zealot = {
		en = color_letters("SSS", "SSSAINTED"),
		["zh-cn"] = prefix("SSS", "至圣者"),
	},
	fury_level_X_zealot = {
		en = "E" .. color_letters("X", "XALTED"),
		["zh-cn"] = prefix("X", "至高者"),
	},
	fury_level_XX_zealot = {
		en = "E" .. color_letters("XX", "XXCISED"),
		["zh-cn"] = prefix("XX", "净化者"),
	},

	fury_level_D_psyker = {
		en = color_letters("D", "DISCIPLINED"),
		["zh-cn"] = prefix("D", "自律者"),
	},
	fury_level_C_psyker = {
		en = color_letters("C", "CHANNELING"),
		["zh-cn"] = prefix("C", "引导者"),
	},
	fury_level_B_psyker = {
		en = color_letters("B", "BRAINBURST"),
		["zh-cn"] = prefix("B", "脑爆者"),
	},
	fury_level_A_psyker = {
		en = color_letters("A", "ASCENDANT"),
		["zh-cn"] = prefix("A", "升华者"),
	},
	fury_level_S_psyker = {
		en = color_letters("S", "SOULFIRE"),
		["zh-cn"] = prefix("S", "灵魂之火"),
	},
	fury_level_SS_psyker = {
		en = color_letters("SS", "SSHATTERMIND"),
		["zh-cn"] = prefix("SS", "碎灵者"),
	},
	fury_level_SSS_psyker = {
		en = color_letters("SSS", "SSSINGULARITY"),
		["zh-cn"] = prefix("SSS", "奇点掌控者"),
	},
	fury_level_X_psyker = {
		en = "E" .. color_letters("X", "XCORIATING"),
		["zh-cn"] = prefix("X", "灼魂者"),
	},
	fury_level_XX_psyker = {
		en = "E" .. color_letters("XX", "XXCISED"),
		["zh-cn"] = prefix("XX", "灵体净化者"),
	},

	fury_level_D_ogryn = {
		en = color_letters("D", "DA BOSS"),
		["zh-cn"] = prefix("D", "老大"),
	},
	fury_level_C_ogryn = {
		en = color_letters("C", "CRUSHIN'"),
		["zh-cn"] = prefix("C", "碾压者"),
	},
	fury_level_B_ogryn = {
		en = color_letters("B", "BIG LAD"),
		["zh-cn"] = prefix("B", "大个子"),
	},
	fury_level_A_ogryn = {
		en = color_letters("A", "ABSOLUTE UNIT"),
		["zh-cn"] = prefix("A", "绝对巨物"),
	},
	fury_level_S_ogryn = {
		en = color_letters("S", "SLAB"),
		["zh-cn"] = prefix("S", "厚板硬汉"),
	},
	fury_level_SS_ogryn = {
		en = color_letters("SS", "SSUPA SLAB"),
		["zh-cn"] = prefix("SS", "超级硬汉"),
	},
	fury_level_SSS_ogryn = {
		en = color_letters("SSS", "SSSTRONGEST"),
		["zh-cn"] = prefix("SSS", "最强壮汉"),
	},
	fury_level_X_ogryn = {
		en = "E" .. color_letters("X", "XTRA BIG"),
		["zh-cn"] = prefix("X", "超大个"),
	},
	fury_level_XX_ogryn = {
		en = "E" .. color_letters("XX", "XXTREEM"),
		["zh-cn"] = prefix("XX", "巨兽"),
	},

	fury_level_D_skitarii = {
		en = color_letters("D", "DIAGNOSTIC"),
		["zh-cn"] = prefix("D", "诊断者"),
	},
	fury_level_C_skitarii = {
		en = color_letters("C", "CALIBRATED"),
		["zh-cn"] = prefix("C", "校准者"),
	},
	fury_level_B_skitarii = {
		en = color_letters("B", "BINHARIC"),
		["zh-cn"] = prefix("B", "二进制信使"),
	},
	fury_level_A_skitarii = {
		en = color_letters("A", "AUGMENTED"),
		["zh-cn"] = prefix("A", "强化者"),
	},
	fury_level_S_skitarii = {
		en = color_letters("S", "SYNCHRONISED"),
		["zh-cn"] = prefix("S", "同步执行者"),
	},
	fury_level_SS_skitarii = {
		en = color_letters("SS", "SSANCTIFIED"),
		["zh-cn"] = prefix("SS", "圣洁者"),
	},
	fury_level_SSS_skitarii = {
		en = color_letters("SSS", "SSSYSTEM PRIME"),
		["zh-cn"] = prefix("SSS", "主系统载体"),
	},
	fury_level_X_skitarii = {
		en = "E" .. color_letters("X", "XCISED"),
		["zh-cn"] = prefix("X", "净化者"),
	},
	fury_level_XX_skitarii = {
		en = "E" .. color_letters("XX", "XXPUNGED"),
		["zh-cn"] = prefix("XX", "根除者"),
	},

	fury_level_D_arbites = {
		en = color_letters("D", "DEPUTIZED"),
		["zh-cn"] = prefix("D", "委任者"),
	},
	fury_level_C_arbites = {
		en = color_letters("C", "CONSTABLE"),
		["zh-cn"] = prefix("C", "治安官"),
	},
	fury_level_B_arbites = {
		en = color_letters("B", "BAILIFF"),
		["zh-cn"] = prefix("B", "执达吏"),
	},
	fury_level_A_arbites = {
		en = color_letters("A", "ARBITRATOR"),
		["zh-cn"] = prefix("A", "仲裁者"),
	},
	fury_level_S_arbites = {
		en = color_letters("S", "SENTENCER"),
		["zh-cn"] = prefix("S", "判官"),
	},
	fury_level_SS_arbites = {
		en = color_letters("SS", "SSUBJUGATOR"),
		["zh-cn"] = prefix("SS", "镇压官"),
	},
	fury_level_SSS_arbites = {
		en = color_letters("SSS", "SSSENTINEL"),
		["zh-cn"] = prefix("SSS", "守望执法者"),
	},
	fury_level_X_arbites = {
		en = "E" .. color_letters("X", "XACTING"),
		["zh-cn"] = prefix("X", "严苛者"),
	},
	fury_level_XX_arbites = {
		en = "E" .. color_letters("XX", "XXECUTIONER"),
		["zh-cn"] = prefix("XX", "行刑执行官"),
	},

	fury_level_D_broker = {
		en = color_letters("D", "DRIFTER"),
		["zh-cn"] = prefix("D", "漂泊者"),
	},
	fury_level_C_broker = {
		en = color_letters("C", "CUTTHROAT"),
		["zh-cn"] = prefix("C", "割喉者"),
	},
	fury_level_B_broker = {
		en = color_letters("B", "BRAWLER"),
		["zh-cn"] = prefix("B", "斗殴者"),
	},
	fury_level_A_broker = {
		en = color_letters("A", "APEX"),
		["zh-cn"] = prefix("A", "顶尖者"),
	},
	fury_level_S_broker = {
		en = color_letters("S", "SCOURGE"),
		["zh-cn"] = prefix("S", "灾祸"),
	},
	fury_level_SS_broker = {
		en = color_letters("SS", "SSLUMLORD"),
		["zh-cn"] = prefix("SS", "窝棚霸主"),
	},
	fury_level_SSS_broker = {
		en = color_letters("SSS", "SSSYNDICATE"),
		["zh-cn"] = prefix("SSS", "辛迪加头目"),
	},
	fury_level_X_broker = {
		en = "E" .. color_letters("X", "XILE"),
		["zh-cn"] = prefix("X", "流放者"),
	},
	fury_level_XX_broker = {
		en = "E" .. color_letters("XX", "XXCEPTIONAL"),
		["zh-cn"] = prefix("XX", "乱世枭雄"),
	},
}