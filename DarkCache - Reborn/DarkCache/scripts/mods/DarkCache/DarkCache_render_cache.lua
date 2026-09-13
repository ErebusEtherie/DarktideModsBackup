local mod = get_mod("DarkCache")
local common = mod.common

-- ---------------------------------------------------------------------------
-- Cache for the icons the game RENDERS: cosmetics, weapons, weapon skins,
-- trinkets, companion gear, player portraits.
--
-- How the engine does it (scripts/ui/render_target_icon_generator_base.lua):
-- a request is queued; one at a time the item -- or a mannequin wearing it --
-- is spawned in a hidden world, given a few frames to settle, captured into a
-- render target and copied into a slot of a shared texture atlas; the widget
-- is handed that atlas and samples it. When the last widget lets go,
-- unload_request_reference() frees the slot and deletes the request, so
-- re-opening the screen replays every step. That is the spinners.
--
-- What changes here: when the last reference to a fully rendered icon is
-- dropped, the reference is detached exactly as the engine would, but the
-- request and its atlas slot are kept and the entry goes into a memory-bounded
-- LRU. On the next request the engine finds it already `spawned` and calls the
-- widget back on the spot -- a path that already exists, since it is what
-- happens when two widgets show the same item at once.
--
-- Entries leave on eviction, on invalidation (the item, the render settings or
-- the resolution changed), and on every loading screen.
--
-- None of this can be written to disk: these icons only exist as GPU render
-- targets and the engine's Lua API has no way to read one back.
-- ---------------------------------------------------------------------------

local render_cache = {}
mod.render_cache = render_cache

-- ---------------------------------------------------------------------------
-- Request helpers
-- ---------------------------------------------------------------------------

local function find_request(instance, reference_id)
	local requests_by_size = instance._requests_by_size
	if not requests_by_size then
		return nil, nil
	end

	for size_key, requests in pairs(requests_by_size) do
		for _, request in pairs(requests) do
			local references_lookup = request.references_lookup
			if references_lookup and references_lookup[reference_id] then
				return request, size_key
			end
		end
	end

	return nil, nil
end

-- True when the request holds a finished capture we can hand out again.
local function is_cacheable(instance, request)
	return request ~= nil
		and request.spawned
		and not request.spawning
		and request.grid_index ~= nil
		and request.atlas_id ~= nil
		and instance._active_request ~= request
		and not instance._shutting_down
end

-- Detach one reference, mirroring what unload_request_reference() does for a
-- reference that is not the last one -- destroy callback first, then the
-- bookkeeping -- but without ever touching the atlas slot.
local function detach_reference(request, reference_id)
	local destroy_callbacks = request.destroy_callbacks
	if destroy_callbacks and destroy_callbacks[reference_id] then
		destroy_callbacks[reference_id]()
		destroy_callbacks[reference_id] = nil
	end

	local references_array = request.references_array
	for i = 1, #references_array do
		if references_array[i] == reference_id then
			table.remove(references_array, i)
			break
		end
	end

	if request.callbacks then
		request.callbacks[reference_id] = nil
	end

	request.references_lookup[reference_id] = nil
end

-- Give a cached entry back to the game: free its atlas slot and forget the
-- request, which is the tail of the engine's own unload_request_reference().
local function release(instance, request, size_key)
	-- Something started using it again between eviction being decided and now:
	-- dropping it would blank a visible icon, so leave it alone.
	if request.references_array and #request.references_array > 0 then
		return
	end

	local atlas_generator = instance._render_target_atlas_generator
	local grid_index = request.grid_index
	local atlas_id = request.atlas_id

	-- get_atlas_render_target() returns nil for an atlas that is already gone;
	-- freeing a slot of it would blow up later in the generator's update.
	if atlas_generator and grid_index and atlas_id and atlas_generator:get_atlas_render_target(atlas_id) then
		atlas_generator:free_atlas_grid_index(atlas_id, grid_index)
	end

	request.grid_index = nil
	request.atlas_id = nil
	request.spawned = false

	local requests_by_size = instance._requests_by_size
	local bucket = requests_by_size and requests_by_size[size_key]
	if bucket and bucket[request.id] == request then
		bucket[request.id] = nil
	end

	local queue = instance._requests_queue_order
	if queue then
		for i = #queue, 1, -1 do
			if queue[i] == request.id then
				table.remove(queue, i)
			end
		end
	end

	if instance._active_request == request then
		instance._active_request = nil
	end
end

render_cache.release = release

local function state_for(instance)
	return common.state_for(instance, release)
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

