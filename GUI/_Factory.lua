local addon = cfPowerTicker

addon.GUI = addon.GUI or {}

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------

function addon.GUI.MakeSettingsPanelDraggable()
	if not SettingsPanel or SettingsPanel.cfDragEnabled then return end
	SettingsPanel.cfDragEnabled = true
	SettingsPanel:SetMovable(true)
	SettingsPanel:EnableMouse(true)
	SettingsPanel:RegisterForDrag("LeftButton")
	SettingsPanel:HookScript("OnDragStart", function(self) self:StartMoving() end)
	SettingsPanel:HookScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
end

----------------------------------------------------------------------
-- Text widgets
----------------------------------------------------------------------

function addon.GUI.Title(panel, text)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 16, -16)
	fs:SetText(text)
	return fs
end

function addon.GUI.Header(panel, anchor, text)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
	fs:SetText(text)
	fs:SetTextColor(1, 0.82, 0)
	return fs
end

function addon.GUI.Note(panel, anchor, text, opts)
	opts = opts or {}
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
	fs:SetText(text)
	if opts.color == "muted" then
		fs:SetTextColor(0.7, 0.7, 0.7)
	elseif opts.color == "warning" then
		fs:SetTextColor(1, 0.4, 0.1)
	end
	return fs
end

----------------------------------------------------------------------
-- Interactive widgets
----------------------------------------------------------------------

local function SetWidgetEnabled(widget, isEnabled)
	if isEnabled then
		widget:Enable()
		if widget.Text then widget.Text:SetTextColor(1, 0.82, 0) end
	else
		widget:Disable()
		if widget.Text then widget.Text:SetTextColor(0.5, 0.5, 0.5) end
	end
end

local function AddTooltip(frame, text)
	if not text then return end
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end

function addon.GUI.Checkbox(panel, anchor, label, key, opts)
	opts = opts or {}
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	if opts.col2 then
		checkbox:SetPoint("TOPLEFT", anchor, "TOPLEFT", opts.col2, 0)
	else
		checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
	end
	checkbox.Text:SetText(label)
	checkbox:SetHitRectInsets(0, -checkbox.Text:GetStringWidth(), 0, 0)

	local gated = opts.classGate

	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(addon.db[key] and true or false)
		if gated then
			SetWidgetEnabled(self, false)
		elseif opts.dependency then
			SetWidgetEnabled(self, opts.dependency:GetChecked())
		end
	end)

	checkbox:SetScript("OnClick", function(self)
		if gated then return end
		local checked = self:GetChecked() and true or false
		addon.db[key] = checked
		if checked then
			if opts.onEnable then opts.onEnable() end
		else
			if opts.onDisable then opts.onDisable() end
		end
	end)

	if opts.dependency then
		local function Sync()
			if gated then return end
			SetWidgetEnabled(checkbox, opts.dependency:GetChecked())
		end
		opts.dependency:HookScript("OnClick", Sync)
		opts.dependency:HookScript("OnShow", Sync)
	end

	AddTooltip(checkbox, opts.tooltip)
	return checkbox
end
