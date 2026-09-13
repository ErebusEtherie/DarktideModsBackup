-- Versioned, executable local packages. Validation never evaluates Lua.
local P={format="Darktide.DIY.Package",version=2,api={major=1,minor=1},max_packages=256,max_files=256,max_bytes=33554432,max_library_bytes=134217728}
local compile=Mods and Mods.lua and Mods.lua.loadstring or loadstring
local function fail(where,message) error(where..": "..message,0) end
local function keys(s) local t={};for k in s:gmatch("%S+")do t[k]=true end;return t end
local function object(t,allowed,path)
    if type(t)~="table" or getmetatable(t) then fail(path,"object required") end
    for k in pairs(t)do if not allowed[k] then fail(path.."."..tostring(k),"unknown field; use namespaced extensions for metadata") end end
end
local function array(t,limit,path)
    if type(t)~="table" or getmetatable(t) or #t>limit then fail(path,"array exceeds limit "..limit) end
    local n=0;for k in pairs(t)do n=n+1;if type(k)~="number" or k%1~=0 or k<1 or k>#t then fail(path,"dense array required") end end
    if n~=#t then fail(path,"dense array required") end
end
function P.id(id) return type(id)=="string" and #id<=64 and id:match("^[a-z][a-z0-9_%-]*$")~=nil and P.path(id) end
function P.path(path)
    if type(path)~="string" or #path>192 or path:find('[%z\1-\31<>:"\\|?*]') or path:sub(1,1)=="/" or path:sub(-1)=="/" or path:find("//",1,true) then return false end
    local count=0
    for part in path:gmatch("[^/]+")do
        count=count+1;local stem=(part:match("^([^%.]+)") or ""):upper()
        if #part>64 or part=="." or part==".." or part:sub(1,1)=="." or part:match("[%. ]$") or
            stem=="CON" or stem=="PRN" or stem=="AUX" or stem=="NUL" or stem:match("^COM[1-9]$") or stem:match("^LPT[1-9]$") then return false end
    end
    return count>0 and count<=8
end
local function version(s,path)
    if type(s)~="string" then fail(path,"semantic version MAJOR.MINOR.PATCH required") end
    local a,b,c=s:match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then fail(path,"semantic version MAJOR.MINOR.PATCH required") end
    for _,part in ipairs({a,b,c})do if #part>4 or #part>1 and part:sub(1,1)=="0" then fail(path,"version components use 0-9999 without leading zeros") end end
    a,b,c=tonumber(a),tonumber(b),tonumber(c)
    if a>9999 or b>9999 or c>9999 then fail(path,"version component exceeds 9999") end
    return {a,b,c}
end
local function compare(a,b)
    for i=1,3 do if a[i]~=b[i] then return a[i]<b[i] and -1 or 1 end end;return 0
end
local capabilities=keys("actions.v1 effects.v1 events.v1 resources.v1 assets.v1 modules.v1 cleanup.v1 native.v1")
local asset_extensions={texture=keys("png jpg jpeg dds texture"),font=keys("slug"),video=keys("ivf bk2"),
    material=keys("material"),particles=keys("particles"),unit=keys("unit"),animation=keys("animation"),mouse_cursor=keys("png"),slug_album=keys("slug")}
