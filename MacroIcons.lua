-- Hide only names drawn over HaploBox-owned macro icons on Blizzard actionbars.
-- Icons, cooldowns, keybinding labels and third-party macros remain unchanged.
local HB=HaploBox
local names={
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarLeftButton", "MultiBarRightButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}
local restore={}
local function sameBody(entry,body)
    return entry and body and (body==entry.onBody or body==entry.offBody or
        body==entry.leaderBody or body==entry.legacyBody)
end
function HB.IsOwnedMacroName(name,index)
    if type(name)~="string" then return false end
    local key=HB.Norm and HB.UnitIdent and HB.Norm(HB.UnitIdent("player"))
    if not key or not HB.db then return false end
    if name=="HB Smart Follow" then
        return HB.db.smartFollowOwners and HB.db.smartFollowOwners[key] or false
    end
    local registry=HB.db.boxMacros and HB.db.boxMacros[key]
    local entry=registry and registry[name]
    if not entry or not index or not GetMacroBody then return false end
    local ok,body=pcall(GetMacroBody,index)
    return ok and sameBody(entry,body) or false
end
local function updateButton(button)
    if not button or not GetActionInfo or not GetMacroInfo then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local idx=button.action
    if not idx and button.GetAttribute then
        local ok,slot=pcall(button.GetAttribute,button,"action")
        if ok then idx=slot end
    end
    if not idx then return end
    local ok,kind,macro=pcall(GetActionInfo,idx)
    local hide=false
    if ok and kind=="macro" and type(macro)=="number" then
        local infoOK,name=pcall(GetMacroInfo,macro)
        hide=infoOK and HB.IsOwnedMacroName(name,macro)
    end
    local text=button.Name or (button.GetName and _G[(button:GetName() or "").."Name"])
    if not text or not text.SetAlpha then return end
    if hide then
        if restore[text]==nil then restore[text]=(text.GetAlpha and text:GetAlpha()) or 1 end
        text:SetAlpha(0)
    elseif restore[text]~=nil then
        text:SetAlpha(restore[text])
        restore[text]=nil
    end
end
local function refresh()
    for _,prefix in ipairs(names) do
        for i=1,12 do
            updateButton(_G[prefix..i])
        end
    end
end
local frame=CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("UPDATE_MACROS")
frame:SetScript("OnEvent",refresh)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(3,refresh) end
