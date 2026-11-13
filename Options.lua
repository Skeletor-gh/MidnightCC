local addonName = ...
local Addon = MidnightCC

local COLUMN_WIDTH = 300
local LEFT_X = 16
local RIGHT_X = 350
local SLIDER_WIDTH = 260

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------

local function CreateHeader(parent, text, anchorFrame, x, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetText(text)

    if anchorFrame then
        header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", x or 0, y or -18)
    end

    return header
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateInputBox(parent, width)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetSize(width, 20)
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    return editBox
end

local function CreateDropdown(parent, width, generator)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    dropdown:SetupMenu(generator)
    return dropdown
end

-- Labeled slider built on Blizzard's current MinimalSliderWithSteppers template
-- (OptionsSliderTemplate now lives in DeprecatedTemplates.xml).
local function CreateSlider(parent, label, minValue, maxValue, formatValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(SLIDER_WIDTH, 44)

    container.Label = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    container.Label:SetPoint("TOPLEFT", 0, 0)
    container.Label:SetText(label)

    local slider = CreateFrame("Frame", nil, container, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", container.Label, "BOTTOMLEFT", -4, -2)
    slider:SetWidth(SLIDER_WIDTH - 40)

    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatValue),
    }

    slider:Init(minValue, minValue, maxValue, maxValue - minValue, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        onChange(math.floor(value + 0.5))
    end, container)

    function container:SetValue(value)
        slider:SetValue(value)
    end

    return container
end

local function CreateCheckbox(parent, label, tooltip, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)

    checkbox.Label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkbox.Label:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
    checkbox.Label:SetText(label)

    checkbox:SetScript("OnClick", function(button)
        onClick(button:GetChecked())
    end)

    if tooltip then
        checkbox:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", GameTooltip_Hide)
    end

    return checkbox
end

---------------------------------------------------------------------------
-- Panel construction
---------------------------------------------------------------------------

local function BuildAppearanceColumn(panel, anchor)
    local controls = {}

    local fontHeader = CreateHeader(panel, "Cooldown font", anchor, 0, -24)
    controls.font = CreateDropdown(panel, 220, function(_, root)
        root:SetScrollMode(20 * 14)

        for _, fontName in ipairs(Addon:GetSortedFontNames()) do
            root:CreateRadio(fontName, function(name)
                return Addon.db.fontName == name
            end, function(name)
                Addon:SetFontName(name)
            end, fontName)
        end
    end)
    controls.font:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -6)

    local styleHeader = CreateHeader(panel, "Font format", controls.font)
    controls.style = CreateDropdown(panel, 220, function(_, root)
        for _, styleKey in ipairs(Addon.fontStyleOrder) do
            root:CreateRadio(Addon.fontStyles[styleKey].label, function(key)
                return Addon.db.fontStyle == key
            end, function(key)
                Addon:SetFontStyle(key)
            end, styleKey)
        end
    end)
    controls.style:SetPoint("TOPLEFT", styleHeader, "BOTTOMLEFT", 0, -6)

    local anchorHeader = CreateHeader(panel, "Position on button", controls.style)
    controls.anchor = CreateDropdown(panel, 220, function(_, root)
        for _, anchorKey in ipairs(Addon.anchorOrder) do
            root:CreateRadio(Addon.anchorLabels[anchorKey], function(key)
                return Addon.db.anchor == key
            end, function(key)
                Addon:SetAnchor(key)
            end, anchorKey)
        end
    end)
    controls.anchor:SetPoint("TOPLEFT", anchorHeader, "BOTTOMLEFT", 0, -6)

    local limits = Addon.limits

    controls.size = CreateSlider(panel, "Font size", limits.fontSize.min, limits.fontSize.max, function(value)
        return tostring(math.floor(value + 0.5))
    end, function(value)
        Addon:SetFontSize(value)
    end)
    controls.size:SetPoint("TOPLEFT", controls.anchor, "BOTTOMLEFT", 0, -20)

    local function FormatOffset(value)
        return math.floor(value + 0.5) .. " px"
    end

    controls.offsetX = CreateSlider(panel, "Horizontal offset", limits.offset.min, limits.offset.max, FormatOffset, function(value)
        Addon:SetOffsetX(value)
    end)
    controls.offsetX:SetPoint("TOPLEFT", controls.size, "BOTTOMLEFT", 0, -10)

    controls.offsetY = CreateSlider(panel, "Vertical offset", limits.offset.min, limits.offset.max, FormatOffset, function(value)
        Addon:SetOffsetY(value)
    end)
    controls.offsetY:SetPoint("TOPLEFT", controls.offsetX, "BOTTOMLEFT", 0, -10)

    controls.showNumbers = CreateCheckbox(panel, "Always show cooldown numbers",
        "Shows countdown numbers on action buttons even when Blizzard's \"Show Numbers for Cooldowns\" option (Options > Gameplay > Combat) is off. Untick to follow Blizzard's setting.",
        function(checked)
            Addon:SetShowNumbers(checked)
        end)
    controls.showNumbers:SetPoint("TOPLEFT", controls.offsetY, "BOTTOMLEFT", -4, -14)

    return controls
