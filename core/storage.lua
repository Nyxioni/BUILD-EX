local Storage = {}

local translit = {
    ['а']='a', ['б']='b', ['в']='v', ['г']='g', ['д']='d', ['е']='e', ['ё']='yo', ['ж']='zh', ['з']='z', ['и']='i', ['й']='y', ['к']='k', ['л']='l', ['м']='m', ['н']='n', ['о']='o', ['п']='p', ['р']='r', ['с']='s', ['т']='t', ['у']='u', ['ф']='f', ['х']='h', ['ц']='ts', ['ч']='ch', ['ш']='sh', ['щ']='sch', ['ъ']='', ['ы']='y', ['ь']='', ['э']='e', ['ю']='yu', ['я']='ya',
    ['А']='A', ['Б']='B', ['В']='V', ['Г']='G', ['Д']='D', ['Е']='E', ['Ё']='Yo', ['Ж']='Zh', ['З']='Z', ['И']='I', ['Й']='Y', ['К']='K', ['Л']='L', ['М']='M', ['Н']='N', ['О']='O', ['П']='P', ['Р']='R', ['С']='S', ['Т']='T', ['У']='U', ['Ф']='F', ['Х']='H', ['Ц']='Ts', ['Ч']='Ch', ['Ш']='Sh', ['Щ']='Sch', ['Ъ']='', ['Ы']='Y', ['Ь']='', ['Э']='E', ['Ю']='Yu', ['Я']='Ya',
    [' ']='_'
}

local function sanitizeFilename(str)
    local res = ""
    for i = 1, #str do
        local c = str:sub(i,i)
        -- This is a very simple ASCII filter, proper UTF-8 transliteration in Lua requires parsing multi-byte sequences.
        -- For simplicity, we just strip non-alphanumeric chars that aren't underscore, to prevent broken filenames.
        if c:match("[%w_]") then res = res .. c end
    end
    if res == "" then res = "build_" .. tostring(os.time()) end
    return res
end

-- В Cyberpunk Lua (Lua 5.4) работа с utf-8 сложная без внешних библиотек,
-- поэтому мы просто кодируем все не-ASCII символы в hex или просто удаляем.
local function makeSafeFilename(name)
    local safe = string.gsub(name, "[^%w_]", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return safe
end

function Storage.SaveBuild(name, data)
    local safeName = makeSafeFilename(name)
    local path = "builds/" .. safeName .. ".json"
    
    -- Ensure timestamp and name are included
    data.name = name
    data.timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local file = io.open(path, "w")
    if file then
        local success, result = pcall(function() return json.encode(data, { indent = true }) end)
        if success then
            local writeOk = pcall(function() file:write(result) end)
            file:close()
            
            if not writeOk then return false, "Failed to write to file" end
            
            -- Добавляем в индекс
            local index = Storage.ListBuilds()
            local found = false
            for _, b in ipairs(index) do
                if b == name then found = true break end
            end
            if not found then
                table.insert(index, name)
                local idxFile = io.open("builds/_index.json", "w")
                if idxFile then
                    local s, res = pcall(function() return json.encode(index) end)
                    if s then pcall(function() idxFile:write(res) end) end
                    pcall(function() idxFile:close() end)
                end
            end
            
            return true, nil
        else
            file:close()
            print("[CyberBuildManager] JSON Error: " .. tostring(result))
            return false, "JSON Encode Error: " .. tostring(result)
        end
    end
    return false, "File write error: " .. path
end

function Storage.LoadBuild(name)
    local safeName = makeSafeFilename(name)
    local file = io.open("builds/" .. safeName .. ".json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, result = pcall(function() return json.decode(content) end)
        if success then
            return result
        else
            print("[CyberBuildManager] JSON Decode Error: " .. tostring(result))
            return nil
        end
    end
    return nil
end

function Storage.ListBuilds()
    local builds = {}
    local idxFile = io.open("builds/_index.json", "r")
    if idxFile then
        local content = idxFile:read("*a")
        idxFile:close()
        local success, result = pcall(function() return json.decode(content) end)
        if success and type(result) == "table" then
            for _, b in ipairs(result) do
                if type(b) == "string" then
                    table.insert(builds, b)
                end
            end
        end
    end
    return builds
end

function Storage.DeleteBuild(name)
    local safeName = makeSafeFilename(name)
    local path = "builds/" .. safeName .. ".json"
    
    -- Delete the file
    os.remove(path)
    
    -- Remove from index
    local index = Storage.ListBuilds()
    local updatedIndex = {}
    local found = false
    
    for _, b in ipairs(index) do
        if b ~= name then
            table.insert(updatedIndex, b)
        else
            found = true
        end
    end
    
    if found then
        local idxFile = io.open("builds/_index.json", "w")
        if idxFile then
            local s, res = pcall(function() return json.encode(updatedIndex) end)
            if s then pcall(function() idxFile:write(res) end) end
            pcall(function() idxFile:close() end)
        end
    end
    
    return true
end

function Storage.SaveRentalCache(items)
    local path = "builds/_rental_cache.json"
    local file = io.open(path, "w")
    if file then
        local success, result = pcall(function() return json.encode(items) end)
        if success then
            pcall(function() file:write(result) end)
        end
        file:close()
    end
end

function Storage.LoadRentalCache()
    local path = "builds/_rental_cache.json"
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(function() return json.decode(content) end)
        if success and data then return data end
    end
    return nil
end

function Storage.ClearRentalCache()
    os.remove("builds/_rental_cache.json")
end

return Storage