local function hook_generator_class(class_name)
	local class_table = rawget(_G, "CLASS") and CLASS[class_name]

	if not class_table then
		mod:error("class %s was not found, icon caching is disabled for it", class_name)
		return
	end

	-- The last reference to a rendered icon is going away. Keep the pixels.
	mod:hook(class_table, "unload_request_reference", function (func, self, reference_id, keep_reference)
		-- keep_reference is the engine's own "I will re-request this in a
		-- moment" path (portrait rendering being toggled off); stay out of it.
		if keep_reference then
			return func(self, reference_id, keep_reference)
		end

		local state = state_for(self)
		if not state or not common.channel_enabled(state.channel) then
			return func(self, reference_id, keep_reference)
		end

		local request, size_key = find_request(self, reference_id)

		-- Not the last reference, or nothing worth keeping: let the engine
		-- handle it exactly as it always did.
		if not request or #request.references_array > 1 or not is_cacheable(self, request) then
			return func(self, reference_id, keep_reference)
		end

		-- Oversized formats are refused outright. An atlas is allocated in
		-- 5x5 slots whatever the slot size, so a single cached 1400x1400
		-- portrait pins 196 MB of video memory for the whole session -- enough
		-- to starve the game's texture streamer and blur everything, in
		-- missions included. See the ceiling's rationale in DarkCache_common.
		if not common.size_is_cacheable(request.size) then
			common.bump(state.channel, "oversized")
			common.debug("not cached (%s), %sx%s is above the size ceiling",
				state.channel, tostring(request.size and request.size[1]), tostring(request.size and request.size[2]))

			return func(self, reference_id, keep_reference)
		end

		detach_reference(request, reference_id)
		common.retain(self, request, size_key, request.size, state.channel, release)
	end)

	-- An icon is being asked for. If it is one we kept, it stops being a cache
	-- entry and becomes a live request again -- the engine then finds it
	-- `spawned` and fires the widget callback on the spot.
	mod:hook(class_table, "_generate_icon_request", function (func, self, request_id_prefix, data, on_load_callback, optional_render_context, prioritized, on_unload_callback, current_reference_id)
		local state = state_for(self)

		if state and common.channel_enabled(state.channel) then
			local size = optional_render_context and optional_render_context.size or self._default_size
			local size_key = self:_get_key_by_size(size)
			local bucket = self._requests_by_size and self._requests_by_size[size_key]
			local existing = bucket and bucket[request_id_prefix .. "_" .. size_key]

			if existing and common.contains(existing) then
				-- Taken out before calling through, so the callback the engine
				-- runs synchronously can never see it as evictable.
				common.detach(existing)
				common.bump(state.channel, "hits")
				common.debug("cache hit (%s) %s", state.channel, tostring(request_id_prefix))
			elseif not existing then
				common.bump(state.channel, "misses")
			end
		end

		return func(self, request_id_prefix, data, on_load_callback, optional_render_context, prioritized, on_unload_callback, current_reference_id)
	end)

	-- The game wants a request re-rendered: the item changed, or the render
	-- settings / resolution did. A cached entry is stale by definition, so drop
	-- it rather than spend the render queue redrawing something nobody is
	-- looking at -- it will be rendered again, fresh, when it is next needed.
	mod:hook(class_table, "_update_request", function (func, self, request, data, prioritized)
		local state = state_for(self)

		if state and request and common.contains(request) then
			local entry = common.detach(request)

			if #request.references_array == 0 then
				release(self, request, entry.size_key)
				common.bump(state.channel, "invalidated")
				return
			end
		end

		return func(self, request, data, prioritized)
	end)

	-- Optional: override the engine's settling delay before each capture.
	-- `request.frame_delay` is only ever read by the engine, never written, so
	-- it is ours to own -- and assigning nil when the option is back at the
	-- game's own value is what makes reverting the option take effect on
	-- requests that were already given an override.
	mod:hook_safe(class_table, "_handle_request", function (self, request)
		if request then
			request.frame_delay = common.frame_delay()
		end
	end)

	-- The engine disables the hidden icon world when there is nothing left to
	-- render, but set_world_disabled() only stops the world simulating: without
	-- its second argument the viewport stays active, so the world goes on being
	-- drawn into its capture render target every frame for the rest of the
	-- session, however long ago the last icon was made. Passing include_viewport
	-- switches that off between renders, and back on before the next icon is
	-- spawned -- which happens several frames ahead of any capture, so nothing
	-- is ever photographed on a dead viewport.
	--
	-- No option of its own: it is a straight correction with no trade-off to
	-- weigh, so it simply follows the master switch like everything else.
	mod:hook(class_table, "_pause_rendering", function (func, self)
		if not common.enabled() then
			return func(self)
		end

		local world_spawner = self._world_spawner

		if world_spawner then
			world_spawner:set_world_disabled(true, true)
		end
	end)

	mod:hook(class_table, "_resume_rendering", function (func, self)
		if not common.enabled() then
			return func(self)
		end

		local world_spawner = self._world_spawner

		if world_spawner then
			world_spawner:set_world_disabled(false, true)
		end
	end)

	-- Hand everything back before the renderer tears itself down: the atlases
	-- of the main renderers belong to UIManager, not to the instance, so a
	-- cached slot left behind here would stay occupied for good.
	mod:hook(class_table, "destroy", function (func, self)
		common.flush(self)
		common.forget(self)

		return func(self)
	end)
end

function render_cache.init()
	hook_generator_class("PortraitUI")
	hook_generator_class("WeaponIconUI")
end

return render_cache
