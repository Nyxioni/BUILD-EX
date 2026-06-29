local CyberBuildManager = {
    showWindow = false,
    buildNameInput = "MyBuild",
    historyNameInput = "",
    statusMessage = "Ожидание",
    buildsList = {},
    
    -- Поля для ввода очков
    addAttrPoints = 0,
    addPerkPoints = 0,
    addMoneyAmount = 0,
    addLevelAmount = 0,
    addSCAmount = 0,
    
    -- Очередь для отложенного выполнения
    delayedQueue = {},
    
    -- Галочки для загрузки
    loadOptions = {
        attributes = true,
        skills = true,
        perks = true,
        equipment = true,
        money = false,
        level = false,
        vehicles = false
    },
    
    itemLoadMode = 0,
    pendingModeSwitch = -1,
    pendingDeleteBuild = nil,
    currentlyInRental = false,
    selectedBuildData = nil,
    windowPositionSet = false,
    selectedBuildDetails = {},
    

    
    -- Стейт-машина для фазированной загрузки
    loadState = {
        active = false,
        data = nil,
        phase = 0,
        frames = 0,
        buildName = ""
    }
}

local Storage = require("core/storage")
local Attributes = require("modules/attributes")
local Perks = require("modules/perks")
local Skills = require("modules/skills")
local Equipment = require("modules/equipment")


function CyberBuildManager:RefreshBuilds()
    local success, result = pcall(Storage.ListBuilds)
    if success then
        self.buildsList = result
    else
        self.buildsList = { "Refresh Crash: " .. tostring(result) }
    end
end

function CyberBuildManager:StartBuildLoad(buildName, data)
    -- 1. Сжигаем 'прокатные' вещи из Примерочной
    local cache = Storage.LoadRentalCache()
    if cache then
        pcall(function()
            local player = Game.GetPlayer()
            local ts = Game.GetTransactionSystem()
            if player and ts then
                for _, tdbidStr in ipairs(cache) do
                    ts:RemoveItemByTDBID(player, TweakDBID.new(tdbidStr), 1)
                end
            end
        end)
        Storage.ClearRentalCache()
    end

    -- 2. Карусель Автосейвов (Умная Заморозка)
    if self.itemLoadMode == 2 and self.currentlyInRental == true then
        print("[CyberBuildManager] Умная заморозка: Пропуск автосейва в режиме Примерочной.")
    else
        -- Сдвиг карусели
        local as2 = Storage.LoadBuild("_AutoSave_2")
        if as2 then Storage.SaveBuild("_AutoSave_3", as2) end
        
        local as1 = Storage.LoadBuild("_AutoSave_1")
        if as1 then Storage.SaveBuild("_AutoSave_2", as1) end
        
        -- Читаем текущее состояние и сохраняем как AutoSave 1
        local sA, attrRes = pcall(Attributes.Read)
        local sP, perksRes = pcall(Perks.Read)
        local sS, skillsRes = pcall(Skills.Read)
        local sE, equipRes = pcall(Equipment.Read)
        
        local currentMoney = 0
        local currentLevel = 1
        local currentSC = 1
        local currentVehicles = {}
        pcall(function()
            local p = Game.GetPlayer()
            local ts = Game.GetTransactionSystem()
            if p and ts then
                currentMoney = ts:GetItemQuantity(p, ItemID.FromTDBID(TweakDBID.new("Items.money")))
            end
            local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
            if devData then
                currentLevel = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "Level"))
                currentSC = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "StreetCred"))
            end
            local vs = Game.GetVehicleSystem()
            if vs then
                local vsList = vs:GetPlayerUnlockedVehicles()
                if vsList then
                    for _, v in ipairs(vsList) do
                        local strID = string.match(tostring(v.recordID), "%-%-%[%[ (.-) %-%-%]%]")
                        if strID then
                            table.insert(currentVehicles, {
                                id = strID,
                                name = NameToString(v.name)
                            })
                        end
                    end
                end
            end
        end)
        
        if sA and sP and sS and sE then
            local currentState = { 
                attributes = attrRes,
                perks = perksRes,
                skills = skillsRes,
                equipment = equipRes,
                money = currentMoney,
                level = currentLevel,
                streetCred = currentSC,
                vehicles = currentVehicles
            }
            Storage.SaveBuild("_AutoSave_1", currentState)
        end
        self:RefreshBuilds()
    end
    
    self.currentlyInRental = (self.itemLoadMode == 2)

    self.loadState.active = true
    self.loadState.data = data
    self.loadState.buildName = buildName
    self.loadState.phase = 1
    self.loadState.frames = 0
    self.statusMessage = "Загрузка: Продажа перков..."
    print("[CyberBuildManager] Начинаем фазированную загрузку билда: " .. buildName)
