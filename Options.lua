local addonName = ...
local Addon = MidnightCC

local anchorLabels = {
    top = "Top",
    center = "Center",
    bottom = "Bottom",
}

local function GetFontStyleLabel(styleKey)
    local style = Addon.fontStyles and Addon.fontStyles[styleKey]
    return style and style.label or "Outline"
end

local function CreateFontSelector(frame, anchor)
    local selectorButton = CreateFrame("Button", addonName .. "FontSelectorButton", frame, "UIPanelButtonTemplate")
    selectorButton:SetSize(220, 24)
    selectorButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    local listFrame = CreateFrame("Frame", addonName .. "FontSelectorList", frame)
    listFrame:SetSize(248, 170)
    listFrame:SetPoint("TOPLEFT", selectorButton, "BOTTOMLEFT", 0, -2)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:Hide()

    local background = listFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.9)

    local inset = listFrame:CreateTexture(nil, "BORDER")
    inset:SetPoint("TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    local scrollFrame = CreateFrame("ScrollFrame", addonName .. "FontSelectorScroll", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(212, 1)
    scrollFrame:SetScrollChild(content)

    local itemHeight = 20
    local function RefreshList()
        local fonts = Addon:GetSortedFontNames()

        for index, fontName in ipairs(fonts) do
            local button = content.buttons and content.buttons[index]

            if not button then
                content.buttons = content.buttons or {}
                button = CreateFrame("Button", nil, content)
                button:SetSize(212, itemHeight)

                button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                button.text:SetPoint("LEFT", 6, 0)
                button.text:SetPoint("RIGHT", -6, 0)
                button.text:SetJustifyH("LEFT")

                button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
                button.highlight:SetAllPoints()
                button.highlight:SetColorTexture(1, 1, 1, 0.1)

                content.buttons[index] = button
            end

            button:SetPoint("TOPLEFT", 0, -((index - 1) * itemHeight))
            button.text:SetText(fontName)
            button:Show()

            button:SetScript("OnClick", function()
                Addon:SetFontName(fontName)
                selectorButton:SetText(fontName)
                listFrame:Hide()
            end)
        end

        if content.buttons then
            for index = #fonts + 1, #content.buttons do
                content.buttons[index]:Hide()
            end
        end

        content:SetHeight(math.max(#fonts * itemHeight, 1))
    end

    selectorButton:SetText(Addon.db.fontName)
    selectorButton:SetScript("OnClick", function()
        RefreshList()
        listFrame:SetShown(not listFrame:IsShown())
    end)

    frame:SetScript("OnHide", function()
        listFrame:Hide()
    end)

    return selectorButton
end

function Addon:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", addonName .. "OptionsPanel", UIParent)
    panel.name = addonName
    panel:Hide()

    panel:SetScript("OnShow", function(frame)
        if frame.initialized then
            return
        end

        frame.initialized = true

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("MidnightCC")

        local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        subtitle:SetText("Reskin cooldown number fonts only (no cooldown value comparisons).")

        local dropdownLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropdownLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
        dropdownLabel:SetText("Cooldown font")

        local fontSelectorButton = CreateFontSelector(frame, dropdownLabel)

        local fontStyleLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontStyleLabel:SetPoint("TOPLEFT", fontSelectorButton, "BOTTOMLEFT", 0, -24)
        fontStyleLabel:SetText("Cooldown font format")

        local fontStyleDropdown = CreateFrame("Frame", addonName .. "FontStyleDropdown", frame, "UIDropDownMenuTemplate")
        fontStyleDropdown:SetPoint("TOPLEFT", fontStyleLabel, "BOTTOMLEFT", -16, -4)

        UIDropDownMenu_SetWidth(fontStyleDropdown, 180)
        UIDropDownMenu_Initialize(fontStyleDropdown, function()
            for _, styleKey in ipairs(Addon.fontStyleOrder) do
                local styleData = Addon.fontStyles[styleKey]

                if styleData then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = styleData.label
                    info.checked = (Addon.db.fontStyle == styleKey)
                    info.func = function()
                        UIDropDownMenu_SetSelectedName(fontStyleDropdown, styleData.label)
                        Addon:SetFontStyle(styleKey)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)
        UIDropDownMenu_SetSelectedName(fontStyleDropdown, GetFontStyleLabel(Addon.db.fontStyle or Addon.defaults.fontStyle))

        local anchorLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        anchorLabel:SetPoint("TOPLEFT", fontStyleDropdown, "BOTTOMLEFT", 16, -24)
        anchorLabel:SetText("Cooldown anchor")

        local anchorDropdown = CreateFrame("Frame", addonName .. "AnchorDropdown", frame, "UIDropDownMenuTemplate")
        anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -16, -4)

        UIDropDownMenu_SetWidth(anchorDropdown, 140)
        UIDropDownMenu_Initialize(anchorDropdown, function()
            for _, anchor in ipairs({ "top", "center", "bottom" }) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = anchorLabels[anchor]
                info.checked = (Addon.db.anchor == anchor)
                info.func = function()
                    UIDropDownMenu_SetSelectedName(anchorDropdown, anchorLabels[anchor])
                    Addon:SetAnchor(anchor)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(anchorDropdown, anchorLabels[Addon.db.anchor] or anchorLabels.center)

        local slider = CreateFrame("Slider", addonName .. "SizeSlider", frame, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", anchorDropdown, "BOTTOMLEFT", 20, -28)
        slider:SetWidth(280)
        slider:SetMinMaxValues(8, 48)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(Addon.db.fontSize)

        _G[slider:GetName() .. "Low"]:SetText("8")
        _G[slider:GetName() .. "High"]:SetText("48")
        _G[slider:GetName() .. "Text"]:SetText("Cooldown font size: " .. Addon.db.fontSize)

        slider:SetScript("OnValueChanged", function(_, value)
            local rounded = math.floor(value + 0.5)
            _G[slider:GetName() .. "Text"]:SetText("Cooldown font size: " .. rounded)
            Addon:SetFontSize(rounded)
        end)

        local offsetXSlider = CreateFrame("Slider", addonName .. "OffsetXSlider", frame, "OptionsSliderTemplate")
        offsetXSlider:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)
        offsetXSlider:SetWidth(280)
        offsetXSlider:SetMinMaxValues(-10, 10)
        offsetXSlider:SetValueStep(1)
        offsetXSlider:SetObeyStepOnDrag(true)
        offsetXSlider:SetValue(Addon.db.offsetX or 0)

        _G[offsetXSlider:GetName() .. "Low"]:SetText("-10")
        _G[offsetXSlider:GetName() .. "High"]:SetText("10")
        _G[offsetXSlider:GetName() .. "Text"]:SetText("Cooldown X offset: " .. (Addon.db.offsetX or 0) .. "px")

        offsetXSlider:SetScript("OnValueChanged", function(_, value)
            local rounded = math.floor(value + 0.5)
            _G[offsetXSlider:GetName() .. "Text"]:SetText("Cooldown X offset: " .. rounded .. "px")
            Addon:SetOffsets(rounded, Addon.db.offsetY or 0)
        end)

        local offsetYSlider = CreateFrame("Slider", addonName .. "OffsetYSlider", frame, "OptionsSliderTemplate")
        offsetYSlider:SetPoint("TOPLEFT", offsetXSlider, "BOTTOMLEFT", 0, -28)
        offsetYSlider:SetWidth(280)
        offsetYSlider:SetMinMaxValues(-10, 10)
        offsetYSlider:SetValueStep(1)
        offsetYSlider:SetObeyStepOnDrag(true)
        offsetYSlider:SetValue(Addon.db.offsetY or 0)

        _G[offsetYSlider:GetName() .. "Low"]:SetText("-10")
        _G[offsetYSlider:GetName() .. "High"]:SetText("10")
        _G[offsetYSlider:GetName() .. "Text"]:SetText("Cooldown Y offset: " .. (Addon.db.offsetY or 0) .. "px")

        offsetYSlider:SetScript("OnValueChanged", function(_, value)
            local rounded = math.floor(value + 0.5)
            _G[offsetYSlider:GetName() .. "Text"]:SetText("Cooldown Y offset: " .. rounded .. "px")
            Addon:SetOffsets(Addon.db.offsetX or 0, rounded)
        end)

        local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshButton:SetSize(140, 24)
        refreshButton:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", -8, -30)
        refreshButton:SetText("Refresh Cooldowns")
        refreshButton:SetScript("OnClick", function()
            Addon:RefreshAllCooldowns()
        end)
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category

        if Settings.RegisterCanvasLayoutSubcategory and Settings.RegisterVerticalLayoutCategory then
            local parentCategory = Settings.RegisterVerticalLayoutCategory("Skeletor")
            Settings.RegisterAddOnCategory(parentCategory)

            category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name, panel.name)
        else
            category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        end

        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
        self.settingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    SLASH_MIDNIGHTCC1 = "/midnightcc"
    SlashCmdList["MIDNIGHTCC"] = function()
        if Settings and Settings.OpenToCategory and (Addon.settingsCategory or Addon.settingsCategoryID) then
            Settings.OpenToCategory(Addon.settingsCategory or Addon.settingsCategoryID)
            return
        end

        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end
end
