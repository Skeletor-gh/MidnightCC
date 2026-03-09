local addonName = ...
local strmatch = string.match

MidnightCC = CreateFrame("Frame", addonName .. "Frame")

local Addon = MidnightCC

Addon.defaults = {
    fontName = "Friz Quadrata TT",
    fontSize = 20,
    fontStyle = "outline",
    anchor = "center",
    offsetX = 0,
    offsetY = 0,
}

Addon.fontStyles = {
    normal = {
        label = "Normal",
        flags = "",
        shadow = false,
    },
    outline = {
        label = "Outline",
        flags = "OUTLINE",
        shadow = false,
    },
    shadow = {
        label = "Shadow",
        flags = "",
        shadow = true,
    },
    shadowOutline = {
        label = "Shadow + Outline",
        flags = "OUTLINE",
        shadow = true,
    },
}

Addon.fontStyleOrder = {
    "normal",
    "outline",
    "shadow",
    "shadowOutline",
}

Addon.availableFonts = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\skurri.ttf",
}

Addon.cooldowns = setmetatable({}, { __mode = "k" })
Addon.scanThrottleSeconds = 0.2

Addon.anchorPoints = {
    top = "TOP",
    center = "CENTER",
    bottom = "BOTTOM",
}


local actionButtonNamePatterns = {
    "^ActionButton%d+$",
    "^MultiBarBottomLeftButton%d+$",
    "^MultiBarBottomRightButton%d+$",
    "^MultiBarRightButton%d+$",
    "^MultiBarLeftButton%d+$",
    "^MultiBar5Button%d+$",
    "^MultiBar6Button%d+$",
    "^MultiBar7Button%d+$",
    "^PetActionButton%d+$",
    "^StanceButton%d+$",
    "^PossessButton%d+$",
    "^OverrideActionBarButton%d+$",
    "^ZoneAbilityFrameSpellButton$",
    "^ExtraActionButton%d+$",
}

local blockedFrameNamePatterns = {
    "^NamePlate",
    "NamePlate",
}

local function SafeCall(frame, methodName, ...)
    if not frame then
        return nil
    end

    local method = frame[methodName]

    if type(method) ~= "function" then
        return nil
    end

    local ok, result = pcall(method, frame, ...)

    if not ok then
        return nil
    end

    return result
end

local function IsBlockedFrameName(frameName)
    if not frameName then
        return false
    end

    for _, pattern in ipairs(blockedFrameNamePatterns) do
        if strmatch(frameName, pattern) then
            return true
        end
    end

    return false
end

local function IsBlockedCooldownFrame(frame)
    local current = frame

    while current do
        if SafeCall(current, "IsForbidden") then
            return true
        end

        local currentName = SafeCall(current, "GetName")

        if IsBlockedFrameName(currentName) then
            return true
        end

        local debugName = SafeCall(current, "GetDebugName")

        if IsBlockedFrameName(debugName) then
            return true
        end

        current = SafeCall(current, "GetParent")
    end

    return false
end

local function IsNamedActionButton(frame)
    if not frame or IsBlockedCooldownFrame(frame) then
        return false
    end

    local frameName = SafeCall(frame, "GetName")

    if not frameName then
        return false
    end

    for _, pattern in ipairs(actionButtonNamePatterns) do
        if strmatch(frameName, pattern) then
            return true
        end
    end

    return false
end

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

function Addon:GetFontPath()
    if self.sharedMedia and self.db.fontName then
        local sharedPath = self.sharedMedia:Fetch("font", self.db.fontName, true)

        if sharedPath then
            return sharedPath
        end
    end

    return self.availableFonts[self.db.fontName] or self.availableFonts[self.defaults.fontName] or STANDARD_TEXT_FONT
end

