-- MidnightCC: reskins the countdown numbers on action-bar cooldowns.
-- Only font, style and position are changed. Cooldown values are never read,
-- compared or used for logic, so the addon stays clear of Midnight's secret values.

local addonName = ...

MidnightCC = MidnightCC or {}

local Addon = MidnightCC
Addon.name = addonName
Addon.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

local strmatch = string.match
local floor, max, min = math.floor, math.max, math.min

---------------------------------------------------------------------------
-- Configuration tables
---------------------------------------------------------------------------

Addon.limits = {
    fontSize = { min = 8, max = 48 },
    offset = { min = -10, max = 10 },
}

Addon.defaults = {
    fontName = "Friz Quadrata TT",
    fontSize = 20,
    fontStyle = "outline",
    anchor = "center",
    offsetX = 0,
    offsetY = 0,
    showNumbers = true,
}

Addon.fontStyles = {
    normal = { label = "Normal", flags = "", shadow = false },
    outline = { label = "Outline", flags = "OUTLINE", shadow = false },
    thickOutline = { label = "Thick Outline", flags = "THICKOUTLINE", shadow = false },
    shadow = { label = "Shadow", flags = "", shadow = true },
    shadowOutline = { label = "Shadow + Outline", flags = "OUTLINE", shadow = true },
}

Addon.fontStyleOrder = { "normal", "outline", "thickOutline", "shadow", "shadowOutline" }

Addon.availableFonts = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF",
}

Addon.anchorPoints = {
    top = "TOP",
    center = "CENTER",
    bottom = "BOTTOM",
}

Addon.anchorLabels = {
    top = "Top",
    center = "Center",
    bottom = "Bottom",
}

Addon.anchorOrder = { "top", "center", "bottom" }

-- Fields that make up a preset, and the type each one is stored as.
Addon.presetFields = {
    { key = "fontName", kind = "string" },
    { key = "fontSize", kind = "number" },
    { key = "fontStyle", kind = "string" },
    { key = "anchor", kind = "string" },
    { key = "offsetX", kind = "number" },
    { key = "offsetY", kind = "number" },
    { key = "showNumbers", kind = "boolean" },
}

Addon.scanThrottleSeconds = 0.2

-- Cooldown frames we style, frames we've ruled out, and which style revision
-- each tracked cooldown currently has. All weak-keyed so pooled frames can be collected.
Addon.cooldowns = setmetatable({}, { __mode = "k" })
Addon.rejected = setmetatable({}, { __mode = "k" })
Addon.styled = setmetatable({}, { __mode = "k" })
Addon.styleRevision = 1

---------------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------------

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end

    if canaccessvalue and not canaccessvalue(value) then
        return true
    end

    return false
end

local function SafeCall(object, methodName, ...)
    if type(object) ~= "table" then
        return nil
    end

    local method = object[methodName]

    if type(method) ~= "function" then
        return nil
    end

    local ok, result = pcall(method, object, ...)

    if not ok or IsSecret(result) then
        return nil
    end

    return result
end

local function Trim(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = strmatch(value, "^%s*(.-)%s*$")

    if trimmed == "" then
        return nil
    end

    return trimmed
end

local function ClampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)

    if not number then
        return fallback
    end

    number = floor(number + 0.5)
    return max(minValue, min(maxValue, number))
end

Addon.Trim = Trim
Addon.ClampNumber = ClampNumber

---------------------------------------------------------------------------
-- Action-bar cooldown detection
---------------------------------------------------------------------------

local actionButtonNamePatterns = {
    "^ActionButton%d+$",
    "^MultiBarBottomLeftButton%d+$",
    "^MultiBarBottomRightButton%d+$",
    "^MultiBarRightButton%d+$",
    "^MultiBarLeftButton%d+$",
    "^MultiBar%dButton%d+$",
    "^PetActionButton%d+$",
    "^StanceButton%d+$",
    "^PossessButton%d+$",
    "^OverrideActionBarButton%d+$",
    "^ExtraActionButton%d+$",
    "^ZoneAbilityFrameSpellButton",
}