end

function CyberBuildManager:FormatBuildDetails(data)
    local details = {
        general = {},
        attributes = {},
        skills = {},
        perks = {},
        equipment = {},
        weapons = {},
        cyberware = {},
        vehicles = {}
    }
    
    local function GetLocName(tdbidStr)
        if not tdbidStr or tdbidStr == "" then return "Нет" end
        local status, res = pcall(function()
            local rec = TweakDBInterface.GetItemRecord(TweakDBID.new(tdbidStr))
            if rec then
                local locKey = rec:DisplayName()
                local text = Game.GetLocalizedTextByKey(locKey)
                if text and text ~= "" then return text end
            end
            return nil
        end)
        if status and res then return res else return string.gsub(tdbidStr, "Items%.", "") end
    end

    if data.money then
        table.insert(details.general, "Эдди (Деньги): " .. tostring(data.money))
    end
    if data.level then
        table.insert(details.general, "Уровень: " .. tostring(data.level))
    end
    if data.streetCred then
        table.insert(details.general, "Репутация: " .. tostring(data.streetCred))
    end
    if data.vehicles and #data.vehicles > 0 then
        table.insert(details.general, "Машин в гараже: " .. tostring(#data.vehicles))
        for _, v in ipairs(data.vehicles) do
            local dispName = v.name
            if dispName == nil or dispName == "" then dispName = v.id end
            table.insert(details.vehicles, dispName)
        end
    end

    if data.attributes then
        table.insert(details.attributes, "Сила: " .. tostring(data.attributes.Body or 0))
        table.insert(details.attributes, "Реакция: " .. tostring(data.attributes.Reflexes or 0))
        table.insert(details.attributes, "Техника: " .. tostring(data.attributes.TechnicalAbility or 0))
        table.insert(details.attributes, "Интеллект: " .. tostring(data.attributes.Intelligence or 0))
        table.insert(details.attributes, "Хладнокровие: " .. tostring(data.attributes.Cool or 0))
    end
    
    if data.skills then
        for k, v in pairs(data.skills) do
            table.insert(details.skills, tostring(k) .. ": " .. tostring(v))
        end
    end
    
    if data.perks and data.perks.perks then
        local counts = {}
        local catMap = { Intelligence="Интеллект", Reflexes="Реакция", Body="Сила", Tech="Техника", Cool="Хладнокровие" }
        for perkStr, level in pairs(data.perks.perks) do
            local cat = string.match(perkStr, ": ([A-Za-z]+)_")
            if cat then
                local catName = catMap[cat] or cat
                counts[catName] = (counts[catName] or 0) + level
            else
                counts["Другое"] = (counts["Другое"] or 0) + level
            end
        end
        for k, v in pairs(counts) do
            table.insert(details.perks, "Ветвь " .. k .. ": " .. tostring(v) .. " очков")
        end
    end
    
    if data.equipment then
        -- Clothing
        local clothes = {"Head", "Face", "OuterChest", "InnerChest", "Legs", "Feet"}
        for _, slot in ipairs(clothes) do
            if data.equipment[slot] and data.equipment[slot]["0"] then
                table.insert(details.equipment, slot .. ": " .. GetLocName(data.equipment[slot]["0"]))
            end
        end
        
        -- Weapons
        if data.equipment.Weapon then
            for i=0,2 do
                if data.equipment.Weapon[tostring(i)] and data.equipment.Weapon[tostring(i)].baseTdbid then
                    table.insert(details.weapons, "Слот " .. tostring(i+1) .. ": " .. GetLocName(data.equipment.Weapon[tostring(i)].baseTdbid))
                end
            end
        end
        
        -- Cyberware
        local cwSlots = {"SystemReplacementCW", "ArmsCW", "HandsCW", "NervousSystemCW", "CardiovascularSystemCW", "IntegumentarySystemCW", "FrontalCortexCW", "EyesCW", "MusculoskeletalSystemCW", "LegsCW"}
        for _, slot in ipairs(cwSlots) do
            if data.equipment[slot] then
                for k, cwId in pairs(data.equipment[slot]) do
                    local name = string.gsub(slot, "CW", "")
                    table.insert(details.cyberware, name .. ": " .. GetLocName(cwId))
                end
            end
        end
    end
    
    self.selectedBuildDetails = details
end

function CyberBuildManager:Init()
    print("[CyberBuildManager] Мод успешно загружен (v1.0).")
    self:RefreshBuilds()
end

function CyberBuildManager:SaveCurrentState(buildName)
    local sA, attrRes = pcall(Attributes.Read)
    local sP, perksRes = pcall(Perks.Read)
    local sS, skillsRes = pcall(Skills.Read)
    local sE, equipRes = pcall(Equipment.Read)
    
    local currentMoney = 0
    local currentLevel = 1
    local currentSC = 1
    local currentVehicles = {}
    pcall(function()
        local p = Game.GetPlayer()
        local ts = Game.GetTransactionSystem()
        if p and ts then
            currentMoney = ts:GetItemQuantity(p, ItemID.FromTDBID(TweakDBID.new("Items.money")))
        end
        local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
        if devData then
            currentLevel = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "Level"))
            currentSC = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "StreetCred"))
        end
        local vs = Game.GetVehicleSystem()
        if vs then
            local vsList = vs:GetPlayerUnlockedVehicles()
            if vsList then
                for _, v in ipairs(vsList) do
                    local strID = string.match(tostring(v.recordID), "%-%-%[%[ (.-) %-%-%]%]")
                    if strID then
                        table.insert(currentVehicles, {
                            id = strID,
                            name = NameToString(v.name)
                        })
                    end
                end
            end
        end
    end)
    
    if sA and sP and sS and sE then
        local data = { 
            attributes = attrRes,
            perks = perksRes,
            skills = skillsRes,
            equipment = equipRes,
            money = currentMoney,
            level = currentLevel,
            streetCred = currentSC,
            vehicles = currentVehicles
        }
        if data.attributes then
            local saveOk, err = Storage.SaveBuild(buildName, data)
            if saveOk then
                self.statusMessage = "Билд '" .. buildName .. "' сохранен!"
                self:RefreshBuilds()
            else
                self.statusMessage = "Ошибка: " .. tostring(err)
            end
        else
            self.statusMessage = "Ошибка: Игрок не найден"
        end
    else
        self.statusMessage = "Сбой при чтении! А: " .. tostring(sA) .. " П: " .. tostring(sP) .. " Н: " .. tostring(sS) .. " Э: " .. tostring(sE)
    end
