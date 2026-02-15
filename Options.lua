local addonName = ...
local Addon = MidnightCC

local anchorLabels = {
    top = "Top",
    center = "Center",
    bottom = "Bottom",
}

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

        local dropdown = CreateFrame("Frame", addonName .. "FontDropdown", frame, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", dropdownLabel, "BOTTOMLEFT", -16, -4)

        UIDropDownMenu_SetWidth(dropdown, 220)
        UIDropDownMenu_Initialize(dropdown, function()
            for _, fontName in ipairs(Addon:GetSortedFontNames()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = fontName
                info.checked = (Addon.db.fontName == fontName)
                info.func = function()
                    UIDropDownMenu_SetSelectedName(dropdown, fontName)
                    Addon:SetFontName(fontName)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(dropdown, Addon.db.fontName)

        local anchorLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        anchorLabel:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -24)
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

        local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshButton:SetSize(140, 24)
        refreshButton:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -8, -28)
        refreshButton:SetText("Refresh Cooldowns")
        refreshButton:SetScript("OnClick", function()
            Addon:RefreshAllCooldowns()
        end)
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    SLASH_MIDNIGHTCC1 = "/midnightcc"
    SlashCmdList["MIDNIGHTCC"] = function()
        if Settings and Settings.OpenToCategory and Addon.settingsCategoryID then
            Settings.OpenToCategory(Addon.settingsCategoryID)
            return
        end

        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end
end
