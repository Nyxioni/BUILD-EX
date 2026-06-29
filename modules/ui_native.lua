local UI = {}
local Locales = require("modules/locales")
local CBM = nil

function UI.Init(mainModule)
    CBM = mainModule
    
    -- Перехватываем ЛЮБОЕ открытое меню игры (гениальная идея!)
    Observe('gameuiMenuGameController', 'OnInitialize', function(this)
        UI.ActiveController = this
        UI.InjectOpenButton(this)
    end)
    
    Observe('gameuiMenuGameController', 'OnUninitialize', function(this)
        UI.ActiveController = nil
    end)
end

function UI.CreateButton(textStr, width, height, onClick, parentController)
    local container = inkCanvas.new()
    container:SetSize(Vector2.new({ X = width, Y = height }))
    container:SetInteractive(true)
    
    local bg = inkRectangle.new()
    bg:SetTintColor(HDRColor.new({ Red = 0.6, Green = 0.0, Blue = 0.0, Alpha = 0.8 }))
    bg:SetAnchor(inkEAnchor.Fill)
    bg:SetSize(Vector2.new({ X = width, Y = height }))
    bg:Reparent(container)
    
    local text = inkText.new()
    text:SetText(textStr)
    text:SetFontFamily("base\\gameplay\\gui\\fonts\\rajdhani\\rajdhani.inkfontfamily")
    text:SetFontStyle(CName.new("Regular"))
    text:SetFontSize(32)
    text:SetTintColor(HDRColor.new({ Red = 1.0, Green = 1.0, Blue = 1.0, Alpha = 1.0 }))
    text:SetAnchor(inkEAnchor.Center)
    text:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    text:Reparent(container)
    
    container:RegisterToCallback("OnHoverOver", function(e)
        bg:SetTintColor(HDRColor.new({ Red = 0.0, Green = 1.0, Blue = 1.0, Alpha = 0.8 }))
        if parentController then parentController:PlaySound("Button", "OnHover") end
    end)
    
    container:RegisterToCallback("OnHoverOut", function(e)
        bg:SetTintColor(HDRColor.new({ Red = 0.6, Green = 0.0, Blue = 0.0, Alpha = 0.8 }))
    end)
    
    container:RegisterToCallback("OnRelease", function(e)
        if e:IsAction('click') then
            if parentController then parentController:PlaySound("Button", "OnPress") end
            onClick()
        end
    end)
    
    return container
end

function UI.InjectOpenButton(controller)
    local root = controller:GetRootCompoundWidget()
    if not root then return end
    
    local button = UI.CreateButton(Locales.Get("NATIVE_BTN_OPEN"), 350, 60, function()
        UI.OpenNativeMenu(controller)
    end, controller)
    
    button:SetAnchor(inkEAnchor.BottomLeft)
    button:SetAnchorPoint(Vector2.new({ X = 0, Y = 1 }))
    button:SetMargin(inkMargin.new({ left = 100, top = 0, right = 0, bottom = 100 }))
    
    button:Reparent(root)
end

function UI.OpenNativeMenu(parentController)
    local root = parentController:GetRootCompoundWidget()
    
    -- Основной контейнер
    local menuRoot = inkCanvas.new()
    menuRoot:SetName(CName.new("CBM_MainMenu"))
    menuRoot:SetSize(Vector2.new({ X = 4000, Y = 4000 })) -- Жесткий размер больше экрана
    menuRoot:SetAnchor(inkEAnchor.Center)
    menuRoot:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    menuRoot:SetInteractive(true) -- Перекрываем клики позади
    
    -- Фон
    local bg = inkRectangle.new()
    bg:SetSize(Vector2.new({ X = 4000, Y = 4000 }))
    bg:SetAnchor(inkEAnchor.Center)
    bg:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    bg:SetTintColor(HDRColor.new({ Red = 0.05, Green = 0.0, Blue = 0.05, Alpha = 0.95 }))
    bg:Reparent(menuRoot)
    
    -- Сетка 3 колонок
    local hPanel = inkHorizontalPanel.new()
    hPanel:SetSize(Vector2.new({ X = 1600, Y = 900 }))
    hPanel:SetAnchor(inkEAnchor.Center)
    hPanel:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    hPanel:SetMargin(inkMargin.new({ left = 0, top = 0, right = 0, bottom = 0 }))
    hPanel:Reparent(menuRoot)
    
    -- Колонка 1: Билды
    local col1 = inkVerticalPanel.new()
    col1:SetMargin(inkMargin.new({ left = 0, top = 0, right = 50, bottom = 0 }))
    local title1 = inkText.new()
    title1:SetText(Locales.Get("NATIVE_TITLE"))
    title1:SetFontFamily("base\\gameplay\\gui\\fonts\\rajdhani\\rajdhani.inkfontfamily")
    title1:SetFontStyle(CName.new("Regular"))
    title1:SetFontSize(50)
    title1:SetTintColor(HDRColor.new({ Red = 1.0, Green = 0.0, Blue = 0.3, Alpha = 1.0 }))
    title1:Reparent(col1)
    
    -- Кнопка закрытия
    local closeBtn = UI.CreateButton(Locales.Get("NATIVE_BTN_CLOSE"), 200, 50, function()
        menuRoot:SetVisible(false)
    end, parentController)
    closeBtn:SetMargin(inkMargin.new({ left = 0, top = 50, right = 0, bottom = 0 }))
    closeBtn:Reparent(col1)
    
    col1:Reparent(hPanel)
    
    -- Прикрепляем к Хабу
    menuRoot:Reparent(root)
end

registerHotkey("cbm_open_native", "Open CyberBuildManager Native UI", function()
    if UI.ActiveController then
        UI.OpenNativeMenu(UI.ActiveController)
        print("[CyberBuildManager] Opened Native UI via Hotkey!")
    else
        print("[CyberBuildManager] You must be in the Hub Menu (Inventory/Map) to open the UI!")
    end
end)

return UI
