-- Minimal WoW API stubs to exercise MidnightCC headlessly (Lua 5.3 via texlua).
local repo = arg[1]
unpack = table.unpack
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameFontHighlight = {}
GameTooltip = setmetatable({}, { __index = function() return function() end end })
GameTooltip_Hide = function() end

local allFrames = {}
local hooks = {}
local cvars = { countdownForCooldowns = false }

C_CVar = { GetCVarBool = function(n) return cvars[n] end }
C_AddOns = { GetAddOnMetadata = function(_, key) if key == "Version" then return "1.3.0" end end }
C_Timer = { After = function(_, fn) fn() end }
issecretvalue = function(v) return type(v) == "table" and v.__secret == true end
canaccessvalue = function(v) return not issecretvalue(v) end

function hooksecurefunc(tbl, name, fn)
    if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
    local orig = tbl[name]
    tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

-- Widget "classes" share a method table per type so metatable hooks work.
local methodTables = {}
local function Methods(objType)
    if methodTables[objType] then return methodTables[objType] end
    local m = {}
    methodTables[objType] = m
    m.GetObjectType = function(self) return self._type end
    m.GetName = function(self) return rawget(self, "_name") end
    m.GetParent = function(self) return rawget(self, "_parent") end
    m.IsForbidden = function(self) return rawget(self, "_forbidden") or false end
    m.GetRegions = function(self) return unpack(self._regions) end
    m.GetChildren = function(self) return unpack(self._children) end
    m.HookScript = function(self, s, f) self._hooks[s] = self._hooks[s] or {} table.insert(self._hooks[s], f) end
    m.SetScript = function(self, s, f) self._scripts[s] = f end
    m.GetScript = function(self, s) return self._scripts[s] end
    m.RegisterEvent = function(self, e) self._events[e] = true end
    m.UnregisterEvent = function(self, e) self._events[e] = nil end
    m.IsShown = function(self) return self._shown end
    m.Show = function(self) self._shown = true if self._scripts.OnShow then self._scripts.OnShow(self) end
        for _, f in ipairs(self._hooks.OnShow or {}) do f(self) end end
    m.Hide = function(self) self._shown = false end
    m.GetAttribute = function(self, k) return self._attr[k] end
    m.CreateFontString = function(self) return NewRegion("FontString", self) end
    m.CreateTexture = function(self) return NewRegion("Texture", self) end
    m.SetHideCountdownNumbers = function(self, v) self.hideNumbers = v end
    m.SetCooldown = function(self) self._cdset = (rawget(self, "_cdset") or 0) + 1 end
    m.SetCooldownFromDurationObject = m.SetCooldown
    m.GetID = function() return 42 end
    m.IsMenuOpen = function() return false end
    m.GetChecked = function(self) return self._checked end
    m.SetChecked = function(self, v) self._checked = v end
    m.GetText = function(self) return self._text end
    m.SetText = function(self, v) self._text = v end
    setmetatable(m, { __index = function() return function() end end })
    return m
end

function NewRegion(objType, parent)
    local r = setmetatable({ _type = objType, _parent = parent, _points = {} }, { __index = Methods("Region" .. objType) })
    local m = Methods("Region" .. objType)
    m.GetObjectType = function(self) return self._type end
    m.SetFont = function(self, path, size, flags)
        if path == "BROKEN" then error("invalid font") end
        self.font = { path, size, flags } return true
    end
    m.SetShadowOffset = function(self, x, y) self.shadow = { x, y } end
    m.ClearAllPoints = function(self) self._points = {} end
    m.SetPoint = function(self, ...) self._points = { ... } end
    if parent and parent._regions then table.insert(parent._regions, r) end
    return r
end

function CreateFrame(objType, name, parent, template)
    local f = setmetatable({ _type = objType, _name = name, _parent = parent, _regions = {}, _children = {},
        _hooks = {}, _scripts = {}, _events = {}, _attr = {}, _shown = true, template = template }, { __index = Methods(objType) })
    if parent then table.insert(parent._children, f) end
    if name then _G[name] = f end
    table.insert(allFrames, f)
    if template == "MinimalSliderWithSteppersTemplate" then
        f.Init = function(self, v) self.value = v end
        f.RegisterCallback = function(self, _, cb) self.cb = cb end
        f.SetValue = function(self, v) if self.value ~= v then self.value = v self.cb(nil, v) end end
    end
    if template == "WowStyle1DropdownTemplate" then
        f.SetupMenu = function(self, g) self.gen = g end
        f.GenerateMenu = function(self)
            local root = setmetatable({ items = {} }, { __index = function() return function() end end })
            root.CreateRadio = function(r, text, isSel, setSel, data) table.insert(r.items, { text = text, isSel = isSel, setSel = setSel, data = data }) end
            root.CreateTitle = function(r, t) table.insert(r.items, { title = t }) end
            self.gen(self, root)
            self.root = root
        end
    end
    return f
end