function Addon:GetSortedFontNames()
    local names = {}

    for name in pairs(self.availableFonts) do
        names[#names + 1] = name
    end

    if self.sharedMedia then
        for _, name in ipairs(self.sharedMedia:List("font") or {}) do
            if not self.availableFonts[name] then
                names[#names + 1] = name
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
    local styleKey = self.db.fontStyle or self.defaults.fontStyle
    return self.fontStyles[styleKey] or self.fontStyles[self.defaults.fontStyle]
end

function Addon:ApplyFontToRegion(region, cooldown)
    if not region or region:GetObjectType() ~= "FontString" then
        return
    end

    local fontStyle = self:GetFontStyle()

    region:SetFont(self:GetFontPath(), self.db.fontSize, fontStyle.flags)

    if fontStyle.shadow and region.SetShadowOffset and region.SetShadowColor then
        region:SetShadowOffset(1, -1)
        region:SetShadowColor(0, 0, 0, 1)
    elseif region.SetShadowOffset and region.SetShadowColor then
        region:SetShadowOffset(0, 0)
        region:SetShadowColor(0, 0, 0, 0)
    end

    if cooldown and region.SetPoint and region.ClearAllPoints then
        local anchorPoint = self:GetAnchorPoint()
        region:ClearAllPoints()
        region:SetPoint(anchorPoint, cooldown, anchorPoint, self.db.offsetX or 0, self.db.offsetY or 0)
    end
end

function Addon:IsActionBarCooldown(cooldown)
    if not cooldown or IsBlockedCooldownFrame(cooldown) then
        return false
    end

    local frame = cooldown

    while frame do
        if IsNamedActionButton(frame) then
            return true
        end

        if frame.GetAttribute then
            local actionSlot = SafeCall(frame, "GetAttribute", "action")

            if type(actionSlot) == "number" then
                return true
            end

            if SafeCall(frame, "GetAttribute", "type") == "action" then
                return true
            end
        end

        if type(frame.action) == "number" then
            return true
        end

        frame = SafeCall(frame, "GetParent")
    end

    return false
end

function Addon:ApplyToCooldown(cooldown)
    if not cooldown then
        return
    end

    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(false)
    end

    local regionIndex = 1
    local region = select(regionIndex, cooldown:GetRegions())

    while region do
        self:ApplyFontToRegion(region, cooldown)
        regionIndex = regionIndex + 1
        region = select(regionIndex, cooldown:GetRegions())
    end

    local childIndex = 1
    local child = select(childIndex, cooldown:GetChildren())

    while child do
        if child.GetObjectType and child:GetObjectType() == "FontString" then
            self:ApplyFontToRegion(child, cooldown)
        elseif child.GetRegions then
            local childRegionIndex = 1
            local childRegion = select(childRegionIndex, child:GetRegions())

            while childRegion do
                self:ApplyFontToRegion(childRegion, cooldown)
                childRegionIndex = childRegionIndex + 1
                childRegion = select(childRegionIndex, child:GetRegions())
            end
        end

        childIndex = childIndex + 1
        child = select(childIndex, cooldown:GetChildren())
    end
end

function Addon:RegisterCooldown(cooldown)
    if not cooldown or self.cooldowns[cooldown] or not self:IsActionBarCooldown(cooldown) then
        return
    end

    self.cooldowns[cooldown] = true

    if cooldown.HookScript then
        cooldown:HookScript("OnShow", function(frame)
            Addon:ApplyToCooldown(frame)
        end)
    end

    self:ApplyToCooldown(cooldown)
end

function Addon:ScanCooldownFrames()
    local frame = EnumerateFrames()

    while frame do
        if frame.GetObjectType and frame:GetObjectType() == "Cooldown" and self:IsActionBarCooldown(frame) then
            self:RegisterCooldown(frame)
        end

        frame = EnumerateFrames(frame)
    end
end

function Addon:RequestCooldownScan()
    if self.scanQueued then
        return
    end

    self.scanQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(self.scanThrottleSeconds, function()
            Addon.scanQueued = false
            Addon:ScanCooldownFrames()
        end)
        return
    end

    self.scanQueued = false
    self:ScanCooldownFrames()
end

function Addon:ApplyToKnownCooldowns()
    for cooldown in pairs(self.cooldowns) do
        self:ApplyToCooldown(cooldown)
    end
end

function Addon:RefreshAllCooldowns()
    self:ScanCooldownFrames()
    self:ApplyToKnownCooldowns()
end

function Addon:HookCooldownAPIs()
    if self.cooldownHooksInstalled then
        return
    end

    self.cooldownHooksInstalled = true

    if CooldownFrame_Set then
        hooksecurefunc("CooldownFrame_Set", function(cooldown)
            Addon:RegisterCooldown(cooldown)
        end)
    end

    if CooldownFrame_SetDisplayAsPercentage then
        hooksecurefunc("CooldownFrame_SetDisplayAsPercentage", function(cooldown)
            Addon:RegisterCooldown(cooldown)
        end)
    end
end

function Addon:InitializeDatabase()
    MidnightCCDB = MidnightCCDB or {}
    CopyDefaults(MidnightCCDB, self.defaults)
    self.db = MidnightCCDB
end

function Addon:SetFontName(fontName)
    local isCustomFont = self.availableFonts[fontName]

    if not isCustomFont and self.sharedMedia then
        isCustomFont = self.sharedMedia:Fetch("font", fontName, true)
    end

    if not isCustomFont then
        return
    end

    self.db.fontName = fontName
    self:RefreshAllCooldowns()
end

function Addon:SetAnchor(anchor)
    if not self.anchorPoints[anchor] then
        return
    end

    self.db.anchor = anchor
    self:RefreshAllCooldowns()
end

function Addon:SetFontStyle(styleKey)
    if not self.fontStyles[styleKey] then
        return
    end

    self.db.fontStyle = styleKey
    self:RefreshAllCooldowns()
end

function Addon:InitializeSharedMedia()
    if not LibStub then
        return
    end

    local sharedMedia = LibStub("LibSharedMedia-3.0", true)

    if not sharedMedia then
        return
    end

    self.sharedMedia = sharedMedia

    if sharedMedia.RegisterCallback then
        sharedMedia.RegisterCallback(self, "LibSharedMedia_Registered", function()
            Addon:RefreshAllCooldowns()
        end)
    end
end

function Addon:SetFontSize(fontSize)
    local size = tonumber(fontSize)

    if not size then
        return
    end

    size = math.floor(size + 0.5)
    size = math.max(8, math.min(48, size))

    self.db.fontSize = size
    self:RefreshAllCooldowns()
end

function Addon:SetOffsets(offsetX, offsetY)
    local x = tonumber(offsetX)
    local y = tonumber(offsetY)

    if not x or not y then
        return
    end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)

    x = math.max(-10, math.min(10, x))
    y = math.max(-10, math.min(10, y))

    self.db.offsetX = x
    self.db.offsetY = y
    self:RefreshAllCooldowns()
end

Addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Addon:InitializeDatabase()
        Addon:InitializeSharedMedia()
        Addon:CreateOptionsPanel()
        Addon:RefreshAllCooldowns()
        Addon:HookCooldownAPIs()
        return
    end

    Addon:RequestCooldownScan()
end)

Addon:RegisterEvent("PLAYER_LOGIN")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")