function P.new(Schema,Codec,Hash)
    local api={}
    api.identity=function(package_id,entry_id) return "p"..Hash.hex(package_id.."/"..entry_id):sub(1,40) end
    function api.namespace(pack) return pack.manifest.entry_namespace or pack.manifest.id end
    function api.entry_identity(pack,id) return api.identity(api.namespace(pack),id) end
    function api.signal_id(pack,name)
        for _,shared in ipairs(pack.manifest.shared_signals or {})do if shared==name then return name end end
        return "s"..Hash.hex(api.namespace(pack).."/"..name):sub(1,40)
    end
    function api.prepare_entry(pack,entry,packages)
        local e=Schema.copy(entry)
        local function conditions(list)
            for _,c in ipairs(list or {})do
                if c.field=="signal" or c.field=="event.signal_name" then c.value=api.signal_id(pack,c.value)
                elseif c.field=="affix" then
                    local dep,id=c.value:match("^@([a-z0-9_%-]+)/([a-z0-9_%-]+)$")
                    if dep then
                        local permitted=false
                        for _,d in ipairs(pack.manifest.dependencies or {})do if d.id==dep then permitted=true end end
                        if not permitted then fail(pack.manifest.id,"undeclared affix dependency: "..dep) end
                        c.value=packages and packages[dep] and api.entry_identity(packages[dep],id) or api.identity(dep,id)
                    else c.value=api.entry_identity(pack,c.value) end
                end
            end
        end
        conditions(e.conditions)
        for _,r in ipairs(e.rules or {})do
            conditions(r.conditions)
            for _,a in ipairs(r.actions)do if a.type=="signal" then a.name=api.signal_id(pack,a.name) end end
        end
        return e
    end
    local function validate(files,kind,expected)
        if type(files)~="table" or type(files["package.json"])~="string" then fail("package.json","missing package manifest") end
        local manifest,reason=Codec.decode(files["package.json"]);if not manifest then fail("package.json",reason) end
        object(manifest,keys("format version id entry_namespace package_version name description author kind api definitions entrypoint files assets dependencies conflicts requires_mods capabilities shared_signals extensions"),"package.json")
        if manifest.format~=P.format or manifest.version~=1 and manifest.version~=P.version then fail("package.json","unsupported package format/version") end
        if manifest.entry_namespace~=nil and not P.id(manifest.entry_namespace) then fail("package.json.entry_namespace","valid stable namespace required") end
        if not P.id(manifest.id) or expected and manifest.id~=expected then fail("package.json.id","must match its package folder ID") end
        if manifest.kind~=kind then fail("package.json.kind","wrong manager; expected "..kind) end
        local ver=version(manifest.package_version,"package.json.package_version")
        object(manifest.api,keys("major min_minor"),"package.json.api")
        if manifest.api.major~=P.api.major or type(manifest.api.min_minor)~="number" or manifest.api.min_minor%1~=0 or manifest.api.min_minor<0 or manifest.api.min_minor>P.api.minor then fail("package.json.api","unsupported Lua API requirement") end
        if manifest.definitions~="definitions.json" then fail("package.json.definitions","definitions.json required") end
        if manifest.entrypoint~=nil and (not P.path(manifest.entrypoint) or not manifest.entrypoint:match("^lua/.+%.lua$")) then fail("package.json.entrypoint","use a declared lua/*.lua module") end
        for _,key in ipairs({"dependencies","conflicts","requires_mods","capabilities","shared_signals"})do if manifest[key]~=nil then array(manifest[key],64,"package.json."..key) end end
        local signals={}
        for _,name in ipairs(manifest.shared_signals or {})do if not P.id(name) or signals[name] then fail("package.json.shared_signals","invalid or duplicate signal ID") end;signals[name]=true end
        local seen={}
        for _,dep in ipairs(manifest.dependencies or {})do
            object(dep,keys("id min_version before_version"),"package.json.dependencies")
            if not P.id(dep.id) or seen[dep.id] then fail("package.json.dependencies","invalid or duplicate dependency") end
            seen[dep.id]=true;version(dep.min_version,"dependency.min_version")
            if dep.before_version then if compare(version(dep.before_version,"dependency.before_version"),version(dep.min_version,"dependency.min_version"))<=0 then fail("package.json.dependencies","empty version range") end end
        end
        seen={}
        for _,id in ipairs(manifest.conflicts or {})do if not P.id(id) or seen[id] then fail("package.json.conflicts","invalid or duplicate package ID") end;seen[id]=true end
        for _,dep in ipairs(manifest.requires_mods or {})do
            object(dep,keys("id api_major optional"),"package.json.requires_mods")
            if type(dep.id)~="string" or #dep.id>64 or not dep.id:match("^[%w_%-]+$") then fail("package.json.requires_mods","invalid mod ID") end
            if dep.api_major~=nil and (type(dep.api_major)~="number" or dep.api_major<1 or dep.api_major%1~=0) then fail("package.json.requires_mods","invalid API major") end
            if dep.optional~=nil and type(dep.optional)~="boolean" then fail("package.json.requires_mods","optional must be boolean") end
        end
        for _,cap in ipairs(manifest.capabilities or {})do if not capabilities[cap] then fail("package.json.capabilities","unsupported capability "..tostring(cap)) end end
        if manifest.extensions then
            if type(manifest.extensions)~="table" then fail("package.json.extensions","object required") end
            for key in pairs(manifest.extensions)do if type(key)~="string" or not key:match("^[%w_-]+%.[%w_.-]+$") then fail("package.json.extensions","namespaced keys required") end end
        end
        array(manifest.files,P.max_files,"package.json.files")
        local declared={};local names={};local total=#files["package.json"]
        for _,path in ipairs(manifest.files)do
            if not P.path(path) or path=="package.json" or declared[path:lower()] then fail("package.json.files","invalid or duplicate file path") end
            if path~="definitions.json" and not path:match("^lua/.+%.lua$") and not path:match("^resources/.+") then fail(path,"files must be definitions.json, lua/*.lua or resources/*") end
            if type(files[path])~="string" then fail(path,"declared file is missing") end
            if #files[path]>(path:match("^lua/") and 262144 or path=="definitions.json" and 524288 or 8388608) then fail(path,"file is too large") end
            declared[path:lower()]=path;names[#names+1]=path;total=total+#files[path]
            if path:match("^lua/") then
                if files[path]:byte(1)==27 then fail(path,"Lua source required; bytecode is not portable") end
                if not compile then fail(path,"Lua source compiler unavailable") end
                local fn,err=compile(files[path],"@DIY/"..manifest.id.."/"..path);if not fn then fail(path,err) end
            end
        end
        if total>P.max_bytes then fail(manifest.id,"package exceeds 32 MiB") end
        for path in pairs(files)do if path~="package.json" and declared[path:lower()]~=path then fail(path,"file is absent from the manifest") end end
        if not declared["definitions.json"] or manifest.entrypoint and not declared[manifest.entrypoint:lower()] then fail("package.json","definitions or entrypoint missing from files") end
        if manifest.assets~=nil then
            array(manifest.assets,64,"package.json.assets")
            if manifest.api.min_minor<1 then fail("package.json.assets","assets require API min_minor 1") end
            local ids,aliases={},{}
            for _,asset in ipairs(manifest.assets)do
                object(asset,keys("id type path hotspot_x hotspot_y"),"package.json.assets")
                if not P.id(asset.id) or ids[asset.id] then fail("package.json.assets","invalid or duplicate asset ID") end
                ids[asset.id]=true
                local extensions=asset_extensions[asset.type]
                if not extensions then fail("package.json.assets","unsupported asset type") end
                if not P.path(asset.path) or not asset.path:match("^resources/.+") or declared[asset.path:lower()]~=asset.path then fail("package.json.assets","asset path must match a declared resources file") end
                if not extensions[asset.path:match("%.([^.]+)$")] then fail("package.json.assets","asset extension does not match its type") end
                -- SimpleAssets derives native names by dropping the extension.
                -- Two source files of one native type may not share that name.
                local alias=asset.type..":"..asset.path:gsub("%.[^.]+$",""):lower()
                local config=asset.path..":"..tostring(asset.hotspot_x)..":"..tostring(asset.hotspot_y)
                if aliases[alias] and aliases[alias]~=config then fail("package.json.assets","conflicting resource name or cursor hotspot") end
                aliases[alias]=config
                if asset.type=="mouse_cursor" then
                    for _,key in ipairs({"hotspot_x","hotspot_y"})do local n=asset[key]
                        if type(n)~="number" or n%1~=0 or n<0 or n>65535 then fail("package.json.assets",key.." must be an integer from 0 to 65535") end
                    end
                elseif asset.hotspot_x~=nil or asset.hotspot_y~=nil then fail("package.json.assets","hotspot coordinates are only valid for mouse_cursor") end
                if asset.type=="animation" then
                    local bones=asset.path:gsub("%.animation$",".bones")
                    if declared[bones:lower()]~=bones then fail("package.json.assets","animation requires a declared same-stem .bones file") end
                end
            end
        end
        local raw,err=Codec.decode(files["definitions.json"]);if not raw then fail("definitions.json",err) end
        return manifest,ver,names,total,raw
    end
    function api.validate(files,catalog,kind,expected)
        local ok,result=pcall(function()
            -- Validate metadata through the same localized text contract as definitions.
            local manifest,ver,names,total,raw=validate(files,kind,expected)
            local document,err=Schema.validate(raw,catalog,kind);if not document then fail("definitions.json",err) end
            if manifest.version>=2 and #document.entries~=1 then fail("definitions.json","version 2 packages must contain exactly one entry") end
            local encoded;encoded,err=Codec.encode(document);if not encoded then fail("definitions.json",err.." after normalization") end
            for _,entry in ipairs(document.entries)do if entry.script and not manifest.entrypoint then fail("package.json.entrypoint","script entries require a Lua entrypoint") end end
            local metadata={format=Schema.format,version=Schema.version,kind=kind,id=manifest.id,name=manifest.name,description=manifest.description,entries={}}
            local valid;valid,err=Schema.validate(metadata,catalog,kind);if not valid then fail("package.json",err) end
            if manifest.author~=nil and (type(manifest.author)~="string" or #manifest.author>256) then fail("package.json.author","text up to 256 bytes required") end
            table.sort(names);local identity={assert(Codec.encode(manifest))}
            for _,name in ipairs(names)do identity[#identity+1]=name..":"..#files[name]..":"..Hash.hex(files[name]) end
            local pack={manifest=manifest,version=ver,document=document,files=Schema.copy(files),bytes=total,hash=Hash.hex(table.concat(identity,"\n"))}
            for _,entry in ipairs(document.entries)do api.prepare_entry(pack,entry) end
            return pack
        end)
        if not ok then return nil,tostring(result) end;return result
    end
    function api.from_document(document,package_id,with_script,namespace)
        local id=package_id or document.id
        local files={["definitions.json"]=assert(Codec.encode(document))}
        local manifest={format=P.format,version=#document.entries==1 and P.version or 1,id=id,entry_namespace=namespace,package_version="1.0.0",name=document.name,description=document.description,
            kind=document.kind,api={major=1,min_minor=0},definitions="definitions.json",files={"definitions.json"}}
        -- Loose JSON used a shared signal namespace. Preserve that contract
        -- when migrating documents into a package directory.
        local signals={}
        local function collect(list)for _,c in ipairs(list or {})do if c.field=="signal" or c.field=="event.signal_name" then signals[c.value]=true end end end
        for _,e in ipairs(document.entries)do
            collect(e.conditions)
            for _,r in ipairs(e.rules or {})do collect(r.conditions);for _,a in ipairs(r.actions)do if a.type=="signal" then signals[a.name]=true end end end
        end
        manifest.shared_signals={};for name in pairs(signals)do manifest.shared_signals[#manifest.shared_signals+1]=name end;table.sort(manifest.shared_signals)
        if with_script then
            manifest.entrypoint="lua/main.lua";manifest.files[#manifest.files+1]="lua/main.lua";manifest.files[#manifest.files+1]="resources/README.txt"
            files["lua/main.lua"]="-- Trusted local mod code. Add callbacks by the original ID in definitions.json.\nreturn { api_version = { major = 1, minor = 0 }, entries = {}, exports = {} }\n"
            files["resources/README.txt"]="Declare every resource in package.json files. Read frozen bytes with context:resource('resources/name'). Native material/sound use requires a valid game resource identifier.\n"
        end
        files["package.json"]=assert(Codec.encode(manifest));return files
    end
    function api.child_id(namespace,entry_id)
        local id=namespace.."-"..entry_id
        return #id<=64 and id or id:sub(1,47).."-"..Hash.hex(id):sub(1,16)
    end
    function api.split_document(document,namespace,with_script,force_children)
        local out={};namespace=namespace or document.id
        for _,entry in ipairs(document.entries)do
            local doc=Schema.copy(document);doc.entries={Schema.copy(entry)}
            doc.name=Schema.copy(entry.name);doc.description=Schema.copy(entry.description)
            local id=(force_children or #document.entries>1) and api.child_id(namespace,entry.id) or namespace
            out[id]=api.from_document(doc,id,with_script,namespace)
        end
        return out
    end
    function api.split_package(pack)
        local out={};local namespace=api.namespace(pack)
        for _,entry in ipairs(pack.document.entries)do
            local id=api.child_id(pack.manifest.id,entry.id)
            local doc=Schema.copy(pack.document);doc.entries={Schema.copy(entry)};doc.name=Schema.copy(entry.name);doc.description=Schema.copy(entry.description)
            local files=Schema.copy(pack.files);local manifest=Schema.copy(pack.manifest)
            manifest.id=id;manifest.version=P.version;manifest.entry_namespace=namespace;manifest.name=doc.name;manifest.description=doc.description
            files['definitions.json']=assert(Codec.encode(doc))
            if manifest.entrypoint then
                local wrapper='lua/individual_entry.lua';local n=0
                while files[wrapper]do n=n+1;wrapper='lua/individual_entry_'..n..'.lua'end
                files[wrapper]='local source = package_require('..string.format('%q',manifest.entrypoint)..')\nreturn { api_version = source.api_version, entries = { ['..string.format('%q',entry.id)..'] = source.entries and source.entries['..string.format('%q',entry.id)..'] }, exports = source.exports }\n'
                manifest.files[#manifest.files+1]=wrapper;manifest.entrypoint=wrapper
            end
            files['package.json']=assert(Codec.encode(manifest));out[id]=files
        end
        return out
    end
    function api.compose(packages,catalog,kind,disabled,mod_lookup)
        local errors,ordered,done,visiting={}, {}, {}, {}
        local function visit(id)
            if done[id]~=nil then return done[id] end
            if disabled and disabled[id] then errors[id]="Package disabled";done[id]=false;return false end
            local p=packages[id];if not p then errors[id]="Missing dependency: "..id;done[id]=false;return false end
            if visiting[id] then errors[id]="Dependency cycle: "..id;return false end
            visiting[id]=true
            local valid=true;local dep_hashes={p.hash}
            for _,dep in ipairs(p.manifest.dependencies or {})do
                local d=packages[dep.id]
                if not d or not visit(dep.id) then errors[id]="Unavailable dependency: "..dep.id;valid=false
                elseif compare(d.version,version(dep.min_version,"min_version"))<0 or dep.before_version and compare(d.version,version(dep.before_version,"before_version"))>=0 then errors[id]="Dependency version mismatch: "..dep.id;valid=false
                else dep_hashes[#dep_hashes+1]=dep.id..":"..d.closure_hash end
            end
            for _,other in ipairs(p.manifest.conflicts or {})do if packages[other] and not (disabled and disabled[other]) then errors[id]="Conflicting package: "..other;valid=false end end
            for _,dep in ipairs(p.manifest.requires_mods or {})do
                local m=mod_lookup and mod_lookup(dep.id)
                local available=m and (not m.is_enabled or m:is_enabled())
                if not dep.optional and (not available or dep.api_major and (not m.diy_api or m.diy_api.version~=dep.api_major)) then errors[id]="Required mod/API unavailable: "..dep.id;valid=false end
            end
            visiting[id]=nil;done[id]=valid
            if valid then p.closure_hash=Hash.hex(table.concat(dep_hashes,"\n"));ordered[#ordered+1]=p end
            return valid
        end
        local names={};for id in pairs(packages)do names[#names+1]=id end;table.sort(names)
        for _,id in ipairs(names)do visit(id) end
        local document={format=Schema.format,version=Schema.version,kind=kind,id="diy_packages",name={en="DIY packages",["zh-cn"]="DIY 包",["zh-tw"]="DIY 套件"},entries={}}
        local sources,hashes,active={},{},{}
        for _,p in ipairs(ordered)do
            local missing=false;local collision
            for _,dep in ipairs(p.manifest.dependencies or {})do if not active[dep.id] then missing=dep.id end end
            for _,entry in ipairs(p.document.entries)do if sources[api.entry_identity(p,entry.id)] then collision=entry.id;break end end
            if missing then errors[p.manifest.id]="Dependency was not loaded: "..missing
            elseif collision then errors[p.manifest.id]="Entry namespace already provided: "..collision
            elseif #document.entries+#p.document.entries>Schema.max_entries then errors[p.manifest.id]="Combined entry limit exceeded (128)"
            else
                local start=#document.entries
                active[p.manifest.id]=p
                for _,entry in ipairs(p.document.entries)do
                    local e=api.prepare_entry(p,entry,packages);e.id=api.entry_identity(p,entry.id)
                    if e.exclusive_group then e.exclusive_group="g"..Hash.hex(api.namespace(p).."/"..e.exclusive_group):sub(1,40) end
                    sources[e.id]={package_id=p.manifest.id,document_id=p.document.id,entry_id=entry.id,name=p.manifest.name}
                    hashes[e.id]=Hash.hex(assert(Codec.encode(entry)).."\n"..p.closure_hash)..":"..p.bytes
                    document.entries[#document.entries+1]=e
                end
                if not Codec.encode(document) then
                    for i=#document.entries,start+1,-1 do
                        local id=document.entries[i].id;sources[id]=nil;hashes[id]=nil;document.entries[i]=nil
                    end
                    active[p.manifest.id]=nil;errors[p.manifest.id]="Combined definitions exceed JSON byte/node limits"
                end
            end
        end
        table.sort(document.entries,function(a,b)return a.id<b.id end)
        return {document=document,packages=active,sources=sources,hashes=hashes,errors=errors,ordered=ordered}
    end
    return api
end
return P