end

local function BuildPreview(panel, controls)
    local preview = CreateFrame("Frame", nil, panel)
    preview:SetSize(45, 45)

    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetDesaturated(true)
    icon:SetVertexColor(0.6, 0.6, 0.6)

    local text = preview:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(GameFontHighlight)
    text:SetText("12")
    text:SetTextColor(1, 1, 1)

    controls.preview = function()
        Addon:ApplyFontToRegion(text, preview)
    end

    return preview
end

local function BuildPresetColumn(panel, anchor, refreshControls)
    local controls = {}
    local selectedPreset = Addon.db.activePreset

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", anchor, "TOPLEFT", RIGHT_X - LEFT_X, -24)
    header:SetText("Presets")

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetJustifyH("LEFT")
    status:SetWidth(COLUMN_WIDTH)

    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.3, 0.3)
        else
            status:SetTextColor(0.6, 0.9, 0.6)
        end
    end

    controls.presets = CreateDropdown(panel, 220, function(_, root)
        local names = Addon:GetSortedPresetNames()

        if #names == 0 then
            root:CreateTitle("No saved presets yet")
            return
        end

        for _, presetName in ipairs(names) do
            root:CreateRadio(presetName, function(name)
                return selectedPreset == name
            end, function(name)
                selectedPreset = name
                controls.name:SetText(name)
            end, presetName)
        end
    end)
    controls.presets:SetDefaultText("Select a preset")
    controls.presets:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)

    local loadButton = CreateButton(panel, "Load", 70, function()
        if selectedPreset and Addon:LoadPreset(selectedPreset) then
            SetStatus("Loaded \"" .. selectedPreset .. "\".")
        else
            SetStatus("Select a preset to load.", true)
        end
    end)
    loadButton:SetPoint("TOPLEFT", controls.presets, "BOTTOMLEFT", 0, -8)

    local deleteButton = CreateButton(panel, "Delete", 70, function()
        if selectedPreset and Addon:DeletePreset(selectedPreset) then
            SetStatus("Deleted \"" .. selectedPreset .. "\".")
            selectedPreset = nil
            controls.name:SetText("")
            refreshControls()
        else
            SetStatus("Select a preset to delete.", true)
        end
    end)
    deleteButton:SetPoint("LEFT", loadButton, "RIGHT", 6, 0)

    local nameHeader = CreateHeader(panel, "Save current settings as", loadButton, 0, -18)
    controls.name = CreateInputBox(panel, 180)
    controls.name:SetPoint("TOPLEFT", nameHeader, "BOTTOMLEFT", 6, -6)
    controls.name:SetMaxLetters(48)

    local function SaveFromInput()
        local savedName = Addon:SavePreset(controls.name:GetText())

        if savedName then
            selectedPreset = savedName
            controls.name:SetText(savedName)
            controls.name:ClearFocus()
            SetStatus("Saved \"" .. savedName .. "\".")
            refreshControls()
        else
            SetStatus("Enter a preset name first.", true)
        end
    end

    controls.name:SetScript("OnEnterPressed", SaveFromInput)

    local saveButton = CreateButton(panel, "Save", 70, SaveFromInput)
    saveButton:SetPoint("LEFT", controls.name, "RIGHT", 6, 0)

    local ioHeader = CreateHeader(panel, "Import / export string", controls.name, -6, -18)
    controls.io = CreateInputBox(panel, 260)
    controls.io:SetPoint("TOPLEFT", ioHeader, "BOTTOMLEFT", 6, -6)
    controls.io:SetScript("OnEditFocusGained", controls.io.HighlightText)

    local exportButton = CreateButton(panel, "Export", 80, function()
        local source = selectedPreset and Addon:GetPreset(selectedPreset) or Addon.db
        controls.io:SetText(Addon:SerializePreset(source))
        controls.io:SetFocus()
        controls.io:HighlightText()
        SetStatus("Copy the string with Ctrl+C.")
    end)
    exportButton:SetPoint("TOPLEFT", controls.io, "BOTTOMLEFT", -6, -8)

    local importButton = CreateButton(panel, "Import", 80, function()
        local preset = Addon:DeserializePreset(controls.io:GetText())

        if preset then
            Addon:ApplyPresetData(preset, nil)
            selectedPreset = nil
            controls.io:ClearFocus()
            SetStatus("Imported settings. Save them as a preset to keep them.")
        else
            SetStatus("That doesn't look like a MidnightCC string.", true)
        end
    end)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 6, 0)

    status:SetPoint("TOPLEFT", exportButton, "BOTTOMLEFT", 0, -10)

    controls.validateSelection = function()
        if selectedPreset and not Addon:GetPreset(selectedPreset) then
            selectedPreset = nil
        end
    end

    return controls
