local addon = cfPowerTicker

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
	local db = addon.db
	local K = addon.KEYS

	if fullPower then
		if currentPowerType == POWER.MANA then
			return db[K.MANA_FULL]
		elseif currentPowerType == POWER.ENERGY then
			return db[K.ENERGY_FULL]
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
		spark:SetVertexColor(1, 0, 0)
	else
		if tickEndTime <= now then
			local elapsed = (now - tickEndTime) % TICK_INTERVAL
			tickEndTime = now + TICK_INTERVAL - elapsed
		end
		progress = 1 - (tickEndTime - now) / TICK_INTERVAL
		spark:SetVertexColor(1, 1, 1)
	end

	spark:SetPoint("CENTER", PlayerFrameManaBar, "LEFT", PlayerFrameManaBar:GetWidth() * progress, 0)
	spark:Show()
end

local overlayFrame

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "UNIT_DISPLAYPOWER" then
		currentPowerType = UnitPowerType("player")
		lastPower = UnitPower("player")
	elseif event == "UNIT_POWER_UPDATE" then
		local now = GetTime()
		local power = UnitPower("player")

		if power > lastPower then
			local gain = power - lastPower
			if currentPowerType ~= POWER.MANA or gain >= GetManaRegen() * TICK_INTERVAL * 0.9 then
				tickEndTime = now + TICK_INTERVAL
			end
		elseif power < lastPower and currentPowerType == POWER.MANA then
			fsrEndTime = now + FSR_DURATION
		end

		lastPower = power
	end
end)

function addon.Enable()
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

function addon.Disable()
	eventFrame:UnregisterEvent("UNIT_POWER_UPDATE")
	eventFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
	if overlayFrame then overlayFrame:SetScript("OnUpdate", nil) end
	if spark then spark:Hide() end
end
