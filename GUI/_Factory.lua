local addon = cfPowerTicker

addon.GUI = addon.GUI or {}

function addon.GUI.MakeSettingsPanelDraggable()
	if not SettingsPanel or SettingsPanel.cfDragEnabled then return end
	SettingsPanel.cfDragEnabled = true
	SettingsPanel:SetMovable(true)
	SettingsPanel:EnableMouse(true)
	SettingsPanel:RegisterForDrag("LeftButton")
	SettingsPanel:HookScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	SettingsPanel:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
end

function addon.GUI.SetCheckboxEnabled(checkbox, enabled)
	if enabled then
		checkbox:Enable()
		checkbox.Text:SetTextColor(1, 0.82, 0)
	else
		checkbox:Disable()
		checkbox.Text:SetTextColor(0.5, 0.5, 0.5)
	end
end

function addon.GUI.AddTooltip(frame, text)
	if not text then return end
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end

function addon.GUI.CreateCheckbox(panel, anchor, label, key, onEnable, onDisable, dependency, col2, tooltip)
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	if col2 then
		checkbox:SetPoint("TOPLEFT", anchor, "TOPLEFT", col2, 0)
	else
		checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
	end
	checkbox.Text:SetText(label)
	checkbox:SetHitRectInsets(0, -checkbox.Text:GetStringWidth(), 0, 0)
	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(addon.db[key])
		if addon.disabledClass then
			addon.GUI.SetCheckboxEnabled(self, false)
		end
	end)
	checkbox:SetScript("OnClick", function(self)
		if addon.disabledClass then return end
		local enabled = self:GetChecked()
		addon.db[key] = enabled
		if enabled then
			if onEnable then onEnable() end
		else
			if onDisable then onDisable() end
		end
	end)

	if dependency then
		local function UpdateState()
			if addon.disabledClass then
				addon.GUI.SetCheckboxEnabled(checkbox, false)
				return
			end
			addon.GUI.SetCheckboxEnabled(checkbox, dependency:GetChecked())
		end
		dependency:HookScript("OnClick", UpdateState)
		dependency:HookScript("OnShow", UpdateState)
	end

	addon.GUI.AddTooltip(checkbox, tooltip)
	return checkbox
end
