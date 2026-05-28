-- Warriors only use rage (no regen tick); the addon adds nothing for them.
local _, class = UnitClass("player")
if class == "WARRIOR" then return end

local TICK_INTERVAL = 2
local FSR_DURATION = 5

local powerType = UnitPowerType("player")
local lastPower = UnitPower("player")
local tickEndTime = GetTime() + TICK_INTERVAL
local fsrEndTime = 0

local overlay = CreateFrame("Frame", nil, PlayerFrame)
overlay:SetAllPoints(PlayerFrameManaBar)
overlay:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)

local spark = overlay:CreateTexture(nil, "OVERLAY")
spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
spark:SetSize(32, 32)
spark:SetBlendMode("ADD")
spark:Hide()

overlay:SetScript("OnUpdate", function()
    -- Rage: never. Mana: hide at full. Energy: always (rogues/cat — useful even at max).
    if powerType == Enum.PowerType.Rage
       or (powerType == Enum.PowerType.Mana
           and UnitPower("player") >= UnitPowerMax("player")) then
        spark:Hide()
        return
    end

    local now = GetTime()
    -- No UNIT_POWER_UPDATE fires at full energy; re-anchor tickEndTime to the next
    -- 2s boundary so the spark keeps advancing (modulo handles many missed ticks).
    if tickEndTime <= now then
        tickEndTime = now + TICK_INTERVAL - ((now - tickEndTime) % TICK_INTERVAL)
    end

    local progress
    if powerType == Enum.PowerType.Mana and fsrEndTime > now then
        progress = (fsrEndTime - now) / FSR_DURATION
        spark:SetVertexColor(1, 0, 0)
    else
        progress = 1 - (tickEndTime - now) / TICK_INTERVAL
        spark:SetVertexColor(1, 1, 1)
    end

    spark:SetPoint("CENTER", PlayerFrameManaBar, "LEFT", PlayerFrameManaBar:GetWidth() * progress, -1)
    spark:Show()
end)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_DISPLAYPOWER" then
        powerType = UnitPowerType("player")
        lastPower = UnitPower("player")
        return
    end
    -- UNIT_POWER_UPDATE: detect ticks (real out-of-FSR mana ticks deliver ~baseRegen*2;
    -- partial FSR regen falls short of the 0.9 threshold) and cast-driven mana drops.
    local now = GetTime()
    local power = UnitPower("player")
    if power > lastPower then
        local gain = power - lastPower
        if powerType ~= Enum.PowerType.Mana or gain >= GetManaRegen() * TICK_INTERVAL * 0.9 then
            tickEndTime = now + TICK_INTERVAL
        end
    elseif power < lastPower and powerType == Enum.PowerType.Mana then
        fsrEndTime = now + FSR_DURATION
    end
    lastPower = power
end)
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
