local K = cfPowerTicker.KEYS

local panel = CreateFrame("Frame", "cfPowerTickerSettingsPanel")
panel.name = "cfPowerTicker"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("cfPowerTicker")

local TOOLTIPS = {
	[K.ENABLED] = "Show a spark on the mana/energy bar indicating tick timing",
	[K.MANA_FULL] = "Keep the ticker visible when mana is full",
	[K.ENERGY_FULL] = "Keep the ticker visible when energy is full",
}

local function AddTooltip(frame, text)
	if not text then return end
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function CreateCheckbox(anchor, label, dbKey, col2, dependency)
	local parent = anchor:GetParent() or anchor
	local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	if col2 then
		checkbox:SetPoint("TOPLEFT", anchor, "TOPLEFT", col2, 0)
	else
		checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
	end
	checkbox.Text:SetText(label)
	checkbox:SetHitRectInsets(0, -checkbox.Text:GetStringWidth(), 0, 0)
	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(cfPowerTickerDB and cfPowerTickerDB[dbKey])
	end)
	checkbox:SetScript("OnClick", function(self)
		local enabled = self:GetChecked()
		cfPowerTickerDB[dbKey] = enabled
		if dbKey == K.ENABLED then
			if enabled then cfPowerTicker.Enable() else cfPowerTicker.Disable() end
		end
	end)

	if dependency then
		local function UpdateState()
			local active = dependency:GetChecked()
			if active then
				checkbox:Enable()
				checkbox.Text:SetTextColor(1, 0.82, 0)
			else
				checkbox:Disable()
				checkbox.Text:SetTextColor(0.5, 0.5, 0.5)
			end
		end
		dependency:HookScript("OnClick", UpdateState)
		dependency:HookScript("OnShow", UpdateState)
	end

	AddTooltip(checkbox, TOOLTIPS[dbKey])
	return checkbox
end

local powerTicker = CreateCheckbox(title, "Show Power Ticker", K.ENABLED)
local manaFull = CreateCheckbox(powerTicker, "Show at Full Mana", K.MANA_FULL, nil, powerTicker)
local energyFull = CreateCheckbox(manaFull, "Show at Full Energy", K.ENERGY_FULL, 300, powerTicker)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
Settings.RegisterAddOnCategory(category)

SLASH_CFPOWERTICKER1 = "/cfpt"
SlashCmdList["CFPOWERTICKER"] = function()
	Settings.OpenToCategory(category:GetID())
end
