local Skills = {}

local skillTypes = {
    Headhunter = "CoolSkill",
    Netrunner = "IntelligenceSkill",
    Shinobi = "ReflexesSkill",
    Solo = "StrengthSkill",
    Engineer = "TechnicalAbilitySkill"
}

function Skills.Read()
    local data = {}
    local player = Game.GetPlayer()
    if not player then return data end
    
    local devSystem = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem"))
    local devData = devSystem:GetDevelopmentData(player)
    
    for name, enumName in pairs(skillTypes) do
        local ok, enumVal = pcall(function() return Enum.new("gamedataProficiencyType", enumName) end)
        if ok and enumVal then
            local s, lvl = pcall(function() return devData:GetLevel(enumVal) end)
            if not s or not lvl then
                s, lvl = pcall(function() return devData:GetProficiencyLevel(enumVal) end)
            end
            if s and type(lvl) == "number" then
                data[name] = lvl
            end
        end
    end
    
    return data
end

function Skills.Apply(data)
    local player = Game.GetPlayer()
    if not player then return end
    
    local devSystem = Game.GetScriptableSystemsContainer():Get(CName.new("PlayerDevelopmentSystem"))
    local devData = devSystem:GetDevelopmentData(player)
    
    for name, level in pairs(data) do
        if type(level) == "number" and level > 0 then
            local enumName = skillTypes[name]
            if enumName then
                local ok, enumVal = pcall(function() return Enum.new("gamedataProficiencyType", enumName) end)
                local reasonOk, reasonEnum = pcall(function() return Enum.new("telemetryLevelGainReason", "Gameplay") end)
                
                if ok and enumVal and reasonOk and reasonEnum then
                    pcall(function() devData:SetLevel(enumVal, level, reasonEnum) end)
                end
            end
        end
    end
end

return Skills
