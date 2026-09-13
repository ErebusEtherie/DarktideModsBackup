-- Host-owned Mortis routes. Time resolves choices; it never earns rewards.
local Draft = { timeout = 60, enter_time = 0.25, award_hold_time = 3, exit_time = 0.18, selection_time = 0.8, max_points = 99, progress_max = 10,
    milestones = { 0.08, 0.16, 0.24, 0.32, 0.40, 0.50, 0.60, 0.70, 0.80 } }
-- Shared with the HUD so presentation never consumes the next choice's time.
Draft.reveal_time = Draft.enter_time + Draft.award_hold_time + Draft.exit_time
local function copy(list)
    local r = {}; for i, v in ipairs(list or {}) do r[i] = v end; return r
end
function Draft.limit(mode, value)
    if mode == "draft" then return Draft.progress_max end
    return math.max(0, math.min(Draft.max_points, math.floor(value or 0)))
end
function Draft.buff_limit(mode, value)
    local limit = Draft.limit(mode, value)
    return mode == "preselect" and limit or math.max(0, 2 * limit - 1)
end
function Draft.new(epoch, mode)
    return { epoch = epoch, mode = mode or "draft", earned = 1, milestones = 0, events = {}, players = {}, serial = 0 }
end
function Draft.event(run, key)
    if not key or run.events[key] then return false end
    run.events[key] = true; run.earned = math.min(10, run.earned + 1); return true
end
function Draft.progress(run, fraction)
    if type(fraction) ~= "number" or fraction ~= fraction then return end
    for i, threshold in ipairs(Draft.milestones) do
        if fraction + 0.000001 >= threshold then run.milestones = math.max(run.milestones, i) end
    end
    -- Phase fallback and path catch-up share the same ten slots.
    run.earned = math.max(run.earned, 1 + run.milestones)
end
function Draft.player(run, key)
    local p = run.players[key]
    if not p then
        p = { selected = {}, selected_rounds = {}, version = 0, earned = 1, progress = 0, completed = 0, route_round = 0 }
        run.players[key] = p
    end
    return p
end
local function earned(run, p) return run.mode == "competition" and p.earned or run.earned end
function Draft.counting(p, limit)
    return not p.exhausted and p.earned < Draft.limit("competition", limit or Draft.max_points)
end
function Draft.kill(p, contribution, limit)
    limit = Draft.limit("competition", limit or Draft.max_points)
    if not Draft.counting(p, limit) then return false end
    if type(contribution) ~= "number" or contribution ~= contribution or contribution < 0 or contribution > 100 then return end
    if contribution==0 then return false end
    p.progress = p.progress + contribution
    local rewards = math.floor((p.progress + 0.000001) / 100)
    p.progress = math.max(0, p.progress - rewards * 100)
    p.earned = math.min(limit, p.earned + rewards)
    if p.earned >= limit then p.progress = 0 end
    p.version = p.version + 1
    return true
