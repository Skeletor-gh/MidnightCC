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

local function GetSortedPresetNames()
    local names = {}

    for presetName in pairs(Addon.db.savedPresets or {}) do
        names[#names + 1] = presetName
    end

    table.sort(names)
    return names
end

local function HasModernDropdown()
    return MenuUtil ~= nil
        and C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil
        and C_XMLUtil.GetTemplateInfo("WowStyle1DropdownTemplate") ~= nil
end

-- Creates a single-choice dropdown using the Blizzard Menu system (WowStyle1DropdownTemplate),
-- falling back to the deprecated UIDropDownMenu API when the modern template is unavailable.
-- options: getEntries() -> { { text, value } }, isSelected(value), onSelect(value), placeholder, emptyText
local function CreateDropdown(name, parent, width, options)
    local dropdown

    if HasModernDropdown() then
        dropdown = CreateFrame("DropdownButton", name, parent, "WowStyle1DropdownTemplate")
        dropdown:SetWidth(width + 30)
        dropdown.leftInset = 0

        if options.placeholder then
            dropdown:SetDefaultText(options.placeholder)
        end

        dropdown:SetupMenu(function(_, rootDescription)
            local entries = options.getEntries()

            if #entries == 0 then
                rootDescription:CreateTitle(options.emptyText or "")
                return
            end

            for _, entry in ipairs(entries) do
                rootDescription:CreateRadio(entry.text, options.isSelected, options.onSelect, entry.value)
            end
        end)

        function dropdown:RefreshSelection()
            self:GenerateMenu()
        end

        return dropdown
    end

    dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown.leftInset = 16
    UIDropDownMenu_SetWidth(dropdown, width)

    function dropdown:RefreshSelection()
        local text = options.placeholder

        for _, entry in ipairs(options.getEntries()) do
            if options.isSelected(entry.value) then
                text = entry.text
                break
            end
        end

        UIDropDownMenu_SetText(self, text or "")
    end

    UIDropDownMenu_Initialize(dropdown, function()
        local entries = options.getEntries()

        if #entries == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = options.emptyText or ""
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end

        for _, entry in ipairs(entries) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.checked = options.isSelected(entry.value)
            info.func = function()
                options.onSelect(entry.value)
                dropdown:RefreshSelection()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return dropdown
end

local function GetSliderLabel(slider, key)
    return slider[key] or _G[slider:GetName() .. key]
end

local function CreateSettingSlider(name, parent, minValue, maxValue, formatLabel, onChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(280)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    GetSliderLabel(slider, "Low"):SetText(tostring(minValue))
    GetSliderLabel(slider, "High"):SetText(tostring(maxValue))

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor(value + 0.5)
        GetSliderLabel(slider, "Text"):SetText(formatLabel(rounded))

        if not slider.isRefreshing then
            onChanged(rounded)
        end
    end)

    function slider:SetSettingValue(value)
        self.isRefreshing = true
        self:SetValue(value)
        GetSliderLabel(self, "Text"):SetText(formatLabel(value))
        self.isRefreshing = false
    end

    return slider
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

    function selectorButton:RefreshSelection()
        self:SetText(Addon.db.fontName)
    end

    selectorButton:RefreshSelection()
    selectorButton:SetScript("OnClick", function()
        RefreshList()
        listFrame:SetShown(not listFrame:IsShown())
    end)

    frame:HookScript("OnHide", function()
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

    local function BuildControls(frame)
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("MidnightCC")

        local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        subtitle:SetText("Reskin cooldown number fonts only (no cooldown value comparisons).")

        local selectedPresetName = Addon.db.activePreset

        local presetLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        presetLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -22)
        presetLabel:SetText("Presets")

        local presetDropdown = CreateDropdown(addonName .. "PresetDropdown", frame, 130, {
            placeholder = "(Select preset)",
            emptyText = "(No presets)",
            getEntries = function()
                local entries = {}

                for _, presetName in ipairs(GetSortedPresetNames()) do
                    entries[#entries + 1] = { text = presetName, value = presetName }
                end

                return entries
            end,
            isSelected = function(presetName)
                return selectedPresetName == presetName
            end,
            onSelect = function(presetName)
                selectedPresetName = presetName
            end,
        })
        presetDropdown:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", -presetDropdown.leftInset, -2)

        local function RefreshPresetDropdownText()
            if not (selectedPresetName and Addon.db.savedPresets and Addon.db.savedPresets[selectedPresetName]) then
                selectedPresetName = nil
            end

            presetDropdown:RefreshSelection()
        end

        local function PromptForPresetName(onConfirm)
            local dialogName = addonName .. "PresetNameDialog"

            StaticPopupDialogs[dialogName] = StaticPopupDialogs[dialogName] or {
                text = "Preset name:",
                button1 = ACCEPT,
                button2 = CANCEL,
                hasEditBox = true,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                OnShow = function(dialog, data)
                    local editBox = dialog.EditBox or dialog.editBox

                    if not editBox then
                        return
                    end

                    editBox:SetText((data and data.defaultName) or "")
                    editBox:SetFocus()
                    editBox:HighlightText()
                end,
                OnAccept = function(dialog, data)
                    local editBox = dialog.EditBox or dialog.editBox
                    local name = editBox and editBox:GetText() or nil

                    if data and data.onConfirm then
                        data.onConfirm(name)
                    end
                end,
                EditBoxOnEnterPressed = function(editBox, data)
                    local dialog = editBox:GetParent()
                    data = data or (dialog and dialog.data)

                    if data and data.onConfirm then
                        data.onConfirm(editBox:GetText())
                    end

                    if dialog then
                        dialog:Hide()
                    end
                end,
                EditBoxOnEscapePressed = function(editBox)
                    local dialog = editBox:GetParent()

                    if dialog then
                        dialog:Hide()
                    end
                end,
            }

            StaticPopup_Show(dialogName, nil, nil, {
                defaultName = selectedPresetName,
                onConfirm = onConfirm,
            })
        end

        local savePresetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        savePresetButton:SetSize(48, 22)
        savePresetButton:SetPoint("LEFT", presetDropdown, "RIGHT", presetDropdown.leftInset > 0 and -2 or 8, presetDropdown.leftInset > 0 and 2 or 0)
        savePresetButton:SetText("Save")
        savePresetButton:SetScript("OnClick", function()
            PromptForPresetName(function(name)
                local savedName = Addon:SavePreset(name)

                if savedName then
                    selectedPresetName = savedName
                    RefreshPresetDropdownText()
                end
            end)
        end)

        local loadPresetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        loadPresetButton:SetSize(48, 22)
        loadPresetButton:SetPoint("LEFT", savePresetButton, "RIGHT", 4, 0)
        loadPresetButton:SetText("Load")
        loadPresetButton:SetScript("OnClick", function()
            if selectedPresetName and Addon:LoadPreset(selectedPresetName) then
                frame:RefreshControls()
            end
        end)

        local deletePresetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        deletePresetButton:SetSize(52, 22)
        deletePresetButton:SetPoint("LEFT", loadPresetButton, "RIGHT", 4, 0)
        deletePresetButton:SetText("Delete")
        deletePresetButton:SetScript("OnClick", function()
            if selectedPresetName and Addon:DeletePreset(selectedPresetName) then
                selectedPresetName = nil
                RefreshPresetDropdownText()
            end
        end)

        local presetIOBox = CreateFrame("EditBox", addonName .. "PresetIOBox", frame, "InputBoxTemplate")
        presetIOBox:SetAutoFocus(false)
        presetIOBox:SetSize(236, 20)
        presetIOBox:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", 4, -46)
        presetIOBox:SetTextInsets(4, 4, 2, 2)
        presetIOBox:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)

        local exportPresetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        exportPresetButton:SetSize(52, 22)
        exportPresetButton:SetPoint("LEFT", presetIOBox, "RIGHT", 6, 0)
        exportPresetButton:SetText("Export")
        exportPresetButton:SetScript("OnClick", function()
            local sourcePreset = Addon.db

            if selectedPresetName and Addon.db.savedPresets and Addon.db.savedPresets[selectedPresetName] then
                sourcePreset = Addon.db.savedPresets[selectedPresetName]
            end

            presetIOBox:SetText(Addon:SerializePreset(sourcePreset))
            presetIOBox:HighlightText()
            presetIOBox:SetFocus()
        end)

        local importPresetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        importPresetButton:SetSize(52, 22)
        importPresetButton:SetPoint("LEFT", exportPresetButton, "RIGHT", 4, 0)
        importPresetButton:SetText("Import")
        importPresetButton:SetScript("OnClick", function()
            local importedPreset = Addon:DeserializePreset(presetIOBox:GetText())

            if importedPreset and Addon:ApplyPresetData(importedPreset, nil) then
                selectedPresetName = nil
                frame:RefreshControls()
            end
        end)

        local dropdownLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropdownLabel:SetPoint("TOPLEFT", presetIOBox, "BOTTOMLEFT", -4, -24)
        dropdownLabel:SetText("Cooldown font")

        local fontSelectorButton = CreateFontSelector(frame, dropdownLabel)

        local fontStyleLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontStyleLabel:SetPoint("TOPLEFT", fontSelectorButton, "BOTTOMLEFT", 0, -24)
        fontStyleLabel:SetText("Cooldown font format")

        local fontStyleDropdown = CreateDropdown(addonName .. "FontStyleDropdown", frame, 180, {
            getEntries = function()
                local entries = {}

                for _, styleKey in ipairs(Addon.fontStyleOrder) do
                    local styleData = Addon.fontStyles[styleKey]

                    if styleData then
                        entries[#entries + 1] = { text = styleData.label, value = styleKey }
                    end
                end

                return entries
            end,
            isSelected = function(styleKey)
                return (Addon.db.fontStyle or Addon.defaults.fontStyle) == styleKey
            end,
            onSelect = function(styleKey)
                Addon:SetFontStyle(styleKey)
            end,
        })
        fontStyleDropdown:SetPoint("TOPLEFT", fontStyleLabel, "BOTTOMLEFT", -fontStyleDropdown.leftInset, -4)

        local anchorLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        anchorLabel:SetPoint("TOPLEFT", fontStyleLabel, "BOTTOMLEFT", 0, -60)
        anchorLabel:SetText("Cooldown anchor")

        local anchorDropdown = CreateDropdown(addonName .. "AnchorDropdown", frame, 140, {
            getEntries = function()
                local entries = {}

                for _, anchor in ipairs({ "top", "center", "bottom" }) do
                    entries[#entries + 1] = { text = anchorLabels[anchor], value = anchor }
                end

                return entries
            end,
            isSelected = function(anchor)
                return (Addon.db.anchor or Addon.defaults.anchor) == anchor
            end,
            onSelect = function(anchor)
                Addon:SetAnchor(anchor)
            end,
        })
        anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -anchorDropdown.leftInset, -4)

        local slider = CreateSettingSlider(addonName .. "SizeSlider", frame, 8, 48, function(value)
            return "Cooldown font size: " .. value
        end, function(value)
            Addon:SetFontSize(value)
        end)
        slider:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 4, -64)

        local offsetXSlider = CreateSettingSlider(addonName .. "OffsetXSlider", frame, -10, 10, function(value)
            return "Cooldown X offset: " .. value .. "px"
        end, function(value)
            Addon:SetOffsets(value, Addon.db.offsetY or 0)
        end)
        offsetXSlider:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)

        local offsetYSlider = CreateSettingSlider(addonName .. "OffsetYSlider", frame, -10, 10, function(value)
            return "Cooldown Y offset: " .. value .. "px"
        end, function(value)
            Addon:SetOffsets(Addon.db.offsetX or 0, value)
        end)
        offsetYSlider:SetPoint("TOPLEFT", offsetXSlider, "BOTTOMLEFT", 0, -28)

        local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshButton:SetSize(140, 24)
        refreshButton:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", -8, -30)
        refreshButton:SetText("Refresh Cooldowns")
        refreshButton:SetScript("OnClick", function()
            Addon:RefreshAllCooldowns()
        end)

        -- Re-sync every control with the saved settings (after a preset load/import or reopening the panel).
        function frame:RefreshControls()
            RefreshPresetDropdownText()
            fontSelectorButton:RefreshSelection()
            fontStyleDropdown:RefreshSelection()
            anchorDropdown:RefreshSelection()
            slider:SetSettingValue(Addon.db.fontSize or Addon.defaults.fontSize)
            offsetXSlider:SetSettingValue(Addon.db.offsetX or 0)
            offsetYSlider:SetSettingValue(Addon.db.offsetY or 0)
        end
    end

    panel:SetScript("OnShow", function(frame)
        if not frame.initialized then
            frame.initialized = true
            BuildControls(frame)
        end

        frame:RefreshControls()
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategoryID = category:GetID()
    end

    SLASH_MIDNIGHTCC1 = "/midnightcc"
    SlashCmdList["MIDNIGHTCC"] = function()
        if Settings and Settings.OpenToCategory and Addon.settingsCategoryID then
            Settings.OpenToCategory(Addon.settingsCategoryID)
        end
    end
end
