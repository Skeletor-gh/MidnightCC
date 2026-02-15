local addonName = ...

MidnightCC = CreateFrame("Frame", addonName .. "Frame")

local Addon = MidnightCC

Addon.defaults = {
    fontName = "Friz Quadrata TT",
    fontSize = 20,
    anchor = "center",
    offsetX = 0,
    offsetY = 0,
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

function Addon:ApplyFontToRegion(region, cooldown)
    if not region or region:GetObjectType() ~= "FontString" then
        return
    end

    region:SetFont(self:GetFontPath(), self.db.fontSize, "OUTLINE")

    if cooldown and region.SetPoint and region.ClearAllPoints then
        local anchorPoint = self:GetAnchorPoint()
        region:ClearAllPoints()
        region:SetPoint(anchorPoint, cooldown, anchorPoint, self.db.offsetX or 0, self.db.offsetY or 0)
    end
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
    if not cooldown or self.cooldowns[cooldown] then
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
        if frame.GetObjectType and frame:GetObjectType() == "Cooldown" then
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
