local Attributes = {}
local Telemetry = require("modules/telemetry")

local statTypes = {
    Body = "Strength",
    Reflexes = "Reflexes",
    TechnicalAbility = "TechnicalAbility",
    Intelligence = "Intelligence",
    Cool = "Cool"
}

function Attributes.Read()
    local player = Game.GetPlayer()
    if not player then return nil end
    local statsSystem = Game.GetStatsSystem()
    local entityID = player:GetEntityID()
    
    local devSystem = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem"))
    local devData = devSystem:GetDevelopmentData(player)
    
    local data = {}
    local sum = 0
    for name, statString in pairs(statTypes) do
        local okEnum, statEnum = pcall(function() return Enum.new("gamedataStatType", statString) end)
        if okEnum and statEnum then
            local success, val = pcall(function() return statsSystem:GetStatValue(entityID, statEnum) end)
            if success then
                data[name] = math.floor(val)
                sum = sum + data[name]
            else
                print("[CyberBuildManager] Ошибка чтения атрибута: " .. name)
            end
        else
            print("[CyberBuildManager] Ошибка Enum для атрибута: " .. name)
        end
    end
    
    local s, free = pcall(function() return devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Attribute")) end)
    if not s or type(free) ~= "number" then free = 0 end
    
    data.freePoints = free
    data.totalPool = sum + free
    
    return data
end

function Attributes.Apply(data, loadMode)
    local player = Game.GetPlayer()
    if not player then return end
    
    local devSystem = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem"))
    local devData = devSystem:GetDevelopmentData(player)
    local statsSystem = Game.GetStatsSystem()
    local entityID = player:GetEntityID()
    
    -- В патче 2.0 функция SetAttribute работает только на ПОВЫШЕНИЕ. 
    -- Поэтому сначала обнуляем атрибуты, обманывая проверку игры на "1 сброс за игру"
    pcall(function() 
        devData.hasResetAttributes = false
        devData:ResetAttributes() 
    end)
    
    -- Вычисляем текущий пул игрока (вложенные + свободные)
    -- Мы делаем это ПОСЛЕ сброса, чтобы узнать точное количество очков, возвращенное игрой
    local currentSum = 0
    for name, statString in pairs(statTypes) do
        local okEnum, statEnum = pcall(function() return Enum.new("gamedataStatType", statString) end)
        if okEnum and statEnum then
            local success, val = pcall(function() return statsSystem:GetStatValue(entityID, statEnum) end)
            if success then
                currentSum = currentSum + math.floor(val)
            end
        end
    end
    
    local s, currentFree = pcall(function() return devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Attribute")) end)
    if not s or type(currentFree) ~= "number" then currentFree = 0 end
    
    local currentPool = currentSum + currentFree
    
    -- Вычисляем сколько требует билд (вложенные) и собираем список
    local buildSum = 0
    local targetStats = {}
    for name, statString in pairs(statTypes) do
        if data[name] then
            buildSum = buildSum + data[name]
            table.insert(targetStats, {name = name, enumStr = statString, target = data[name]})
        end
    end
    
    -- Сортируем Характеристики по убыванию требуемого значения. 
    -- В Честном режиме это гарантирует прокачку самых важных для билда статов в первую очередь.
    table.sort(targetStats, function(a, b)
        return a.target > b.target
    end)
    
    -- Если общий пул игрока меньше, чем нужно для билда, искусственно расширяем его (Только не в Легит режиме)
    if loadMode ~= 0 then
        if currentPool < buildSum then
            currentPool = buildSum
        end
    end
    
    local availablePoints = currentPool - 15 -- Базовые 3 очка на 5 статов = 15
    if availablePoints < 0 then availablePoints = 0 end
    
    local buildCost = buildSum - 15
    if buildCost < 0 then buildCost = 0 end
    
    -- Если очков меньше чем нужно, распределяем пропорционально
    if loadMode == 0 and buildCost > 0 and availablePoints < buildCost then
        local ratio = availablePoints / buildCost
        local distributed = 0
        for _, statInfo in ipairs(targetStats) do
            statInfo.cost = statInfo.target - 3
            if statInfo.cost < 0 then statInfo.cost = 0 end
            
            local newCost = math.floor(statInfo.cost * ratio)
            statInfo.assignedCost = newCost
            distributed = distributed + newCost
        end
        
        local leftovers = availablePoints - distributed
        -- Сортируем чтобы лишние очки достались главным статам
        table.sort(targetStats, function(a, b) return (a.cost or 0) > (b.cost or 0) end)
        
        for i = 1, leftovers do
            if targetStats[i] then
                targetStats[i].assignedCost = (targetStats[i].assignedCost or 0) + 1
            end
        end
        
        for _, statInfo in ipairs(targetStats) do
            statInfo.target = 3 + (statInfo.assignedCost or 0)
        end
        -- Все доступные очки мы распределили
        availablePoints = 0
    end
    
    -- Теперь повышаем характеристики до нужного уровня
    for _, statInfo in ipairs(targetStats) do
        local ok, statEnum = pcall(function() return Enum.new("gamedataStatType", statInfo.enumStr) end)
        if ok and statEnum then
            local valToSet = statInfo.target
            
            if loadMode == 0 then
                -- Если мы НЕ в режиме пропорциональности (то есть очков хватает с избытком)
                if buildCost <= 0 or (buildCost > 0 and currentPool - 15 >= buildCost) then
                    local cost = statInfo.target - 3
                    if cost < 0 then cost = 0 end
                    
                    if availablePoints >= cost then
                        availablePoints = availablePoints - cost
                    else
                        valToSet = 3 + availablePoints
                        availablePoints = 0
                    end
                end
            end
            
            -- Устанавливаем уровень
            pcall(function() devData:SetAttribute(statEnum, valToSet) end)
        end
    end
    
    local targetFree = 0
    if loadMode == 0 then
        targetFree = availablePoints
    else
        targetFree = data.freePoints or 0
    end
    
    -- Сохраняем целевое количество свободных очков для Фазы 4
    Attributes._targetFree = targetFree
    
    Telemetry.Log("MATH", string.format("Attributes.Apply: Pool=%d, TargetSum=%d, TargetFree=%d", currentPool, buildSum, targetFree))
    print("[CyberBuildManager] Атрибуты успешно прокачаны!")
end

function Attributes.FixPoints(data)
    local player = Game.GetPlayer()
    if not player then return end
    local devSystem = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem"))
    local devData = devSystem:GetDevelopmentData(player)
    
    -- Считываем сколько свободных очков осталось у игрока ПРЯМО СЕЙЧАС (после сброса и повышений)
    local s2, actualFree = pcall(function() return devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Attribute")) end)
    if not s2 or type(actualFree) ~= "number" then actualFree = 0 end
    
    local targetFree = Attributes._targetFree or 0
    local diff = targetFree - actualFree
    Telemetry.Log("MATH", string.format("Attributes.FixPoints: TargetFree=%d, ActualFree=%d, Diff=%d", targetFree, actualFree, diff))
    if diff ~= 0 then
        pcall(function() devData:AddDevelopmentPoints(diff, Enum.new("gamedataDevelopmentPointType", "Attribute")) end)
    end
    print("[CyberBuildManager] Очки характеристик откорректированы!")
end

return Attributes
