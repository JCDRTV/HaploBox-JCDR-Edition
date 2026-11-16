local H = HaploBoxA4
-- Only one-to-one addon WHISPER packets are used. Never PARTY/RAID, no auto-reply.
H.On("CHAT_MSG_WHISPER", function(message, sender)
    if not H.db or not H.db.whisperForward then return end
    if type(message)~="string" or type(sender)~="string" or H.Secret(message) or H.Secret(sender) then return end
    if H.AmLeader() then return end -- already visible on the leader's own chat
    local leader = H.LeaderName()
    if not leader or not H.Trusted(leader) then return end
    local me = H.UnitName("player") or "?"
    -- Keep packet <240 bytes and never forward linebreak/control delimiters.
    local clean = function(s) return (s:gsub("[|\r\n]"," "):gsub("[%c]","")) end
    local data = clean(me):sub(1,38) .. "|" .. clean(sender):sub(1,44) .. "|" .. clean(message):sub(1,115)
    H.SendTo(leader,"W",data)
end)
function H.ReceiveWhisper(from, raw)
    if not H.AmLeader() or not H.db.whisperForward then return end
    local recipient, originalSender, msg = raw:match("^([^|]+)|([^|]+)|(.+)$")
    if not recipient or not originalSender or not msg then return end
    if H.Norm(from) ~= H.Norm(recipient) then return end
    H.Print("|cffffdc75[Whisper naar " .. recipient .. "]|r " .. originalSender .. ": " .. msg)
end
