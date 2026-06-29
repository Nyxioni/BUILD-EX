local WeaponCloner = {}

-- Вспомогательная функция для чистки TweakDBID строк
local function GetCleanName(tdbidObj)
    local rStr = tostring(tdbidObj)
    local ext = string.match(rStr, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
    if ext then return ext else return rStr end
end

-- Извлекает данные об оружии и его насадках для сохранения в билд
function WeaponCloner.ExtractWeaponData(player, itemID, itemName)
    local weaponData = {
        baseTdbid = itemName,
        qualityNum = 4,
        parts = {}
    }
    
    local ts = Game.GetTransactionSystem()
    local sData, itemDataObj = pcall(function() return ts:GetItemData(player, itemID) end)
    
    if sData and itemDataObj then
        -- Извлекаем качество базы
        local sStatsID, statsObjID = pcall(function() return itemDataObj:GetStatsObjectID() end)
        if sStatsID then
            local stats = Game.GetStatsSystem()
            local sStat, statVal = pcall(function() return stats:GetStatValue(statsObjID, Enum.new("gamedataStatType", "Quality")) end)
            if sStat and statVal > 0 then
                weaponData.qualityNum = statVal
            end
        end
        
        -- Извлекаем насадки
        local sParts, parts = pcall(function() return itemDataObj:GetItemParts() end)
        if sParts and parts then
            for _, part in ipairs(parts) do
                pcall(function()
                    local partItemID = part:GetItemID(part)
                    local slotID = part:GetSlotID(part)
                    local partName = GetCleanName(partItemID.tdbid)
                    local slotName = GetCleanName(slotID)
                    
                    if not string.find(partName, "Empty") then
                        if string.find(slotName, "Scope") or string.find(slotName, "PowerModule") or string.find(slotName, "WeaponMod") then
                            table.insert(weaponData.parts, {
                                tdbid = partName,
                                slot = slotName
                            })
                        end
                    end
                end)
            end
        end
    end
    
    return weaponData
end

-- Спавнит насадки, инжектит цвет и собирает Идеальную Копию пушки
function WeaponCloner.CloneAndInstallParts(player, itemToEquip, targetName, targetWeaponData, itemWasInBackpack, loadMode, rentalItemsThisSession)
    print("[CyberBuildManager] [CLONE] Запуск сборки насадок для " .. targetName)
    local ts = Game.GetTransactionSystem()
    local imSys = Game.GetScriptableSystemsContainer():Get(CName.new('ItemModificationSystem'))
    local stats = Game.GetStatsSystem()
    
    -- Пытаемся получить данные базовой пушки напрямую, даже если она только что создана
    local sBase, baseItemData = pcall(function() return ts:GetItemData(player, itemToEquip) end)
    
    -- Инжектим качество в саму базовую пушку
    if sBase and baseItemData and targetWeaponData.qualityNum then
        pcall(function()
            local wStatsID = baseItemData:GetStatsObjectID()
            if wStatsID then
                local modifier = gameConstantStatModifierData.new()
                modifier.modifierType = Enum.new("gameStatModifierType", "Additive")
                modifier.statType = Enum.new("gamedataStatType", "Quality")
                modifier.value = targetWeaponData.qualityNum
                stats:AddModifier(wStatsID, modifier)
            end
        end)
    end
    
    -- Спавним и устанавливаем насадки
    for _, part in ipairs(targetWeaponData.parts) do
        local sP, pTdbid = pcall(function() return TweakDBID.new(part.tdbid) end)
        if sP and pTdbid then
            local pItemID = ItemID.FromTDBID(pTdbid)
            pcall(function() ts:GiveItem(player, pItemID, 1) end)
            if loadMode == 2 and rentalItemsThisSession then
                table.insert(rentalItemsThisSession, part.tdbid)
            end
            
            -- Получаем данные только что созданной насадки напрямую
            local sPartData, partItemData = pcall(function() return ts:GetItemData(player, pItemID) end)
            
            if sPartData and partItemData then
                pcall(function()
                    if not string.find(part.slot, "WeaponMod") then
                        local partStatsID = partItemData:GetStatsObjectID()
                        if partStatsID then
                            local modifier = gameConstantStatModifierData.new()
                            modifier.modifierType = Enum.new("gameStatModifierType", "Additive")
                            modifier.statType = Enum.new("gamedataStatType", "Quality")
                            modifier.value = targetWeaponData.qualityNum or 4
                            stats:AddModifier(partStatsID, modifier)
                        end
                    end
                    
                    local sSlot, slotTdbid = pcall(function() return TweakDBID.new(part.slot) end)
                    if sSlot and slotTdbid then
                        imSys:InstallItemPart(player, itemToEquip, pItemID, slotTdbid)
                    end
                end)
            end
        end
    end
    
    return itemToEquip
end

return WeaponCloner
