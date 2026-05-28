local addon = cfPowerTicker
local K = addon.KEYS
local F = addon.GUI

local TOOLTIPS = {
	[K.ENABLED]     = "Show a spark on the mana/energy bar indicating tick timing",
	[K.MANA_FULL]   = "Keep the ticker visible when mana is full",
	[K.ENERGY_FULL] = "Keep the ticker visible when energy is full",
}

function addon.InitSettings()
	local panel = CreateFrame("Frame", "cfPowerTickerSettingsPanel")
	panel.name = "cfPowerTicker"
	panel:Hide()

	local title = F.Title(panel, "cfPowerTicker")

	local anchor = title
	if addon.disabledClass then
		anchor = F.Note(panel, title, "Unavailable for warriors", { color = "muted" })
	end

	local powerTicker = F.Checkbox(panel, anchor, "Show Power Ticker", K.ENABLED, {
		onEnable = addon.Enable, onDisable = addon.Disable,
		tooltip = TOOLTIPS[K.ENABLED],
		classGate = addon.disabledClass,
	})
	local manaFull = F.Checkbox(panel, powerTicker, "Show at Full Mana", K.MANA_FULL, {
		dependency = powerTicker,
		tooltip = TOOLTIPS[K.MANA_FULL],
		classGate = addon.disabledClass,
	})
	F.Checkbox(panel, manaFull, "Show at Full Energy", K.ENERGY_FULL, {
		dependency = powerTicker,
		tooltip = TOOLTIPS[K.ENERGY_FULL],
		classGate = addon.disabledClass,
		col2 = 300,
	})

	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
	Settings.RegisterAddOnCategory(category)

	panel:SetScript("OnShow", F.MakeSettingsPanelDraggable)
end
