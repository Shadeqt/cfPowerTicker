-- Core: shared state and helpers for the power ticker and the druid form bar.
-- Loaded first (see the .toc); exposes everything on the private `addon` table
-- so the other files reach it without touching globals.
local _, addon = ...

-- Warriors only use rage (no regen tick); the addon adds nothing for them. Mark it
-- inert here and let each consumer bail on `addon.active` rather than re-checking class.
local _, class = UnitClass("player")
addon.class  = class
addon.active = class ~= "WARRIOR"
if not addon.active then return end

addon.TICK_INTERVAL = 2
addon.FSR_DURATION  = 5
local TICK_INTERVAL = addon.TICK_INTERVAL
local FSR_DURATION  = addon.FSR_DURATION

-- The shared 2s regen-tick clock. Energy and mana tick on the same server boundary,
-- so a single clock keeps the main bar's spark and the druid bar's spark in lockstep
-- — including in bear form, where the main overlay is parked and the druid overlay is
-- the one advancing it.
local clock = { tickEnd = GetTime() + TICK_INTERVAL }
addon.clock = clock

-- Re-anchor to the next boundary once it has elapsed. No power event fires at full
-- energy/mana, so an OnUpdate must advance the clock itself; the modulo absorbs many
-- missed ticks at once.
function clock:Reanchor(now)
    if self.tickEnd <= now then
        self.tickEnd = now + TICK_INTERVAL - ((now - self.tickEnd) % TICK_INTERVAL)
    end
end

-- A real tick was observed: re-anchor to exactly 2s out.
function clock:Bump(now)
    self.tickEnd = now + TICK_INTERVAL
end

-- 0..1 fill for the white tick spark (sweeps left→right across the 2s window).
function clock:TickProgress(now)
    return 1 - (self.tickEnd - now) / TICK_INTERVAL
end

-- The shared five-second-rule window. FSR is a property of the MANA POOL alone — it does not
-- depend on which power is currently displayed — so it is detected here, once, off the pool
-- itself, and every spark reads it. (Detecting it off *displayed* power, as before, went blind
-- to mana spent while shapeshifted, so breaking a form with a cast never started FSR.)
local MANA = Enum.PowerType.Mana
local fsrEnd = 0
local fsrManaLast = UnitPower("player", MANA)

-- 0..1 fill for the red FSR spark (sweeps right→left across the window), or nil if not in FSR.
function addon.FsrProgress(now)
    if fsrEnd <= now then return nil end
    return (fsrEnd - now) / FSR_DURATION
end

-- Watch the mana pool directly: any drop is a spend and opens a fresh FSR window.
-- UNIT_POWER_UPDATE carries the MANA token whenever the pool changes — even while energy/rage
-- is displayed — so this stays correct across shapeshifts (where displayed-power tracking did not).
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

-- Was this mana gain a real regen tick (~baseRegen*2), as opposed to a partial
-- FSR drip that falls short of the 0.9 threshold? Guard against GetManaRegen()
-- returning 0, which would otherwise classify every drip as a full tick.
function addon.IsRealTick(gain)
    local regen = GetManaRegen()
    return regen > 0 and gain >= regen * TICK_INTERVAL * 0.9
end

-- A real regen gain re-anchors the shared tick clock. `isMana` true → the gain must clear the
-- real-tick threshold (partial mana drips that fall short don't count); false (energy) → every
-- gain is a tick. FSR is watched separately off the mana pool (fsrWatcher above), so this only
-- concerns the white tick boundary.
function addon.NoteGain(now, current, last, isMana)
    if current > last and (not isMana or addon.IsRealTick(current - last)) then
        clock:Bump(now)
    end
end

-- Line colors borrowed from class colors: FSR = Death Knight red, regen tick = Priest
-- white, bad clip = Rogue yellow. Pulled from RAID_CLASS_COLORS so they track the client
-- (all three classes are present in the Classic Era table).
local CC      = RAID_CLASS_COLORS
local FSR_C   = CC.DEATHKNIGHT
local TICK_C  = CC.PRIEST
local CLIP_C  = CC.ROGUE

-- A self-animating tick spark bound to `host` (a StatusBar/region). Each frame it
-- re-anchors the shared clock and calls `compute(now)`, which returns either
--   progress (0..1), isFSR (bool), badClip (bool)
--                                  → draw the line: FSR color if FSR, else clip color if a
--                                    cast is clipping the tick poorly, else tick color, or
--   nil                            → hide it.
-- Visibility is the caller's job via the returned overlay:SetShown — a hidden frame's
-- OnUpdate never fires, so parking it costs zero CPU.
function addon.NewTickSpark(host, compute)
    local overlay = CreateFrame("Frame", nil, host)
    overlay:SetAllPoints(host)
    overlay:SetFrameLevel(host:GetFrameLevel() + 10)

    -- A moving "mark" frame carrying the 2px line and a casting-bar spark glow. Anchoring both to
    -- the frame lets one SetPoint move them together and one SetShown toggle them together; only
    -- the color is set per-texture, since vertex color doesn't inherit.
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
        clock:Reanchor(now)

        local progress, isFSR, badClip = compute(now)
        if not progress then
            mark:Hide()
            return
        end
        local c = isFSR and FSR_C or badClip and CLIP_C or TICK_C
        local x = host:GetWidth() * progress
        mark:ClearAllPoints()
        mark:SetPoint("TOP", host, "TOPLEFT", x, 0)
        mark:SetPoint("BOTTOM", host, "BOTTOMLEFT", x, 0)
        mark:Show()
        line:SetVertexColor(c.r, c.g, c.b)
        glow:SetVertexColor(c.r, c.g, c.b)
    end)

    return overlay
end