local function GetMatchableName(frame)
    local name = SafeCall(frame, "GetName")

    if type(name) ~= "string" then
        return nil
    end

    return name
end

local function MatchesAny(name, patterns)
    for index = 1, #patterns do
        if strmatch(name, patterns[index]) then
            return true
        end
    end

    return false
end

-- Nameplates and forbidden frames are off limits: their cooldowns can carry
-- secret values and touching them is what caused taint in early 12.0 builds.
local function IsInBlockedTree(frame)
    local current = frame

    while current do
        if SafeCall(current, "IsForbidden") then
            return true
        end

        local name = GetMatchableName(current)

        if name and strmatch(name, "NamePlate") then
            return true
        end

        current = SafeCall(current, "GetParent")
    end

    return false
end

local function IsActionButton(frame)
    local name = GetMatchableName(frame)

    if name and MatchesAny(name, actionButtonNamePatterns) then
        return true
    end

    -- Third-party bars (Bartender4, Dominos, ElvUI, ...) are secure action
    -- buttons, so they expose an action slot via attributes or a field.
    if type(SafeCall(frame, "GetAttribute", "action")) == "number" then
        return true
    end

    if SafeCall(frame, "GetAttribute", "type") == "action" then
        return true
    end

    local ok, action = pcall(function()
        return frame.action
    end)

    return ok and type(action) == "number" and not IsSecret(action)
end

function Addon:IsActionBarCooldown(cooldown)
    if not cooldown or IsInBlockedTree(cooldown) then
        return false
    end

    local frame = cooldown

    while frame do
        if IsActionButton(frame) then
            return true
        end

        frame = SafeCall(frame, "GetParent")
    end

    return false
end

---------------------------------------------------------------------------
-- Styling
---------------------------------------------------------------------------

function Addon:GetFontPath()
    local fontName = self.db.fontName

    if self.sharedMedia and fontName then
        local sharedPath = self.sharedMedia:Fetch("font", fontName, true)

        if sharedPath then
            return sharedPath
        end
    end

    return self.availableFonts[fontName] or self.availableFonts[self.defaults.fontName] or STANDARD_TEXT_FONT
end

