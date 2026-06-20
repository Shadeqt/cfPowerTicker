-- Power-tick spark on the player's mana/energy bar: a white spark sweeping each 2s
-- regen tick, plus a red five-second-rule countdown for mana users. Shared constants,
-- the tick clock, and the spark component all live in Core.lua (loaded first).
local _, addon = ...
if not addon.active then return end   -- warriors have no regen tick

local clock = addon.clock
local TICK_INTERVAL = addon.TICK_INTERVAL

local powerType = UnitPowerType("player")
local lastPower = UnitPower("player")

-- "Bad clip" warning. Mana is spent (and the five-second rule starts) when a cast
-- completes, so the efficient play is for a regen tick to land in the last 0.5s before
-- completion — banking that tick right before regen locks out. Set at cast start by
-- projecting the cast's end onto the tick clock; held for the cast's duration; cleared
-- when the cast ends. FSR red takes priority over this yellow (see Core's color order).
local badClip = false

-- Whether the spark has anything to draw right now.
-- Rage: never. Mana: not at full. Energy: always (rogues/cat — no event fires at
-- full energy, so the loop must keep running to re-anchor the tick itself).
local function shouldAnimate()
    if powerType == Enum.PowerType.Rage then
        return false
    end
    if powerType == Enum.PowerType.Mana then
        return UnitPower("player") < UnitPowerMax("player")
    end
    return true
end

-- Red FSR countdown while a mana user is inside the five-second rule, else the white
-- 2s tick. Visibility (SetShown below) gates the OnUpdate, so this only runs when there
-- is actually something to animate.
local overlay = addon.NewTickSpark(PlayerFrameManaBar, function(now)
    if powerType == Enum.PowerType.Mana then
        local fsr = addon.FsrProgress(now)
        if fsr then return fsr, true end        -- red five-second-rule countdown
    end
    return clock:TickProgress(now), false, badClip   -- white tick, or yellow on a bad clip
end)

-- Watch the player's casts. On start, project the cast's completion onto the tick clock:
-- if it lands more than 0.5s past the last tick boundary, the cast wastes the tick → yellow.
-- Instants have no cast time (UnitCastingInfo returns nil) and are ignored.
local casts = CreateFrame("Frame")
casts:SetScript("OnEvent", function(_, event)
    if event == "UNIT_SPELLCAST_START" then
        local _, _, _, _, endTimeMS = UnitCastingInfo("player")
        if endTimeMS then
            local castEnd = endTimeMS / 1000               -- GetTime()-based seconds
            local gap = (castEnd - clock.tickEnd) % TICK_INTERVAL
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

-- Start in the correct state instead of waiting for the first event (e.g. a full-mana
-- caster logs in parked; an energy user logs in running).
overlay:SetShown(shouldAnimate())

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_DISPLAYPOWER" then
        powerType = UnitPowerType("player")
        lastPower = UnitPower("player")
        overlay:SetShown(shouldAnimate())
        return
    end
    -- UNIT_POWER_UPDATE / UNIT_MAXPOWER: a real gain re-anchors the shared tick clock.
    local power = UnitPower("player")
    addon.NoteGain(GetTime(), power, lastPower, powerType == Enum.PowerType.Mana)
    lastPower = power
    -- Drive visibility from a current-vs-max predicate (not "a spend was seen") so the
    -- loop parks the instant mana caps and wakes on any change that revives it.
    overlay:SetShown(shouldAnimate())
end)
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