end



function CyberBuildManager:ApplyTheme()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.08, 0.08, 0.08, 0.95)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.98, 0.84, 0.12, 0.8) 
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.12, 0.12, 0.12, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.0, 0.45, 0.55, 1.0) 
    ImGui.PushStyleColor(ImGuiCol.TitleBgCollapsed, 0.05, 0.05, 0.05, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.9, 0.9, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.0, 0.8, 0.9, 0.8) 
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.0, 0.45, 0.55, 1.0) 
    ImGui.PushStyleColor(ImGuiCol.Header, 0.3, 0.3, 0.3, 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.0, 0.8, 0.9, 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.0, 0.45, 0.55, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.25, 0.25, 0.25, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.3, 0.3, 0.3, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Tab, 0.15, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, 0.0, 0.8, 0.9, 0.8)
    ImGui.PushStyleColor(ImGuiCol.TabActive, 0.0, 0.45, 0.55, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.PopupRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 0.0)
end

function CyberBuildManager:PopTheme()
    ImGui.PopStyleColor(18)
    ImGui.PopStyleVar(4)
end

function CyberBuildManager:Draw()
    if self.showWindow then
        self:ApplyTheme()
        
        ImGui.SetNextWindowSize(900, 750, ImGuiCond.FirstUseEver)
        if ImGui.Begin("CyberBuildManager v1.0 (Neon Edition)", ImGuiWindowFlags.NoCollapse) then
            
            -- HEADER: STATUS & PROGRESS
            ImGui.BeginChild("HeaderStatus", 0, 40, true)
            if self.loadState.active then
                ImGui.TextColored(0.0, 1.0, 1.0, 1.0, "Статус: " .. self.statusMessage)
                ImGui.SameLine(300)
                local progress = self.loadState.phase / 4.0
                ImGui.ProgressBar(progress, 350, 15, "")
            else
                ImGui.TextColored(0.98, 0.84, 0.12, 1.0, "Статус: " .. self.statusMessage)
            end
            ImGui.EndChild()
            
            ImGui.Spacing()
            
            -- COLLAPSING HEADER: LOAD SETTINGS
            if ImGui.CollapsingHeader(" Тонкая настройка загрузки") then
                ImGui.Indent(10)
                ImGui.TextColored(0.0, 0.8, 0.9, 1.0, "Опции:")
                self.loadOptions.attributes = ImGui.Checkbox("Характеристики", self.loadOptions.attributes)
                ImGui.SameLine()
                self.loadOptions.perks = ImGui.Checkbox("Перки", self.loadOptions.perks)
                ImGui.SameLine()
                self.loadOptions.skills = ImGui.Checkbox("Навыки", self.loadOptions.skills)
                ImGui.SameLine()
                self.loadOptions.equipment = ImGui.Checkbox("Экипировка", self.loadOptions.equipment)
                ImGui.SameLine()
                self.loadOptions.money = ImGui.Checkbox("Деньги (НГ+)", self.loadOptions.money)
                ImGui.SameLine()
                self.loadOptions.level = ImGui.Checkbox("Уровень (НГ+)", self.loadOptions.level)
                ImGui.SameLine()
                self.loadOptions.vehicles = ImGui.Checkbox("Гараж (Машины)", self.loadOptions.vehicles)
                
                ImGui.Spacing()
                ImGui.TextColored(0.0, 0.8, 0.9, 1.0, "Режим:")
                if ImGui.RadioButton("Честный", self.itemLoadMode == 0) then self.itemLoadMode = 0 end
                if ImGui.IsItemHovered() then ImGui.SetTooltip("Использует только ваши текущие очки и предметы в инвентаре.\nМатематически балансирует билд под ваш уровень.") end
                ImGui.SameLine()
                if ImGui.RadioButton("Песочница", self.itemLoadMode == 1) then if self.itemLoadMode ~= 1 then self.pendingModeSwitch = 1 end end
                if ImGui.IsItemHovered() then ImGui.SetTooltip("Создает недостающие очки и предметы из воздуха.\nВНИМАНИЕ: Навсегда меняет ваше сохранение!") end
                ImGui.SameLine()
                if ImGui.RadioButton("Примерочная", self.itemLoadMode == 2) then if self.itemLoadMode ~= 2 then self.pendingModeSwitch = 2 end end
                if ImGui.IsItemHovered() then ImGui.SetTooltip("Выдает предметы на время. При смене билда созданные вещи уничтожаются.\nАвтосохранения блокируются.") end
                
                ImGui.Unindent(10)
                ImGui.Spacing()
            end
            
            ImGui.Separator()
            
            if ImGui.BeginTabBar("BuildTabs") then
                if ImGui.BeginTabItem("Мои Билды") then
                    ImGui.Spacing()
                    
                    ImGui.BeginChild("BuildListPane", 250, 450, true)
                    local hasBuilds = false
                    for i, buildName in ipairs(self.buildsList) do
                        if not string.match(buildName, "^_AutoSave_") and not string.match(buildName, "^_History_") then
                            hasBuilds = true
                            if ImGui.Selectable(buildName, self.selectedBuild == buildName) then
                                if self.selectedBuild ~= buildName then
                                    self.selectedBuild = buildName
                                    self.selectedBuildData = Storage.LoadBuild(buildName)
                                    if self.selectedBuildData then
                                        self:FormatBuildDetails(self.selectedBuildData)
                                    end
                                end
                            end
                        end
                    end
                    if not hasBuilds then ImGui.TextDisabled("Нет сохраненных билдов.") end
                    ImGui.EndChild()
                    
                    ImGui.SameLine()
                    
                    ImGui.BeginChild("BuildDetailsPane", 0, 450, true)
                    if self.selectedBuild and self.selectedBuild ~= "" then
                        ImGui.TextColored(0.0, 0.8, 0.9, 1.0, "Билд:")
                        ImGui.SameLine()
                        ImGui.Text(self.selectedBuild)
                        
                        ImGui.SameLine(330)
                        if ImGui.Button("ЗАГРУЗИТЬ БИЛД", 130, 25) then
                            local data = Storage.LoadBuild(self.selectedBuild)
                            if data then self:StartBuildLoad(self.selectedBuild, data) end
                        end
                        
                        ImGui.Separator()
                        
                        ImGui.BeginChild("DetailsScroll", 0, 360, true)
                        if self.selectedBuildData and self.selectedBuildDetails then
                            local selectedDetails = self.selectedBuildDetails
                            if #selectedDetails.general > 0 then
                                if ImGui.CollapsingHeader("Общее") then
                                    for _, v in ipairs(selectedDetails.general) do ImGui.TextColored(0.98, 0.84, 0.12, 1.0, "- " .. v) end
                                end
                            end
                            if #selectedDetails.vehicles > 0 then
                                if ImGui.CollapsingHeader(" Гараж") then
                                    ImGui.Indent(10)
                                    for _, v in ipairs(selectedDetails.vehicles) do ImGui.Text(v) end
                                    ImGui.Unindent(10)
                                end
                            end
                            if ImGui.CollapsingHeader("Характеристики (" .. tostring(self.selectedBuildData.attributes and self.selectedBuildData.attributes.totalPool or 0) .. " очков)") then
                                for _, v in ipairs(self.selectedBuildDetails.attributes) do ImGui.Text("- " .. v) end
                            end
                            if ImGui.CollapsingHeader("Перки") then
                                if #self.selectedBuildDetails.perks == 0 then ImGui.Text("Нет перков") else
                                    for _, v in ipairs(self.selectedBuildDetails.perks) do ImGui.Text("- " .. v) end
                                end
                            end
                            if ImGui.CollapsingHeader("Навыки") then
                                if #self.selectedBuildDetails.skills == 0 then ImGui.Text("Нет данных") else
                                    for _, v in ipairs(self.selectedBuildDetails.skills) do ImGui.Text("- " .. v) end
                                end
                            end
                            if ImGui.CollapsingHeader("Оружие") then
                                if #self.selectedBuildDetails.weapons == 0 then ImGui.Text("Без оружия") else
                                    for _, v in ipairs(self.selectedBuildDetails.weapons) do ImGui.Text("- " .. v) end
                                end
                            end
                            if ImGui.CollapsingHeader("Одежда") then
                                if #self.selectedBuildDetails.equipment == 0 then ImGui.Text("Голышом") else
                                    for _, v in ipairs(self.selectedBuildDetails.equipment) do ImGui.Text("- " .. v) end
                                end
                            end
                            if ImGui.CollapsingHeader("Импланты") then
                                if #self.selectedBuildDetails.cyberware == 0 then ImGui.Text("Чистая органика") else
                                    for _, v in ipairs(self.selectedBuildDetails.cyberware) do ImGui.Text("- " .. v) end
                                end
                            end
                        else
                            ImGui.TextDisabled("Данные билда повреждены или недоступны.")
                        end
                        ImGui.EndChild()
                        
                        ImGui.Spacing()
                        if ImGui.Button("Удалить билд", 150, 20) then
                            self.pendingDeleteBuild = self.selectedBuild
                        end
                    else
                        ImGui.TextDisabled("Выберите билд из списка слева...")
                    end
                    ImGui.EndChild()
                    
                    ImGui.Separator()
                    self.buildNameInput = ImGui.InputText("Имя билда", self.buildNameInput, 100)
                    ImGui.SameLine()
                    if ImGui.Button("Сохранить текущий билд") then self:SaveCurrentState(self.buildNameInput) end
                    
                    ImGui.EndTabItem()
                end
                
                if ImGui.BeginTabItem("История") then
                    ImGui.BeginChild("HistoryPane", 0, 450, true)
                    local hasHistory = false
                    for i, buildName in ipairs(self.buildsList) do
                        if string.match(buildName, "^_AutoSave_") or string.match(buildName, "^_History_") then
                            hasHistory = true
                            local dn = buildName
                            if string.match(buildName, "^_AutoSave_") then
                                dn = "[Автосейв] " .. string.sub(buildName, 11)
                                ImGui.TextColored(0.0, 0.8, 0.9, 1.0, dn)
                            else
                                dn = "[Вручную] " .. string.sub(buildName, 10)
                                ImGui.Text(dn)
                            end
                            ImGui.SameLine(300)
                            if ImGui.Button("Загрузить##h_"..tostring(i)) then
                                local data = Storage.LoadBuild(buildName)
                                if data then self:StartBuildLoad(buildName, data) end
                            end
                            ImGui.SameLine()
                            if ImGui.Button("Удалить##hdel_"..tostring(i)) then self.pendingDeleteBuild = buildName end
                        end
                    end
                    if not hasHistory then ImGui.Text("История пуста.") end
                    ImGui.EndChild()
                    
                    self.historyNameInput = ImGui.InputText("Заметка", self.historyNameInput, 100)
                    ImGui.SameLine()
                    if ImGui.Button("Быстрое сохранение (в Историю)") then
                        local safeName = self.historyNameInput
                        if safeName == "" then safeName = "Manual_" .. tostring(os.time()) end
                        self:SaveCurrentState("_History_" .. safeName)
                        self.historyNameInput = ""
                    end
                    ImGui.EndTabItem()
                end
                
                if ImGui.BeginTabItem("Чит-Панель") then

                    ImGui.Spacing()
                    if ImGui.Button("Полный сброс (Атрибуты и Перки)", -1, 30) then
                        if not self.loadState.active then
                            local p = Game.GetPlayer()
                            if p then
                                local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                                pcall(function() devData.hasResetAttributes = false; devData:ResetAttributes() end)
                                pcall(Perks.SellAll)
                                self.statusMessage = "Атрибуты и перки сброшены! Очки возвращены."
                            end
                        end
                    end
                    
                    ImGui.Spacing()
                    ImGui.Columns(2, "CheatColumns", true)
                    
                    ImGui.TextColored(0.98, 0.84, 0.12, 1.0, "Очки прокачки")
                    local newAttr, attrChanged = ImGui.InputInt("Атрибуты (+/-)", self.addAttrPoints, 1, 5)
                    if attrChanged then self.addAttrPoints = newAttr end
                    if ImGui.Button("Применить##attr") then
                        local p = Game.GetPlayer()
                        if p and self.addAttrPoints ~= 0 then
                            local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                            pcall(function() 
                                local change = self.addAttrPoints
                                if change < 0 then
                                    local freePts = devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Attribute"))
                                    change = math.max(-freePts, change)
                                end
                                if change ~= 0 then
                                    devData:AddDevelopmentPoints(change, Enum.new("gamedataDevelopmentPointType", "Attribute")) 
                                end
                            end)
                            self.statusMessage = "Атрибуты изменены."
                        end
                    end
                    
                    ImGui.Spacing()
                    local newPerk, perkChanged = ImGui.InputInt("Перки (+/-)", self.addPerkPoints, 1, 5)
                    if perkChanged then self.addPerkPoints = newPerk end
                    if ImGui.Button("Применить##perk") then
                        local p = Game.GetPlayer()
                        if p and self.addPerkPoints ~= 0 then
                            local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                            pcall(function() 
                                local change = self.addPerkPoints
                                if change < 0 then
                                    local freePts = devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Primary"))
                                    change = math.max(-freePts, change)
                                end
                                if change ~= 0 then
                                    devData:AddDevelopmentPoints(change, Enum.new("gamedataDevelopmentPointType", "Primary")) 
                                end
                            end)
                            self.statusMessage = "Перки изменены."
                        end
                    end
                    
                    ImGui.NextColumn()
                    
                    ImGui.TextColored(0.98, 0.84, 0.12, 1.0, "Инвентарь и Уровни")
                    local newMoney, moneyChanged = ImGui.InputInt("Эдди (+/-)", self.addMoneyAmount, 1000, 10000)
                    if moneyChanged then self.addMoneyAmount = newMoney end
                    if ImGui.Button("Применить##money") then
                        local p = Game.GetPlayer()
                        local ts = Game.GetTransactionSystem()
                        if p and ts and self.addMoneyAmount ~= 0 then
                            local amount = self.addMoneyAmount
                            if amount > 0 then
                                Game.AddToInventory("Items.money", amount)
                            else
                                local amountToRemove = math.abs(amount)
                                local currentMoney = ts:GetItemQuantity(p, ItemID.FromTDBID(TweakDBID.new("Items.money")))
                                if amountToRemove > currentMoney then amountToRemove = currentMoney end
                                ts:RemoveItemByTDBID(p, TweakDBID.new("Items.money"), amountToRemove)
                            end
                            self.statusMessage = "Эдди изменены."
                        end
                    end
                    
                    ImGui.Spacing()
                    local newLevelAmt, levelAmtChanged = ImGui.InputInt("Уровень (+/-)", self.addLevelAmount, 1, 5)
                    if levelAmtChanged then self.addLevelAmount = newLevelAmt end
                    if ImGui.Button("Применить##level") then
                        local p = Game.GetPlayer()
                        if p and self.addLevelAmount ~= 0 then
                            local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                            pcall(function() 
                                local cur = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "Level"))
                                local nlvl = math.max(1, math.min(60, cur + self.addLevelAmount))
                                local actualChange = nlvl - cur
                                devData:SetLevel(Enum.new("gamedataProficiencyType", "Level"), nlvl, Enum.new("telemetryLevelGainReason", "Gameplay")) 
                                
                                if actualChange < 0 then
                                    local freeAttr = devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Attribute"))
                                    local deductAttr = math.max(-freeAttr, actualChange)
                                    if deductAttr < 0 then
                                        devData:AddDevelopmentPoints(deductAttr, Enum.new("gamedataDevelopmentPointType", "Attribute"))
                                    end
                                    
                                    local freePerk = devData:GetDevPoints(Enum.new("gamedataDevelopmentPointType", "Primary"))
                                    local deductPerk = math.max(-freePerk, actualChange)
                                    if deductPerk < 0 then
                                        devData:AddDevelopmentPoints(deductPerk, Enum.new("gamedataDevelopmentPointType", "Primary"))
                                    end
                                end
                            end)
                            self.statusMessage = "Уровень изменен."
                        end
                    end
                    
                    ImGui.Spacing()
                    local newSCAmt, scAmtChanged = ImGui.InputInt("Репутация (+/-)", self.addSCAmount, 1, 5)
                    if scAmtChanged then self.addSCAmount = newSCAmt end
                    if ImGui.Button("Применить##sc") then
                        local p = Game.GetPlayer()
                        if p and self.addSCAmount ~= 0 then
                            local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                            pcall(function() 
                                local cur = devData:GetProficiencyLevel(Enum.new("gamedataProficiencyType", "StreetCred"))
                                local nlvl = math.max(1, math.min(50, cur + self.addSCAmount))
                                devData:SetLevel(Enum.new("gamedataProficiencyType", "StreetCred"), nlvl, Enum.new("telemetryLevelGainReason", "Gameplay")) 
                            end)
                            self.statusMessage = "Репутация изменена."
                        end
                    end
                    
                    ImGui.Columns(1)
                    ImGui.EndTabItem()
                end
                
                ImGui.EndTabBar()
            end

            ImGui.Separator()
            if ImGui.Button("ЗАКРЫТЬ", -1, 30) then self.showWindow = false end
            
            -- Popups
            if self.pendingModeSwitch ~= -1 then ImGui.OpenPopup("Внимание! Смена режима") end
            if ImGui.BeginPopupModal("Внимание! Смена режима", true, ImGuiWindowFlags.AlwaysAutoResize) then
                local modeName = self.pendingModeSwitch == 1 and "Песочница" or "Примерочная"
                ImGui.Text("Вы собираетесь включить режим '" .. modeName .. "'.")
                ImGui.Text("Этот режим предназначен для тестов и фана. Он может необратимо изменить инвентарь или ваши очки прокачки!")
                ImGui.Separator()
                if ImGui.Button("Да, я понимаю риски", 150, 0) then self.itemLoadMode = self.pendingModeSwitch; self.pendingModeSwitch = -1; ImGui.CloseCurrentPopup() end
                ImGui.SameLine()
                if ImGui.Button("Отмена", 100, 0) then self.pendingModeSwitch = -1; ImGui.CloseCurrentPopup() end
                ImGui.EndPopup()
            end
            
            if self.pendingDeleteBuild ~= nil then ImGui.OpenPopup("Удаление билда") end
            if ImGui.BeginPopupModal("Удаление билда", true, ImGuiWindowFlags.AlwaysAutoResize) then
                ImGui.Text("Вы уверены, что хотите навсегда удалить билд:")
                ImGui.Text("'" .. tostring(self.pendingDeleteBuild) .. "' ?")
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 1.0)
                ImGui.Text("Это действие нельзя отменить!")
                ImGui.PopStyleColor()
                ImGui.Separator()
                if ImGui.Button("Да, удалить", 120, 0) then Storage.DeleteBuild(self.pendingDeleteBuild); self.statusMessage = "Билд удален."; self:RefreshBuilds(); self.pendingDeleteBuild = nil; ImGui.CloseCurrentPopup() end
                ImGui.SameLine()
                if ImGui.Button("Отмена", 100, 0) then self.pendingDeleteBuild = nil; ImGui.CloseCurrentPopup() end
                ImGui.EndPopup()
            end
        end
        ImGui.End()
        
        self:PopTheme()
    end
