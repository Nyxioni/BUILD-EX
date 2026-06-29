-- modules/builds.lua
local Builds = {}

local buildsPath = "builds/"

-- Сохранение билда в JSON
function Builds.SaveBuild(name, description, data)
    -- Убираем спецсимволы из имени файла для безопасности
    local safeName = name:gsub("[\\/:*?\"<>|]", "_")
    local filename = buildsPath .. safeName .. ".json"
    local file = io.open(filename, "w")
    if file then
        local buildData = {
            name = name,
            description = description,
            timestamp = os.time(),
            data = data
        }
        -- Используем встроенную библиотеку json CET
        file:write(json.encode(buildData))
        file:close()
        return true
    end
    print("[CyberBuildManager] Ошибка: Не удалось создать файл " .. filename)
    return false
end

-- Загрузка билда из JSON
function Builds.LoadBuild(safeName)
    local filename = buildsPath .. safeName .. ".json"
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local status, result = pcall(json.decode, content)
        if status then
            return result
        else
            print("[CyberBuildManager] Ошибка: Поврежденный JSON в файле " .. filename)
            return nil
        end
    end
    return nil
end

-- Удаление билда
function Builds.DeleteBuild(safeName)
    local filename = buildsPath .. safeName .. ".json"
    return os.remove(filename)
end

-- Получение списка всех сохраненных билдов
function Builds.GetBuildsList()
    local list = {}
    -- dir() - стандартная функция CET для чтения директорий
    local files = dir(buildsPath)
    if files then
        for _, fileInfo in ipairs(files) do
            if fileInfo.name:match("%.json$") then
                local safeName = fileInfo.name:gsub("%.json$", "")
                local buildInfo = Builds.LoadBuild(safeName)
                if buildInfo then
                    -- Сохраняем имя файла (safeName), чтобы потом к нему обращаться
                    buildInfo.safeName = safeName
                    table.insert(list, buildInfo)
                end
            end
        end
    end
    -- Сортировка по времени создания (новые сверху)
    table.sort(list, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return list
end

return Builds
