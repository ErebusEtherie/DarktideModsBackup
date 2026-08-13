

require("scripts/ui/view_elements/view_element_base")

---@param widget table
---@param id string
local function place_rect(widget, id, x, y, w, h)
	local s = widget.style[id]
	s.offset[1] = x
	s.offset[2] = y
	s.size[1] = w
	s.size[2] = h
end

---@param widget table
---@param id string
---@param a number
local function set_alpha(widget, id, a)
	widget.style[id].color[1] = a
end

---@param widget table
---@param id string
---@param text string|nil
local function set_text(widget, id, text)
	widget.content[id] = text or ""
end

local function loc_or(mod, key, fallback)
	local text = mod:localize(key)
	if not text or text == "<" .. key .. ">" then
		return fallback
	end
	return text
end

local FlappyElement = class("DLModMenuFlappyElement@" .. tostring({}), "ViewElementBase")

FlappyElement.init = function(self, parent, draw_layer, start_scale, context)

	local mod = get_mod(context and context.mod_name)
	self._mod = mod

	local _module = mod.dl_hud.__hud_modules["mod_menu"]
	self._c = _module.flappy_constants

	local defs = _module.flappy_definitions
	self._definitions = defs
	FlappyElement.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = defs.scenegraph_definition,
		widget_definitions = defs.widget_definitions,
	})

	self._was_visible = false
	self._best = 0
	self:_reset()
end

---@return number
FlappyElement._random_gap = function(self)
	local C = self._c
	local lo = C.GAP_MARGIN + C.PIPE_GAP * 0.5
	local hi = self._play_h - C.GAP_MARGIN - C.PIPE_GAP * 0.5
	return lo + math.random() * (hi - lo)
end

FlappyElement._reset = function(self)
	local C = self._c
	self._play_h = C.FIELD_H - C.GROUND_H
	self._start_y = self._play_h * C.BIRD_START_FRAC
	self._state = "ready"
	self._bird_y = self._start_y
	self._bird_v = 0
	self._bob = 0
	self._score = 0

	self._pipes = self._pipes or {}
	for i = 1, C.PIPE_POOL do
		self._pipes[i] = self._pipes[i] or {}
		local p = self._pipes[i]
		p.x = C.PIPE_FIRST_X + (i - 1) * C.PIPE_SPACING
		p.gap = self:_random_gap()
		p.scored = false
	end
end

FlappyElement._die = function(self)
	self._state = "dead"
	if self._score > self._best then
		self._best = self._score
	end
end

---@param dt number
---@param pressed boolean|nil
FlappyElement._step_playing = function(self, dt, pressed)
	local C = self._c
	if pressed then
		self._bird_v = C.FLAP_VELOCITY
	end
	self._bird_v = math.min(self._bird_v + C.GRAVITY * dt, C.MAX_FALL_SPEED)
	self._bird_y = self._bird_y + self._bird_v * dt

	if self._bird_y < 0 then
		self._bird_y = 0
		self._bird_v = 0
	end

	local move = C.SCROLL_SPEED * dt
	move = move + (move * (self._score / 95))
	local bird_left = C.BIRD_X
	local bird_right = C.BIRD_X + C.BIRD_SIZE
	local bird_top = self._bird_y
	local bird_bot = self._bird_y + C.BIRD_SIZE

	for i = 1, #self._pipes do
		local p = self._pipes[i]
		p.x = p.x - move

		if p.x < -C.PIPE_W then
			p.x = p.x + C.PIPE_POOL * C.PIPE_SPACING
			p.gap = self:_random_gap()
			p.scored = false
		end
		if not p.scored and (p.x + C.PIPE_W) < bird_left then
			p.scored = true
			self._score = self._score + 1
		end
		if p.x < bird_right and (p.x + C.PIPE_W) > bird_left then
			local gap_top = p.gap - C.PIPE_GAP * 0.5
			local gap_bot = p.gap + C.PIPE_GAP * 0.5
			if bird_top < gap_top or bird_bot > gap_bot then
				self:_die()
				return
			end
		end
	end

	if bird_bot >= self._play_h then
		self._bird_y = self._play_h - C.BIRD_SIZE
		self:_die()
	end
end

FlappyElement.update = function(self, dt, t, input_service)
	FlappyElement.super.update(self, dt, t, input_service)

	if not self:visible() then
		self._was_visible = false
		return
	end
	if not self._was_visible then
		self._was_visible = true
		self:_reset()
	end

	local C = self._c

	dt = math.min(dt or 0, 0.05)
	local pressed = input_service and input_service:get("left_pressed")

	if self._state == "ready" then
		self._bob = self._bob + dt
		self._bird_y = self._start_y + math.sin(self._bob * C.BOB_SPEED) * C.BOB_AMPLITUDE
		if pressed then
			self._state = "playing"
			self._bird_v = C.FLAP_VELOCITY
		end
	elseif self._state == "playing" then
		self:_step_playing(dt, pressed)
	elseif self._state == "dead" then

		self._bird_v = math.min(self._bird_v + C.GRAVITY * dt, C.MAX_FALL_SPEED)
		self._bird_y = math.min(self._bird_y + self._bird_v * dt, self._play_h - C.BIRD_SIZE)
		if pressed then
			self:_reset()
		end
	end

	self:_render()
end

FlappyElement._render = function(self)
	local C = self._c
	local mod = self._mod
	local field = self._widgets_by_name.field
	local play_h = self._play_h

	place_rect(field, "bird", C.BIRD_X, self._bird_y, C.BIRD_SIZE, C.BIRD_SIZE)
	place_rect(field, "bird_eye", C.BIRD_X + C.BIRD_SIZE - 20, self._bird_y + 12, 10, 10)

	for i = 1, #self._pipes do
		local p = self._pipes[i]
		local top_id = "pipe_top_" .. i
		local bot_id = "pipe_bot_" .. i
		local x0 = math.max(p.x, 0)
		local x1 = math.min(p.x + C.PIPE_W, C.FIELD_W)
		local w = x1 - x0
		if w > 0 then
			local gap_top = p.gap - C.PIPE_GAP * 0.5
			local gap_bot = p.gap + C.PIPE_GAP * 0.5
			place_rect(field, top_id, x0, 0, w, gap_top)
			place_rect(field, bot_id, x0, gap_bot, w, play_h - gap_bot)
			set_alpha(field, top_id, C.COLOR.PIPE[1])
			set_alpha(field, bot_id, C.COLOR.PIPE[1])
		else
			set_alpha(field, top_id, 0)
			set_alpha(field, bot_id, 0)
		end
	end

	set_text(field, "score", tostring(self._score))

	local state = self._state
	set_text(field, "prompt", state == "ready" and loc_or(mod, "flappy_prompt", "CLICK TO FLAP") or "")
	set_text(field, "gameover", state == "dead" and loc_or(mod, "flappy_gameover", "SYSTEM FAILURE") or "")
	set_text(
		field,
		"hint",
		state == "dead"
				and (loc_or(mod, "flappy_retry", "CLICK TO REBOOT") .. "   " .. loc_or(mod, "flappy_best", "BEST") .. " " .. self._best)
			or ""
	)
end

return FlappyElement
