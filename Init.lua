cfPowerTicker = cfPowerTicker or {}
local addon = cfPowerTicker

local _, class = UnitClass("player")
addon.disabledClass = class == "WARRIOR"

addon.KEYS = {
	ENABLED = "PowerTicker",
	MANA_FULL = "PowerTicker_ManaFull",
	ENERGY_FULL = "PowerTicker_EnergyFull",
}

local defaults = {
	[addon.KEYS.ENABLED] = true,
	[addon.KEYS.MANA_FULL] = true,
	[addon.KEYS.ENERGY_FULL] = true,
}

cfPowerTickerDB = cfPowerTickerDB or {}
for key, value in pairs(defaults) do
	if cfPowerTickerDB[key] == nil then
		cfPowerTickerDB[key] = value
	end
end
for key in pairs(cfPowerTickerDB) do
	if defaults[key] == nil then
		cfPowerTickerDB[key] = nil
	end
end

addon.db = cfPowerTickerDB

EventUtil.ContinueOnAddOnLoaded("cfPowerTicker", function()
	if not addon.disabledClass and addon.db[addon.KEYS.ENABLED] then
		addon.Enable()
	end
end)
