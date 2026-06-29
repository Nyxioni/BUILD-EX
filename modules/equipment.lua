local WeaponCloner = require("modules/weapon_cloner")
local Telemetry = require("modules/telemetry")
local Equipment = {}

-- Все поддерживаемые зоны экипировки
local equipmentAreas = {
    -- Оружие
    "Weapon",
    -- Быстрый доступ
    "Gadget", "Consumable", "QuickSlot",
    -- Одежда
    "Head", "Face", "OuterChest", "InnerChest", "Legs", "Feet",
    -- Киберимпланты
    "FrontalCortexCW", "SystemReplacementCW", "EyesCW", "MusculoskeletalSystemCW",
    "NervousSystemCW", "CardiovascularSystemCW", "LegsCW", "ArmsCW", "HandsCW", "IntegumentarySystemCW"
}

function Equipment.Read()
    local data = {}
    local player = Game.GetPlayer()
    if not player then return data end
    
    local success, eqSys = pcall(function() return Game.GetScriptableSystemsContainer():Get(CName.new('EquipmentSystem')) end)
    if not success or not eqSys then return { _ERROR = "No EquipmentSystem" } end

    for _, areaName in ipairs(equipmentAreas) do
        local ok, areaEnum = pcall(function() return Enum.new('gamedataEquipmentArea', areaName) end)
        if ok and areaEnum then
            data[areaName] = {}
            for slotIndex = 0, 3 do
                local s, itemID = pcall(function() return eqSys:GetItemInEquipSlot(player, areaEnum, slotIndex) end)
                local okID, idVal = pcall(function() return itemID.tdbid end)
                if s and itemID and okID and idVal then
                    local name = "unknown"
                    pcall(function()
                        local n = Game.NameToString(idVal)
                        if n and n ~= "" then name = n end
                    end)
                    
                    if name == "unknown" then
                        local sStr, rawStr = pcall(function() return tostring(idVal) end)
                        if sStr and rawStr and rawStr ~= "0" and not string.match(rawStr, "00000000") then
                            local extracted = string.match(rawStr, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
                            if extracted then
                                name = extracted
                            else
                                name = rawStr
                            end
                        end
                    end
                    
                    local isWeapon = false
                    if areaName == "Weapon" then isWeapon = true end
                    
                    if name ~= "unknown" and name ~= "0" and not string.match(name, "00000000") then
                        if isWeapon then
                            data[areaName][tostring(slotIndex)] = WeaponCloner.ExtractWeaponData(player, itemID, name)
                        else
                            data[areaName][tostring(slotIndex)] = name
                        end
                    end
                end
            end
        end
    end
    
    return data
end

function Equipment.Apply(data, loadMode)
    loadMode = loadMode or 1
    local rentalItemsThisSession = {}
    
    local player = Game.GetPlayer()
    if not player then return end
    
    local ts = Game.GetTransactionSystem()
    local eqSys = Game.GetScriptableSystemsContainer():Get(CName.new('EquipmentSystem'))
    if not ts or not eqSys then return end

    print("[CyberBuildManager] --- НАЧАЛО УМНОЙ ЗАГРУЗКИ ЭКИПИРОВКИ ---")
    local pd = nil
    pcall(function() pd = eqSys:GetPlayerData(player) end)
    if not pd then 
        print("[CyberBuildManager] [FATAL] Не удалось получить PlayerData!")
        return 
    end
    


    if data.Inventory then
        print("[CyberBuildManager] --- ВЫДАЧА ДОПОЛНИТЕЛЬНОГО ИНВЕНТАРЯ ---")
        for _, invItem in pairs(data.Inventory) do
            if loadMode ~= 0 then
                pcall(function()
                    local itemId = ItemID.new(TweakDBID.new(invItem))
                    ts:GiveItem(player, itemId, 1)
                    print("[CyberBuildManager] Выдан предмет: " .. invItem)
                    if loadMode == 2 then table.insert(rentalItemsThisSession, invItem) end
                end)
            end
        end
    end

    for _, areaName in ipairs(equipmentAreas) do
        local ok, areaEnum = pcall(function() return Enum.new('gamedataEquipmentArea', areaName) end)
        if ok and areaEnum then
            local sArea, areaIndex = pcall(function() return pd:GetEquipAreaIndex(areaEnum) end)
            if not sArea or not areaIndex then areaIndex = -1 end
            
            for slotIndex = 0, 3 do
                -- Читаем текущий надетый предмет (как при сохранении)
                local currentHash = 0
                local currentName = "unknown"
                local hasItem, currentItem = pcall(function() return eqSys:GetItemInEquipSlot(player, areaEnum, slotIndex) end)
                
                if hasItem and currentItem then
                    local sH, h = pcall(function() return currentItem.tdbid.hash end)
                    if sH and h and h ~= 0 then 
                        currentHash = h 
                        pcall(function()
                            local n = Game.NameToString(currentItem.tdbid)
                            if n and n ~= "" then currentName = n end
                        end)
                        if currentName == "unknown" then
                            pcall(function()
                                local rStr = tostring(currentItem.tdbid)
                                local ext = string.match(rStr, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
                                if ext then currentName = ext else currentName = rStr end
                            end)
                        end
                    end
                end
                
                -- Читаем целевой предмет из билда
                local targetName = nil
                local targetWeaponData = nil
                if data[areaName] and data[areaName][tostring(slotIndex)] then
                    local tData = data[areaName][tostring(slotIndex)]
                    if type(tData) == "table" and tData.baseTdbid then
                        targetName = tData.baseTdbid
                        targetWeaponData = tData
                    else
                        targetName = tData
                    end
                end
                
                -- ЛОГИКА УМНОГО ЗЕРКАЛА
                if currentHash ~= 0 and not targetName then
                    -- 1. СНЯТИЕ: на игроке есть вещь, а в билде пусто
                    print(string.format("[CyberBuildManager] [MIRROR] Снимаю %s из %s:%d (в билде пусто)", currentName, areaName, slotIndex))
                    Telemetry.Log("EQUIP", string.format("Unequipping %s from %s:%d because build slot is empty.", currentName, areaName, slotIndex))
                    local unequipSuccess = false
                    
                    -- Пробуем надежное снятие через UnequipRequest (патч 2.0+)
                    local sReq, errReq = pcall(function() 
                        local req = UnequipRequest.new()
                        req.owner = player
                        req.areaType = areaEnum
                        req.slotIndex = slotIndex
                        eqSys:QueueRequest(req)
                    end)
                    if sReq then unequipSuccess = true end
                    
                    if not unequipSuccess and areaIndex ~= -1 then
                        local sU, errU = pcall(function() 
                            pd:UnequipItem(areaIndex, slotIndex, true) 
                            unequipSuccess = true
                        end)
                        if not sU then print("[CyberBuildManager] [FAIL] UnequipItem (force): " .. tostring(errU)) end
                    end
                    
                    if not unequipSuccess or string.match(areaName, "CW") or areaName == "QuickSlot" or areaName == "Gadget" or areaName == "Consumable" then
                        pcall(function() ts:RemoveItemFromAnySlot(player, currentItem) end)
                    end
                    
                elseif targetName and currentName ~= targetName then
                    print(string.format("[CyberBuildManager] [MIRROR] Надеваю %s в %s:%d (сейчас: %s)", targetName, areaName, slotIndex, currentName))
                    
                    local s, tdbid = pcall(function() return TweakDBID.new(targetName) end)
                    if s and tdbid then
                        local itemToEquip = nil
                        
                        local sPcall, getOk, list = pcall(function() return ts:GetItemList(player) end)
                        if sPcall and getOk and type(list) == "table" then
                            for _, itemData in ipairs(list) do
                                pcall(function()
                                    local invItemID = itemData:GetID()
                                    local invName = "unknown"
                                    local rStr = tostring(invItemID.tdbid)
                                    local ext = string.match(rStr, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
                                    if ext then invName = ext else invName = rStr end
                                    
                                    if invName == targetName then
                                        itemToEquip = invItemID
                                    end
                                end)
                                if itemToEquip then break end
                            end
                        end
                        
                        local itemWasInBackpack = false
                        if not itemToEquip then
                            if loadMode == 0 then
                                print("[CyberBuildManager] [LEGIT] Предмет " .. targetName .. " не найден в рюкзаке, пропускаем.")
                                Telemetry.Log("EQUIP", string.format("[LEGIT] Item %s not found in backpack. Skipping.", targetName))
                            else
                                print("[CyberBuildManager] [MIRROR] Предмет " .. targetName .. " не найден в рюкзаке! Создаю новый.")
                                Telemetry.Log("EQUIP", string.format("[SANDBOX] Item %s not found in backpack. Spawning new item.", targetName))
                                local genericItemID = ItemID.FromTDBID(tdbid)
                                pcall(function() ts:GiveItem(player, genericItemID, 1) end)
                                if loadMode == 2 then table.insert(rentalItemsThisSession, targetName) end
                                -- ВАЖНО: В Патче 2.0 киберимпланты требуют уникальный "инстансовый" ID из рюкзака.
                                -- Нельзя надеть genericItemID. Поэтому заново сканируем рюкзак, чтобы найти только что созданный предмет!
                                pcall(function()
                                    local newList = ts:GetItemList(player)
                                    for _, itemData in ipairs(newList) do
                                        local invItemID = itemData:GetID()
                                        local invName = "unknown"
                                        local rStr = tostring(invItemID.tdbid)
                                        local ext = string.match(rStr, "%-%-[%[%s*(.-)%s*%-%-]%]")
                                        if ext then invName = ext else invName = rStr end
                                        
                                        if invName == targetName then
                                            itemToEquip = invItemID
                                            break
                                        end
                                    end
                                end)
                                
                                if not itemToEquip then itemToEquip = genericItemID end
                            end
                        else
                            print("[CyberBuildManager] [MIRROR] Нашел предмет " .. targetName .. " в рюкзаке! Надеваю его.")
                            Telemetry.Log("EQUIP", string.format("Found item %s in backpack. Equipping.", targetName))
                            itemWasInBackpack = true
                        end
                        
                        -- ЛОГИКА КЛОНИРОВАНИЯ НАСАДОК
                        if itemToEquip and loadMode ~= 0 and targetWeaponData and targetWeaponData.parts and #targetWeaponData.parts > 0 then
                            itemToEquip = WeaponCloner.CloneAndInstallParts(player, itemToEquip, targetName, targetWeaponData, itemWasInBackpack, loadMode, rentalItemsThisSession)
                        end
                        
                        if itemToEquip then
                            if currentHash ~= 0 and currentName ~= "unknown" then
                                local sReq, errReq = pcall(function() 
                                    local req = UnequipRequest.new()
                                    req.owner = player
                                    req.areaType = areaEnum
                                    req.slotIndex = slotIndex
                                    eqSys:QueueRequest(req)
                                end)
                                if not sReq then
                                    pcall(function() pd:UnequipItem(areaIndex, slotIndex, true) end)
                                end
                            end
                            
                            local sE, errE = pcall(function() 
                                local req = EquipRequest.new()
                                req.owner = player
                                req.itemID = itemToEquip
                                req.slotIndex = slotIndex
                                eqSys:QueueRequest(req)
                            end)
                        
                        -- В Патче 2.0 движок блокирует надевание киберимплантов через QueueRequest, если мы не у Рипера, 
                        -- ИЛИ если у персонажа не хватает лимита емкости (Level 15 не тянет Легендарки).
                        -- Единственный способ надеть их — жестко прописать через PlayerData!
                        if string.match(areaName, "CW") then
                            pcall(function() pd:EquipItem(itemToEquip, slotIndex) end)
                        elseif not sE then
                            pcall(function() pd:EquipItem(itemToEquip, slotIndex) end)
                        end
                        end
                    end
                elseif targetName and currentName == targetName then
                    -- 3. СОВПАДАЕТ: ничего не трогаем (идеальный билд)
                    -- Раскомментируйте строку ниже, чтобы видеть пропуски в логе
                    -- print(string.format("[CyberBuildManager] [MIRROR] Пропуск %s:%d (уже надето)", areaName, slotIndex))
                end
            end
        end
    end
    
    if loadMode == 2 and #rentalItemsThisSession > 0 then
        local Storage = require("core/storage")
        local existingCache = Storage.LoadRentalCache() or {}
        for _, idStr in ipairs(rentalItemsThisSession) do
            table.insert(existingCache, idStr)
        end
        Storage.SaveRentalCache(existingCache)
        print("[CyberBuildManager] [RENTAL] Сохранено " .. tostring(#rentalItemsThisSession) .. " временных предметов.")
    end
    
    print("[CyberBuildManager] --- КОНЕЦ УМНОЙ ЗАГРУЗКИ ЭКИПИРОВКИ ---")
end

return Equipment
