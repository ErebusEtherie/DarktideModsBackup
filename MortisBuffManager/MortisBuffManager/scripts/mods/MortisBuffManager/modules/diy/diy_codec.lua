-- Strict data-only JSON and deterministic canonical output. No Lua evaluation.
local C={max_bytes=524288,max_depth=20,max_nodes=30000}
local array_names={entries=true,rules=true,conditions=true,keywords=true,tags=true,exclude_tags=true,breeds=true,archetypes=true,families=true,talents=true,actions=true,selected=true,tier_limits=true,
    files=true,dependencies=true,conflicts=true,requires_mods=true,capabilities=true,shared_signals=true,events=true,
    weapons=true,weapon_keywords=true,grenade_abilities=true,combat_abilities=true,resources=true,any_resources=true}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        local map={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
        return map[c] or string.format("\\u%04x",c:byte())
    end)..'"'
end
function C.encode(value)
    local seen={};local nodes=0
    local function encode(v,depth,key)
        if depth>C.max_depth then error("JSON nesting limit",0) end
        nodes=nodes+1;if nodes>C.max_nodes then error("JSON node limit",0) end
        if type(v)=="string" then return quote(v) end
        if type(v)=="number" and finite(v) then return string.format("%.17g",v) end
        if type(v)=="boolean" then return tostring(v) end
        if type(v)~="table" or getmetatable(v) or seen[v] then error("JSON data only",0) end
        seen[v]=true
        local n,count,keys=#v,0,{}
        for k in pairs(v) do count=count+1;keys[count]=k end
        local array=n>0 or count==0 and array_names[key]
        local out={}
        if array then
            if n~=count then error("JSON sparse array",0) end
            for i=1,n do if v[i]==nil then error("JSON sparse array",0) end;out[i]=encode(v[i],depth+1) end
        else
            for _,k in ipairs(keys) do if type(k)~="string" then error("JSON object key",0) end end
            table.sort(keys)
            for _,k in ipairs(keys) do out[#out+1]=quote(k)..":"..encode(v[k],depth+1,k) end
        end
        seen[v]=nil
        return (array and "[" or "{")..table.concat(out,",")..(array and "]" or "}")
    end
    local ok,result=pcall(encode,value,0)
    if not ok then return nil,result end
    if #result>C.max_bytes then return nil,"JSON file limit" end
    return result
end
function C.decode(text)
    if type(text)~="string" or #text>C.max_bytes then return nil,"JSON file limit (512 KiB)" end
    text=text:gsub("^\239\187\191","")
    local p,n,nodes=1,#text,0
    local function fail(message) error("JSON byte "..p..": "..message,0) end
    local function skip() local _,last=text:find("^[ \t\r\n]*",p);p=(last or p-1)+1 end
    local function utf8(v)
        if v<128 then return string.char(v) end
        if v<2048 then return string.char(192+math.floor(v/64),128+v%64) end
        if v<65536 then return string.char(224+math.floor(v/4096),128+math.floor(v/64)%64,128+v%64) end
        return string.char(240+math.floor(v/262144),128+math.floor(v/4096)%64,128+math.floor(v/64)%64,128+v%64)
    end
    local function str()
        p=p+1;local out={}
        while p<=n do
            local c=text:sub(p,p);p=p+1
            if c=='"' then return table.concat(out) end
            if c=="\\" then
                c=text:sub(p,p);p=p+1
                local map={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if map[c] then out[#out+1]=map[c]
                elseif c=="u" then
                    local hex=text:sub(p,p+3);if #hex~=4 or hex:find("[^%x]") then fail("unicode escape") end
                    p=p+4;local code=tonumber(hex,16)
                    if code>=55296 and code<=56319 then
                        if text:sub(p,p+1)~="\\u" then fail("unpaired surrogate") end
                        local low=text:sub(p+2,p+5);if #low~=4 or low:find("[^%x]") then fail("unicode escape") end
                        low=tonumber(low,16);if low<56320 or low>57343 then fail("unpaired surrogate") end
                        p=p+6;code=65536+(code-55296)*1024+low-56320
                    elseif code>=56320 and code<=57343 then fail("unpaired surrogate") end
                    out[#out+1]=utf8(code)
                else fail("unknown escape") end
            elseif c:byte()<32 then fail("control character")
            elseif c:byte()>=128 then
                local first=c:byte();local length=first>=194 and first<=223 and 2 or first>=224 and first<=239 and 3 or first>=240 and first<=244 and 4
                if not length or p+length-2>n then fail("invalid UTF-8") end
                for i=1,length-1 do local b=text:byte(p+i-1);if b<128 or b>191 then fail("invalid UTF-8") end end
                local second=text:byte(p)
                if first==224 and second<160 or first==237 and second>159 or first==240 and second<144 or first==244 and second>143 then fail("invalid UTF-8") end
                out[#out+1]=c..text:sub(p,p+length-2);p=p+length-1
            else out[#out+1]=c end
        end
        fail("unterminated string")
    end
    local parse
    parse=function(depth)
        if depth>C.max_depth then fail("nesting limit") end
        nodes=nodes+1;if nodes>C.max_nodes then fail("node limit") end
        skip();local c=text:sub(p,p)
        if c=='"' then return str()
        elseif c=="{" or c=="[" then
            local object=c=="{";p=p+1;skip();local out,seen={},{}
            local close=object and "}" or "]"
            if text:sub(p,p)==close then p=p+1;return out end
            while true do
                local key
                if object then
                    if text:sub(p,p)~='"' then fail("object key") end
                    key=str();if seen[key] then fail("duplicate key "..key) end;seen[key]=true;skip()
                    if text:sub(p,p)~=":" then fail("missing colon") end;p=p+1
                else key=#out+1 end
                out[key]=parse(depth+1);skip();c=text:sub(p,p);p=p+1
                if c==close then return out end
                if c~="," then fail("missing comma") end;skip()
            end
        elseif text:sub(p,p+3)=="true" then p=p+4;return true
        elseif text:sub(p,p+4)=="false" then p=p+5;return false
        elseif text:sub(p,p+3)=="null" then fail("null is not part of DIY schema")
        else
            local start=p
            if c=="-" then p=p+1 end
            c=text:sub(p,p)
            if c=="0" then p=p+1
            elseif c:match("[1-9]") then repeat p=p+1 until not text:sub(p,p):match("%d")
            else fail("value") end
            if text:sub(p,p)=="." then
                p=p+1;if not text:sub(p,p):match("%d") then fail("fraction") end
                repeat p=p+1 until not text:sub(p,p):match("%d")
            end
            if text:sub(p,p):match("[eE]") then
                p=p+1;if text:sub(p,p):match("[+-]") then p=p+1 end
                if not text:sub(p,p):match("%d") then fail("exponent") end
                repeat p=p+1 until not text:sub(p,p):match("%d")
            end
            local result=tonumber(text:sub(start,p-1));if not finite(result) then fail("finite number") end
            return result
        end
    end
    local ok,value=pcall(function() local v=parse(0);skip();if p<=n then fail("trailing data") end;return v end)
    if not ok then return nil,value end
    return value
end
function C.fingerprint(value)
    local text,err=C.encode(value);if not text then return nil,err end
    -- Two bounded integer hashes, stable on LuaJIT's exact integer range.
    local a,b=1,7
    for i=1,#text do local v=text:byte(i);a=(a*131+v)%2147483647;b=(b*137+v)%2147483629 end
    return string.format("%08x%08x:%d",a,b,#text)
end
return C
