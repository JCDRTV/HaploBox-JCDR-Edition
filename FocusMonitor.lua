-- HaploBox Alpha 3: focus correctness is displayed IN PLACE above the status icon.
-- No external raid warning, chat spam, sound or automatic focus changes.
local HB = HaploBox
function HB.FocusStatus(name)
    local leader = HB.GroupLeader and HB.GroupLeader()
    local key = HB.Norm(name)
    if not leader or not key then return "unknown" end
    local known = HB.focusKnown and HB.focusKnown[key]
    if not known then return "unknown" end
    local current = HB.focus and HB.focus[key]
    if key == HB.Norm(leader) then
        -- A leader must have NO focus; followers must focus on the leader.
        return current and "leader_wrong" or "leader"
    end
    if not current then return "missing" end
    if HB.Norm(current) ~= HB.Norm(leader) then return "wrong" end
    return "correct"
end
function HB.OnFocusMonitorChanged()
    if HB.OnFocusChanged then HB.OnFocusChanged() end
end
function HB.OnGroupLeaderChanged()
    if HB.OnFocusChanged then HB.OnFocusChanged() end
    if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end
    if HB.RefreshControls then HB.RefreshControls() end
end
function HB.PrintFocusCheck()
    local leader = HB.GroupLeader and HB.GroupLeader()
    if not leader then HB.print("No verified WoW party leader visible.") return end
    HB.print("Party leader and focus goal: " .. leader)
    for _, n in ipairs(HB.TeamOrder and HB.TeamOrder() or {}) do
        local k = HB.Norm(n)
        local current = HB.focus and HB.focus[k]
        HB.print(n .. ": " .. HB.FocusStatus(n) .. " (focus " .. (current or "none") .. ")")
    end
end