end

function Addon:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", addonName .. "OptionsPanel")
    panel.name = addonName
    panel:Hide()
    self.optionsPanel = panel

    local controls

    local function RefreshControls()
        if not controls then
            return
        end

        controls.size:SetValue(Addon.db.fontSize)
        controls.offsetX:SetValue(Addon.db.offsetX)
        controls.offsetY:SetValue(Addon.db.offsetY)
        controls.showNumbers:SetChecked(Addon.db.showNumbers)

        controls.validateSelection()

        -- Don't rebuild a menu the user is clicking in; Blizzard updates its
        -- text itself once the click has been handled.
        for _, dropdown in ipairs({ controls.font, controls.style, controls.anchor, controls.presets }) do
            if not dropdown:IsMenuOpen() then
                dropdown:GenerateMenu()
            end
        end

        controls.preview()
    end

    panel:SetScript("OnShow", function(frame)
        if not controls then
            local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", LEFT_X, -16)
            title:SetText("MidnightCC |cff808080v" .. Addon.version .. "|r")

            local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
            subtitle:SetText("Restyles the countdown numbers on your action bars. Cooldown values are never read or compared.")

            controls = BuildAppearanceColumn(frame, subtitle)

            local presetControls = BuildPresetColumn(frame, subtitle, RefreshControls)
            for key, value in pairs(presetControls) do
                controls[key] = value
            end

            local preview = BuildPreview(frame, controls)
            preview:SetPoint("TOPLEFT", controls.io, "BOTTOMLEFT", -6, -110)

            local previewLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            previewLabel:SetPoint("BOTTOMLEFT", preview, "TOPLEFT", 0, 6)
            previewLabel:SetText("Preview")

            local refreshButton = CreateButton(frame, "Refresh Cooldowns", 150, function()
                Addon:RefreshAllCooldowns()
            end)
            refreshButton:SetPoint("TOPLEFT", controls.showNumbers, "BOTTOMLEFT", 4, -16)

            local resetButton = CreateButton(frame, "Reset to Defaults", 150, function()
                Addon:ResetToDefaults()
            end)
            resetButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)
        end

        RefreshControls()
    end)

    -- Keep the panel in sync with changes made through presets or slash commands.
    self.OnSettingsChanged = function()
        if panel:IsShown() then
            RefreshControls()
        end
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.settingsCategoryID = category:GetID()
end
