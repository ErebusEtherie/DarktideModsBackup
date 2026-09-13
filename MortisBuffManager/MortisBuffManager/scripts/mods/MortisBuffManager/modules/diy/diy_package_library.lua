-- Filesystem packages feed the existing validated selection/options library.
-- Discovery changes next-mission data only; active engines retain snapshots.
local L={}
function L.new(mod,kind,catalog,Schema,Codec,Files,Base,Packages,Hash,options)
    options=options or {}
    local self=Base.new(mod,kind,catalog,Schema,Codec,Files,options)
    local package_api=Packages.new(Schema,Codec,Hash)
    local previous_document=Schema.copy(self.document);local previous_selected=Schema.copy(self.options.selected)
    local saved=mod:get("diy_packages_v1")
    local settings=type(saved)=="table" and saved.version==1 and Schema.copy(saved) or {version=1,disabled={}}
    settings.disabled=type(settings.disabled)=="table" and settings.disabled or {}
    for id,value in pairs(settings.disabled)do if not Packages.id(id) or value~=true then settings.disabled[id]=nil end end
    self.packages={};self.active_packages={};self.package_errors={};self.entry_sources={};self.entry_hashes={};self.legacy_policy_keys={}
    self.document={format=Schema.format,version=Schema.version,kind=kind,id="diy_packages",name={en="DIY packages",["zh-cn"]="DIY 包",["zh-tw"]="DIY 套件"},entries={}}
    local store,store_error,snapshot,snapshot_revision
    local initializing=true
    local raw_signature=self.signature
    local function persist() mod:set("diy_packages_v1",Schema.copy(settings)) end
    local function filesystem()
        if store then return store end
        local ffi=Mods and Mods.lua and Mods.lua.ffi
        if not ffi then local ok,value=pcall(require,"ffi");if ok then ffi=value end end
        if not ffi then return nil,"diy_package_io" end
        local ok,value,why=pcall(Files.new,ffi,options.name)
        if not ok then store_error=tostring(value);return nil,"diy_package_io" end
        store,store_error=value,why
        return store,store_error
    end
    local function report(error)
        if type(error)=="string" and error:match("^template_") then error="diy_package_io" end
        self.last_error=error;return nil,error
    end
    local startup_id_map={}
    local function read_package(fs,id)
        local files=fs.read_package(id,Packages.id,Packages.path)
        return files and package_api.validate(files,catalog,kind,id)
    end
    local function install(fs,batch,preserve,reenable,strict_namespace)
        local names,why=fs.list_packages(Packages.id);if not names then return nil,why end
        local existing,canonical={},{}
        for _,id in ipairs(names)do
            local pack=read_package(fs,id);existing[id]=pack or false
            if pack and #pack.document.entries==1 then canonical[id]=assert(Codec.encode(pack.document)) end
        end
        local plans={}
        for id,files in pairs(batch)do
            local pack,err=package_api.validate(files,catalog,kind,id);if not pack then return nil,err end
            plans[#plans+1]=pack
        end
        table.sort(plans,function(a,b)return a.manifest.id<b.manifest.id end)
        local written,mapping={},{}
        for _,pack in ipairs(plans)do
            local id=pack.manifest.id;local selected
            local wanted=assert(Codec.encode(pack.document));local entry=pack.document.entries[1]
            local old=existing[id]
            if preserve and old and #old.document.entries==1 and package_api.entry_identity(old,old.document.entries[1].id)==package_api.entry_identity(pack,entry.id) then selected=old end
            if not selected then for _,other_id in ipairs(names)do
                if canonical[other_id]==wanted and (not strict_namespace or package_api.namespace(existing[other_id])==package_api.namespace(pack)) then selected=existing[other_id];break end
            end end
            if not selected then
                if existing[id]~=nil then
                    id=id:sub(1,47).."-"..Hash.hex(wanted):sub(1,16)
                    if strict_namespace then return nil,"diy_package_exists: "..pack.manifest.id end
                    local files=Schema.copy(pack.files);local manifest=Schema.copy(pack.manifest)
                    manifest.id=id;manifest.entry_namespace=id;files['package.json']=assert(Codec.encode(manifest))
                    pack=assert(package_api.validate(files,catalog,kind,id))
                end
                local ok,err=fs.write_package(id,pack.files,Packages.id,Packages.path)
                if not ok and err=='diy_package_exists' then
                    local same=read_package(fs,id)
                    if same and Codec.encode(same.document)==wanted then selected=same else return nil,err end
                elseif not ok then return nil,err end
                selected=selected or pack;existing[id]=selected;canonical[id]=wanted;names[#names+1]=id
            end
            id=selected.manifest.id;written[#written+1]=id
            mapping[entry.id]=package_api.entry_identity(selected,entry.id)
            if reenable then settings.disabled[id]=nil end
        end
        return true,nil,written,mapping
    end
    local function write_document(fs,document,id,with_script,preserve,reenable,force_children)
        return install(fs,package_api.split_document(document,id,with_script,force_children),preserve,reenable,false)
    end
    local function retire_multi(fs,pack)
        local ok,why,children=install(fs,package_api.split_package(pack),true,false,true)
        if not ok then return nil,why end
        local unchanged=read_package(fs,pack.manifest.id)
        if not unchanged or unchanged.hash~=pack.hash then return nil,"diy_package_changed" end
        local backup;backup,why=fs.retire_package(pack.manifest.id,Packages.id)
        if not backup then return nil,why end
        if settings.disabled[pack.manifest.id] then for _,id in ipairs(children)do settings.disabled[id]=true end end
        settings.disabled[pack.manifest.id]=nil
        settings.package_backups=settings.package_backups or {};settings.package_backups[pack.manifest.id]=backup
        persist();return true
    end
    local function bootstrap(fs)
        if not settings.bootstrapped then
        -- Convert existing loose JSON once. Preserve originals and never
        -- replace a directory that its author has already installed.
        local names,why=fs.list();if not names then return nil,why end
        for _,name in ipairs(names)do
            local bytes=fs.read(name)
            local raw=bytes and Codec.decode(bytes)
            local doc=raw and Schema.validate(raw,catalog,kind)
            if doc and #doc.entries>0 then
                local id=name:sub(1,-6);if not Packages.id(id) then id=doc.id end
                local ok,err=write_document(fs,doc,id,true,true)
                if not ok and err~="diy_package_exists" then return nil,err end
            end
        end
        if #previous_document.entries>0 and previous_document.id~="diy_packages" then
            local ok,err,_,mapping=write_document(fs,previous_document,previous_document.id,true,true)
            if not ok then return nil,err end;startup_id_map=mapping
        end
        settings.bootstrapped=true;persist()
        end
        if options.starter then
            local starter=options.starter();local id="starter-"..kind
            local legacy=read_package(fs,id)
            if legacy and #legacy.document.entries>1 then
                local ok,err=retire_multi(fs,legacy);if not ok then return nil,err end
            end
            if starter and not settings.individual_starters then
                local ok,err=write_document(fs,starter,id,true,true,false,true)
                if not ok then return nil,err end
                settings.individual_starters=true;persist()
            end
        end
        return true
    end
    local function lookup(name)
        local ok,value=pcall(get_mod,name);return ok and value or nil
    end
    function self.directory()
        local fs,why=filesystem();return fs and fs.package_directory,why
    end
    function self.copy_directory()
        local path,why=self.directory();if not path then return report(why) end
        if Clipboard and Clipboard.put then Clipboard.put(path)
        elseif Clipboard and Clipboard.set then Clipboard.set(path)
        else return report(path) end
        return true
    end
    function self.signature()
        return self.package_signature or raw_signature()
    end
    function self.scan()
        local fs,why=filesystem();if not fs then return report(why) end
        local ok;ok,why=bootstrap(fs);if not ok then return report(why) end
        local selected=self.files[self.selected_file]
        local names,errors;names,why,errors=fs.list_packages(Packages.id)
        if not names then return report(why) end
        local packages={};errors=errors or {};local total_bytes=0
        for _,id in ipairs(names)do
            local files;files,why=fs.read_package(id,Packages.id,Packages.path)
            local pack;if files then pack,why=package_api.validate(files,catalog,kind,id) end
            if pack and total_bytes+pack.bytes>Packages.max_library_bytes then errors[id]="diy_package_limit"
            elseif pack then packages[id]=pack;total_bytes=total_bytes+pack.bytes else errors[id]=why end
        end
        local composed=package_api.compose(packages,catalog,kind,settings.disabled,lookup)
        for id,error in pairs(composed.errors)do errors[id]=error end
        -- Preparation is local and optional: a failed visual resource must not
        -- remove otherwise valid gameplay entries or change room hashes.
        for id,pack in pairs(composed.packages)do if pack.manifest.assets and #pack.manifest.assets>0 then
            local ok,base,hash=pcall(fs.stage_assets,pack,Packages.path,Hash)
            if ok and base then pack.asset_base=base;pack.asset_hash=hash
            else pack.asset_error=tostring(ok and hash or base);errors[id]=pack.asset_error end
        end end
        local identities={}
        for id,pack in pairs(composed.packages)do identities[#identities+1]=id..":"..pack.closure_hash end
        table.sort(identities);local signature=Hash.hex(table.concat(identities,"\n"))..":"..#composed.document.entries
        local changed=signature~=self.package_signature
        self.packages,self.active_packages,self.package_errors=packages,composed.packages,errors
        self.files=names;self.selected_file=math.max(1,math.min(self.selected_file,#names))
        for i,id in ipairs(names)do if id==selected then self.selected_file=i end end
        if changed then
            local selected_ids={};local seen={}
            for _,id in ipairs(self.options.selected)do if composed.sources[id] then selected_ids[#selected_ids+1]=id;seen[id]=true end end
            if not settings.selection_migrated then
                for _,old_id in ipairs(previous_selected)do
                    local mapped=startup_id_map[old_id]
                    if mapped and composed.sources[mapped] and not seen[mapped] then selected_ids[#selected_ids+1]=mapped;seen[mapped]=true end
                end
                local old_hash=Hash.hex(assert(Codec.encode(previous_document)))
                for id,pack in pairs(composed.packages)do
                    if Hash.hex(assert(Codec.encode(pack.document)))==old_hash then
                        for _,old_id in ipairs(previous_selected)do
                            local mapped=package_api.entry_identity(pack,old_id)
                            if composed.sources[mapped] and not seen[mapped] then selected_ids[#selected_ids+1]=mapped;seen[mapped]=true end
                        end
                        break
                    end
                end
            end
            table.sort(selected_ids);self.options.selected=selected_ids
            self.document=composed.document;self.entry_sources=composed.sources;self.entry_hashes=composed.hashes
            if kind=="conditions" then self.options.mode="manual";self.options.max_total=#self.document.entries end
            self.legacy_policy_keys={}
            for id,source in pairs(composed.sources)do
                local old=source.document_id.."/"..source.entry_id
                self.legacy_policy_keys[old]=self.legacy_policy_keys[old] or {}
                self.legacy_policy_keys[old][#self.legacy_policy_keys[old]+1]=composed.document.id.."/"..id
            end
            self.package_signature=signature
            mod:set("diy_document_v1",assert(Codec.encode(self.document)))
            mod:set("diy_options_v1",Schema.copy(self.options))
            settings.selection_migrated=true;persist()
        end
        self.revision=self.revision+1;snapshot=nil
        self.last_error=nil;self.last_message=nil
        if options.changed and changed and not initializing then options.changed("packages") end
        return true
    end
    function self.package_enabled(id) return self.active_packages[id]~=nil end
    function self.package_disabled(id) return settings.disabled[id]==true end
    function self.format_message(value)
        local key,extra=tostring(value):match("^(diy_[%w_]+)(.*)$")
        return key and (mod:localize(key)..extra) or tostring(value)
    end
    function self.status_message()
        local loaded,invalid=0,0
        for _ in pairs(self.active_packages)do loaded=loaded+1 end
        for id in pairs(self.package_errors)do if not settings.disabled[id] then invalid=invalid+1 end end
        local summary=mod:localize("diy_packages_count",loaded,#self.files,#self.document.entries,invalid)
        local id=self.files[self.selected_file]
        local issue=id and self.package_errors[id]
        if not issue then
            local ids={};for key in pairs(self.package_errors)do if not settings.disabled[key] then ids[#ids+1]=key end end;table.sort(ids)
            id=ids[1];issue=id and self.package_errors[id]
        end
        if issue then
            if settings.disabled[id] then issue=mod:localize("diy_package_disabled")
            else issue=self.format_message(issue) end
            return summary.."\n"..id..": "..issue,not settings.disabled[id]
        end
        return summary,false
    end
    function self.toggle_package(id)
        if not Packages.id(id) then return report("diy_package_path") end
        settings.disabled[id]=not settings.disabled[id] or nil;persist();return self.scan()
    end
    function self.import_file(name)
        -- A selected installed package is already discovered at startup;
        -- this action explicitly reloads it after authoring changes.
        if not Packages.id(name) then return report("diy_package_path") end
        local ok,why=self.scan();if not ok then return nil,why end
        for i,id in ipairs(self.files)do if id==name then self.selected_file=i end end
        if not self.active_packages[name] then return report(self.package_errors[name] or "diy_package_missing") end
        return self.document
    end
    function self.import_text(text,source)
        local raw,why=Codec.decode(text);if not raw then return report(why) end
        local doc;doc,why=Schema.validate(raw,catalog,kind);if not doc then return report(why) end
        if #doc.entries==0 then return report("diy_empty") end
        local fs;fs,why=filesystem();if not fs then return report(why) end
        local canonical=assert(Codec.encode(doc))
        -- The starter and author folders may use a different ID from the
        -- JSON document. Reuse an identical installed document under any
        -- valid folder ID, preserving its Lua/resources and selected keys.
        local installed,listing_error=fs.list_packages(Packages.id)
        if not installed then return report(listing_error) end
        for _,existing_id in ipairs(installed)do
            local existing=read_package(fs,existing_id)
            if existing and Codec.encode(existing.document)==canonical then
                if #existing.document.entries>1 then
                    local ok,err=retire_multi(fs,existing);if not ok then return report(err) end
                    break
                else
                    settings.disabled[existing_id]=nil;persist();self.source_file=source
                    return self.import_file(existing_id)
                end
            end
        end
        local ok,ids;ok,why,ids=write_document(fs,doc,doc.id,true,false,true)
        if not ok then return report(why) end
        persist();self.source_file=source;return self.import_file(ids[1])
    end
    function self.export(name,document)
        local fs,why=filesystem();if not fs then return report(why) end
        if document then
            local doc;doc,why=Schema.validate(document,catalog,kind);if not doc then return report(why) end
            local id="starter-"..kind
            local ok,ids;ok,why,ids=write_document(fs,doc,id,true,true,false,true)
            if not ok and why~="diy_package_exists" then return report(why) end
            self.scan()
            for i,value in ipairs(self.files)do if value==ids[1] then self.selected_file=i end end
            self.last_message=ok and "diy_packages_refreshed" or "diy_package_exists"
            return true
        end
        if not next(self.active_packages) then return report("diy_package_missing") end
        local path;path,why=fs.export_packages(self.active_packages,Packages.id,Packages.path)
        if not path then return report(why) end
        self.last_error=nil;self.last_message=mod:localize("diy_packages_exported",path);return path
    end
    function self.snapshot()
        if not snapshot or snapshot_revision~=self.revision then
            snapshot={document=Schema.copy(self.document),options=Schema.copy(self.options),signature=self.signature(),
                packages=Schema.copy(self.active_packages),sources=Schema.copy(self.entry_sources),hashes=Schema.copy(self.entry_hashes)}
            snapshot_revision=self.revision
        end
        return snapshot
    end
    function self.runtime_error(package_id,message)
        self.package_errors[package_id]=tostring(message);self.revision=self.revision+1
    end
    function self.resolve_startup_dependencies()
        if self.startup_dependencies_resolved then return end
        self.startup_dependencies_resolved=true
        for _,pack in pairs(self.packages)do if #(pack.manifest.requires_mods or {})>0 then return self.scan() end end
    end
    -- Initialization performs a single directory scan. There is no filesystem
    -- work from snapshot(), signatures, frame updates, kills, or entry effects.
    -- Declared assets are frozen under the provider-readable cache during scan.
    self.scan()
    initializing=false
    return self
end
return L
