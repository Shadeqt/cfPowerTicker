-- Druid form mana bar + mana ticker (merged from the old cfDruidBar addon).
-- While shapeshifted the displayed power is energy/rage, so the main ticker can't show
-- mana regen. For druids we add a secondary bar carrying the hidden mana pool (shown
-- only in forms), plus its own spark driven off the MANA pool:
--   • red FSR countdown  → both forms
--   • white 2s mana tick → bear only (in cat the energy spark already marks the shared
--                          tick boundary), and only until mana is full
local _, addon = ...
if not addon.active or addon.class ~= "DRUID" then return end

local clock = addon.clock
local MANA = Enum.PowerType.Mana

local manaLast = UnitPower("player", MANA)

-- Build the secondary form-mana bar: a mana-pool StatusBar tucked under the player mana
-- bar, with its own dark backing, border, and the Left/Center/Right text Blizzard drives.
local function CreateBar()
    local bar = CreateFrame("StatusBar", nil, PlayerFrame)
    bar:SetPoint("TOPLEFT", PlayerFrameManaBar, "BOTTOMLEFT", 1, -2)
    bar:SetPoint("TOPRIGHT", PlayerFrameManaBar, "BOTTOMRIGHT", 1, -2)  -- width follows the mana bar
    bar:SetHeight(PlayerFrameManaBar:GetHeight())
    bar:SetFrameLevel(PlayerFrame:GetFrameLevel() - 1)  -- behind the frame, so its border tucks over our top edge

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.5)  -- our bar's own dark backing

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", bar, -3, 2)       -- frame the bar just outside its edges
    border:SetPoint("BOTTOMRIGHT", bar, 3, -2)
    border:SetBackdrop({
        edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
        edgeSize = 8 })
    bar.border = border

    -- Parented to border (a frame level above bar) so text draws OVER the border edge.
    bar.LeftText = border:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.LeftText:SetPoint("LEFT", bar, "LEFT", 3, 0)
    bar.TextString = border:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.TextString:SetPoint("CENTER", bar)
    bar.RightText = border:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.RightText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)

    return bar
end

local bar = CreateBar()
local border = bar.border

-- Mirror the player MANA bar's texture, then re-apply mana color (SetStatusBarTexture clears it).
local function SyncTexture()
    bar:SetStatusBarTexture(PlayerFrameManaBar:GetStatusBarTexture():GetTexture())
    local manaColor = PowerBarColor[MANA]
    bar:SetStatusBarColor(manaColor.r, manaColor.g, manaColor.b)
end
local function SyncBorderColor()
    border:SetBackdropBorderColor(PlayerFrameTexture:GetVertexColor())
end

-- Our own spark on the druid bar. Red FSR in both forms; white mana tick in bear only
-- (cat's energy spark already marks the shared tick) and only until mana is full.
local manaOverlay = addon.NewTickSpark(bar, function(now)
    local fsr = addon.FsrProgress(now)
    if fsr then return fsr, true end                             -- red FSR countdown, both forms
    if UnitPowerType("player") == Enum.PowerType.Rage
        and UnitPower("player", MANA) < UnitPowerMax("player", MANA) then
        return clock:TickProgress(now), false                    -- white mana tick, bear only, until full
    end
    return nil                                                   -- cat post-FSR / full mana: nothing to draw
end)

-- Render the bar's text via Blizzard's updater. lockShow forces text past the statusText
-- gate, and Blizzard groups NONE in with NUMERIC — so honor NONE ourselves by hiding,
-- matching what every other status-text bar in the UI does.
local function UpdateText(self)
    if not self:IsShown() then return end   -- the updater would Show() the bar otherwise
    if GetCVar("statusTextDisplay") == "NONE" then
        self.TextString:Hide()
        self.LeftText:Hide()
        self.RightText:Hide()
    else
        TextStatusBar_UpdateTextString(self)
    end
end

local function DruidOnEvent(self, event, arg1, arg2)
    if event == "UNIT_POWER_UPDATE" then
        if arg2 ~= "MANA" then return end                          -- arg2 = power type
        -- A real mana-pool gain anchors the shared tick clock (FSR is watched in Core).
        local mana = UnitPower("player", MANA)
        addon.NoteGain(GetTime(), mana, manaLast, true)
        manaLast = mana
        if self:IsShown() then self:SetValue(mana) end
    elseif event == "CVAR_UPDATE" then
        if arg1 ~= "statusText" and arg1 ~= "statusTextDisplay" then return end  -- arg1 = cvar name
        self.lockShow = C_CVar.GetCVarBool("statusText") and 1 or 0  -- status-text cvar changed: refresh the text gate
    else
        self.lockShow = C_CVar.GetCVarBool("statusText") and 1 or 0  -- Blizzard's text gate checks lockShow > 0
        manaLast = UnitPower("player", MANA)
        self:SetMinMaxValues(0, UnitPowerMax("player", MANA))
        self:SetValue(manaLast)
        local show = UnitPowerMax("player", MANA) > 0 and UnitPowerType("player") ~= MANA
        self:SetShown(show)         -- show the bar (and run its OnUpdate) only while in a non-mana form
        manaOverlay:SetShown(show)
    end
    UpdateText(self)
end

SyncTexture()
SyncBorderColor()
hooksecurefunc(PlayerFrameManaBar, "SetStatusBarTexture", SyncTexture)
hooksecurefunc(PlayerFrameTexture, "SetVertexColor", SyncBorderColor)

bar:Hide()
manaOverlay:Hide()
bar:SetScript("OnEvent", DruidOnEvent)
bar:RegisterEvent("PLAYER_ENTERING_WORLD")
bar:RegisterEvent("CVAR_UPDATE")                              -- react to the statusText toggle, like Blizzard's bars
bar:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
bar:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
DruidOnEvent(bar, "PLAYER_ENTERING_WORLD")