end

function CyberBuildManager:Update(dt)

    if self.loadState.active then
        if self.loadState.frames > 0 then
            self.loadState.frames = self.loadState.frames - 1
        else
            local phase = self.loadState.phase
            local data = self.loadState.data
            
            if phase == 1 then
                -- ФАЗА 1: Продаем абсолютно все перки
                -- СОХРАНЯЕМ ИСТИННЫЙ ПУЛ ОЧКОВ ДО ТОГО КАК ДВИЖОК ИХ УДАЛИТ!
                self.loadState.truePoints = Perks.GetTrueTotalPoints()
                
                if self.loadOptions.perks and data.perks then
                    pcall(Perks.SellAll)
                end
                self.loadState.frames = 1
                self.loadState.phase = 2
                self.statusMessage = "Загрузка: Сброс характеристик..."
                
            elseif phase == 2 then
                -- ФАЗА 2: Сброс характеристик (работает, так как перков больше нет) и прокачка их
                if self.loadOptions.attributes and data.attributes then
                    pcall(Attributes.Apply, data.attributes, self.itemLoadMode)
                end
                
                -- ВОССТАНОВЛЕНИЕ ПОТЕРЯННЫХ ОЧКОВ ПЕРКОВ!
                -- После ResetAttributes движок мог удалить перки без возврата очков.
                if self.loadState.truePoints then
                    pcall(Perks.RestoreTruePoints, self.loadState.truePoints)
                end
                
                if self.loadOptions.skills and data.skills then
                    pcall(Skills.Apply, data.skills)
                end
                self.loadState.frames = 10
                self.loadState.phase = 3
                self.statusMessage = "Загрузка: Покупка перков..."
                
            elseif phase == 3 then
                -- ФАЗА 3: Покупка нужных перков из билда
                if self.loadOptions.perks and data.perks then
                    pcall(Perks.BuySaved, data.perks, self.itemLoadMode)
                end
                self.loadState.frames = 5
                self.loadState.phase = 4
                self.statusMessage = "Загрузка: Применение снаряжения..."
                
            elseif phase == 4 then
                -- ФАЗА 4: Возвращаем оставшиеся очки и надеваем снаряжение
                if self.loadOptions.attributes and data.attributes then
                    pcall(Attributes.FixPoints, data.attributes)
                end
                if self.loadOptions.perks and data.perks then
                    pcall(Perks.FixPoints, data.perks, self.itemLoadMode)
                end
                if self.loadOptions.equipment and data.equipment then
                    pcall(Equipment.Apply, data.equipment, self.itemLoadMode)
                end
                if self.loadOptions.equipment and data.cyberware then
                    pcall(Equipment.Apply, data.cyberware, self.itemLoadMode)
                end
                
                if self.loadOptions.money and data.money then
                    pcall(function()
                        local p = Game.GetPlayer()
                        local ts = Game.GetTransactionSystem()
                        if p and ts then
                            local currentMoney = ts:GetItemQuantity(p, ItemID.FromTDBID(TweakDBID.new("Items.money")))
                            local diff = data.money - currentMoney
                            if diff > 0 then
                                Game.AddToInventory("Items.money", diff)
                            elseif diff < 0 then
                                ts:RemoveItemByTDBID(p, TweakDBID.new("Items.money"), math.abs(diff))
                            end
                        end
                    end)
                end
                
                if self.loadOptions.level and data.level and data.streetCred then
                    pcall(function()
                        local p = Game.GetPlayer()
                        local devData = Game.GetScriptableSystemsContainer():Get(CName.new('PlayerDevelopmentSystem')):GetDevelopmentData(p)
                        if devData then
                            devData:SetLevel(Enum.new("gamedataProficiencyType", "Level"), data.level, Enum.new("telemetryLevelGainReason", "Gameplay"))
                            devData:SetLevel(Enum.new("gamedataProficiencyType", "StreetCred"), data.streetCred, Enum.new("telemetryLevelGainReason", "Gameplay"))
                        end
                    end)
                end
                
                if self.loadOptions.vehicles and data.vehicles then
                    pcall(function()
                        local vs = Game.GetVehicleSystem()
                        if vs then
                            for _, v in ipairs(data.vehicles) do
                                vs:EnablePlayerVehicle(v.id, true, false)
                            end
                        end
                    end)
                end
                
                self.loadState.active = false
                self.statusMessage = "Билд '" .. self.loadState.buildName .. "' успешно загружен!"
            end
        end
    end

    -- Старая очередь (на всякий случай)
    if #self.delayedQueue > 0 then
        local newQueue = {}
        for _, task in ipairs(self.delayedQueue) do
            task.frames = task.frames - 1
            if task.frames <= 0 then
                pcall(task.func)
            else
                table.insert(newQueue, task)
            end
        end
        self.delayedQueue = newQueue
    end
end

registerForEvent("onInit", function()
    CyberBuildManager:Init()
end)

registerForEvent("onUpdate", function(deltaTime)
    CyberBuildManager:Update(deltaTime)
end)

registerForEvent("onOverlayOpen", function()
    CyberBuildManager.showWindow = true
end)

registerForEvent("onOverlayClose", function()
    CyberBuildManager.showWindow = false
end)

registerForEvent("onDraw", function()
    CyberBuildManager:Draw()
end)







return CyberBuildManager
