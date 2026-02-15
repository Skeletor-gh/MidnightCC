local addonName = ...

MidnightCC = CreateFrame("Frame", addonName .. "Frame")

local Addon = MidnightCC

Addon.defaults = {
    fontName = "Friz Quadrata TT",
    fontSize = 20,
}

Addon.availableFonts = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\skurri.ttf",
}

Addon.cooldowns = setmetatable({}, { __mode = "k" })

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

function Addon:GetFontPath()
    return self.availableFonts[self.db.fontName] or self.availableFonts[self.defaults.fontName] or STANDARD_TEXT_FONT
end

function Addon:ApplyFontToRegion(region)
    if not region or region:GetObjectType() ~= "FontString" then
        return
    end

    region:SetFont(self:GetFontPath(), self.db.fontSize, "OUTLINE")
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
        self:ApplyFontToRegion(region)
        regionIndex = regionIndex + 1
        region = select(regionIndex, cooldown:GetRegions())
    end

    local childIndex = 1
    local child = select(childIndex, cooldown:GetChildren())

    while child do
        if child.GetObjectType and child:GetObjectType() == "FontString" then
            self:ApplyFontToRegion(child)
        elseif child.GetRegions then
            local childRegionIndex = 1
            local childRegion = select(childRegionIndex, child:GetRegions())

            while childRegion do
                self:ApplyFontToRegion(childRegion)
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

function Addon:ApplyToKnownCooldowns()
    for cooldown in pairs(self.cooldowns) do
        self:ApplyToCooldown(cooldown)
    end
end

function Addon:RefreshAllCooldowns()
    self:ScanCooldownFrames()
    self:ApplyToKnownCooldowns()
end

function Addon:InitializeDatabase()
    MidnightCCDB = MidnightCCDB or {}
    CopyDefaults(MidnightCCDB, self.defaults)
    self.db = MidnightCCDB
end

function Addon:SetFontName(fontName)
    if not self.availableFonts[fontName] then
        return
    end

    self.db.fontName = fontName
    self:RefreshAllCooldowns()
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

Addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Addon:InitializeDatabase()
        Addon:CreateOptionsPanel()
        Addon:RefreshAllCooldowns()

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
        return
    end

    Addon:ScanCooldownFrames()
end)

Addon:RegisterEvent("PLAYER_LOGIN")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")
Addon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
Addon:RegisterEvent("SPELL_UPDATE_COOLDOWN")
Addon:RegisterEvent("BAG_UPDATE_COOLDOWN")
Addon:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
Addon:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
