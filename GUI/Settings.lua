local K = cfPowerTicker.KEYS
local disabledClass = cfPowerTicker.disabledClass
local factory = cfPowerTicker.GUI

local panel = CreateFrame("Frame", "cfPowerTickerSettingsPanel")
panel.name = "cfPowerTicker"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("cfPowerTicker")

local unsupportedText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
unsupportedText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
unsupportedText:SetText("Unavailable for warriors")
unsupportedText:SetTextColor(0.7, 0.7, 0.7)
unsupportedText:SetShown(disabledClass)

local TOOLTIPS = {
	[K.ENABLED] = "Show a spark on the mana/energy bar indicating tick timing",
	[K.MANA_FULL] = "Keep the ticker visible when mana is full",
	[K.ENERGY_FULL] = "Keep the ticker visible when energy is full",
}

local firstAnchor = disabledClass and unsupportedText or title
local powerTicker = factory.CreateCheckbox(panel, firstAnchor, "Show Power Ticker", K.ENABLED, cfPowerTicker.Enable, cfPowerTicker.Disable, nil, nil, TOOLTIPS[K.ENABLED])
local manaFull = factory.CreateCheckbox(panel, powerTicker, "Show at Full Mana", K.MANA_FULL, nil, nil, powerTicker, nil, TOOLTIPS[K.MANA_FULL])
local energyFull = factory.CreateCheckbox(panel, manaFull, "Show at Full Energy", K.ENERGY_FULL, nil, nil, powerTicker, 300, TOOLTIPS[K.ENERGY_FULL])

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
Settings.RegisterAddOnCategory(category)

panel:SetScript("OnShow", factory.MakeSettingsPanelDraggable)

SLASH_CFPOWERTICKER1 = "/cfpt"
SlashCmdList["CFPOWERTICKER"] = function()
	Settings.OpenToCategory(category:GetID())
end
