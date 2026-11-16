-- Only standard Blizzard party frames are managed here, not player or target frames.
local H = HaploBoxA4
local known = {"PartyMemberFrame1","PartyMemberFrame2","PartyMemberFrame3","PartyMemberFrame4","CompactPartyFrame"}
local original, originalAlpha, pending = {}, {}, false
local hooked = {}
local hiding = false
function H.UpdateBlizzardParty()
    if not H.db then return end
    if InCombatLockdown and InCombatLockdown() then pending = true return end
    pending = false
    for _,name in ipairs(known) do
        local frame = _G[name]
        if frame and frame.Hide and frame.Show then
            if not hooked[frame] and hooksecurefunc then
                hooked[frame] = true
                hooksecurefunc(frame, "Show", function(self)
                    if hiding or not (H.db and H.db.ui.hideBlizzardParty) then return end
                    -- Show() can briefly paint between the next frame and Hide().
                    -- Alpha suppression prevents this while combat forbids Hide().
                    pcall(self.SetAlpha,self,0)
                    if InCombatLockdown and InCombatLockdown() then pending = true return end
                    hiding = true
                    self:Hide()
                    hiding = false
                end)
            end
            if H.db.ui.hideBlizzardParty then
                if original[frame] == nil then original[frame] = frame:IsShown() end
                if originalAlpha[frame] == nil then originalAlpha[frame] = frame:GetAlpha() end
                pcall(frame.SetAlpha,frame,0)
                hiding = true
                pcall(frame.Hide,frame)
                hiding = false
            else
                if originalAlpha[frame] ~= nil then pcall(frame.SetAlpha,frame,originalAlpha[frame]) end
                if original[frame] then pcall(frame.Show,frame) end
                original[frame],originalAlpha[frame] = nil,nil
            end
        end
    end
end
H.On("PLAYER_REGEN_ENABLED",function() if pending then H.UpdateBlizzardParty() end end)
H.On("GROUP_ROSTER_UPDATE",function() H.After(1,H.UpdateBlizzardParty) end)
H.OnReady(function()
    H.After(2,H.UpdateBlizzardParty)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1,function() if H.db then H.UpdateBlizzardParty() end end)
    end
end)
