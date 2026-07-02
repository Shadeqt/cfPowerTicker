-- cfPowerTicker: a spark on the player's mana/energy power bar marking each 2s regen tick, plus a
-- red five-second-rule countdown for mana users. Two OPTIONAL warnings (energy overcap-snap purple,
-- bad-clip yellow) are isolated in clearly-marked blocks below and can be removed without touching
-- the core. Single file; warriors (rage only, no regen tick) early-return and allocate nothing.
local _, class = UnitClass("player")
if class == "WARRIOR" then return end

local TICK_INTERVAL = 2
local FSR_DURATION  = 5

-- The 2s regen-tick clock, held as a single boundary timestamp. Energy and mana tick on the same
-- server boundary, so this one value drives the spark for whichever power is displayed. It is read
-- and re-anchored inline by the spark's OnUpdate (at full power, where no event fires) and bumped by
-- a real regen gain in the event handler.
local tickEnd = GetTime() + TICK_INTERVAL

-- The five-second-rule window. FSR is a property of the MANA POOL alone — it does not depend on which
-- power is currently displayed — so it is detected once, off the pool itself. (Reading the mana pool
-- directly keeps FSR correct across shapeshifts, unlike displayed-power tracking, which went blind to
-- mana spent while energy/rage was shown.) `fsrEnd` is the window's end time; the spark reads it inline.
local MANA = Enum.PowerType.Mana
local fsrEnd = 0
local fsrManaLast = UnitPower("player", MANA)
local fsrWatcher = CreateFrame("Frame")
fsrWatcher:SetScript("OnEvent", function(_, _, _, powerToken)
    if powerToken ~= "MANA" then return end
    local mana = UnitPower("player", MANA)
    if mana < fsrManaLast then
        fsrEnd = GetTime() + FSR_DURATION
    end
    fsrManaLast = mana
end)
fsrWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")

-- Spark line colors borrowed from class colors so they track the client: FSR = Death Knight red,
-- regen tick = Priest white. CLIP_C (Druid orange) is used only by the optional bad-clip block.
local CC     = RAID_CLASS_COLORS
local FSR_C  = CC.DEATHKNIGHT
local TICK_C = CC.PRIEST
local CLIP_C = CC.DRUID

local powerType = UnitPowerType("player")
local lastPower = UnitPower("player")
local badClip   = false   -- set by the optional bad-clip block below; stays false if that block is removed

-- =====================================================================================================
-- OPTIONAL FEATURE — energy overcap-snap warning.
-- While displaying energy with an ATTACKABLE TARGET, snap the power bar to Demon Hunter fel-purple for
-- the back half of a tick once a +20 regen tick would overcap (current > max - 20), so you can spend
-- before the tick is wasted; it snaps back to the normal energy color otherwise. The target gate keeps
-- it quiet while idle (nothing to spend on). Rides the spark's existing per-frame loop (no extra frame).
-- TO DISABLE: comment the EnergyOvercapWarn(progress) call in the spark OnUpdate below.
local ENERGY   = Enum.PowerType.Energy
local ENERGY_C = PowerBarColor[ENERGY]   -- the canonical Blizzard energy color
local WARN_C   = CC.DEMONHUNTER          -- fel-purple
local function EnergyOvercapWarn(progress)
    if powerType ~= ENERGY then return end
    -- order cheap→costly: UnitCanAttack only runs in the back half of a tick at high energy.
    local warn = progress >= 0.5 and UnitPower("player") > UnitPowerMax("player") - 20
        and UnitCanAttack("player", "target")
    local c = warn and WARN_C or ENERGY_C
    PlayerFrameManaBar:SetStatusBarColor(c.r, c.g, c.b)
end
-- =====================================================================================================

-- =====================================================================================================
-- OPTIONAL FEATURE — bad-clip yellow warning.
-- Mana is spent (and FSR starts) when a cast COMPLETES, so the efficient play is to bank a regen tick
-- in the last 0.5s before completion. On cast start, project the cast's end onto the tick clock; if it
-- lands >0.5s past the boundary, the cast wastes the tick → flag badClip (the spark draws it CLIP_C
-- orange; FSR red still takes priority). Gated to MANA-COST casts only (CostsMana, the block's own
-- helper). TO DISABLE: delete this whole block — badClip stays false and the spark never draws orange.
local GetSpellPowerCost = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
local function CostsMana(spellID)
    if not spellID or not GetSpellPowerCost then return false end
    local costs = GetSpellPowerCost(spellID)
    if not costs then return false end
    for _, cost in ipairs(costs) do
        if cost.type == MANA and cost.cost > 0 then
            return true
        end
    end
    return false
end

