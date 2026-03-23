cfPowerTicker = {}

local KEYS = {
	ENABLED = "PowerTicker",
	MANA_FULL = "PowerTicker_ManaFull",
	ENERGY_FULL = "PowerTicker_EnergyFull",
}
cfPowerTicker.KEYS = KEYS

local DEFAULTS = {
	[KEYS.ENABLED] = true,
	[KEYS.MANA_FULL] = true,
	[KEYS.ENERGY_FULL] = true,
}

local POWER = { MANA = 0, RAGE = 1, ENERGY = 3 }

local TICK_INTERVAL = 2
local FSR_DURATION = 5

local tickEndTime = 0
local fsrEndTime = 0
local lastPower = 0
local currentPowerType = 0
local spark

local function SetupOverlay()
	local overlayFrame = CreateFrame("Frame", nil, PlayerFrame)
	overlayFrame:SetAllPoints(PlayerFrameManaBar)
	overlayFrame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)

	spark = overlayFrame:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetSize(32, 32)
	spark:SetBlendMode("ADD")
	spark:Hide()

	return overlayFrame
end

local function ShouldShowSpark()
	if currentPowerType == POWER.RAGE then return false end

	local fullPower = UnitPower("player") >= UnitPowerMax("player")

	if fullPower then
		if currentPowerType == POWER.MANA then
			return cfPowerTickerDB[KEYS.MANA_FULL]
		elseif currentPowerType == POWER.ENERGY then
			return cfPowerTickerDB[KEYS.ENERGY_FULL]
		end
		return false
	end

	if currentPowerType == POWER.MANA or currentPowerType == POWER.ENERGY then
		return true
	end

	return false
end

local function OnUpdate()
	if not ShouldShowSpark() then
		spark:Hide()
		return
	end

	local now = GetTime()
	local progress

	if currentPowerType == POWER.MANA and fsrEndTime > now then
		progress = (fsrEndTime - now) / FSR_DURATION
	else
		if tickEndTime <= now then
			local elapsed = (now - tickEndTime) % TICK_INTERVAL
			tickEndTime = now + TICK_INTERVAL - elapsed
		end
		progress = 1 - (tickEndTime - now) / TICK_INTERVAL
	end

	spark:SetPoint("CENTER", PlayerFrameManaBar, "LEFT", PlayerFrameManaBar:GetWidth() * progress, 0)
	spark:Show()
end

local overlayFrame

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "cfPowerTicker" then return end
		self:UnregisterEvent("ADDON_LOADED")

		cfPowerTickerDB = cfPowerTickerDB or {}
		for key, value in pairs(DEFAULTS) do
			if cfPowerTickerDB[key] == nil then
				cfPowerTickerDB[key] = value
			end
		end
		for key in pairs(cfPowerTickerDB) do
			if DEFAULTS[key] == nil then
				cfPowerTickerDB[key] = nil
			end
		end

		if cfPowerTickerDB[KEYS.ENABLED] then
			cfPowerTicker.Enable()
		end
		return
	end

	if event == "UNIT_DISPLAYPOWER" then
		currentPowerType = UnitPowerType("player")
		lastPower = UnitPower("player")
	elseif event == "UNIT_POWER_UPDATE" then
		local now = GetTime()
		local power = UnitPower("player")
		currentPowerType = UnitPowerType("player")

		if power > lastPower then
			local gain = power - lastPower
			if currentPowerType ~= POWER.MANA or gain >= GetManaRegen() * 2 * 0.9 then
				tickEndTime = now + TICK_INTERVAL
			end
		elseif power < lastPower and currentPowerType == POWER.MANA then
			fsrEndTime = now + FSR_DURATION
		end

		lastPower = power
	end
end)
eventFrame:RegisterEvent("ADDON_LOADED")

function cfPowerTicker.Enable()
	if not overlayFrame then
		overlayFrame = SetupOverlay()
	end
	overlayFrame:SetScript("OnUpdate", OnUpdate)
	eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	currentPowerType = UnitPowerType("player")
	lastPower = UnitPower("player")
	tickEndTime = GetTime() + TICK_INTERVAL
end

function cfPowerTicker.Disable()
	eventFrame:UnregisterEvent("UNIT_POWER_UPDATE")
	eventFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
	if overlayFrame then overlayFrame:SetScript("OnUpdate", nil) end
	if spark then spark:Hide() end
end