end
local function available(list, used)
    local r, seen = {}, {}
    for _, name in ipairs(list or {}) do
        if not used[name] and not seen[name] then r[#r + 1] = name; seen[name] = true end
    end
    return r
end
local function owned(p)
    local r = {}; for _, name in ipairs(p.selected) do r[name] = true end; return r
end
local function family_pool(pool, family, used)
    local route = pool.routes[family]
    if not route then return {} end
    local priority = available(route.priority, used)
    return #priority > 0 and priority or available(route.buffs, used)
end
-- Native strategy: category by weight, then a uniform Buff in that category.
-- Work on copies so unselected options remain available for future choices.
local function weighted(groups, weights, count, random)
    local choices, used = {}, {}
    for _ = 1, count do
        local candidates, total = {}, 0
        for _, key in ipairs(groups.order) do
            local list, weight = available(groups[key], used), weights and weights[key] or 1
            if #list > 0 and type(weight) == "number" and weight > 0 and weight < math.huge then
                total = total + weight; candidates[#candidates + 1] = { list = list, weight = weight }
            end
        end
        if total == 0 then break end
        local roll, chosen = random(1000000) / 1000000 * total, candidates[#candidates]
        for _, candidate in ipairs(candidates) do
            roll = roll - candidate.weight
            if roll <= 0 then chosen = candidate; break end
        end
        local name
        if groups.entry_weights then
            local total=0
            for _,id in ipairs(chosen.list)do total=total+(groups.entry_weights[id] or 1) end
            local roll=random(1000000)/1000000*total
            name=chosen.list[#chosen.list]
            for _,id in ipairs(chosen.list)do roll=roll-(groups.entry_weights[id] or 1);if roll<=0 then name=id;break end end
        else name = chosen.list[random(#chosen.list)] end
        used[name] = true; choices[#choices + 1] = name
    end
    return choices
end
local function reward_pool(run, p, pool)
    if pool.refresh then pool.refresh(p.selected) end
    local used = owned(p)
    if not p.family and not pool.skip_family then
        local groups = { order = {} }
        for _, family in ipairs(pool.families) do
            if #family_pool(pool, family, used) > 0 then
                groups.order[#groups.order + 1] = family; groups[family] = { family }
            end
        end
        return "family", groups, pool.family_weights
    end
    -- Every earned round has a non-route choice, independently of its route grant.
    local groups = { order = copy(pool.categories) }
    for _, category in ipairs(groups.order) do groups[category] = available(pool.legendary[category], used) end
    groups.entry_weights=pool.entry_weights
    return "legendary", groups
end
local function grant(p, name, round, automatic)
    p.selected[#p.selected + 1] = name
    p.selected_rounds[#p.selected] = round
    if automatic then
        p.rewards = p.rewards or {}
        p.rewards[#p.rewards + 1] = { id = #p.selected, name = name, round = round }
    end
    p.version = p.version + 1
end
function Draft.selection(p, rounds)
    local cached = p.selection_cache
    if cached and cached.count == #p.selected and cached.rounds == rounds then return cached.value end
    local result = {}
    for i, name in ipairs(p.selected) do
        if p.selected_rounds[i] <= rounds then result[#result + 1] = name end
    end
    p.selection_cache = { count = #p.selected, rounds = rounds, value = result }
    return result
end
local function start(run, p, limit, pool, now, random)
    if p.active then return end
    p.skip_family=pool.skip_family==true
    local maximum = math.min(earned(run, p), Draft.limit(run.mode, limit))
    local capacity = Draft.buff_limit(run.mode, limit)
    while p.completed < maximum and #p.selected < capacity do
        local round = p.completed + 1
        local kind, candidates, weights = reward_pool(run, p, pool)
        local choices = weighted(candidates, weights, 3, random)
        if kind == "family" and #choices < 3 then
            local used = {}; for _, name in ipairs(choices) do used[name] = true end
            local fallback = available(candidates.order, used)
            while #choices < 3 and #fallback > 0 do choices[#choices + 1] = table.remove(fallback, random(#fallback)) end
        end
        if kind == "legendary" and p.route_round < round then
            local route = family_pool(pool, p.family, owned(p))
            -- Reserve room for this round's interactive reward at a total-Buff cap.
            if #route > 0 and #p.selected + (#choices > 0 and 1 or 0) < capacity then
                grant(p, route[random(#route)], round, true)
            elseif #route == 0 and #choices == 0 then
                p.exhausted = true; return
            end
            p.route_round = round
        end
        if kind == "legendary" and run.mode == "competition" and #choices == 1 then
            -- The last compatible non-route Buff needs no meaningless picker.
            grant(p, choices[1], round, true)
        elseif #choices > 0 then
            run.serial = run.serial + 1
            local ready_at = math.max(now, p.presentation_until or now)
            p.active = { id = run.epoch .. ":" .. run.serial, kind = kind, round = round, choices = choices,
                ready_at = ready_at, deadline = ready_at + Draft.timeout }
            p.version = p.version + 1; p.exhausted = false; return
        end
        if kind == "family" then p.exhausted = true; return end
        -- With no non-route candidates, finish the route-only round once.
        p.completed = round; p.version = p.version + 1
    end
    p.exhausted = false
end
local function present_rewards(p, previous_round, now, selected)
    local groups, last = 0, nil
    for _, reward in ipairs(p.rewards or {}) do
        if reward.round > previous_round and reward.round <= p.completed and reward.round ~= last then
            groups = groups + 1; last = reward.round
        end
    end
    if groups == 0 then return end
    p.presentation_until = math.max(now, p.presentation_until or now)
        + (selected and Draft.selection_time or 0) + groups * Draft.reveal_time
    if p.active then
        p.active.ready_at = p.presentation_until
        p.active.deadline = p.active.ready_at + Draft.timeout
    end
end
local function valid_choice(run, p, pool, active)
    local kind, groups, weights = reward_pool(run, p, pool)
    if active.kind ~= kind then return false end
    local valid = {}
    for _, category in ipairs(groups.order) do
        if kind == "family" or not weights or (weights[category] or 1) > 0 then
            for _, name in ipairs(groups[category]) do valid[name] = true end
        end
    end
    for _, name in ipairs(active.choices) do if not valid[name] then return false end end
    return true
end
function Draft.choose(run, p, id, index, limit, pool, now, random)
    local active = p.active
    local previous_round = p.completed
    if not active or id ~= active.id or type(index) ~= "number" or index % 1 ~= 0
        or not active.choices[index] or #p.selected >= Draft.buff_limit(run.mode, limit)
        or active.round > math.min(earned(run, p), Draft.limit(run.mode, limit)) then return false end
    if not valid_choice(run, p, pool, active) then
        p.active = nil; start(run, p, limit, pool, now, random); return false
    end
    local name = active.choices[index]
    if active.kind == "family" then
        p.family = name
        local candidates = family_pool(pool, name, owned(p))
        grant(p, candidates[random(#candidates)], active.round, true)
        p.route_round = active.round
    else grant(p, name, active.round) end
    p.last = { id = id, index = index, name = name, kind = active.kind }
    p.completed = active.round
    p.active = nil; p.version = p.version + 1
    start(run, p, limit, pool, now, random)
    present_rewards(p, previous_round, now, true)
    return true
end
function Draft.tick(run, p, limit, pool, now, random)
    limit = Draft.limit(run.mode, limit)
    if #p.selected >= Draft.buff_limit(run.mode, limit) or p.completed >= math.min(limit, earned(run, p)) then
        if p.active then p.active = nil; p.version = p.version + 1 end
        return
    end
    local active = p.active
    if active and (p.validated_active ~= active or p.validated_pool ~= pool) then
        if not valid_choice(run, p, pool, active) then p.active = nil; p.version = p.version + 1 end
        p.validated_active, p.validated_pool = p.active, pool
    end
    active = p.active
    if active and now >= active.deadline then
        -- One interactive timeout per tick. The next card gets a full minute.
        Draft.choose(run, p, active.id, random(#active.choices), limit, pool, now, random)
    else
        local previous_round = p.completed
        start(run, p, limit, pool, now, random)
        present_rewards(p, previous_round, now, false)
    end
end
-- The coordinator checks this before asking the catalog to construct a pool.
function Draft.needs_tick(run, p, limit)
    return p.active ~= nil or (not p.exhausted and #p.selected < Draft.buff_limit(run.mode, limit)
        and p.completed < math.min(Draft.limit(run.mode, limit), earned(run, p)))
end
function Draft.snapshot(run, p, limit, now)
    local rounds = Draft.limit(run.mode, limit)
    limit = Draft.buff_limit(run.mode, limit)
    local selected = Draft.selection(p, rounds)
    local spent, total, active = #selected, math.min(earned(run, p), rounds), p.active
    local cache = p.rewards_cache
    if not cache or cache.completed ~= p.completed or cache.rounds ~= rounds or cache.count ~= #(p.rewards or {}) then
        cache = { completed = p.completed, rounds = rounds, count = #(p.rewards or {}), value = {} }
        for _, reward in ipairs(p.rewards or {}) do
            -- Show automatic awards after the round's choice, not before it.
            if reward.round <= math.min(p.completed, rounds) then cache.value[#cache.value + 1] = reward end
        end
        p.rewards_cache = cache
    end
    local counting = run.mode == "competition" and Draft.counting(p, rounds)
    return { epoch = run.epoch, mode = run.mode, family = p.family, progress = counting and p.progress or 0, version = p.version,
        counting = counting, rewards = cache.value, completed = p.completed,skip_family=p.skip_family==true,
        -- earned counts rounds; spent/limit count actual Buffs. Never derive a
        -- choice queue from selected Buffs now that one round can grant two.
        limit = limit, earned = total, spent = spent,
        queued = (spent >= limit or p.exhausted) and 0 or math.max(0, total - p.completed - (active and 1 or 0)),
        selected = selected, last = p.last and {
            id = p.last.id, index = p.last.index, name = p.last.name, kind = p.last.kind } or nil,
        exhausted = p.exhausted == true,
        active = active and { id = active.id, kind = active.kind, choices = copy(active.choices),
            delay = math.max(0, (active.ready_at or now) - now),
            remaining = math.min(Draft.timeout, math.max(0, active.deadline - now)) } or nil }
end
return Draft