function Addon:GetSortedFontNames()
    local names, seen = {}, {}

    for name in pairs(self.availableFonts) do
        names[#names + 1] = name
        seen[name] = true
    end

    if self.sharedMedia then
        for _, name in ipairs(self.sharedMedia:List("font") or {}) do
            if not seen[name] then
                names[#names + 1] = name
                seen[name] = true
            end
        end
    end

    table.sort(names)
    return names
end

function Addon:GetAnchorPoint()
    return self.anchorPoints[self.db.anchor] or self.anchorPoints[self.defaults.anchor]
end

function Addon:GetFontStyle()
    return self.fontStyles[self.db.fontStyle] or self.fontStyles[self.defaults.fontStyle]
end

local function IsFontString(region)
    return region and SafeCall(region, "GetObjectType") == "FontString"
end

function Addon:ApplyFontToRegion(region, cooldown)
    local fontStyle = self:GetFontStyle()
    local size = self.db.fontSize

    -- SetFont fails (returns false or errors) when the file can't be loaded,
    -- e.g. a SharedMedia font that was uninstalled; fall back to the default font.
    local ok, success = pcall(region.SetFont, region, self:GetFontPath(), size, fontStyle.flags)

    if not ok or not success then
        pcall(region.SetFont, region, STANDARD_TEXT_FONT, size, fontStyle.flags)
    end

    if fontStyle.shadow then
        region:SetShadowOffset(1, -1)
        region:SetShadowColor(0, 0, 0, 1)
    else
        region:SetShadowOffset(0, 0)
        region:SetShadowColor(0, 0, 0, 0)
    end

    local anchorPoint = self:GetAnchorPoint()
    region:ClearAllPoints()
    region:SetPoint(anchorPoint, cooldown, anchorPoint, self.db.offsetX or 0, self.db.offsetY or 0)
end

-- The button's primary cooldown (button.cooldown). Charge and loss-of-control
-- cooldowns are separate frames that Blizzard deliberately keeps number-less.
local function GetOwningButton(cooldown)
    local parent = SafeCall(cooldown, "GetParent")

    if not parent then
        return nil
    end

    local ok, mainCooldown = pcall(function()
        return parent.cooldown
    end)

    if ok and mainCooldown == cooldown then
        return parent
    end

    return nil
end

function Addon:IsMainCooldown(cooldown)
    return GetOwningButton(cooldown) ~= nil
end

local function BlizzardHidesNumbers()
    return not (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("countdownForCooldowns"))
end

function Addon:UpdateCountdownVisibility(cooldown)
    if not self.db.showNumbers or not self:IsMainCooldown(cooldown) then
        return
    end

    cooldown:SetHideCountdownNumbers(false)
end

-- Hands countdown visibility back to Blizzard's "Show numbers for cooldowns" option.
function Addon:RestoreCountdownVisibility()
    local hide = BlizzardHidesNumbers()

    for cooldown in pairs(self.cooldowns) do
        if self:IsMainCooldown(cooldown) then
            cooldown:SetHideCountdownNumbers(hide)
        end
    end
end

-- Returns true when at least one countdown font string was found and styled.
function Addon:ApplyToCooldown(cooldown)
    if not cooldown or not self.db or SafeCall(cooldown, "IsForbidden") then
        return false
    end

    self:UpdateCountdownVisibility(cooldown)

    local styledAny = false
    local regions = { cooldown:GetRegions() }

    for index = 1, #regions do
        local region = regions[index]

        if IsFontString(region) then
            self:ApplyFontToRegion(region, cooldown)
            styledAny = true
        end
    end

    local children = { cooldown:GetChildren() }

    for childIndex = 1, #children do
        local childRegions = { children[childIndex]:GetRegions() }

        for index = 1, #childRegions do
            local region = childRegions[index]

            if IsFontString(region) then
                self:ApplyFontToRegion(region, cooldown)
                styledAny = true
            end
        end
    end

    -- The countdown font string is created lazily by the client, so only mark
    -- the cooldown as done once it actually exists.
    if styledAny then
        self.styled[cooldown] = self.styleRevision
    end

    return styledAny
end

function Addon:RegisterCooldown(cooldown)
    if not cooldown or self.cooldowns[cooldown] then
        return self.cooldowns[cooldown] == true
    end

    if self.rejected[cooldown] then
        return false
    end

    if not self:IsActionBarCooldown(cooldown) then
        self.rejected[cooldown] = true
        return false
    end

    self.cooldowns[cooldown] = true

    cooldown:HookScript("OnShow", function(frame)
        Addon:UpdateCooldown(frame)
    end)

    return true
end

-- Cheap entry point used by hooks: styles a cooldown only if it is an action-bar
-- cooldown that hasn't picked up the current style revision yet.
function Addon:UpdateCooldown(cooldown)
    if not self.db or self.styled[cooldown] == self.styleRevision then
        return
    end

    if self:RegisterCooldown(cooldown) then
        self:ApplyToCooldown(cooldown)
    end
end

function Addon:ScanCooldownFrames()
    -- Frames can be reparented between scans (e.g. bar addons loading late),
    -- so give previously rejected frames another chance.
    wipe(self.rejected)

    local frame = EnumerateFrames()

    while frame do
        if SafeCall(frame, "GetObjectType") == "Cooldown" then
            self:UpdateCooldown(frame)
        end

        frame = EnumerateFrames(frame)
    end
end

function Addon:RequestCooldownScan()
    if self.scanQueued then
        return
    end

    self.scanQueued = true

    C_Timer.After(self.scanThrottleSeconds, function()
        Addon.scanQueued = false
        Addon:ScanCooldownFrames()
    end)
end

-- Called after any setting change: bumps the style revision and restyles the
-- cooldowns we already know about, without rescanning the whole UI.
function Addon:ApplyStyle()
    self.styleRevision = self.styleRevision + 1

    -- Turning "always show numbers" off (directly or via a preset) hands the
    -- countdown visibility back to Blizzard's own setting.
    if self.forcedNumbers and not self.db.showNumbers then
        self:RestoreCountdownVisibility()
    end

    self.forcedNumbers = self.db.showNumbers

    for cooldown in pairs(self.cooldowns) do
        self:ApplyToCooldown(cooldown)
    end

    if self.OnSettingsChanged then
        self:OnSettingsChanged()
    end
end

function Addon:RefreshAllCooldowns()
    self.styleRevision = self.styleRevision + 1
    self:ScanCooldownFrames()

    for cooldown in pairs(self.cooldowns) do
        self:ApplyToCooldown(cooldown)
    end
end

function Addon:HookCooldownAPIs()
    if self.cooldownHooksInstalled then
        return
    end

    self.cooldownHooksInstalled = true

    -- Post-hooking the shared Cooldown widget methods catches every action-bar
    -- cooldown (Blizzard and third-party bars) the moment it starts. Only the
    -- frame is used; the cooldown arguments, which may be secret, are ignored.
    local probe = CreateFrame("Cooldown")
    local methods = getmetatable(probe).__index

    local function OnCooldownSet(cooldown)
        Addon:UpdateCooldown(cooldown)
    end

    for _, methodName in ipairs({
        "SetCooldown",
        "SetCooldownDuration",
        "SetCooldownFromDurationObject",
        "SetCooldownFromExpirationTime",
        "SetCooldownUNIX",
    }) do
        if type(methods[methodName]) == "function" then
            hooksecurefunc(methods, methodName, OnCooldownSet)
        end
    end

    if CooldownFrame_Set then
        hooksecurefunc("CooldownFrame_Set", OnCooldownSet)
    end

    -- Blizzard re-applies its "Show numbers for cooldowns" option whenever that
    -- setting changes or a button is (re)initialised; keep our override on top.
    if ActionButton_UpdateCooldownNumberHidden then
        hooksecurefunc("ActionButton_UpdateCooldownNumberHidden", function(button)
            local cooldown = button and button.cooldown

            if cooldown and Addon.db and Addon.db.showNumbers and Addon.cooldowns[cooldown] then
                cooldown:SetHideCountdownNumbers(false)
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Presets
---------------------------------------------------------------------------

local function EncodePresetValue(value)
    local encoded = tostring(value):gsub("([^%w%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)

    return encoded
end

local function DecodePresetValue(value)
    if type(value) ~= "string" then
        return nil
    end

    local decoded = value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)

    return decoded
end

local function CoerceField(kind, value)
    if kind == "number" then
        return tonumber(value)
    elseif kind == "boolean" then
        if value == true or value == "true" or value == "1" then
            return true
        elseif value == false or value == "false" or value == "0" then
            return false
        end

        return nil
    elseif type(value) == "string" then
        return value
    end

    return nil
end

-- Builds a clean, fully populated preset from any table (db, saved preset or import).
function Addon:SanitizePreset(source)
    local defaults = self.defaults
    local preset = {}

    source = type(source) == "table" and source or {}

    for _, field in ipairs(self.presetFields) do
        local value = CoerceField(field.kind, source[field.key])

        if value == nil then
            value = defaults[field.key]
        end

        preset[field.key] = value
    end

    preset.fontSize = ClampNumber(preset.fontSize, self.limits.fontSize.min, self.limits.fontSize.max, defaults.fontSize)
    preset.offsetX = ClampNumber(preset.offsetX, self.limits.offset.min, self.limits.offset.max, defaults.offsetX)
    preset.offsetY = ClampNumber(preset.offsetY, self.limits.offset.min, self.limits.offset.max, defaults.offsetY)

    if not self.fontStyles[preset.fontStyle] then
        preset.fontStyle = defaults.fontStyle
    end

    if not self.anchorPoints[preset.anchor] then
        preset.anchor = defaults.anchor
    end

    return preset
end

function Addon:ApplyPresetData(presetData, presetName)
    if type(presetData) ~= "table" then
        return false
    end

    local preset = self:SanitizePreset(presetData)

    for _, field in ipairs(self.presetFields) do
        self.db[field.key] = preset[field.key]
    end

    self.db.activePreset = presetName
    self:ApplyStyle()
    return true
end

function Addon:SerializePreset(presetData)
    local preset = self:SanitizePreset(presetData or self.db)
    local segments = {}

    for _, field in ipairs(self.presetFields) do
        segments[#segments + 1] = field.key .. "=" .. EncodePresetValue(preset[field.key])
    end

    return table.concat(segments, ";")
end

function Addon:DeserializePreset(serializedPreset)
    local trimmed = Trim(serializedPreset)

    if not trimmed then
        return nil
    end

    local knownFields = {}

    for _, field in ipairs(self.presetFields) do
        knownFields[field.key] = field.kind
    end

    local raw = {}
    local hasValue = false

    for segment in trimmed:gmatch("([^;]+)") do
        local rawKey, rawValue = segment:match("^([^=]+)=(.*)$")
        local key = Trim(rawKey)
        local kind = key and knownFields[key]

        if kind then
            local value = CoerceField(kind, DecodePresetValue(rawValue))

            if value ~= nil then
                raw[key] = value
                hasValue = true
            end
        end
    end

    if not hasValue then
        return nil
    end

    return self:SanitizePreset(raw)
end

function Addon:SavePreset(name)
    local presetName = Trim(name)

    if not presetName then
        return nil
    end

    self.db.savedPresets[presetName] = self:SanitizePreset(self.db)
    self.db.activePreset = presetName
    return presetName
end

function Addon:GetPreset(name)
    local presetName = Trim(name)
    local savedPreset = presetName and self.db.savedPresets[presetName]

    -- Very early versions stored presets as serialized strings.
    if type(savedPreset) == "string" then
        savedPreset = self:DeserializePreset(savedPreset)
    end

    return savedPreset, presetName
end

function Addon:LoadPreset(name)
    local preset, presetName = self:GetPreset(name)

    if not preset then
        return false
    end

    return self:ApplyPresetData(preset, presetName)
end

function Addon:DeletePreset(name)
    local presetName = Trim(name)

    if not presetName or self.db.savedPresets[presetName] == nil then
        return false
    end

    self.db.savedPresets[presetName] = nil

    if self.db.activePreset == presetName then
        self.db.activePreset = nil
    end

    return true
end

function Addon:GetSortedPresetNames()
    local names = {}

    for presetName in pairs(self.db.savedPresets) do
        names[#names + 1] = presetName
    end

    table.sort(names)
    return names
end

function Addon:ResetToDefaults()
    self:ApplyPresetData(self.defaults, nil)
end

---------------------------------------------------------------------------
-- Setters (used by the options panel and presets)
---------------------------------------------------------------------------

function Addon:IsKnownFont(fontName)
    if type(fontName) ~= "string" then
        return false
    end

    if self.availableFonts[fontName] then
        return true
    end

    return self.sharedMedia and self.sharedMedia:Fetch("font", fontName, true) ~= nil or false
end

local function SetValue(key, value)
    if Addon.db[key] == value then
        return
    end

    Addon.db[key] = value
    Addon.db.activePreset = nil
    Addon:ApplyStyle()
end

function Addon:SetFontName(fontName)
    if self:IsKnownFont(fontName) then
        SetValue("fontName", fontName)
    end
end

function Addon:SetAnchor(anchor)
    if self.anchorPoints[anchor] then
        SetValue("anchor", anchor)
    end
end

function Addon:SetFontStyle(styleKey)
    if self.fontStyles[styleKey] then
        SetValue("fontStyle", styleKey)
    end
end

function Addon:SetFontSize(fontSize)
    if tonumber(fontSize) then
        SetValue("fontSize", ClampNumber(fontSize, self.limits.fontSize.min, self.limits.fontSize.max, self.defaults.fontSize))
    end
end

function Addon:SetOffsetX(offsetX)
    if tonumber(offsetX) then
        SetValue("offsetX", ClampNumber(offsetX, self.limits.offset.min, self.limits.offset.max, 0))
    end
end

function Addon:SetOffsetY(offsetY)
    if tonumber(offsetY) then
        SetValue("offsetY", ClampNumber(offsetY, self.limits.offset.min, self.limits.offset.max, 0))
    end
end

-- Kept for backwards compatibility with anything calling the old API.
function Addon:SetOffsets(offsetX, offsetY)
    self:SetOffsetX(offsetX)
    self:SetOffsetY(offsetY)
end

function Addon:SetShowNumbers(enabled)
    SetValue("showNumbers", enabled and true or false)
end

---------------------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------------------

function Addon:InitializeDatabase()
    local db = type(MidnightCCDB) == "table" and MidnightCCDB or {}

    if type(db.savedPresets) ~= "table" then
        db.savedPresets = {}
    end

    -- Normalise stored settings (also fills in options added in newer versions).
    local preset = self:SanitizePreset(db)

    for _, field in ipairs(self.presetFields) do
        db[field.key] = preset[field.key]
    end

    if db.activePreset ~= nil and (type(db.activePreset) ~= "string" or db.savedPresets[db.activePreset] == nil) then
        db.activePreset = nil
    end

    -- groupProfiles was written by 1.2.x but never used.
    db.groupProfiles = nil
    db.dbVersion = 2

    MidnightCCDB = db
    self.db = db
    self.forcedNumbers = db.showNumbers
end

function Addon:InitializeSharedMedia()
    if self.sharedMedia then
        return
    end

    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

    if not sharedMedia then
        return
    end

    self.sharedMedia = sharedMedia

    -- Restyle only when the font we're using becomes available (e.g. a media
    -- pack that loads after us), not for every piece of media registered.
    sharedMedia.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType, key)
        if mediaType == "font" and Addon.db and key == Addon.db.fontName then
            Addon:ApplyStyle()
        end
    end)
end

function Addon:OpenOptions()
    if Settings and Settings.OpenToCategory and self.settingsCategoryID then
        Settings.OpenToCategory(self.settingsCategoryID)
    end
end

function Addon:Print(message)
    print("|cff8f7cffMidnightCC|r: " .. message)
end

local function HandleSlashCommand(input)
    local command = (Trim(input) or ""):lower()

    if command == "" or command == "config" or command == "options" then
        Addon:OpenOptions()
    elseif command == "refresh" then
        Addon:RefreshAllCooldowns()
        Addon:Print("Cooldown text refreshed.")
    elseif command == "reset" then
        Addon:ResetToDefaults()
        Addon:Print("Settings reset to defaults.")
    else
        Addon:Print("v" .. Addon.version .. " commands:")
        print("  /mcc - open the options panel")
        print("  /mcc refresh - rescan and restyle all action-bar cooldowns")
        print("  /mcc reset - restore default settings")
    end
end

function MidnightCC_OnAddonCompartmentClick()
    Addon:OpenOptions()
end

local eventFrame = CreateFrame("Frame", addonName .. "EventFrame")
Addon.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then
            return
        end

        eventFrame:UnregisterEvent("ADDON_LOADED")
        Addon:InitializeDatabase()
        Addon:InitializeSharedMedia()
        Addon:CreateOptionsPanel()
        Addon:HookCooldownAPIs()

        SLASH_MIDNIGHTCC1 = "/midnightcc"
        SLASH_MIDNIGHTCC2 = "/mcc"
        SlashCmdList.MIDNIGHTCC = HandleSlashCommand
    elseif event == "PLAYER_LOGIN" then
        -- LibSharedMedia may be embedded in an addon that loaded after us.
        Addon:InitializeSharedMedia()
        Addon:RefreshAllCooldowns()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:RequestCooldownScan()
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