function EnumerateFrames(prev)
    if not prev then return allFrames[1] end
    for i, f in ipairs(allFrames) do if f == prev then return allFrames[i + 1] end end
end

MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
CreateMinimalSliderFormatter = function(_, fn) return fn end
Settings = {
    RegisterCanvasLayoutCategory = function(panel) return { GetID = function() return 42 end, panel = panel } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) Settings.opened = id end,
}
SlashCmdList = {}
local printed = {}
print = function(...) table.insert(printed, table.concat({ ... }, " ")) end

-- Blizzard-like action button: main cooldown + charge + loss-of-control cooldowns.
local function MakeActionButton(name)
    local button = CreateFrame("CheckButton", name, UIParent)
    button.action = 1
    button.cooldown = CreateFrame("Cooldown", name .. "Cooldown", button)
    button.cooldown.hideNumbers = true -- Blizzard CVar off
    NewRegion("FontString", button.cooldown)
    button.chargeCooldown = CreateFrame("Cooldown", nil, button)
    button.chargeCooldown.hideNumbers = true
    NewRegion("FontString", button.chargeCooldown)
    button.lossOfControlCooldown = CreateFrame("Cooldown", nil, button)
    button.lossOfControlCooldown.hideNumbers = true
    return button
end

function ActionButton_UpdateCooldownNumberHidden(button)
    button.cooldown:SetHideCountdownNumbers(not cvars.countdownForCooldowns)
end

UIParent = CreateFrame("Frame", "UIParent")
local ab1 = MakeActionButton("ActionButton1")
-- third-party bar button (attribute-based detection)
local bt = CreateFrame("CheckButton", "BT4Button7", UIParent)
bt._attr.type = "action"
bt.cooldown = CreateFrame("Cooldown", nil, bt)
NewRegion("FontString", bt.cooldown)
-- nameplate aura cooldown that must be ignored
local np = CreateFrame("Frame", "NamePlate1", UIParent)
local npcd = CreateFrame("Cooldown", nil, CreateFrame("Frame", nil, np))
NewRegion("FontString", npcd)
-- random non-action cooldown (e.g. buff frame)
local buff = CreateFrame("Frame", "BuffFrameAura1", UIParent)
local buffcd = CreateFrame("Cooldown", nil, buff)
NewRegion("FontString", buffcd)

-- v1.2 saved variables, including dead groupProfiles + an out-of-range value
MidnightCCDB = {
    fontName = "Morpheus", fontSize = 200, fontStyle = "bogus", anchor = "top", offsetX = 3, offsetY = -2,
    groupProfiles = { a = "b" }, activePreset = "Gone",
    savedPresets = { Raid = { fontName = "Arial Narrow", fontSize = 14, fontStyle = "shadow", anchor = "bottom", offsetX = 0, offsetY = 0 },
        Legacy = "fontName=Skurri;fontSize=30;fontStyle=outline;anchor=center;offsetX=1;offsetY=1" },
}

local function load(file)
    local chunk = assert(loadfile(repo .. "/" .. file))
    chunk("MidnightCC")
end
load("MidnightCC.lua")
load("Options.lua")

local ev = MidnightCCEventFrame
local onEvent = ev._scripts.OnEvent
onEvent(ev, "ADDON_LOADED", "OtherAddon")
assert(MidnightCC.db == nil, "should ignore other addons' ADDON_LOADED")
onEvent(ev, "ADDON_LOADED", "MidnightCC")
onEvent(ev, "PLAYER_LOGIN")
onEvent(ev, "PLAYER_ENTERING_WORLD")

local A = MidnightCC
local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end io.write("ok  " .. msg .. "\n") end
io.stdout:write("") -- noop

-- migration
check(A.db.fontSize == 48, "font size clamped on migration")
check(A.db.fontStyle == "outline", "invalid style reset")
check(A.db.groupProfiles == nil, "groupProfiles removed")
check(A.db.activePreset == nil, "dangling activePreset cleared")
check(A.db.showNumbers == true, "new showNumbers default filled")

-- detection
check(A.cooldowns[ab1.cooldown], "Blizzard action button cooldown tracked")
check(A.cooldowns[ab1.chargeCooldown], "charge cooldown tracked (styled)")
check(A.cooldowns[bt.cooldown], "third-party attribute-based button tracked")
check(not A.cooldowns[npcd], "nameplate cooldown ignored")
check(not A.cooldowns[buffcd], "non-action cooldown ignored")

-- styling
local fs = ab1.cooldown._regions[1]
check(fs.font and fs.font[1] == "Fonts\\MORPHEUS.TTF" and fs.font[2] == 48, "main countdown font applied")
check(fs._points[1] == "TOP" and fs._points[4] == 3 and fs._points[5] == -2, "anchor + offsets applied")
check(rawget(npcd._regions[1], "font") == nil, "nameplate font untouched")

