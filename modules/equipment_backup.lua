local Equipment = {}

-- Все поддерживаемые зоны экипировки
local equipmentAreas = {
    -- Оружие
    "Weapon",
    -- Быстрый доступ
    "Gadget", "Consumable",
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
                    
                    if name ~= "unknown" and name ~= "0" and not string.match(name, "00000000") then
                        data[areaName][tostring(slotIndex)] = {
                            id = name,
                            hash = tostring(itemID)
                        }
                    end
                end
            end
        end
    end
    
    return data
end

function Equipment.Apply(data)
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
                            if currentName == "unknown" then
                                local rStr = tostring(currentItem.tdbid)
                                local ext = string.match(rStr, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
                                if ext then currentName = ext else currentName = rStr end
                            end
                        end)
                    end
                end
                
                -- Читаем целевой предмет из билда
                local targetTdbidStr = nil
                local targetHashStr = nil
                
                if data[areaName] and data[areaName][tostring(slotIndex)] then
                    local targetData = data[areaName][tostring(slotIndex)]
                    if type(targetData) == "string" then
                        targetTdbidStr = targetData
                    elseif type(targetData) == "table" then
                        targetTdbidStr = targetData.id
                        targetHashStr = targetData.hash
                    end
                end
                
                -- ЛОГИКА УМНОГО ЗЕРКАЛА
                if currentHash ~= 0 and not targetTdbidStr then
                    -- 1. СНЯТИЕ: на игроке есть вещь, а в билде пусто
                    print(string.format("[CyberBuildManager] [MIRROR] Снимаю %s из %s:%d (в билде пусто)", currentName, areaName, slotIndex))
                    local unequipSuccess = false
                    if areaIndex ~= -1 then
                        local sU, errU = pcall(function() 
                            pd:UnequipItem(areaIndex, slotIndex, true) 
                            unequipSuccess = true
                        end)
                        if not sU then print("[CyberBuildManager] [FAIL] UnequipItem (force): " .. tostring(errU)) end
                    end
                    
                    -- Если стандартное снятие не сработало (особенно для имплантов 2.0+), используем хак TransactionSystem
                    if not unequipSuccess or string.match(areaName, "CW") then
                        print("[CyberBuildManager] [FALLBACK] Использую низкоуровневое снятие (RemoveItemFromAnySlot) для " .. areaName)
                        pcall(function() ts:RemoveItemFromAnySlot(player, currentItem) end)
                    end
                    
                elseif targetTdbidStr then
                    -- 2. СОВПАДЕНИЕ ИЛИ ЗАМЕНА
                    local isPerfectMatch = false
                    if hasItem and currentItem then
                        if targetHashStr and targetHashStr ~= "" then
                            isPerfectMatch = (tostring(currentItem) == targetHashStr)
                        else
                            isPerfectMatch = (currentName == targetTdbidStr)
                        end
                    end
                    
                    if isPerfectMatch then
                        -- СОВПАДАЕТ: ничего не трогаем (идеальный билд)
                    else
                        -- НАДЕВАНИЕ / ЗАМЕНА
                        print(string.format("[CyberBuildManager] [MIRROR] Ищу %s в %s:%d", targetTdbidStr, areaName, slotIndex))
                        
                        local s, tdbid = pcall(function() return TweakDBID.new(targetTdbidStr) end)
                        if s and tdbid then
                            local genericItemID = ItemID.FromTDBID(tdbid)
                            local instanceID = nil
                            local backupInstanceID = nil
                            
                            local success, itemList = pcall(function() return ts:GetItemList(player) end)
                            if success and type(itemList) == "table" then
                                for _, itemData in ipairs(itemList) do
                                    local sID, currID = pcall(function() return itemData:GetID() end)
                                    if sID and currID then
                                        -- Проверка Приоритет 1: Идеальное совпадение по хешу
                                        if targetHashStr and tostring(currID) == targetHashStr then
                                            instanceID = currID
                                            break
                                        end
                                        
                                        -- Проверка Приоритет 2: Совпадение по базовому ID
                                        local sTdb, currTdb = pcall(function() return currID.tdbid end)
                                        if sTdb and currTdb and tostring(currTdb) == tostring(tdbid) then
                                            if not backupInstanceID then backupInstanceID = currID end
                                        end
                                    end
                                end
                            end
                            
                            if not instanceID then instanceID = backupInstanceID end
                            
                            if not instanceID then
                                print("[CyberBuildManager] [EQUIP] Нет в инвентаре. Создаю базовую копию (GiveItem)...")
                                pcall(function() ts:GiveItem(player, genericItemID, 1) end)
                                
                                local s2, list2 = pcall(function() return ts:GetItemList(player) end)
                                if s2 and type(list2) == "table" then
                                    for _, itemData in ipairs(list2) do
                                        local sID, currID = pcall(function() return itemData:GetID() end)
                                        if sID and currID then
                                            local sTdb, currTdb = pcall(function() return currID.tdbid end)
                                            if sTdb and currTdb and tostring(currTdb) == tostring(tdbid) then
                                                instanceID = currID
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            
                            local itemToEquip = instanceID or genericItemID
                            
                            -- Для надежности снимаем текущий предмет перед надеванием нового
                            if currentHash ~= 0 then
                                if areaIndex ~= -1 then
                                    pcall(function() pd:UnequipItem(areaIndex, slotIndex, true) end)
                                end
                                pcall(function() ts:RemoveItemFromAnySlot(player, currentItem) end)
                            end
                            
                            -- Пробуем надеть через очередь (патч 2.0+)
                            local sReq, errReq = pcall(function() 
                                local req = EquipRequest.new()
                                req.owner = player
                                req.itemID = itemToEquip
                                req.slotIndex = slotIndex
                                eqSys:QueueRequest(req)
                            end)
                            if not sReq then
                                print("[CyberBuildManager] [FALLBACK] QueueRequest не сработал: " .. tostring(errReq) .. ", пробуем прямое надевание")
                                pcall(function() pd:EquipItem(itemToEquip, slotIndex) end)
                            end
                    end
                    end
                end
            end
        end
    end
    print("[CyberBuildManager] --- КОНЕЦ УМНОЙ ЗАГРУЗКИ ЭКИПИРОВКИ ---")
end

return Equipment
