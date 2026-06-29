local Perks = {}
local Telemetry = require("modules/telemetry")

function Perks.Read()
    local player = Game.GetPlayer()
    if not player then return { _ERROR = "No player" } end
    local devData = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem")):GetDevelopmentData(player)
    
    local data = { perks = {} }
    
    local s1, freePrim = pcall(function() return devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Primary")) end)
    local s2, freeEsp = pcall(function() return devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Espionage")) end)
    
    data.freePrimary = (s1 and type(freePrim) == "number") and freePrim or 0
    data.freeEspionage = (s2 and type(freeEsp) == "number") and freeEsp or 0

    local success, records = pcall(function()
        local recs = TweakDB:GetRecords("gamedataNewPerk_Record")
        if not recs or #recs == 0 then recs = TweakDB:GetRecords("NewPerk_Record") end
        return recs
    end)
    
    if success and records then
        for _, record in ipairs(records) do
            local ok, enumValue = pcall(function() return record:Type() end)
            if ok and enumValue then
                local sName, perkName = pcall(function() return tostring(enumValue) end)
                if sName and perkName then
                    local s, res = pcall(function() return devData:IsNewPerkBought(enumValue) end)
                    if s and (res == true or (type(res) == "number" and res > 0)) then
                        data.perks[perkName] = 1
                    end
                end
            end
        end
    end
    
    return data
end

function Perks.SellAll()
    local player = Game.GetPlayer()
    if not player then return end
    local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(player)
    local currentPerks = Perks.Read()
    if currentPerks.perks then
        local success, records = pcall(function()
            local recs = TweakDB:GetRecords("gamedataNewPerk_Record")
            if not recs or #recs == 0 then recs = TweakDB:GetRecords("NewPerk_Record") end
            if not recs or #recs == 0 then recs = TweakDB:GetRecords("Perk_Record") end
            return recs
        end)
        
        if success and records then
            local nameToEnum = {}
            for _, record in ipairs(records) do
                local ok, enumValue = pcall(function() return record:Type() end)
                if ok and enumValue then
                    local sName, perkName = pcall(function() return tostring(enumValue) end)
                    if sName and perkName then
                        nameToEnum[perkName] = enumValue
                    end
                end
            end
            
            local maxIterations = 15
            for iter = 1, maxIterations do
                for perkName, _ in pairs(currentPerks.perks) do
                    local enumValue = nameToEnum[perkName]
                    if enumValue then
                        pcall(function() devData:ForceSellNewPerk(enumValue) end)
                    end
                end
            end
        end
    end
end

function Perks.BuySaved(data, loadMode)
    local player = Game.GetPlayer()
    if not player then return end
    local pds = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem'))
    local devData = pds:GetDevelopmentData(player)
    
    local ptPrimary = Enum.new("gamedataDevelopmentPointType", "Primary")
    local ptEspionage = Enum.new("gamedataDevelopmentPointType", "Espionage")
    
    if loadMode and loadMode ~= 0 then
        pcall(function() devData:AddDevelopmentPoints(1000, ptPrimary) end)
        pcall(function() devData:AddDevelopmentPoints(1000, ptEspionage) end)
    end
    
    local success, records = pcall(function()
        local recs = TweakDB:GetRecords("gamedataNewPerk_Record")
        if not recs or #recs == 0 then recs = TweakDB:GetRecords("NewPerk_Record") end
        if not recs or #recs == 0 then recs = TweakDB:GetRecords("Perk_Record") end
        return recs
    end)
    
    if success and records then
        local nameToEnum = {}
        for _, record in ipairs(records) do
            local ok, enumValue = pcall(function() return record:Type() end)
            if ok and enumValue then
                local sName, perkName = pcall(function() return tostring(enumValue) end)
                if sName and perkName then
                    nameToEnum[perkName] = enumValue
                end
            end
        end
        
        -- Пытаемся купить перки с учетом зависимостей
        local toBuy = {}
        local buildPerks = data.perks or data
        for perkName, _ in pairs(buildPerks) do
            if nameToEnum[perkName] then
                toBuy[perkName] = nameToEnum[perkName]
            end
        end
        
        local maxIterations = 15
        for iter = 1, maxIterations do
            for perkName, enumValue in pairs(toBuy) do
                local hasReq = false
                if loadMode == 0 then
                    local sReq, reqRes = pcall(function() return devData:HasEnoughtAttributePoints(enumValue) end)
                    if sReq and reqRes == true then
                        hasReq = true
                    end
                else
                    hasReq = true
                end
                
                if hasReq then
                    pcall(function() devData:BuyNewPerk(enumValue, false) end)
                end
            end
        end
    end
end

function Perks.GetTrueTotalPoints()
    local player = Game.GetPlayer()
    if not player then return { Primary = 0, Espionage = 0 } end
    local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(player)
    
    local ptPrimary = Enum.new("gamedataDevelopmentPointType", "Primary")
    local ptEspionage = Enum.new("gamedataDevelopmentPointType", "Espionage")
    
    local s1, freePrim = pcall(function() return devData:GetDevPoints(ptPrimary) end)
    local s2, freeEsp = pcall(function() return devData:GetDevPoints(ptEspionage) end)
    freePrim = (s1 and type(freePrim) == "number") and freePrim or 0
    freeEsp = (s2 and type(freeEsp) == "number") and freeEsp or 0
    
    local spentPrim = 0
    local spentEsp = 0
    
    local currentPerks = Perks.Read()
    if currentPerks.perks then
        for perkName, _ in pairs(currentPerks.perks) do
            if string.find(perkName, "Espionage_") then
                spentEsp = spentEsp + 1
            else
                spentPrim = spentPrim + 1
            end
        end
    end
    
    local f = io.open("cbm_debug.txt", "a")
    if f then
        f:write("GetTrueTotalPoints -> Free: " .. tostring(freePrim) .. " Spent: " .. tostring(spentPrim) .. " Total: " .. tostring(freePrim + spentPrim) .. "\n")
        f:close()
    end
    
    return {
        Primary = freePrim + spentPrim,
        Espionage = freeEsp + spentEsp
    }
end

function Perks.AreAllPrimaryPerksSold()
    local currentPerks = Perks.Read()
    if currentPerks.perks then
        for perkName, _ in pairs(currentPerks.perks) do
            if not string.find(perkName, "Espionage_") then
                return false
            end
        end
    end
    return true
end

function Perks.RestoreTruePoints(savedTruePoints)
    if not savedTruePoints then return end
    local player = Game.GetPlayer()
    if not player then return end
    local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(player)
    
    local ptPrimary = Enum.new("gamedataDevelopmentPointType", "Primary")
    local ptEspionage = Enum.new("gamedataDevelopmentPointType", "Espionage")
    
    local currentTruePoints = Perks.GetTrueTotalPoints()
    
    local diffPrim = savedTruePoints.Primary - currentTruePoints.Primary
    local diffEsp = savedTruePoints.Espionage - currentTruePoints.Espionage
    
    Telemetry.Log("MATH", string.format("Perks.RestoreTruePoints: SavedPrim=%d, CurPrim=%d, DiffPrim=%d", savedTruePoints.Primary, currentTruePoints.Primary, diffPrim))
    
    if diffPrim ~= 0 then
        local s, err = pcall(function() devData:AddDevelopmentPoints(diffPrim, ptPrimary) end)
    end
    
    if diffEsp ~= 0 then
        pcall(function() devData:AddDevelopmentPoints(diffEsp, ptEspionage) end)
    end
end

function Perks.FixPoints(data, loadMode)
    if loadMode == 0 then return end
    local player = Game.GetPlayer()
    if not player then return end
    local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(player)
    
    local ptPrimary = Enum.new("gamedataDevelopmentPointType", "Primary")
    local ptEspionage = Enum.new("gamedataDevelopmentPointType", "Espionage")
    
    local s1, curPrim = pcall(function() return devData:GetDevPoints(ptPrimary) end)
    local s2, curEsp = pcall(function() return devData:GetDevPoints(ptEspionage) end)
    curPrim = (s1 and type(curPrim) == "number") and curPrim or 0
    curEsp = (s2 and type(curEsp) == "number") and curEsp or 0
    
    local targetPrim = data.freePrimary or 0
    local targetEsp = data.freeEspionage or 0
    
    local diffPrim = targetPrim - curPrim
    local diffEsp = targetEsp - curEsp
    
    Telemetry.Log("MATH", string.format("Perks.FixPoints (Sandbox Cleanup): TargetPrim=%d, CurPrim=%d, DiffPrim=%d", targetPrim, curPrim, diffPrim))
    
    if diffPrim ~= 0 then pcall(function() devData:AddDevelopmentPoints(diffPrim, ptPrimary) end) end
    if diffEsp ~= 0 then pcall(function() devData:AddDevelopmentPoints(diffEsp, ptEspionage) end) end
end

return Perks
