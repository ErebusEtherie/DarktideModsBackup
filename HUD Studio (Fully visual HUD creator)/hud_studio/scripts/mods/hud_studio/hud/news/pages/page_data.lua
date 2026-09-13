---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_news_page_data then
	return mod.hud_studio_news_page_data
end

---@class NewsPageData
local NewsPageData = {}

local md_to_rt = mod.dl.md.to_rich_text

local THEME = "dark"

local format_lines = function(lines)
	if not lines or #lines == 0 then
		return
	end
	for i = 1, #lines do
		lines[i] = md_to_rt(THEME, lines[i])
	end
end

function NewsPageData.version_label(version)
	if type(version) ~= "number" then
		return tostring(version or "")
	end

	return (string.format("%.3f", version):gsub("0+$", ""):gsub("%.$", ""))
end

function NewsPageData.new(ctx)
	ctx = ctx or {}

	ctx.version_label = NewsPageData.version_label(ctx.version)

	ctx.title = ctx.title or ("Update Version " .. ctx.version_label)

	format_lines(ctx.lines)

	format_lines(ctx.breaking_changes)

	format_lines(ctx.hotfixes)

	format_lines(ctx.bug_fixes)

	if ctx.features then
		for i = 1, #ctx.features do
			local lines = ctx.features[i].lines

			format_lines(lines)
		end
	end

	return ctx
end

mod.hud_studio_news_page_data = NewsPageData

return NewsPageData
