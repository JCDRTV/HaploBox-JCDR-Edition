-- TB18: shared mouse-transparent incoming-heal display for Party + Mini Heal.
-- 12.x combat may return SECRET values from all health and heal APIs.
-- Never perform arithmetic, comparisons, table indexing or text conversion on
-- those values: hand them directly to Blizzard's native StatusBar setters.
-- The indicator is anchored to the live native HP fill's RIGHT edge, with a
-- full-width heal fill clipped by the HP bar's geometry. No Lua hp+heal math.
local HB=HaploBox
local calculator
local function isSecret(v) return issecretvalue and issecretvalue(v) end

local function getPrediction(unit)
    -- New retail/Forever API, built for health prediction with secret values.
    -- A single calculator is reset before every use (5 units/2 displays).
    if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        local ok,value=pcall(function()
            if not calculator then calculator=CreateUnitHealPredictionCalculator() end
            if calculator.ResetPredictedValues then calculator:ResetPredictedValues() end
            UnitGetDetailedHealPrediction(unit,nil,calculator)
            if calculator.GetTotalIncomingHeals then
                return calculator:GetTotalIncomingHeals()
            end
            if calculator.GetIncomingHeals then
                return calculator:GetIncomingHeals()
            end
        end)
        if ok and type(value)=="number" then return value end
    end
    -- Classic / versions not exposing the calculator.
    if UnitGetIncomingHeals then
        local ok,value=pcall(UnitGetIncomingHeals,unit)
        if ok and type(value)=="number" then return value end
    end
    return nil
end

function HB.AttachIncomingHealBar(healthBar)
    if not healthBar or not healthBar.GetStatusBarTexture then return nil end
    local fill=healthBar:GetStatusBarTexture()
    if not fill then return nil end
    local clip=CreateFrame("Frame",nil,healthBar)
    clip:SetAllPoints(healthBar)
    clip:EnableMouse(false)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local predicted=CreateFrame("StatusBar",nil,clip)
    predicted:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    predicted:SetStatusBarColor(0.67,0.96,0.63,0.58)
    predicted:SetMinMaxValues(0,1)
    predicted:SetValue(0)
    predicted:EnableMouse(false)
    -- Texture fill is natively resized when UnitHealth changes; this anchor
    -- automatically follows its right edge, even when HP is a secret value.
    predicted:SetPoint("LEFT",fill,"RIGHT",0,0)
    predicted:SetSize(math.max(1,healthBar:GetWidth()),math.max(1,healthBar:GetHeight()))
    if healthBar.HookScript then
        healthBar:HookScript("OnSizeChanged",function(self,width,height)
            -- Width/height are UI dimensions, not protected combat health.
            if type(width)=="number" and type(height)=="number" and
               not isSecret(width) and not isSecret(height) then
                predicted:SetSize(math.max(1,width),math.max(1,height))
            end
        end)
    end
    predicted:Hide()
    return predicted
end

function HB.UpdateIncomingHealBar(predicted,unit,maxHealth)
    if not predicted then return end
    if not unit then predicted:Hide() return end
    local heal=getPrediction(unit)
    if type(heal)~="number" then predicted:Hide() return end
    -- A secret value can be passed directly to StatusBar:SetValue. No
    -- scripting decision about its magnitude is needed: 0 means zero fill.
    local maxHP=maxHealth
    if type(maxHP)~="number" and UnitHealthMax then
        local ok,value=pcall(UnitHealthMax,unit)
        if ok then maxHP=value end
    end
    if type(maxHP)~="number" then predicted:Hide() return end
    local ok=pcall(function()
        predicted:SetMinMaxValues(0,maxHP)
        predicted:SetValue(heal)
    end)
    if ok then predicted:Show() else predicted:Hide() end
end