-- numbers: main forced on, charge/LoC left hidden (the 1.2 double-number bug)
check(ab1.cooldown.hideNumbers == false, "main cooldown numbers forced visible")
check(ab1.chargeCooldown.hideNumbers == true, "charge cooldown numbers stay hidden")
check(ab1.lossOfControlCooldown.hideNumbers == true, "loss-of-control numbers stay hidden")
ActionButton_UpdateCooldownNumberHidden(ab1)
check(ab1.cooldown.hideNumbers == false, "override survives Blizzard CVar refresh")
A:SetShowNumbers(false)
check(ab1.cooldown.hideNumbers == true, "turning option off restores Blizzard CVar state")
ActionButton_UpdateCooldownNumberHidden(ab1)
check(ab1.cooldown.hideNumbers == true, "Blizzard setting respected when option off")
A:SetShowNumbers(true)
check(ab1.cooldown.hideNumbers == false, "turning option back on forces numbers")

-- metatable hook picks up a button created later
local ab2 = MakeActionButton("MultiBar5Button3")
ab2.cooldown:SetCooldown(0, 10)
check(A.cooldowns[ab2.cooldown] and ab2.cooldown._regions[1].font, "late button styled via SetCooldown hook")
local laterNp = CreateFrame("Cooldown", nil, np)
laterNp:SetCooldown(0, 1)
check(A.rejected[laterNp] and not A.cooldowns[laterNp], "nameplate cooldown rejected + cached via hook")

-- live setting change restyles without needing a rescan
A:SetFontSize(12)
check(fs.font[2] == 12 and ab2.cooldown._regions[1].font[2] == 12, "font size change applied to all tracked")
A:SetOffsetX(99)
check(A.db.offsetX == 10, "offset clamped")

-- broken font falls back
A.availableFonts.Broken = "BROKEN"
A:SetFontName("Broken")
check(fs.font[1] == STANDARD_TEXT_FONT, "failing SetFont falls back to default font")
A.availableFonts.Broken = nil
A:SetFontName("Friz Quadrata TT")
A:SetFontName("Not A Font")
check(A.db.fontName == "Friz Quadrata TT", "unknown font rejected")

-- presets
check(A:LoadPreset("Raid") and A.db.fontSize == 14 and A.db.anchor == "bottom", "saved table preset loads")
check(A.db.activePreset == "Raid", "active preset recorded")
A:SetFontSize(15)
check(A.db.activePreset == nil, "manual change clears active preset label")
check(A:LoadPreset("Legacy") and A.db.fontName == "Skurri" and A.db.fontSize == 30, "legacy string preset loads")
check(A:SavePreset("  Mine  ") == "Mine" and A.db.savedPresets.Mine, "save trims name")
local s = A:SerializePreset()
local d = A:DeserializePreset(s)
check(d.fontName == A.db.fontName and d.fontSize == A.db.fontSize and d.showNumbers == true, "export/import round-trip")
local old = A:DeserializePreset("fontName=Arial%20Narrow;fontSize=999;fontStyle=shadow;anchor=nowhere;offsetX=-50;offsetY=2;groupProfiles.x=y")
check(old.fontName == "Arial Narrow" and old.fontSize == 48 and old.anchor == "center" and old.offsetX == -10, "1.2 export string imports + sanitised")
check(A:DeserializePreset("garbage") == nil and A:DeserializePreset("") == nil, "garbage import rejected")
check(A:DeletePreset("Mine") and not A.db.savedPresets.Mine, "delete preset")

-- options panel builds and syncs
local panel = A.optionsPanel
panel:Show()
check(true, "options panel OnShow ran without error")
A:SetFontSize(22)
A:ResetToDefaults()
check(A.db.fontSize == 20 and A.db.fontName == "Friz Quadrata TT", "reset to defaults")

-- slash commands
SlashCmdList.MIDNIGHTCC("")
check(Settings.opened == 42, "/mcc opens settings")
SlashCmdList.MIDNIGHTCC("refresh")
SlashCmdList.MIDNIGHTCC("help")
check(#printed >= 3, "slash refresh/help print output")
MidnightCC_OnAddonCompartmentClick()
check(SLASH_MIDNIGHTCC2 == "/mcc", "addon compartment + /mcc alias registered")

-- panel widgets drive settings
local function find(tpl, pred) for _, f in ipairs(allFrames) do if f.template == tpl and (not pred or pred(f)) then return f end end end
local dd = find("WowStyle1DropdownTemplate")
dd:GenerateMenu()
local picked
for _, it in ipairs(dd.root.items) do if it.text == "Arial Narrow" then it.setSel(it.data) picked = it end end
check(A.db.fontName == "Arial Narrow" and picked.isSel(picked.data), "font dropdown radio sets + reports selection")
local slider = find("MinimalSliderWithSteppersTemplate")
slider.cb(nil, 31.4)
check(A.db.fontSize == 31, "size slider updates setting (rounded)")
check(slider.value == 31 or slider.value == 31.4, "slider synced")
io.write("ALL TESTS PASSED\n")
