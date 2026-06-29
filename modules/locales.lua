local Locales = {
    current = "en"
}

Locales.strings = {
    en = {
        STATUS_WAITING = "Waiting",
        STATUS_LOAD_PHASE1 = "Loading: Selling perks...",
        STATUS_LOAD_PHASE2 = "Loading: Resetting attributes...",
        STATUS_LOAD_PHASE3 = "Loading: Buying perks...",
        STATUS_LOAD_PHASE4 = "Loading: Equipping items...",
        STATUS_LOAD_DONE = "Build '%s' loaded successfully!",
        STATUS_SAVE_DONE = "Build '%s' saved!",
        STATUS_SAVE_ERR = "Error: %s",
        STATUS_PLAYER_ERR = "Error: Player not found",
        STATUS_RESET_DONE = "Attributes and perks reset! Points refunded.",
        STATUS_ATTR_DONE = "Attributes changed.",
        STATUS_PERK_DONE = "Perks changed.",
        STATUS_MONEY_DONE = "Eddies changed.",
        STATUS_LVL_DONE = "Level changed.",
        STATUS_SC_DONE = "Street Cred changed.",
        STATUS_DEL_DONE = "Build deleted.",
        
        HEADER_OPTIONS = " Load Configuration",
        LBL_OPTIONS = "Options:",
        OPT_ATTR = "Attributes",
        OPT_PERK = "Perks",
        OPT_SKILL = "Skills",
        OPT_EQUIP = "Equipment",
        OPT_MONEY = "Money (NG+)",
        OPT_LVL = "Level (NG+)",
        OPT_VEHICLES = "Garage (Cars)",
        
        LBL_MODE = "Mode:",
        MODE_LEGIT = "Legit",
        MODE_LEGIT_TT = "Uses only your current points and inventory items.\nMathematically balances the build for your level.",
        MODE_SANDBOX = "Sandbox",
        MODE_SANDBOX_TT = "Creates missing points and items out of thin air.\nWARNING: Permanently alters your save file!",
        MODE_RENTAL = "Rental",
        MODE_RENTAL_TT = "Grants items temporarily. Created items are destroyed when you switch builds.\nAutosaves are blocked.",
        
        TAB_MY_BUILDS = "My Builds",
        TAB_HISTORY = "History",
        TAB_CHEAT = "Cheat Panel",
        
        LBL_NO_BUILDS = "No saved builds.",
        LBL_BUILD_INFO = "Build:",
        BTN_LOAD = "LOAD BUILD",
        
        CAT_GENERAL = "General",
        CAT_GARAGE = " Garage",
        CAT_ATTR = "Attributes (%s points)",
        CAT_SKILLS = "Skills",
        CAT_WEAPON = "Weapons",
        CAT_CLOTHES = "Clothes",
        CAT_CW = "Cyberware",
        
        NO_PERKS = "No perks",
        NO_SKILLS = "No skills",
        NO_WEAPONS = "No weapons",
        NO_CLOTHES = "No clothes",
        NO_CW = "No cyberware",
        CORRUPTED = "Build data is corrupted or unavailable.",
        
        BTN_DEL = "Delete Build",
        LBL_SELECT_LEFT = "Select a build from the list on the left...",
        
        INPUT_BUILD = "Build Name",
        BTN_SAVE_BUILD = "Save Current Build",
        
        LBL_HISTORY_EMPTY = "History is empty.",
        BTN_HISTORY_LOAD = "Load",
        BTN_HISTORY_DEL = "Delete",
        INPUT_NOTE = "Note",
        BTN_QUICKSAVE = "Quick Save (to History)",
        
        BTN_RESET_ALL = "Full Reset (Attributes & Perks)",
        HDR_CHEAT_PTS = "Skill Points",
        HDR_CHEAT_INV = "Inventory & Levels",
        
        BTN_APPLY = "Apply",
        INP_ATTR = "Attributes (+/-)",
        INP_PERK = "Perks (+/-)",
        INP_MONEY = "Eddies (+/-)",
        INP_LVL = "Level (+/-)",
        INP_SC = "Street Cred (+/-)",
        
        BTN_CLOSE = "CLOSE",
        
        POP_MODE_TITLE = "Warning! Mode Change",
        POP_MODE_DESC1 = "You are about to enable '%s' mode.",
        POP_MODE_DESC2 = "This mode is intended for testing and fun. It may irreversibly change your inventory or perk points!",
        POP_MODE_BTN_YES = "Yes, I understand the risks",
        POP_MODE_BTN_NO = "Cancel",
        
        POP_DEL_TITLE = "Delete Build",
        POP_DEL_DESC1 = "Are you sure you want to permanently delete build:",
        POP_DEL_DESC2 = "This action cannot be undone!",
        POP_DEL_BTN_YES = "Yes, delete",
        
        STATUS = "Status: ",
        WINDOW_TITLE = "CyberBuildManager v1.0 (Neon Edition)",
        
        NATIVE_TITLE = "DATA BANK",
        NATIVE_BTN_OPEN = "[ BUILD MANAGER ]",
        NATIVE_BTN_CLOSE = "CLOSE",
        
        LOC_MONEY = "Eddies: ",
        LOC_LVL = "Level: ",
        LOC_SC = "Street Cred: ",
        LOC_GARAGE = "Cars in garage: ",
        
        LOC_BODY = "Body: ",
        LOC_REFL = "Reflexes: ",
        LOC_TECH = "Tech: ",
        LOC_INT = "Intelligence: ",
        LOC_COOL = "Cool: ",
        
        LOC_BRANCH = "%s tree: %d points",
        LOC_SLOT = "Slot %d: %s",
        
        TXT_AUTOSAVE = "[Autosave] ",
        TXT_MANUAL = "[Manual] ",
        
        TREE_INT = "Intelligence",
        TREE_REFL = "Reflexes",
        TREE_BODY = "Body",
        TREE_TECH = "Tech",
        TREE_COOL = "Cool",
        TREE_OTHER = "Other"
    },
    
    ru = {
        STATUS_WAITING = "Ожидание",
        STATUS_LOAD_PHASE1 = "Загрузка: Продажа перков...",
        STATUS_LOAD_PHASE2 = "Загрузка: Сброс характеристик...",
        STATUS_LOAD_PHASE3 = "Загрузка: Покупка перков...",
        STATUS_LOAD_PHASE4 = "Загрузка: Применение снаряжения...",
        STATUS_LOAD_DONE = "Билд '%s' успешно загружен!",
        STATUS_SAVE_DONE = "Билд '%s' сохранен!",
        STATUS_SAVE_ERR = "Ошибка: %s",
        STATUS_PLAYER_ERR = "Ошибка: Игрок не найден",
        STATUS_RESET_DONE = "Атрибуты и перки сброшены! Очки возвращены.",
        STATUS_ATTR_DONE = "Атрибуты изменены.",
        STATUS_PERK_DONE = "Перки изменены.",
        STATUS_MONEY_DONE = "Эдди изменены.",
        STATUS_LVL_DONE = "Уровень изменен.",
        STATUS_SC_DONE = "Репутация изменена.",
        STATUS_DEL_DONE = "Билд удален.",
        
        HEADER_OPTIONS = " Тонкая настройка загрузки",
        LBL_OPTIONS = "Опции:",
        OPT_ATTR = "Характеристики",
        OPT_PERK = "Перки",
        OPT_SKILL = "Навыки",
        OPT_EQUIP = "Экипировка",
        OPT_MONEY = "Деньги (НГ+)",
        OPT_LVL = "Уровень (НГ+)",
        OPT_VEHICLES = "Гараж (Машины)",
        
        LBL_MODE = "Режим:",
        MODE_LEGIT = "Честный",
        MODE_LEGIT_TT = "Использует только ваши текущие очки и предметы в инвентаре.\nМатематически балансирует билд под ваш уровень.",
        MODE_SANDBOX = "Песочница",
        MODE_SANDBOX_TT = "Создает недостающие очки и предметы из воздуха.\nВНИМАНИЕ: Навсегда меняет ваше сохранение!",
        MODE_RENTAL = "Примерочная",
        MODE_RENTAL_TT = "Выдает предметы на время. При смене билда созданные вещи уничтожаются.\nАвтосохранения блокируются.",
        
        TAB_MY_BUILDS = "Мои Билды",
        TAB_HISTORY = "История",
        TAB_CHEAT = "Чит-Панель",
        
        LBL_NO_BUILDS = "Нет сохраненных билдов.",
        LBL_BUILD_INFO = "Билд:",
        BTN_LOAD = "ЗАГРУЗИТЬ БИЛД",
        
        CAT_GENERAL = "Общее",
        CAT_GARAGE = " Гараж",
        CAT_ATTR = "Характеристики (%s очков)",
        CAT_SKILLS = "Навыки",
        CAT_WEAPON = "Оружие",
        CAT_CLOTHES = "Одежда",
        CAT_CW = "Киберимпланты",
        
        NO_PERKS = "Нет перков",
        NO_SKILLS = "Нет данных",
        NO_WEAPONS = "Без оружия",
        NO_CLOTHES = "Голышом",
        NO_CW = "Чистая органика",
        CORRUPTED = "Данные билда повреждены или недоступны.",
        
        BTN_DEL = "Удалить билд",
        LBL_SELECT_LEFT = "Выберите билд из списка слева...",
        
        INPUT_BUILD = "Имя билда",
        BTN_SAVE_BUILD = "Сохранить текущий билд",
        
        LBL_HISTORY_EMPTY = "История пуста.",
        BTN_HISTORY_LOAD = "Загрузить",
        BTN_HISTORY_DEL = "Удалить",
        INPUT_NOTE = "Заметка",
        BTN_QUICKSAVE = "Быстрое сохранение (в Историю)",
        
        BTN_RESET_ALL = "Полный сброс (Атрибуты и Перки)",
        HDR_CHEAT_PTS = "Очки прокачки",
        HDR_CHEAT_INV = "Инвентарь и Уровни",
        
        BTN_APPLY = "Применить",
        INP_ATTR = "Атрибуты (+/-)",
        INP_PERK = "Перки (+/-)",
        INP_MONEY = "Эдди (+/-)",
        INP_LVL = "Уровень (+/-)",
        INP_SC = "Репутация (+/-)",
        
        BTN_CLOSE = "ЗАКРЫТЬ",
        
        POP_MODE_TITLE = "Внимание! Смена режима",
        POP_MODE_DESC1 = "Вы собираетесь включить режим '%s'.",
        POP_MODE_DESC2 = "Этот режим предназначен для тестов и фана. Он может необратимо изменить инвентарь или ваши очки прокачки!",
        POP_MODE_BTN_YES = "Да, я понимаю риски",
        POP_MODE_BTN_NO = "Отмена",
        
        POP_DEL_TITLE = "Удаление билда",
        POP_DEL_DESC1 = "Вы уверены, что хотите навсегда удалить билд:",
        POP_DEL_DESC2 = "Это действие нельзя отменить!",
        POP_DEL_BTN_YES = "Да, удалить",
        
        STATUS = "Статус: ",
        WINDOW_TITLE = "CyberBuildManager v1.0 (Neon Edition)",
        
        NATIVE_TITLE = "БАНК ДАННЫХ",
        NATIVE_BTN_OPEN = "[ МЕНЕДЖЕР БИЛДОВ ]",
        NATIVE_BTN_CLOSE = "ЗАКРЫТЬ",
        
        LOC_MONEY = "Эдди (Деньги): ",
        LOC_LVL = "Уровень: ",
        LOC_SC = "Репутация: ",
        LOC_GARAGE = "Машин в гараже: ",
        
        LOC_BODY = "Сила: ",
        LOC_REFL = "Реакция: ",
        LOC_TECH = "Техника: ",
        LOC_INT = "Интеллект: ",
        LOC_COOL = "Хладнокровие: ",
        
        LOC_BRANCH = "Ветвь %s: %d очков",
        LOC_SLOT = "Слот %d: %s",
        
        TXT_AUTOSAVE = "[Автосейв] ",
        TXT_MANUAL = "[Вручную] ",
        
        TREE_INT = "Интеллект",
        TREE_REFL = "Реакция",
        TREE_BODY = "Сила",
        TREE_TECH = "Техника",
        TREE_COOL = "Хладнокровие",
        TREE_OTHER = "Другое"
    }
}

function Locales.Get(key, ...)
    local str = Locales.strings[Locales.current][key]
    if not str then str = Locales.strings["en"][key] or key end
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

function Locales.SaveConfig(lang)
    Locales.current = lang
    local file = io.open("builds/_lang.txt", "w")
    if file then
        file:write(lang)
        file:close()
    end
end

function Locales.LoadConfig()
    local file = io.open("builds/_lang.txt", "r")
    if file then
        local lang = file:read("*a")
        if lang == "en" or lang == "ru" then
            Locales.current = lang
        end
        file:close()
    end
end

Locales.LoadConfig()
return Locales
