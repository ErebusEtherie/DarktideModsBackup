-- Windows Unicode filesystem access, on explicit library actions only.
-- No shell, extra DLL, Lua evaluation, or polling during gameplay.
local F={}
local function filename(s)
    if type(s)~="string" or #s>192 or not s:match("^[^%.].*%.json$") or s:find('[%z\1-\31<>:"/\\|?*]') then return false end
    local stem=(s:match("^([^%.]+)") or ""):upper()
    return stem~="CON" and stem~="PRN" and stem~="AUX" and stem~="NUL" and not stem:match("^COM[1-9]$") and not stem:match("^LPT[1-9]$")
end

function F.new(ffi,mod_name)
    if mod_name~="MortisBuffManager" and mod_name~="HavocConditionManager" then return nil,"invalid_mod_directory" end
    if not ffi then return nil,"template_io_unavailable" end
    if not pcall(ffi.typeof,"DT_DIY_FIND_DATA") then
        ffi.cdef[[
        typedef struct { unsigned long attributes; unsigned long times[6]; unsigned long size_high, size_low, reserved[2]; unsigned short name[260], alternate[14]; } DT_DIY_FIND_DATA;
        ]]
    end
    -- FFI symbols are shared by every mod. Private symbol aliases keep our
    -- pointer types independent of load order and previously loaded versions.
    ffi.cdef[[
        int __stdcall DT_DIY_IO_MultiByteToWideChar(unsigned int,unsigned long,const char*,int,unsigned short*,int) __asm__("MultiByteToWideChar");
        int __stdcall DT_DIY_IO_WideCharToMultiByte(unsigned int,unsigned long,const unsigned short*,int,char*,int,const char*,int*) __asm__("WideCharToMultiByte");
        unsigned long __stdcall DT_DIY_IO_GetEnvironmentVariableW(const unsigned short*,unsigned short*,unsigned long) __asm__("GetEnvironmentVariableW");
        int __stdcall DT_DIY_IO_CreateDirectoryW(const unsigned short*,void*) __asm__("CreateDirectoryW");
        unsigned long __stdcall DT_DIY_IO_GetFileAttributesW(const unsigned short*) __asm__("GetFileAttributesW");
        void* __stdcall DT_DIY_IO_FindFirstFileW(const unsigned short*,DT_DIY_FIND_DATA*) __asm__("FindFirstFileW");
        int __stdcall DT_DIY_IO_FindNextFileW(void*,DT_DIY_FIND_DATA*) __asm__("FindNextFileW");
        int __stdcall DT_DIY_IO_FindClose(void*) __asm__("FindClose");
        void* __stdcall DT_DIY_IO_CreateFileW(const unsigned short*,unsigned long,unsigned long,void*,unsigned long,unsigned long,void*) __asm__("CreateFileW");
        int __stdcall DT_DIY_IO_ReadFile(void*,void*,unsigned long,unsigned long*,void*) __asm__("ReadFile");
        int __stdcall DT_DIY_IO_WriteFile(void*,const void*,unsigned long,unsigned long*,void*) __asm__("WriteFile");
        int __stdcall DT_DIY_IO_FlushFileBuffers(void*) __asm__("FlushFileBuffers");
        int __stdcall DT_DIY_IO_CloseHandle(void*) __asm__("CloseHandle");
        int __stdcall DT_DIY_IO_MoveFileExW(const unsigned short*,const unsigned short*,unsigned long) __asm__("MoveFileExW");
        int __stdcall DT_DIY_IO_DeleteFileW(const unsigned short*) __asm__("DeleteFileW");
        unsigned long __stdcall DT_DIY_IO_GetLastError(void) __asm__("GetLastError");
        int __stdcall DT_DIY_IO_RemoveDirectoryW(const unsigned short*) __asm__("RemoveDirectoryW");
    ]]
    local win=ffi.load("kernel32")
    local invalid=ffi.cast("void*",-1)
    local function wide(s)
        local n=win.DT_DIY_IO_MultiByteToWideChar(65001,8,s,#s,nil,0)
        if n==0 then error("template_name_invalid",0) end
        local out=ffi.new("unsigned short[?]",n+1); win.DT_DIY_IO_MultiByteToWideChar(65001,8,s,#s,out,n); return out
    end
    local function utf8(s)
        local n=win.DT_DIY_IO_WideCharToMultiByte(65001,0,s,-1,nil,0,nil,nil)
        local out=ffi.new("char[?]",n); win.DT_DIY_IO_WideCharToMultiByte(65001,0,s,-1,out,n,nil,nil); return ffi.string(out)
    end
    local env=ffi.new("unsigned short[32768]")
    local n=win.DT_DIY_IO_GetEnvironmentVariableW(wide("APPDATA"),env,32768)
    if n==0 or n>=32768 then return nil,"template_io_unavailable" end
    local parent=utf8(env).."/Fatshark/Darktide"
    local root=parent.."/"..mod_name
    local directory=root.."/diy"
    local store={directory=directory}
    local function exists(path) return tonumber(win.DT_DIY_IO_GetFileAttributesW(wide(path)))~=4294967295 end
    function store.ensure()
        for _,p in ipairs({root,directory}) do
            if win.DT_DIY_IO_CreateDirectoryW(wide(p),nil)==0 and not exists(p) then return nil,"template_io_failed" end
        end
        return true
    end
    function store.list()
        local ok,err=store.ensure(); if not ok then return nil,err end
        local data=ffi.new("DT_DIY_FIND_DATA[1]")
        local handle=win.DT_DIY_IO_FindFirstFileW(wide(directory.."/*.json"),data)
        if handle==invalid then if win.DT_DIY_IO_GetLastError()==2 then return {} end; return nil,"template_io_failed" end
        local names={}
        repeat
            if math.floor(tonumber(data[0].attributes)/16)%2==0 then names[#names+1]=utf8(data[0].name) end
            if #names>256 then win.DT_DIY_IO_FindClose(handle); return nil,"template_library_full" end
        until win.DT_DIY_IO_FindNextFileW(handle,data)==0
        local errcode=win.DT_DIY_IO_GetLastError(); win.DT_DIY_IO_FindClose(handle)
        if errcode~=18 then return nil,"template_io_failed" end
        table.sort(names); return names
    end
    function store.read(name)
        if not filename(name) then return nil,"template_name_invalid" end
        local filename=name
        local handle=win.DT_DIY_IO_CreateFileW(wide(directory.."/"..filename),2147483648,1,nil,3,128,nil)
        if handle==invalid then return nil,"template_io_failed" end
        local buffer,nread=ffi.new("char[524289]"),ffi.new("unsigned long[1]")
        local ok=win.DT_DIY_IO_ReadFile(handle,buffer,524289,nread,nil); win.DT_DIY_IO_CloseHandle(handle)
        if ok==0 then return nil,"template_io_failed" end
        if nread[0]>524288 then return nil,"template_too_large" end
        return ffi.string(buffer,nread[0])
    end
    function store.remove(name)
        if not filename(name) then return nil,"template_name_invalid" end
        local filename=name
        if win.DT_DIY_IO_DeleteFileW(wide(directory.."/"..filename))==0 then return nil,"template_io_failed" end
        return true
    end
    function store.write(name,text,overwrite)
        if not filename(name) then return nil,"template_name_invalid" end
        if type(text)~="string" or #text>524288 then return nil,"template_too_large" end
        local filename=name
        local ok,err=store.ensure(); if not ok then return nil,err end
        local dest=directory.."/"..filename
        if not overwrite and exists(dest) then return nil,"template_exists" end
        if not exists(dest) then
            local entries,e=store.list(); if not entries then return nil,e end
            if #entries>=256 then return nil,"template_library_full" end
        end
        local tmp,handle
        for i=1,100 do
            tmp=dest..".writing-"..i
            handle=win.DT_DIY_IO_CreateFileW(wide(tmp),1073741824,0,nil,1,128,nil)
            if handle~=invalid then break end
        end
        if handle==invalid then return nil,"template_io_failed" end
        local written=ffi.new("unsigned long[1]")
        local good=win.DT_DIY_IO_WriteFile(handle,text,#text,written,nil)~=0 and tonumber(written[0])==#text and win.DT_DIY_IO_FlushFileBuffers(handle)~=0
        win.DT_DIY_IO_CloseHandle(handle)
        if good then good=win.DT_DIY_IO_MoveFileExW(wide(tmp),wide(dest),overwrite and 9 or 8)~=0 end
        if not good then win.DT_DIY_IO_DeleteFileW(wide(tmp)); return nil,not overwrite and exists(dest) and "template_exists" or "template_io_failed" end
        return true
    end
    -- Package IO shares Unicode handles with legacy JSON migration, but a
    -- package is always an entire directory committed without overwriting it.
    store.package_directory=directory.."/packages"
    store.export_directory=directory.."/exports"
    local function attributes(path) return tonumber(win.DT_DIY_IO_GetFileAttributesW(wide(path))) end
    local function safe_directory(path,create)
        local value=attributes(path)
        if value==4294967295 and create then
            if win.DT_DIY_IO_CreateDirectoryW(wide(path),nil)==0 then return nil,"diy_package_io" end
            value=attributes(path)
        end
        if value==4294967295 or math.floor(value/16)%2~=1 or math.floor(value/1024)%2==1 then return nil,"diy_package_path" end
        return true
    end
    local function children(path)
        local valid,why=safe_directory(path,false);if not valid then return nil,why end
        local data=ffi.new("DT_DIY_FIND_DATA[1]");local handle=win.DT_DIY_IO_FindFirstFileW(wide(path.."/*"),data)
        if handle==invalid then if win.DT_DIY_IO_GetLastError()==2 then return {} end;return nil,"diy_package_io" end
        local out={}
        repeat
            local name=utf8(data[0].name)
            if name~="." and name~=".." then
                out[#out+1]={name=name,attributes=tonumber(data[0].attributes),size=tonumber(data[0].size_low),high=tonumber(data[0].size_high)}
                if #out>256 then win.DT_DIY_IO_FindClose(handle);return nil,"diy_package_limit" end
            end
        until win.DT_DIY_IO_FindNextFileW(handle,data)==0
        local code=win.DT_DIY_IO_GetLastError();win.DT_DIY_IO_FindClose(handle)
        if code~=18 then return nil,"diy_package_io" end
        table.sort(out,function(a,b)return a.name<b.name end);return out
    end
    local function ensure_packages()
        local ok,why=store.ensure();if not ok then return nil,why end
        ok,why=safe_directory(root,false);if not ok then return nil,why end
        ok,why=safe_directory(directory,false);if not ok then return nil,why end
        return safe_directory(store.package_directory,true)
    end
    function store.list_packages(valid_id)
        local ok,why=ensure_packages();if not ok then return nil,why end
        local values;values,why=children(store.package_directory);if not values then return nil,why end
        local names,errors={},{}
        for _,value in ipairs(values)do
            if value.name:sub(1,1)~="." then
                if not valid_id(value.name) or math.floor(value.attributes/16)%2~=1 or math.floor(value.attributes/1024)%2==1 then errors[value.name]="diy_package_path"
                else names[#names+1]=value.name end
            end
        end
        if #names>256 then return nil,"diy_package_limit" end
        return names,nil,errors
    end
    local function read_tree(root_path,valid_path)
        local files,total,count={},0,0
        local function walk(relative,depth)
            if depth>8 then return nil,"diy_package_path" end
            local path=root_path..(relative~="" and "/"..relative or "")
            local rows,why=children(path);if not rows then return nil,why end
            for _,row in ipairs(rows)do
                local rel=(relative~="" and relative.."/" or "")..row.name
                if not valid_path(rel) or math.floor(row.attributes/1024)%2==1 then return nil,"diy_package_path: "..rel end
                if math.floor(row.attributes/16)%2==1 then
                    local ok;ok,why=walk(rel,depth+1);if not ok then return nil,why end
                else
                    count=count+1;total=total+row.size
                    if count>257 or row.high~=0 or row.size>8388608 or total>33554432 then return nil,"diy_package_limit" end
                    local handle=win.DT_DIY_IO_CreateFileW(wide(root_path.."/"..rel),2147483648,1,nil,3,2097280,nil)
                    if handle==invalid then return nil,"diy_package_io: "..rel end
                    local buffer,nread=ffi.new("char[?]",row.size+1),ffi.new("unsigned long[1]")
                    local ok=win.DT_DIY_IO_ReadFile(handle,buffer,row.size+1,nread,nil);win.DT_DIY_IO_CloseHandle(handle)
                    if ok==0 or tonumber(nread[0])~=row.size then return nil,"diy_package_changed: "..rel end
                    files[rel]=ffi.string(buffer,nread[0])
                end
            end
            return true
        end
        local ok,why=walk("",0);if not ok then return nil,why end
        return files
    end
    function store.read_package(id,valid_id,valid_path)
        if not valid_id(id) then return nil,"diy_package_path" end
        return read_tree(store.package_directory.."/"..id,valid_path)
    end
    local function write_tree(parent,id,files,valid_id,valid_path)
        if not valid_id(id) or type(files)~="table" then return nil,"diy_package_path" end
        local final=parent.."/"..id
        if exists(final) then return nil,"diy_package_exists" end
        local names,total={},0
        for name,bytes in pairs(files)do
            if not valid_path(name) or type(bytes)~="string" or #bytes>8388608 then return nil,"diy_package_path" end
            total=total+#bytes;names[#names+1]=name
        end
        if #names>257 or total>33554432 then return nil,"diy_package_limit" end
        table.sort(names)
        local staging
        for i=1,100 do
            local candidate=parent.."/.building-"..id.."-"..i
            if win.DT_DIY_IO_CreateDirectoryW(wide(candidate),nil)~=0 then staging=candidate;break end
        end
        if not staging then return nil,"diy_package_io" end
        local made_files,made_dirs,seen={},{},{}
        local function cleanup()
            for i=#made_files,1,-1 do win.DT_DIY_IO_DeleteFileW(wide(made_files[i])) end
            for i=#made_dirs,1,-1 do win.DT_DIY_IO_RemoveDirectoryW(wide(made_dirs[i])) end
            win.DT_DIY_IO_RemoveDirectoryW(wide(staging))
        end
        for _,name in ipairs(names)do
            local prefix=""
            for part in (name:match("^(.*)/") or ""):gmatch("[^/]+")do
                prefix=prefix=="" and part or prefix.."/"..part
                if not seen[prefix] then
                    local dir=staging.."/"..prefix
                    if win.DT_DIY_IO_CreateDirectoryW(wide(dir),nil)==0 then cleanup();return nil,"diy_package_io" end
                    seen[prefix]=true;made_dirs[#made_dirs+1]=dir
                end
            end
            local dest=staging.."/"..name;local bytes=files[name]
            local handle=win.DT_DIY_IO_CreateFileW(wide(dest),1073741824,0,nil,1,128,nil)
            if handle==invalid then cleanup();return nil,"diy_package_io" end
            made_files[#made_files+1]=dest
            local written=ffi.new("unsigned long[1]")
            local ok=win.DT_DIY_IO_WriteFile(handle,bytes,#bytes,written,nil)~=0 and tonumber(written[0])==#bytes and win.DT_DIY_IO_FlushFileBuffers(handle)~=0
            win.DT_DIY_IO_CloseHandle(handle)
            if not ok then cleanup();return nil,"diy_package_io" end
        end
        if win.DT_DIY_IO_MoveFileExW(wide(staging),wide(final),8)==0 then cleanup();return nil,exists(final) and "diy_package_exists" or "diy_package_io" end
        return final
    end
    function store.write_package(id,files,valid_id,valid_path)
        local ok,why=ensure_packages();if not ok then return nil,why end
        return write_tree(store.package_directory,id,files,valid_id,valid_path)
    end
    -- SimpleAssets accepts only the game root and user-data mods namespace.
    -- Freeze a resource-only copy there at explicit scan time, never while an
    -- entry is running. Existing generations are verified and never replaced.
    store.asset_directory=parent.."/mods/"..mod_name.."/assets/diy-cache"
    function store.stage_assets(pack,valid_path,Hash)
        local files,names,identity,total={},{},{},0
        for path,bytes in pairs(pack.files)do if path:match("^resources/") then
            if not valid_path(path) or type(bytes)~="string" then return nil,"diy_package_path" end
            files[path]=bytes;names[#names+1]=path;total=total+#bytes
        end end
        table.sort(names)
        for _,name in ipairs(names)do identity[#identity+1]=name..":"..#files[name]..":"..Hash.hex(files[name]) end
        -- Cursor hotspots (and typed declarations generally) affect native
        -- construction even when file bytes are identical. They must receive
        -- a new path-derived native name, preserving the previous generation.
        local configs,seen={},{}
        for _,asset in ipairs(pack.manifest.assets or {})do
            local config=asset.type..":"..asset.path..":"..tostring(asset.hotspot_x)..":"..tostring(asset.hotspot_y)
            if not seen[config] then configs[#configs+1]=config;seen[config]=true end
        end
        table.sort(configs)
        for _,config in ipairs(configs)do identity[#identity+1]="asset:"..config end
        local hash=Hash.hex(table.concat(identity,"\n"))
        for _,path in ipairs({parent,parent.."/mods",parent.."/mods/"..mod_name,parent.."/mods/"..mod_name.."/assets",store.asset_directory})do
            local ok,why=safe_directory(path,true);if not ok then return nil,why end
        end
        local target=store.asset_directory.."/"..hash
        if exists(target) then
            local existing,why=read_tree(target,valid_path);if not existing then return nil,why end
            for path,bytes in pairs(files)do if existing[path]~=bytes then return nil,"diy_asset_cache_changed" end end
            for path in pairs(existing)do if files[path]==nil then return nil,"diy_asset_cache_changed" end end
        else
            -- Bound persistent storage too. Never remove a generation that a
            -- current video/native resource may still be reading.
            local used=0
            local function measure(path,depth)
                if depth>10 then return nil,"diy_package_path" end
                local rows,why=children(path);if not rows then return nil,why end
                for _,row in ipairs(rows)do
                    if math.floor(row.attributes/1024)%2==1 then return nil,"diy_package_path" end
                    if math.floor(row.attributes/16)%2==1 then
                        local ok;ok,why=measure(path.."/"..row.name,depth+1);if not ok then return nil,why end
                    else
                        used=used+row.size
                        if row.high~=0 or used+total>134217728 then return nil,"diy_asset_cache_limit" end
                    end
                end
                return true
            end
            local generations,why=children(store.asset_directory);if not generations then return nil,why end
            if #generations>=256 or total>134217728 then return nil,"diy_asset_cache_limit" end
            local ok;ok,why=measure(store.asset_directory,0);if not ok then return nil,why end
            local function valid_hash(id)return type(id)=="string" and #id==64 and id:match("^[a-f0-9]+$") end
            local path;path,why=write_tree(store.asset_directory,hash,files,valid_hash,valid_path)
            if not path then return nil,why end
        end
        return "mods/"..mod_name.."/assets/diy-cache/"..hash,hash
    end
    function store.retire_package(id,valid_id)
        if not valid_id(id) then return nil,"diy_package_path" end
        local ok,why=ensure_packages();if not ok then return nil,why end
        local source=store.package_directory.."/"..id
        ok,why=safe_directory(source,false);if not ok then return nil,why end
        local backup=directory.."/package-backups"
        ok,why=safe_directory(backup,true);if not ok then return nil,why end
        -- Both complete paths are rooted in this manager's validated DIY
        -- directory; reparse-point directories and replacement are refused.
        for i=1,1000 do
            local target=backup.."/"..id.."-"..string.format("%03d",i)
            if not exists(target) then
                if win.DT_DIY_IO_MoveFileExW(wide(source),wide(target),8)~=0 then return target end
                return nil,"diy_package_io"
            end
        end
        return nil,"diy_package_limit"
    end
    function store.export_packages(packages,valid_id,valid_path)
        local ok,why=store.ensure();if not ok then return nil,why end
        ok,why=safe_directory(store.export_directory,true);if not ok then return nil,why end
        local dest
        for i=1,1000 do
            local path=store.export_directory.."/export-"..string.format("%03d",i)
            if win.DT_DIY_IO_CreateDirectoryW(wide(path),nil)~=0 then dest=path;break end
        end
        if not dest then return nil,"diy_package_io" end
        local names={};for id in pairs(packages)do names[#names+1]=id end;table.sort(names)
        for _,id in ipairs(names)do
            local path;path,why=write_tree(dest,id,packages[id].files,valid_id,valid_path)
            if not path then return nil,why end
        end
        return dest
    end
    return store
end
return F
