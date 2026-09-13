local mod=get_mod("HavocConditionManager")
local BuffSettings=require("scripts/settings/buff/buff_settings")
-- Grow only saturated local-server pools. Ordinary units retain native allocation.
-- Keep a finite ceiling for runaway proc chains, with aggregated diagnostics.
local maximum=math.max(BuffSettings.max_proc_events,2400)
local function report(self,t,final)
    local pool=self._hcm_proc_pool
    if not pool then return end
    if not final and ((t or 0)<(pool.next_report or 0) or
        pool.reported_growths==pool.growths and pool.reported_dropped==pool.dropped
        and pool.reported_processed==pool.processed) then return end
    local log=pool.dropped>(pool.reported_dropped or 0) and mod.warning or mod.info
    log(mod,"Proc capacity (%s): unit=%s kind=%s capacity=%d peak=%d growths=%d dropped=%d",
        final and "destroy" or "periodic",tostring(self._unit),pool.owner_kind,pool.capacity,pool.peak,pool.growths,pool.dropped)
    if pool.samples and pool.samples>0 then
        local names,parts={},{}
        for name in pairs(pool.events) do names[#names+1]=name end
        table.sort(names,function(a,b)
            if pool.events[a]==pool.events[b] then return a<b end
            return pool.events[a]>pool.events[b]
        end)
        for i=1,math.min(5,#names) do
            local name=names[i]; parts[#parts+1]=name.."="..pool.events[name]
        end
        mod:info("Proc workload: unit=%s processed_since_growth=%d sampled_batches=%d sampled_events=%d top_events=%s",
            tostring(self._unit),pool.processed,pool.samples,pool.sampled_events,table.concat(parts,","))
        pool.samples=0; pool.sampled_events=0; table.clear(pool.events)
    end
    pool.next_report=(t or 0)+30
    pool.reported_growths,pool.reported_dropped=pool.growths,pool.dropped
    pool.reported_processed=pool.processed
end
mod:hook_require("scripts/extension_systems/buff/buff_extension_base",function(BuffExtensionBase)
    mod._capacity_buff_classes=mod._capacity_buff_classes or setmetatable({},{__mode="k"})
    if mod._capacity_buff_classes[BuffExtensionBase] then return end
    mod._capacity_buff_classes[BuffExtensionBase]=true
    local native_capacity=BuffSettings.max_proc_events
    mod:hook(BuffExtensionBase,"request_proc_event_param_table",function(func,self)
        local pool=self._hcm_proc_pool
        local in_use=self._num_params_table_in_use
        if not pool then
            if in_use<native_capacity or not self._is_server or not mod.has_local_gameplay_authority() then return func(self) end
            pool={capacity=native_capacity,peak=in_use,growths=0,dropped=0,processed=0,
                owner_kind=self._player and "player" or "unit",next_sample=0,samples=0,sampled_events=0,events={}}
            self._hcm_proc_pool=pool
        end
        local requested=in_use+1
        if requested>pool.capacity then
            if requested>maximum then pool.dropped=pool.dropped+1; return nil end
            local expanded=Script.new_array(math.min(maximum,pool.capacity*2))
            local old=self._proc_event_param_tables
            local start=self._param_tables_start_index_reference-1
            -- Reorder references, never copy/clear live parameter objects. This also
            -- preserves nested events queued while the native update is iterating.
            for i=1,pool.capacity do expanded[i]=old[(start+i-1)%pool.capacity+1] end
            self._proc_event_param_tables=expanded
            self._param_tables_start_index_reference=1
            pool.capacity=math.min(maximum,pool.capacity*2)
            pool.growths=pool.growths+1
        end
        local index=(self._param_tables_start_index_reference+requested-2)%pool.capacity+1
        local params=self._proc_event_param_tables[index]
        if not params then params=Script.new_map(32); self._proc_event_param_tables[index]=params end
        self._num_params_table_in_use=requested
        pool.peak=math.max(pool.peak,requested)
        return params
    end)
    mod:hook(BuffExtensionBase,"_clear_param_tables",function(func,self,count)
        local pool=self._hcm_proc_pool
        if not pool then return func(self,count) end
        local time=Managers.time
        local t=time and time:time("gameplay") or 0
        -- Event names remain on native parameter objects until reclamation.
        -- Sample one player batch per five seconds just before reclamation;
        -- never hook Buff dispatch or inspect/modify Buff templates and IDs.
        local sample=pool.owner_kind=="player" and count>0 and t>=pool.next_sample
        if sample then pool.next_sample=t+5; pool.samples=pool.samples+1 end
        pool.processed=pool.processed+count
        local start=self._param_tables_start_index_reference-1
        if sample then
            for i=1,count do
                local params=self._proc_event_param_tables[(start+i-1)%pool.capacity+1]
                local event=params.triggering_proc_event
                if type(event)=="string" then
                    pool.events[event]=(pool.events[event] or 0)+1
                    pool.sampled_events=pool.sampled_events+1
                end
            end
        end
        for i=1,count do table.clear(self._proc_event_param_tables[(start+i-1)%pool.capacity+1]) end
        self._param_tables_start_index_reference=(start+count)%pool.capacity+1
        -- Reclamation already runs for expanded rings that processed events.
        -- Ordinary unit updates no longer need a separate diagnostic hook.
        report(self,t,false)
    end)
    mod:hook_safe(BuffExtensionBase,"destroy",function(self) report(self,nil,true) end)
end)