local casts = CreateFrame("Frame")
casts:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_START" then
        badClip = false
        local _, _, _, _, endTimeMS = UnitCastingInfo("player")
        if endTimeMS and CostsMana(spellID) then
            local castEnd = endTimeMS / 1000               -- GetTime()-based seconds
            local gap = (castEnd - tickEnd) % TICK_INTERVAL
            badClip = gap > 0.5
        end
    else
        badClip = false                                    -- STOP / FAILED / INTERRUPTED
    end
end)
casts:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
casts:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
casts:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
casts:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
-- =====================================================================================================

-- Whether the spark has anything to draw right now. Rage: never. Mana: not at full. Energy: always
-- (no event fires at full energy, so the loop must keep running to re-anchor the tick itself).
local function shouldAnimate()
    if powerType == Enum.PowerType.Rage then
        return false
    end
    if powerType == MANA then
        return UnitPower("player") < UnitPowerMax("player")
    end
    return true
end

-- The spark: a 2px white line + casting-bar glow on a "mark" frame that slides across the power bar.
-- Anchoring line and glow to `mark` lets one SetPoint move them together; only color is set per-texture
-- (vertex color doesn't inherit). Visibility (SetShown, below) gates the OnUpdate, so it only runs when
-- there is something to draw — a hidden frame's OnUpdate never fires, so parking it costs zero CPU.
local overlay = CreateFrame("Frame", nil, PlayerFrameManaBar)
overlay:SetAllPoints(PlayerFrameManaBar)
overlay:SetFrameLevel(PlayerFrameManaBar:GetFrameLevel() + 10)

local mark = CreateFrame("Frame", nil, overlay)
mark:SetWidth(2)
local line = mark:CreateTexture(nil, "OVERLAY")
line:SetColorTexture(1, 1, 1, 1)
line:SetAllPoints(mark)
local glow = mark:CreateTexture(nil, "OVERLAY")
glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
glow:SetSize(32, 32)
glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", mark, "CENTER")

overlay:SetScript("OnUpdate", function()
    local now = GetTime()
    -- Re-anchor at full power, where no event fires; the modulo absorbs many missed ticks at once.
    if tickEnd <= now then
        tickEnd = now + TICK_INTERVAL - ((now - tickEnd) % TICK_INTERVAL)
    end

    -- Mana users inside the five-second rule get the red FSR countdown (sweeps right→left); everyone
    -- else gets the white 2s tick sweep (left→right), recolored orange if the optional bad-clip block
    -- flagged a wasted tick.
    local progress, color
    if powerType == MANA and fsrEnd > now then
        progress, color = (fsrEnd - now) / FSR_DURATION, FSR_C
    else
        progress = 1 - (tickEnd - now) / TICK_INTERVAL
        EnergyOvercapWarn(progress)                 -- OPTIONAL: comment out to disable energy overcap-snap
        color = badClip and CLIP_C or TICK_C
    end

    local x = PlayerFrameManaBar:GetWidth() * progress
    mark:ClearAllPoints()
    mark:SetPoint("TOP", PlayerFrameManaBar, "TOPLEFT", x, 0)
    mark:SetPoint("BOTTOM", PlayerFrameManaBar, "BOTTOMLEFT", x, 0)
    line:SetVertexColor(color.r, color.g, color.b)
    glow:SetVertexColor(color.r, color.g, color.b)
    mark:Show()
end)

-- Start in the correct state instead of waiting for the first event (e.g. a full-mana caster logs in
-- parked; an energy user logs in running).
overlay:SetShown(shouldAnimate())

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_DISPLAYPOWER" then
        powerType = UnitPowerType("player")
        lastPower = UnitPower("player")
        overlay:SetShown(shouldAnimate())
        return
    end
    -- UNIT_POWER_UPDATE / UNIT_MAXPOWER: a real regen gain re-anchors the tick clock. Energy: every
    -- gain is a tick. Mana: only a gain clearing the real-tick threshold (~baseRegen*2) counts, not a
    -- partial FSR drip; guard GetManaRegen()==0 so a drip isn't misread as a tick.
    local power = UnitPower("player")
    if power > lastPower then
        local realTick = powerType ~= MANA
        if not realTick then
            local regen = GetManaRegen()
            realTick = regen > 0 and (power - lastPower) >= regen * TICK_INTERVAL * 0.9
        end
        if realTick then tickEnd = GetTime() + TICK_INTERVAL end
    end
    lastPower = power
    -- Drive visibility from a current-vs-max predicate (not "a spend was seen") so the loop parks the
    -- instant mana caps and wakes on any change that revives it.
    overlay:SetShown(shouldAnimate())
end)
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
