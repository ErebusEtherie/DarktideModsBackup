-- Explicit file import/export, atomic validation and next-mission settings.
local L={}
function L.new(mod,kind,catalog,Schema,Codec,Files,options)
    options=options or {}
    local self={revision=0,last_error=nil,files={},selected_file=1,kind=kind,source_file=nil}
    local function defaults()
        return {format=Schema.format,version=1,kind=kind,id="empty",name="Empty DIY library",entries={}}
    end
    local saved=mod:get("diy_document_v1")
    local parsed,parse_error
    if type(saved)=="string" then parsed,parse_error=Codec.decode(saved) else parsed=saved end
    local document,err
    if parsed then document,err=Schema.validate(parsed,catalog,kind) end
    self.document=document or defaults()
    self.last_error=parse_error or (parsed and not document and err or nil)
    local function checked_options(raw)
        raw=type(raw)=="table" and raw or {}
        local ids={};for _,e in ipairs(self.document.entries) do ids[e.id]=true end
        local selected,seen={},{}
        for _,id in ipairs(type(raw.selected)=="table" and raw.selected or {}) do
            if ids[id] and not seen[id] then selected[#selected+1]=id;seen[id]=true end
        end
        table.sort(selected)
        local seed=tonumber(raw.seed)
        if not Schema.finite(seed) or seed<1 or seed>2147483646 or seed%1~=0 then seed=1 end
        -- Old tier quotas are accepted on input for migration, but never
        -- retained or used: tier is descriptive metadata only.
        local total=tonumber(raw.max_total)
        return {enabled=raw.enabled==true,mode=kind~="conditions" and raw.mode=="random" and "random" or "manual",selected=selected,
            seed=seed,max_total=kind=="conditions" and #self.document.entries or Schema.finite(total) and math.max(0,math.min(99,math.floor(total))) or 6}
    end
    self.options=checked_options(mod:get("diy_options_v1"))
    function self.can_edit() return not (options.busy and options.busy()) end
    function self.eligible(entry)
        if options.eligible then return options.eligible(entry) end
        return true
    end
    function self.signature() return Codec.fingerprint(self.document) end
    function self.set_options(changes)
        if not self.can_edit() then self.last_error="diy_edit_in_hub";return false,self.last_error end
        local raw=Schema.copy(self.options)
        for k,v in pairs(changes) do
            if k~="enabled" and k~="mode" and k~="selected" and k~="seed" and k~="tier_limits" and k~="max_total" then return false,"unknown option" end
            raw[k]=v
        end
        self.options=checked_options(raw);mod:set("diy_options_v1",Schema.copy(self.options));self.revision=self.revision+1;self.last_error=nil
        if options.changed then options.changed("options") end;return true
    end
    function self.toggle(id)
        local selected,found={},false
        for _,s in ipairs(self.options.selected) do if s==id then found=true else selected[#selected+1]=s end end
        if not found then
            local entry;local picked={};for _,s in ipairs(selected) do picked[s]=true end
            for _,e in ipairs(self.document.entries) do if e.id==id then entry=e end end
            if not entry or not entry.enabled then return false end
            local allowed,reason=self.eligible(entry)
            if not allowed then self.last_error=reason or "diy_incompatible";return false end
            local eligible_count=0
            for _,e in ipairs(self.document.entries) do if picked[e.id] and e.enabled and self.eligible(e) then eligible_count=eligible_count+1 end end
            local limit=options.selection_limit and options.selection_limit() or self.options.max_total
            if kind~="conditions" and eligible_count>=limit then self.last_error="diy_selection_full";return false end
            if kind~="conditions" and entry.exclusive_group then for _,e in ipairs(self.document.entries) do
                if picked[e.id] and self.eligible(e) and e.exclusive_group==entry.exclusive_group then self.last_error="diy_exclusive";return false end
            end end
            selected[#selected+1]=id
        end
        self.last_error=nil
        return self.set_options({selected=selected})
    end
    function self.import_text(text,source)
        if not self.can_edit() then self.last_error="diy_edit_in_hub";return nil,self.last_error end
        local decoded,reason=Codec.decode(text)
        if not decoded then self.last_error=reason;return nil,reason end
        local next_document
        next_document,reason=Schema.validate(decoded,catalog,kind)
        if not next_document then self.last_error=reason;return nil,reason end
        local encoded;encoded,reason=Codec.encode(next_document)
        if not encoded then self.last_error=reason;return nil,reason end
        -- Commit only a complete validated replacement; invalid input never
        -- edits the active mission or the previously saved library.
        mod:set("diy_document_v1",encoded)
        self.document=next_document;self.source_file=source
        self.options=checked_options(self.options);mod:set("diy_options_v1",Schema.copy(self.options))
        self.revision=self.revision+1;self.last_error=nil
        if options.changed then options.changed("document") end
        return next_document
    end
    local store,store_error
    local function filesystem()
        if store then return store end
        local ffi=Mods and Mods.lua and Mods.lua.ffi
        if not ffi then local ok,value=pcall(require,"ffi");if ok then ffi=value end end
        if not ffi then return nil,"template_io_unavailable" end
        store,store_error=Files.new(ffi,options.name);return store,store_error
    end
    function self.directory()
        local fs,reason=filesystem();return fs and fs.directory,reason
    end
    function self.scan()
        local fs,reason=filesystem()
        if fs then self.files,reason=fs.list() end
        self.files=self.files or {};self.selected_file=math.max(1,math.min(self.selected_file,#self.files))
        self.last_error=reason;return not reason,reason
    end
    function self.import_file(name)
        local fs,reason=filesystem();if not fs then self.last_error=reason;return nil,reason end
        local text;text,reason=fs.read(name)
        if not text then self.last_error=reason;return nil,reason end
        return self.import_text(text,name)
    end
    function self.export(name,doc)
        local checked,reason=Schema.validate(doc or self.document,catalog,kind)
        if not checked then self.last_error=reason;return nil,reason end
        local text;text,reason=Codec.encode(checked);if not text then self.last_error=reason;return nil,reason end
        local fs;fs,reason=filesystem();if not fs then self.last_error=reason;return nil,reason end
        local ok;ok,reason=fs.write(name,text,false);self.last_error=reason
        if ok then self.scan() end
        return ok,reason
    end
    function self.copy_directory()
        local path,reason=self.directory();if not path then self.last_error=reason;return false end
        if Clipboard and Clipboard.put then Clipboard.put(path)
        elseif Clipboard and Clipboard.set then Clipboard.set(path)
        else self.last_error=path;return false end
        return true
    end
    function self.paste_seed()
        local raw=Clipboard and Clipboard.get and Clipboard.get()
        local n=type(raw)=="string" and raw:match("^%s*(%d+)%s*$")
        n=n and tonumber(n)
        if not Schema.finite(n) or n<1 or n>2147483646 or n%1~=0 then self.last_error="diy_seed_invalid";return false end
        self.last_error=nil;return self.set_options({seed=n})
    end
    function self.snapshot()
        return {document=Schema.copy(self.document),options=Schema.copy(self.options),signature=self.signature()}
    end
    return self
end
return L
