

---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_news then
	return mod.hud_studio_news
end

local VIEW_NAME = "hud_studio_news_view"

local READ_KEY = "news_read_version"

---@class HudStudioNews
local News = {}

local _pages
local _on_close

---@return NewsPageDataShape[]
function News.pages()
	_pages = _pages or mod:io_dofile("hud_studio/scripts/mods/hud_studio/hud/news/pages/entries")

	return _pages
end

local function latest_version()
	local pages = News.pages()
	local newest = pages[1]

	return newest and newest.version_label or nil
end

---@return boolean
function News.has_unread()
	local latest = latest_version()

	return latest ~= nil and latest ~= mod:get(READ_KEY)
end

function News.mark_read()
	local latest = latest_version()

	if latest then
		mod:set(READ_KEY, latest, false)
	end
end

---@param on_close function|nil
function News.open(on_close)
	if Managers.ui:view_instance(VIEW_NAME) then
		return
	end

	_on_close = on_close

	Managers.ui:open_view(VIEW_NAME)
end

function News.close()
	if Managers.ui:view_instance(VIEW_NAME) then
		Managers.ui:close_view(VIEW_NAME)
	end
end

function News.on_view_closed()
	News.mark_read()

	local callback = _on_close
	_on_close = nil

	if callback then
		callback()
	end
end

local function can_show_news()
	local Gameplay = mod.dl.gameplay

	return Gameplay.is_in_hub() or Gameplay.game_mode_name() == "shooting_range"
end

---@return boolean
function News.maybe_intercept_editor()
	if not mod:get("news_on_update") then
		return false
	end

	if not can_show_news() or not News.has_unread() then
		return false
	end

	News.open(function()
		mod:toggle_editor(true)
	end)

	return true
end

function mod.toggle_news(self, is_pressed)
	if is_pressed == false then
		return
	end

	if Managers.ui:view_instance(VIEW_NAME) then
		News.close()
	elseif can_show_news() then
		News.open(nil)
	end
end

function mod.reset_read_news(self, is_pressed)
	if is_pressed == false then
		return
	end

	mod:set(READ_KEY, "", false)
	mod:notify("News read version cleared")
end

mod.hud_studio_news = News

return News
