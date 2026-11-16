-- HaploBox: multibox team helper.
-- Followers report follow start/stop and spell errors to the leader over a
-- hidden addon channel. The leader gets a raid-warning style message on its
-- own screen. Nothing here touches protected frames, so it cannot taint the UI.

local ADDON = ...
local HB = {}
_G.HaploBox = HB

local PREFIX = "HaploBox"
local VERSION = "0.7.0-alpha5-testbuild19-haplobar-squaremap"

-- Sound values: a SOUNDKIT name ("RAID_WARNING"), a sound kit id (8959),
-- a file id ("file:567397") or a file path ("Interface\\AddOns\\HaploBox\\Sounds\\x.ogg").
-- false or "" turns the sound off.
BINDING_HEADER_HAPLOBOX_MAIN = "JCDRbox"
BINDING_NAME_HAPLOBOX_HEAL_TOGGLE = "Toggle Follower Heal UI"
local DEFAULTS = {
	sounds = {
		followOn     = "IG_QUEST_LIST_OPEN",
		followOff    = "IG_QUEST_LIST_CLOSE",
		leaderAlert  = "RAID_WARNING",
		focusError   = false,
		shareError   = "IG_QUEST_FAILED",
		inviteAccept = "IG_PLAYER_INVITE",
		mountOn      = false,
		mountOff     = false,
	},
	alertOnFollowStart  = false,  -- leader also gets a (green) message when a follower starts following
	autoAcceptInvite    = true,   -- followers accept invites from the leader
	autoAcceptShared    = true,   -- accept quests that a team member shares
	autoShareQuests     = "leader", -- "leader", "all" or "off"
	shareErrorAlert     = true,
	relayErrors         = true,   -- followers send cast errors to the leader
	showRelayedErrors   = true,   -- leader prints them in chat
	autoRoleCheck       = true,
	autoFFA             = true,   -- leader auto-sets FFA with trusted teammates, Group Loot with outsiders
	autoLeaveWithLeader = false,
	followMode          = "direct", -- direct: all follow actual leader; dungeon: DPS follow healer
	focusAlerts         = false,    -- Alpha3: focus errors only inline in team frames, no alerts
	teamFrame           = "show", -- new installs: party frames on every client; existing DB setting is preserved
	partyFrameSolo      = false,  -- also show it when not in a group
    partyScale          = 1.0, -- user-approved default; global WoW UI scale controls overall size
    controlsOpen        = false,
    haploMinimapEnabled = true, -- TB19: native minimap, square HaploBox presentation (MAIN / large view)
    miniHealMode        = false, -- local-only; large screen keeps full Main view
    buffOverviewEnabled = true, -- preserve the previously enabled TB15 panel
    debuffOverviewEnabled = false, -- new visual pane opt-in until first test
    goldDetailsOpen     = false,
    bagsDetailsOpen     = false,
	questEnabled        = false,
	tradeEnabled        = false,
	trustedMembers      = "Mael,Lyra,Elya,Nyra,Ayla",
	teamLocked          = false,  -- team frame: locked in place (unlocked shows a drag bar and resize corner)
	teamClassColors     = true,   -- keep existing user-selectable class colours
    -- Buff Watcher defaults: food/XP and team-cast buffs required; Camp optional.
    requiredBuffs       = {xp=true, food=true, camp=false, mark=true, thorns=true, intellect=true, fortitude=true, blessing=false},
	preferredOrder      = "Mael,Lyra,Elya,Nyra,Ayla", -- match character names or their individual name parts
	debug               = false,
}

local SOUND_FALLBACK = {  -- SOUNDKIT ids from the 1.x client, used if the constant is missing
	IG_QUEST_LIST_OPEN = 875, IG_QUEST_LIST_CLOSE = 876, RAID_WARNING = 8959,
	READY_CHECK = 8960, IG_QUEST_FAILED = 847, IG_PLAYER_INVITE = 880, TELL_MESSAGE = 3081,
}

local ERRORS = {  -- UI error global -> short code -> text shown to the leader
	{ "ERR_OUT_OF_RANGE", "R", "out of range" },
	{ "ERR_SPELL_OUT_OF_RANGE", "R", "out of range" },
	{ "SPELL_FAILED_LINE_OF_SIGHT", "L", "no line of sight" },
	{ "SPELL_FAILED_MOVING", "V", "can't cast while moving" },
	{ "SPELL_FAILED_BAD_TARGETS", "B", "invalid target" },
	{ "SPELL_FAILED_UNIT_NOT_INFRONT", "F", "target not in front" },
	{ "ERR_BADATTACKFACING", "F", "target not in front" },
	{ "ERR_OUT_OF_MANA", "M", "out of mana" },
	{ "SPELL_FAILED_SILENCED", "S", "silenced" },
	{ "SPELL_FAILED_STUNNED", "S", "stunned" },
	{ "ERR_SPELL_COOLDOWN", "C", "spell on cooldown" },
}
local ERROR_TEXT = {}
for _, e in ipairs(ERRORS) do ERROR_TEXT[e[2]] = e[3] end

local QUEST_SHARE_ERRORS = {
	"ERR_QUEST_PUSH_INVALID_S", "ERR_QUEST_PUSH_DECLINED_S", "ERR_QUEST_PUSH_DEAD_S",
	"ERR_QUEST_PUSH_LOG_FULL_S", "ERR_QUEST_PUSH_ACCEPTED_S", "ERR_QUEST_PUSH_ONQUEST_S",
	"ERR_QUEST_PUSH_ALREADY_DONE_S", "ERR_QUEST_PUSH_NOT_DAILY_S", "ERR_QUEST_PUSH_TIMER_EXPIRED_S",
	"ERR_QUEST_PUSH_NOT_IN_PARTY_S", "ERR_QUEST_PUSH_DIFFERENT_SERVER_DAILY_S",
	"ERR_QUEST_PUSH_NOT_ALLOWED_S", "ERR_QUEST_PUSH_PREREQUISITE_S", "ERR_QUEST_PUSH_LOW_LEVEL_S",
	"ERR_QUEST_PUSH_HIGH_LEVEL_S", "ERR_QUEST_PUSH_CLASS_S", "ERR_QUEST_PUSH_RACE_S",
	"ERR_QUEST_PUSH_LOW_FACTION_S", "ERR_QUEST_PUSH_WRONG_FACTION_S", "ERR_QUEST_PUSH_BUSY_S",
}
-- Not errors: the quest was accepted or the target already has it.
local QUEST_SHARE_HARMLESS = { ERR_QUEST_PUSH_ACCEPTED_S = true, ERR_QUEST_PUSH_ONQUEST_S = true }

-- ---------------------------------------------------------------- helpers
local function secret(v) return issecretvalue and issecretvalue(v) end

local function str(v)
	if v == nil or secret(v) or type(v) ~= "string" or v == "" then return nil end
	return v
end

local function print_(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffHaploBox|r " .. msg) end
local function debug(msg) if HB.db and HB.db.debug then print_("|cff888888" .. msg .. "|r") end end
HB.print, HB.debug, HB.secret = print_, debug, secret

local myRealm = str(GetRealmName and GetRealmName())
myRealm = myRealm and myRealm:gsub("%s", "") or nil

-- Names are compared case-insensitively, with our own realm suffix removed.
-- WoW Forever uses "Name Surname", normal realms "Name" or "Name-Realm".
function HB.Norm(name)
	name = str(name)
	if not name then return nil end
	name = name:match("^%s*(.-)%s*$")
	if myRealm then
		local base, realm = name:match("^(.-)%-([^%-]+)$")
		if base and realm and realm:gsub("%s", "") == myRealm then name = base end
	end
	return name:lower()
end

function HB.UnitIdent(unit)
	local ok, full = pcall(GetUnitName, unit, true)
	full = ok and str(full) or nil
	if not full then
		local ok2, first, second = pcall(UnitName, unit)
		first = ok2 and str(first) or nil
		second = ok2 and str(second) or nil
		if first then full = second and (first .. " " .. second) or first end
	end
	return full
end

-- The actual WoW party leader may change while the cached HaploBoxTeam.leader
-- does not. Never rely on the static team roster for live focus/follow validation.
function HB.GroupLeader()
	if not (IsInGroup and IsInGroup()) or not UnitIsGroupLeader then return nil end
	local function leaderAt(unit)
		if UnitExists and not UnitExists(unit) then return nil end
		local ok, isLeader = pcall(UnitIsGroupLeader, unit)
		if ok and isLeader and not secret(isLeader) then return HB.UnitIdent(unit) end
	end
	local name = leaderAt("player")
	if name then return name end
	if IsInRaid and IsInRaid() then
		for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
			name = leaderAt("raid" .. i)
			if name then return name end
		end
	else
		for i = 1, 4 do
			name = leaderAt("party" .. i)
			if name then return name end
		end
	end
end
function HB.Leader()
	return HB.GroupLeader() or (HaploBoxTeam and str(HaploBoxTeam.leader))
end
function HB.IsLeaderName(name)
	local leader = HB.Norm(HB.Leader())
	return leader ~= nil and leader == HB.Norm(name)
end
function HB.IAmLeader()
	if IsInGroup and IsInGroup() and UnitIsGroupLeader then
		local ok, isLeader = pcall(UnitIsGroupLeader, "player")
		if ok and not secret(isLeader) then return not not isLeader end
	end
	return HB.IsLeaderName(HB.UnitIdent("player"))
end

function HB.Healer()
	local roles = HaploBoxTeam and HaploBoxTeam.roles or {}
	for n, role in pairs(roles) do
		if role == "healer" then
			local wanted = HB.Norm(n)
			if HB.Norm(HB.UnitIdent("player")) == wanted or (HB.SameTeamMember and HB.SameTeamMember(n, HB.UnitIdent("player"))) then return HB.UnitIdent("player") end
			for i = 1, 4 do
				local u = "party" .. i
				if UnitExists(u) and (HB.Norm(HB.UnitIdent(u)) == wanted or (HB.SameTeamMember and HB.SameTeamMember(n, HB.UnitIdent(u)))) then return HB.UnitIdent(u) end
			end
			return n
		end
	end
end
-- Pure expected-target computation; never issues /follow or changes a focus.
function HB.ExpectedFollowTarget(name)
	local leader = HB.GroupLeader()
	if not leader or HB.Norm(name) == HB.Norm(leader) then return nil end
	if HB.db and HB.db.followMode == "dungeon" then
		local healer = HB.Healer()
		if not healer then return nil end
		if HB.Norm(name) ~= HB.Norm(healer) then return healer end
	end
	return leader
end

function HB.RoleOf(name)
	local roles = HaploBoxTeam and HaploBoxTeam.roles
	local key = HB.Norm(name)
	if not roles or not key then return nil end
	for n, role in pairs(roles) do
		if HB.Norm(n) == key or (HB.SameTeamMember and HB.SameTeamMember(n, name)) then return role end
	end
end
function HB.MyRole() return HB.RoleOf(HB.UnitIdent("player")) end

function HB.PlaySound(key)
	local v = HB.db.sounds[key]
	if not v or v == "" then return end
	HB.lastSound = HB.lastSound or {}
	local now = GetTime()
	if (HB.lastSound[key] or 0) > now then return end
	HB.lastSound[key] = now + 0.5
	if type(v) == "number" then
		PlaySound(v, "Master")
	elseif type(v) == "string" then
		local fileId = v:match("^file:(%d+)$")
		if fileId then
			PlaySoundFile(tonumber(fileId), "Master")
		elseif v:find("[\\/]") then
			PlaySoundFile(v, "Master")
		else
			local kit = (SOUNDKIT and SOUNDKIT[v]) or SOUND_FALLBACK[v]
			if kit then PlaySound(kit, "Master") else debug("unknown sound " .. v) end
		end
	end
end

local function send(msg)
	if not IsInGroup() then return end
	local channel = IsInRaid() and "RAID" or "PARTY"
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then channel = "INSTANCE_CHAT" end
	C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
end
HB.SendTeamMessage = send

local function leaderAlert(text, color)
	if RaidNotice_AddMessage and RaidWarningFrame then
		RaidNotice_AddMessage(RaidWarningFrame, text, color or ChatTypeInfo["RAID_WARNING"])
	else
		UIErrorsFrame:AddMessage(text, 1, 0.2, 0.2)
	end
	print_(text)
end

local function shortName(name)
	return (str(name) or "?"):gsub("%-.*$", "")
end

-- Turns a global format like "%s is already on that quest." into a Lua pattern.
local function formatToPattern(fmt)
	local p = fmt:gsub("%%%d+%$", "%%")                       -- "%1$s" -> "%s"
	p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")        -- escape magic characters
	p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")       -- escaped "%s"/"%d" -> captures
	return "^" .. p .. "$"
end
HB.formatToPattern = formatToPattern

-- ---------------------------------------------------------------- loot
-- true / false when the client can tell, nil when it cannot read the loot method
function HB.IsFFA()
	if C_PartyInfo and C_PartyInfo.GetLootMethod then
		local ok, m = pcall(C_PartyInfo.GetLootMethod)
		if ok and m ~= nil then
			if type(m) == "string" then return m == "freeforall" end
			if Enum and Enum.LootMethod and Enum.LootMethod.Freeforall ~= nil then return m == Enum.LootMethod.Freeforall end
		end
	end
	if GetLootMethod then
		local ok, m = pcall(GetLootMethod)
		if ok and m ~= nil then
			if type(m) == "string" then return m == "freeforall" end
			if Enum and Enum.LootMethod and Enum.LootMethod.Freeforall ~= nil then return m == Enum.LootMethod.Freeforall end
		end
	end
	return nil
end

function HB.SetFFA(quiet)
	if not IsInGroup() then if not quiet then print_("not in a group") end return end
	if UnitIsGroupLeader and not UnitIsGroupLeader("player") then
		if not quiet then print_("only the group leader can change the loot method") end
		return
	end
	if HB.IsFFA() then if not quiet then print_("loot is already free for all") end return end
	local tries = {}
	if C_PartyInfo and C_PartyInfo.SetLootMethod then
		if Enum and Enum.LootMethod and Enum.LootMethod.Freeforall ~= nil then
			tries[#tries + 1] = function() C_PartyInfo.SetLootMethod(Enum.LootMethod.Freeforall) end
		end
		tries[#tries + 1] = function() C_PartyInfo.SetLootMethod("freeforall") end
	end
	if SetLootMethod then tries[#tries + 1] = function() SetLootMethod("freeforall") end end
	for i, fn in ipairs(tries) do
		local ok, err = pcall(fn)
		debug("SetLootMethod try " .. i .. ": " .. tostring(ok) .. " " .. tostring(err))
		if ok then
			if not quiet then print_("loot set to free for all") end
			return true
		end
	end
	print_("could not change the loot method on this client")
end

-- ---------------------------------------------------------------- team sync
-- /hb team (on the leader, grouped): the current group becomes the team, in group
-- order, with the leader first. It is sent as M|<leader>|<name>=<role>;... and every
-- toon that receives it from that leader stores it. /hb role sends R|<role>|<name>.
local function clean(n) return (str(n) or ""):gsub("[|;=]", "") end

local function setRole(name, role)
	HaploBoxTeam.roles = HaploBoxTeam.roles or {}
	local key = HB.Norm(name)
	for n, oldRole in pairs(HaploBoxTeam.roles) do
		if HB.Norm(n) == key then
			HaploBoxTeam.roles[n] = nil
		elseif role == "healer" and oldRole == "healer" then
			HaploBoxTeam.roles[n] = "dps"
		end
	end
	HaploBoxTeam.roles[name] = role
end
HB.SetRoleLocal = setRole

local function refreshTeam()
	if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end
	if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end
	if HB.RefreshControls then HB.RefreshControls() end
end
HB.RefreshTeam = refreshTeam

local function applyTeam(leader, list)
	HaploBoxTeam.leader = leader
	HaploBoxTeam.order = {}
	HaploBoxTeam.roles = {}
	for _, m in ipairs(list) do
		HaploBoxTeam.order[#HaploBoxTeam.order + 1] = m.name
		HaploBoxTeam.roles[m.name] = m.role
	end
	refreshTeam()
end

function HB.TeamSummary()
	local parts = {}
	for _, n in ipairs(HaploBoxTeam.order or {}) do
		local r = HB.RoleOf(n) or "?"
		parts[#parts + 1] = n .. " (" .. (HB.IsLeaderName(n) and "leader, " or "") .. r .. ")"
	end
	return #parts > 0 and table.concat(parts, ", ") or "no team set"
end

function HB.SetTeamFromGroup()
	if not IsInGroup() or IsInRaid() then print_("join a party (not a raid) with your team first") return end
	if not HB.IAmLeader() then print_("only the actual party leader can sync the team") return end
	local me = clean(HB.UnitIdent("player"))
	local units = { "player", "party1", "party2", "party3", "party4" }
	local list, wire = {}, {}
	for _, u in ipairs(units) do
		if UnitExists(u) then
			local name = clean(HB.UnitIdent(u))
			if name ~= "" then
				local role = HB.RoleOf(name) or (u == "player" and "tank" or "dps")
				list[#list + 1] = { name = name, role = role }
				wire[#wire + 1] = name .. "=" .. role
			end
		end
	end
	applyTeam(me, list)
	send("M|" .. me .. "|" .. table.concat(wire, ";"))
	print_("team set and sent: " .. HB.TeamSummary())
end

local function onTeamMessage(sender, leader, body)
	-- Only the real WoW party leader can update the synchronized roster.
	if HB.Norm(sender) ~= HB.Norm(leader) or HB.Norm(sender) ~= HB.Norm(HB.GroupLeader()) then return end
	local list = {}
	for entry in (body or ""):gmatch("[^;]+") do
		local name, role = entry:match("^(.-)=(%a+)$")
		if name and name ~= "" then list[#list + 1] = { name = name, role = role } end
	end
	if #list == 0 then return end
	applyTeam(leader, list)
	print_("team set by |cffffff00" .. shortName(leader) .. "|r: " .. HB.TeamSummary())
end

local function onRoleMessage(sender, role, name)
	if HB.Norm(sender) ~= HB.Norm(name) then return end
	if role ~= "tank" and role ~= "healer" and role ~= "dps" then return end
	setRole(name, role)
	refreshTeam()
	debug(name .. " is now " .. role)
end

-- ---------------------------------------------------------------- events
local f = CreateFrame("Frame")
HB.frame = f
local followEndPending, lastFollowAction
local suppressShareQuest, suppressUntil = nil, 0
local shareErrorPatterns
local errorThrottle = {}

local handlers = {}

-- Follow state of every team member: "S" following, "X" not following, plus who
-- they follow. Messages: F|S|<target> and F|X on a change, F|? asks everyone,
-- F|s|<target> / F|x answer it (lowercase never triggers the leader alert).
HB.followState, HB.followTarget = {}, {}
local myFollowTarget
local function setFollowState(name, state, target)
	local k = HB.Norm(name)
	if not k then return end
	target = state == "S" and str(target) or nil
	if HB.followState[k] == state and HB.followTarget[k] == target then return end
	HB.followState[k], HB.followTarget[k] = state, target
	if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end
end
local function myFollowMsg(lower)
	local code = lastFollowAction == "BEGIN" and "S" or "X"
	if lower then code = code:lower() end
	if lastFollowAction == "BEGIN" and myFollowTarget then return "F|" .. code .. "|" .. myFollowTarget end
	return "F|" .. code
end

-- Focus of every team member: T|<name> when it changes, T| when cleared.
-- Answered together with the follow state on F|?.
HB.focus = {}
HB.focusKnown = HB.focusKnown or {}
local function setFocus(name, target)
	local k = HB.Norm(name)
	if not k then return end
	target = str(target)
	local changed = not HB.focusKnown[k] or HB.focus[k] ~= target
	HB.focusKnown[k] = true -- T| with an empty target is an explicit report, not unknown.
	HB.focus[k] = target
	if changed then
		if HB.OnFocusChanged then HB.OnFocusChanged() end
		if HB.OnFocusMonitorChanged then HB.OnFocusMonitorChanged() end
	end
end
local function myFocusName()
	local n = str(UnitExists("focus") and HB.UnitIdent("focus") or nil)
	return n and n:gsub("|", "") or nil
end
local function focusMsg() return "T|" .. (myFocusName() or "") end

function handlers.PLAYER_FOCUS_CHANGED()
	setFocus(HB.UnitIdent("player"), myFocusName())
	send(focusMsg())
end

local lastQuery = 0
local function queryFollowStates()
	if not IsInGroup() or GetTime() - lastQuery < 3 then return end
	lastQuery = GetTime()
	send("F|?")
	send("D|?") -- ask the real leader for the shared follow mode
	send("Q|?") -- ask whether the leader enabled quest sharing
	send("V|?") -- ask whether the leader enabled automatic trade
	if not HB.IAmLeader() then send(myFollowMsg(true)) end
	setFocus(HB.UnitIdent("player"), myFocusName())
	send(focusMsg())
end

function HB.SetFollowMode(mode)
	if mode ~= "direct" and mode ~= "dungeon" then return false end
	if not HB.IAmLeader() or not HB.GroupLeader() then
		print_("Only the current WoW party leader can set the team's follow mode.")
		return false
	end
	HB.db.followMode = mode
	send("D|" .. mode)
	if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end
	if HB.RefreshControls then HB.RefreshControls() end
	print_("Follow mode: " .. mode .. ". This is monitoring only; use your existing /follow macros.")
	return true
end

function handlers.ADDON_LOADED(name)
	if name ~= ADDON then return end
	HaploBoxDB = HaploBoxDB or {}
	HaploBoxTeam = HaploBoxTeam or {}
	for k, v in pairs(DEFAULTS) do
		if HaploBoxDB[k] == nil then
			HaploBoxDB[k] = type(v) == "table" and CopyTable(v) or v
		end
	end
	for k, v in pairs(DEFAULTS.sounds) do
		if HaploBoxDB.sounds[k] == nil then HaploBoxDB.sounds[k] = v end
	end
    -- SavedVariables upgrades must gain newly supported team-class buffs
    -- without overwriting any of the player's existing watch preferences.
    HaploBoxDB.requiredBuffs=HaploBoxDB.requiredBuffs or {}
    for k,v in pairs(DEFAULTS.requiredBuffs) do
        if HaploBoxDB.requiredBuffs[k]==nil then HaploBoxDB.requiredBuffs[k]=v end
    end
	HB.db = HaploBoxDB
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	shareErrorPatterns = {}
	for _, g in ipairs(QUEST_SHARE_ERRORS) do
		local fmt = _G[g]
		if type(fmt) == "string" then
			shareErrorPatterns[#shareErrorPatterns + 1] = { formatToPattern(fmt), QUEST_SHARE_HARMLESS[g] }
		end
	end
	if HB.CreateOptions then HB.CreateOptions() end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(12,function()
            if HB.db and IsInGroup and IsInGroup() and HB.IAmLeader() then queryFollowStates() end
        end)
    end
end

function handlers.PLAYER_ENTERING_WORLD()
	C_Timer.After(3, queryFollowStates)
	if HB.OnGroupLeaderChanged then HB.OnGroupLeaderChanged() end
end

function handlers.PLAYER_LOGIN()
	local leader = HB.Leader()
	if leader then
		print_(VERSION .. " loaded. Leader: |cffffff00" .. leader .. "|r" .. (HB.IAmLeader() and " (you)" or ""))
	else
		print_(VERSION .. " loaded. No leader set: target the leader and type |cffffff00/hb leader|r")
	end
end

function handlers.AUTOFOLLOW_BEGIN(name)
	followEndPending = nil
	name = str(name)
	-- a refresh of the same follow is not news; a switch to another target is
    if lastFollowAction == "BEGIN" and HB.Norm(name) == HB.Norm(myFollowTarget) then
        -- A repeated /follow also repairs lost leader-side status messages.
        -- No sound or duplicate alert is generated for a same-target refresh.
        send(myFollowMsg(true))
        return
    end
	local wasFollowing = lastFollowAction == "BEGIN"
	lastFollowAction, myFollowTarget = "BEGIN", name
	setFollowState(HB.UnitIdent("player"), "S", name)
	if not wasFollowing then HB.PlaySound("followOn") end
	send(myFollowMsg(false))
end

function handlers.AUTOFOLLOW_END()
	-- WoW fires END followed by BEGIN when following is refreshed: wait before reporting.
	local token = {}
	followEndPending = token
	C_Timer.After(0.65, function()
		if followEndPending ~= token then return end
		followEndPending = nil
		lastFollowAction, myFollowTarget = "END", nil
		setFollowState(HB.UnitIdent("player"), "X")
		HB.PlaySound("followOff")
		send("F|X")
	end)
end

function handlers.PARTY_INVITE_REQUEST(inviter)
	if not HB.db.autoAcceptInvite or not (HB.IsKnownTeam and HB.IsKnownTeam(inviter)) then return end
	AcceptGroup()
	HB.PlaySound("inviteAccept")
	C_Timer.After(0.1, function()
		StaticPopup_Hide("PARTY_INVITE")
		StaticPopup_Hide("PARTY_INVITE_XREALM")
	end)
end

function handlers.PLAYER_REGEN_ENABLED()
    if C_Timer and C_Timer.After then C_Timer.After(0.6, queryFollowStates) end
end

function handlers.GROUP_ROSTER_UPDATE()
	if HB.OnGroupLeaderChanged then HB.OnGroupLeaderChanged() end
	-- Leadership and team membership change independently of party size.
	C_Timer.After(1, queryFollowStates)
	if HB.CheckAutoLoot then HB.CheckAutoLoot() end
	if HB.RefreshControls then HB.RefreshControls() end

end

local function questFromPlayer()
	return UnitExists("questnpc") and UnitIsPlayer("questnpc")
end

function handlers.QUEST_DETAIL()
    if not HB.db.questEnabled or not IsInGroup() then return end
	if not questFromPlayer() then return end
	-- Quests shared by a player are never shared back.
	local id = GetQuestID and GetQuestID()
	if id and id > 0 then suppressShareQuest, suppressUntil = id, GetTime() + 5 end
	if HB.db.autoAcceptShared then
		AcceptQuest()
		HideUIPanel(QuestFrame)
	end
end

-- WoW can additionally confirm a group member's escort/party-start quest
-- without a normal QUEST_DETAIL dialog. Only opt-in members auto-confirm.
function handlers.QUEST_CONFIRM_ACCEPT()
    if HB.db.questEnabled and HB.db.autoAcceptShared and IsInGroup() and ConfirmAcceptQuest then
        pcall(ConfirmAcceptQuest)
    end
end

-- Only the actual leader initiates a share. Receiving clients may accept
-- a game-provided share, but never push that quest back to the party.
local recentlyPushed = {}
function handlers.QUEST_ACCEPTED(a, b)
    local questID = b or a
    if not (HB.db.questEnabled and HB.IAmLeader() and IsInGroup()) then return end
    if questID and questID == suppressShareQuest and GetTime() < suppressUntil then return end
    if type(questID)~="number" or secret(questID) or questID<=0 then return end
    if recentlyPushed[questID] and GetTime()-recentlyPushed[questID]<15 then return end
    recentlyPushed[questID] = GetTime()
    C_Timer.After(0.6, function()
        if HB.db.questEnabled and HB.IAmLeader() and IsInGroup() then
            HB.ShareQuest(nil,questID,true)
        end
    end)
end

local function questTitle(questID, index)
    if questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and t and not secret(t) then return t end
    end
    if index and GetQuestLogTitle then
        local ok,t=pcall(GetQuestLogTitle,index)
        if ok and t and not secret(t) then return t end
    end
    return "quest " .. tostring(questID or index)
end

-- WoW Forever QuestLogPushQuest() sends the CURRENTLY SELECTED quest. The
-- old code could print success even when it never selected a valid entry.
local function selectedQuestIndex(questID)
    if not questID then return nil end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok,index=pcall(C_QuestLog.GetLogIndexForQuestID,questID)
        if ok and type(index)=="number" and not secret(index) and index>0 then return index end
    end
    local total = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()
        or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    if type(total)~="number" or secret(total) then return nil end
    for i=1,math.min(total,500) do
        if C_QuestLog and C_QuestLog.GetInfo then
            local ok,info=pcall(C_QuestLog.GetInfo,i)
            if ok and info and info.questID==questID and not info.isHeader then return i end
        elseif GetQuestLogTitle then
            local ok,_,_,_,isHeader,_,_,_,id=pcall(GetQuestLogTitle,i)
            if ok and not isHeader and id==questID then return i end
        end
    end
end
function HB.ShareQuest(index,questID,retry)
    if not IsInGroup() or not HB.IAmLeader() then return false end
    if not QuestLogPushQuest then return false end
    if questID and (type(questID)~="number" or secret(questID)) then return false end
    index = (questID and selectedQuestIndex(questID)) or index
    local canPush=false
    if questID and C_QuestLog and C_QuestLog.IsPushableQuest then
        local ok,pushable=pcall(C_QuestLog.IsPushableQuest,questID)
        canPush=ok and pushable==true
    end
    if not canPush and index and SelectQuestLogEntry and GetQuestLogPushable then
        local ok=pcall(SelectQuestLogEntry,index)
        if ok then local valid,answer=pcall(GetQuestLogPushable);canPush=valid and not not answer end
    end
    if canPush then
        -- Prefer the modern questID selector; use the legacy index selector
        -- on Forever builds that expose it. Both push functions take NO args.
        local selected=false
        if questID and C_QuestLog and C_QuestLog.SetSelectedQuest then
            selected=pcall(C_QuestLog.SetSelectedQuest,questID)
        end
        if not selected and index and SelectQuestLogEntry then
            selected=pcall(SelectQuestLogEntry,index)
        end
        if selected then
            local ok,err=pcall(QuestLogPushQuest)
            if ok then print_("share requested: "..questTitle(questID,index));return true end
            print_("|cffffaa00share call failed:|r "..tostring(err))
        end
    end
    if retry then
        C_Timer.After(0.9,function()
            if HB.db.questEnabled and HB.IAmLeader() then HB.ShareQuest(nil,questID,false) end
        end)
    else
        print_("|cffffaa00not shareable / not found:|r "..questTitle(questID,index))
    end
    return false
end

function handlers.CHAT_MSG_SYSTEM(msg)
	if not HB.db.shareErrorAlert or secret(msg) or type(msg) ~= "string" then return end
	for _, p in ipairs(shareErrorPatterns) do
		local who = msg:match(p[1])
		if who then
			if not p[2] then
				HB.PlaySound("shareError")
				print_("|cffff4444quest share failed:|r " .. msg)
			end
			return
		end
	end
end

function handlers.UI_ERROR_MESSAGE(_, msg)
	if not HB.db.relayErrors or HB.IAmLeader() or secret(msg) then return end
	for _, e in ipairs(ERRORS) do
		if _G[e[1]] and msg == _G[e[1]] then
			local now = GetTime()
			if (errorThrottle[e[2]] or 0) < now then
				errorThrottle[e[2]] = now + 2
				send("E|" .. e[2])
			end
			return
		end
	end
end

function handlers.CHAT_MSG_ADDON(prefix, msg, _, sender)
	if prefix ~= PREFIX or secret(msg) or secret(sender) then return end
	if HB.Norm(sender) == HB.Norm(HB.UnitIdent("player")) then return end
	local kind, code, arg = strsplit("|", msg)
	if kind == "F" and code == "?" then
		if not HB.IAmLeader() then send(myFollowMsg(true)) end
		setFocus(HB.UnitIdent("player"), myFocusName())
		send(focusMsg())
		return
	end
    if kind == "Y" then
        if HB.ReceivePulse then HB.ReceivePulse(sender,code,arg) end
        return
    end
	if kind == "Q" then
		if code == "?" then
			if HB.IAmLeader() then send("Q|" .. (HB.db.questEnabled and "1" or "0")) end
		elseif (code == "0" or code == "1") and HB.Norm(sender) == HB.Norm(HB.GroupLeader()) then
			if HB.ApplyQuestEnabled then HB.ApplyQuestEnabled(code == "1", false) end
		end
		return
	end
    if kind == "B" then
        -- Only the actual party leader may synchronize required-buff rules.
        if HB.Norm(sender)~=HB.Norm(HB.GroupLeader()) then return end
        local valid={xp=true,food=true,camp=true,mark=true,thorns=true,intellect=true,fortitude=true,blessing=true}
        if valid[code] and (arg=="0" or arg=="1") then
            HB.db.requiredBuffs=HB.db.requiredBuffs or {}
            HB.db.requiredBuffs[code]=(arg=="1")
            if HB.RefreshPartyFrame then HB.RefreshPartyFrame() end
        end
        return
    end
	if kind == "V" then
		if code == "?" then
			if HB.IAmLeader() then send("V|" .. (HB.db.tradeEnabled and "1" or "0")) end
		elseif (code == "0" or code == "1") and HB.Norm(sender) == HB.Norm(HB.GroupLeader()) then
			HB.db.tradeEnabled = code == "1"
			if HB.RefreshControls then HB.RefreshControls() end
		end
		return
	end
	if kind == "H" then
		if code == "me" and HB.IsGroupMember and HB.IsGroupMember(sender) then
			setRole(sender, "healer")
			refreshTeam()
		end
		return
	end
	if kind == "D" then
		if code == "?" then
			if HB.IAmLeader() then send("D|" .. (HB.db.followMode or "direct")) end
		elseif (code == "direct" or code == "dungeon") and HB.Norm(sender) == HB.Norm(HB.GroupLeader()) then
			HB.db.followMode = code
			if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end
		end
		return
	end
	if kind == "M" then onTeamMessage(sender, code, arg) return end
	if kind == "R" then onRoleMessage(sender, code, arg) return end
	if kind == "T" then
		setFocus(sender, code ~= "" and code or nil)
		return
	end
	if kind == "F" and (code == "s" or code == "x") then  -- state report, not a change: no alert
		setFollowState(sender, code:upper(), arg)
		return
	end
	if kind == "F" and (code == "S" or code == "X") then setFollowState(sender, code, arg) end
	if kind == "F" and HB.IAmLeader() then
		if code == "X" then
			HB.PlaySound("leaderAlert")
			leaderAlert(shortName(sender) .. " stopped following!")
		elseif code == "S" and HB.db.alertOnFollowStart then
			leaderAlert(shortName(sender) .. " is following", { r = 0.2, g = 1, b = 0.2 })
		end
	elseif kind == "E" and HB.IAmLeader() and HB.db.showRelayedErrors then
		print_("|cffffaa00" .. shortName(sender) .. ":|r " .. (ERROR_TEXT[code] or code or "?"))
	elseif kind == "HELLO" then
		debug("hello from " .. tostring(sender) .. " " .. tostring(code))
	end
end

function handlers.LFG_ROLE_CHECK_SHOW()
	if not HB.db.autoRoleCheck or not (SetLFGRoles and CompleteLFGRoleCheck) then return end
	local role = HB.MyRole()
	if not role then return end
	local leaderFlag = GetLFGRoles and select(1, GetLFGRoles()) or false
	SetLFGRoles(leaderFlag, role == "tank", role == "healer", role == "dps" or role == "damager")
	CompleteLFGRoleCheck(true)
	debug("role check answered as " .. role)
end

function handlers.UNIT_ENTERING_VEHICLE(unit)
	if unit == "player" then HB.PlaySound("mountOn") end
end

function handlers.UNIT_EXITING_VEHICLE(unit)
	if unit == "player" then HB.PlaySound("mountOff") end
end

f:SetScript("OnEvent", function(_, event, ...)
	local h = handlers[event]
	if h then
		local ok, err = pcall(h, ...)
		if not ok then debug(event .. ": " .. tostring(err)) end
	end
end)
for event in pairs(handlers) do
	pcall(f.RegisterEvent, f, event)  -- some events do not exist on every client
end

-- ---------------------------------------------------------------- slash
local function help()
	print_("commands:")
	print_("  /hb status - leader, role and settings")
	print_("  /hb leader [name] - set the leader (no name: your target)")
	print_("  /hb team - on the leader, in a party: make this group the team and send it to every toon")
	print_("  /hb team show - list the team")
	print_("  /hb role tank|healer|dps - your role (healer: follow arrows, role checks); sent to the group")
	print_("  /hb ffa - set free-for-all loot (group leader only)")
	print_("  /hb invite | leave | healer - control-bar actions")
	print_("  /hb trusted [names] - comma-separated safe team names for invites/loot")
	print_("  /hb trade rule <itemID> <recipient> | trade rules - explicit trade routing")
    print_("  /hb buffs - show Buff Watcher requirements; /hb buffs <xp|food|camp|mark|thorns|intellect|fortitude|blessing> on|off")
    print_("  /hb buffpanel unlock|lock|reset - drag standalone top-right Buff Overview while unlocked")
    print_("  /hb view main|heal|toggle - local display mode (mini = 5 mouseover HP bars)")
	print_("  /hb controls - toggle foldout; drag Controls to move whole party; /hb controls reset - reset both")
	print_("  /hb share - share every quest in your log with the group")
	print_("  /hb sound <event> <value|off> - " .. "events: followOn followOff leaderAlert shareError inviteAccept mountOn mountOff")
	print_("  /hb test <event> - play a sound; /hb test alert - show the leader alert")
	print_("  /hb frame auto|show|hide - team frame on this toon (auto: only when it is the leader)")
	print_("  /hb followmode direct|dungeon|status - leader selects direct or healer chain monitoring")
	print_("  /hb focuscheck - show current focus accuracy for all five characters")
    print_("  /hb auramode - see whether the 12.1 live-combat aura engine is active")
    print_("  /hb statusdebug - inspect live mainbar source flags (follow, loot, repair, quest)")
    print_("  /hb debuffpanel unlock|lock|reset - move mirrored Debuff Overview")
    print_("  /hb overview buff|debuff on|off - same as Quick Menu checkboxes")
	print_("  /hb frame lock | unlock - unlocked: drag the bar to move, drag the corner to resize")
	print_("  /hb frame colors | scale <0.5-2> | solo | reset | order Mael,Lyra,Elya,Nyra,Ayla")
	print_("  /hb who - show how the game names you and your target")
	print_("  /hb options - open the options panel; /hb debug - toggle debug output")
end

SLASH_HAPLOBOX1, SLASH_HAPLOBOX2 = "/hb", "/haplobox"
SlashCmdList.HAPLOBOX = function(input)
	local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "leader" then
		local name = rest ~= "" and rest or HB.UnitIdent("target")
		if not name then print_("no target and no name given") return end
		HaploBoxTeam.leader = name
		print_("leader set to |cffffff00" .. name .. "|r")
	elseif cmd == "role" then
		local r = rest:lower()
		if r ~= "tank" and r ~= "healer" and r ~= "dps" then print_("role must be tank, healer or dps") return end
		local me = clean(HB.UnitIdent("player"))
		setRole(me, r)
		send("R|" .. r .. "|" .. me)
		refreshTeam()
		print_("role set to " .. r .. (IsInGroup() and " (sent to the group)" or ""))
	elseif cmd == "team" then
		if rest:lower() == "show" then print_("team: " .. HB.TeamSummary()) return end
		HB.SetTeamFromGroup()
	elseif cmd == "followmode" then
		local mode = rest:lower()
		if mode == "direct" or mode == "dungeon" then
			HB.SetFollowMode(mode)
		else
			print_("Follow mode: " .. tostring(HB.db.followMode) .. " (use /hb followmode direct or dungeon)")
		end
	elseif cmd == "invite" then
		if HB.InviteTeam then HB.InviteTeam() end
	elseif cmd == "leave" then
		if HB.LeaveTeam then HB.LeaveTeam() end
	elseif cmd == "healer" then
		if HB.AssignMyHealer then HB.AssignMyHealer() end
    elseif cmd == "view" or cmd == "minimode" then
        local m=rest:lower()
        if m=="heal" or m=="mini" then
            if HB.SetMiniHealMode then HB.SetMiniHealMode(true) end
        elseif m=="main" then
            if HB.SetMiniHealMode then HB.SetMiniHealMode(false) end
        elseif m=="toggle" then
            if HB.SetMiniHealMode then HB.SetMiniHealMode(not HB.db.miniHealMode) end
        else
            print_("Local view: "..(HB.db.miniHealMode and "MINI HEAL" or "MAIN").."; use /hb view main|heal|toggle")
        end
    elseif cmd == "controls" then
		if rest:lower() == "reset" then
			if HB.ResetControlPosition then HB.ResetControlPosition() end
		else
			HB.db.controlsOpen = not HB.db.controlsOpen
			if HB.RefreshControls then HB.RefreshControls() end
		end
    elseif cmd == "buffpanel" then
        local mode=rest:lower()
        if mode=="unlock" or mode=="lock" then
            local ok=HB.SetBuffOverviewUnlocked and HB.SetBuffOverviewUnlocked(mode=="unlock")
            print_(ok and ("Buff Overview "..mode.."ed; "..(mode=="unlock" and "drag MOVE BUFFS above panel" or "saved"))
                or "Buff Overview: change position out of combat.")
        elseif mode=="reset" then
            local ok=HB.ResetBuffOverviewPosition and HB.ResetBuffOverviewPosition()
            print_(ok and "Buff Overview moved back to upper-right default." or "Reset after combat.")
        else
            print_("Use /hb buffpanel unlock|lock|reset (independent of party frame movement)")
        end
    elseif cmd == "debuffpanel" then
        local mode=rest:lower()
        if mode=="unlock" or mode=="lock" then
            local ok=HB.SetDebuffOverviewUnlocked and HB.SetDebuffOverviewUnlocked(mode=="unlock")
            print_(ok and ("Debuff Overview "..mode.."ed") or "Change frame lock after combat.")
        elseif mode=="reset" then
            local ok=HB.ResetDebuffOverviewPosition and HB.ResetDebuffOverviewPosition()
            print_(ok and "Debuff Overview position reset." or "Reset after combat.")
        else print_("Use /hb debuffpanel unlock|lock|reset") end
    elseif cmd == "overview" then
        local kind,value=rest:lower():match("^(%a+)%s+(%a+)$")
        if (kind=="buff" or kind=="debuff") and (value=="on" or value=="off") then
            local ok=HB.SetOverviewEnabled and HB.SetOverviewEnabled(kind,value=="on")
            print_(ok and (kind.." Overview "..value:upper()) or "Change overview after combat.")
        else print_("Use /hb overview buff|debuff on|off") end
    elseif cmd == "statusdebug" then
        if HB.MainBarStatusDiagnostics then HB.MainBarStatusDiagnostics() end
    elseif cmd == "buffs" then
        local family,setting=rest:lower():match("^(%a+)%s*(%a*)$")
        local valid={xp=true,food=true,camp=true,mark=true,thorns=true,intellect=true,fortitude=true,blessing=true}
        HB.db.requiredBuffs=HB.db.requiredBuffs or {}
        if not valid[family] then
            local out={}
            for _,k in ipairs({"xp","food","camp","mark","thorns","intellect","fortitude","blessing"}) do
                out[#out+1]=k.."="..(HB.db.requiredBuffs[k] and "ON" or "OFF")
            end
            print_("Required buffs: "..table.concat(out,", ")..". Use /hb buffs <xp|food|camp|mark|thorns|intellect|fortitude|blessing> on|off")
            return
        end
        if setting~="on" and setting~="off" then print_("Use /hb buffs "..family.." on|off") return end
        HB.db.requiredBuffs[family]=setting=="on"
        if HB.IAmLeader() and IsInGroup() then send("B|"..family.."|"..(setting=="on" and "1" or "0")) end
        if HB.RefreshPartyFrame then HB.RefreshPartyFrame() end
        print_("Required buff "..family..": "..setting:upper())
	elseif cmd == "trusted" then
		if rest == "" then print_("trusted team: " .. tostring(HB.db.trustedMembers))
		else HB.db.trustedMembers = rest print_("trusted team now: " .. rest) end
	elseif cmd == "trade" then
		if HB.TradeCommand then HB.TradeCommand(rest) end
	elseif cmd == "focuscheck" then
		if HB.PrintFocusCheck then HB.PrintFocusCheck() end
    elseif cmd == "auramode" then
        print_("Aura renderer: " .. tostring(HB.auraEngine or "not yet initialized") ..
            ". New Blizzard AuraContainer required for live HoTs/debuffs in protected combat.")
	elseif cmd == "ffa" then
		HB.SetFFA(false)
	elseif cmd == "share" then
		if not IsInGroup() then print_("not in a group") return end
		local n = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()
			or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
		local i = 0
		C_Timer.NewTicker(0.4, function()
			i = i + 1
			if C_QuestLog and C_QuestLog.GetInfo then
				local info = C_QuestLog.GetInfo(i)
				if info and not info.isHeader then HB.ShareQuest(i, info.questID) end
			else
				local _, _, _, isHeader = GetQuestLogTitle(i)
				if not isHeader then HB.ShareQuest(i) end
			end
		end, n)
		print_("sharing " .. n .. " quest log entries")
	elseif cmd == "sound" then
		local event, value = rest:match("^(%S+)%s*(.-)$")
		if not event or HB.db.sounds[event] == nil and DEFAULTS.sounds[event] == nil then
			print_("unknown sound event") return
		end
		if value == "" then print_(event .. " = " .. tostring(HB.db.sounds[event])) return end
		if value == "off" then value = false elseif tonumber(value) then value = tonumber(value) end
		HB.db.sounds[event] = value
		print_(event .. " = " .. tostring(value))
		HB.PlaySound(event)
	elseif cmd == "test" then
		if rest == "alert" then
			HB.PlaySound("leaderAlert")
			leaderAlert("Test Follower stopped following!")
		elseif DEFAULTS.sounds[rest] ~= nil then
			HB.lastSound = {}
			HB.PlaySound(rest)
		else
			print_("test what? alert or a sound event")
		end
	elseif cmd == "frame" then
		local a, b = rest:match("^(%S*)%s*(.-)$")
		a = a:lower()
		local alias = { on = "show", off = "hide", all = "show", leader = "auto" }
		a = alias[a] or a
		if a == "auto" or a == "show" or a == "hide" then
			HB.db.teamFrame = a
			print_("team frame on this toon: " .. a)
		elseif a == "scale" and tonumber(b) then
			HB.db.partyScale = math.min(2, math.max(0.5, tonumber(b)))
			print_("team frame scale: " .. HB.db.partyScale)
		elseif a == "order" then
				if b == "" then
					print_("preferred order: " .. tostring(HB.db.preferredOrder or "(off)"))
					return
				end
				HB.db.preferredOrder = b:lower() == "off" and "" or b
				print_("preferred order: " .. (HB.db.preferredOrder ~= "" and HB.db.preferredOrder or "off"))
		elseif a == "solo" then
			HB.db.partyFrameSolo = not HB.db.partyFrameSolo
			print_("team frame when solo: " .. (HB.db.partyFrameSolo and "shown" or "hidden"))
		elseif a == "lock" or a == "unlock" then
			if HB.SetTeamFrameLocked then HB.SetTeamFrameLocked(a == "lock") end
		elseif a == "colors" or a == "colours" then
			HB.db.teamClassColors = not HB.db.teamClassColors
			print_("team frame class colours: " .. (HB.db.teamClassColors and "on" or "off"))
		elseif a == "reset" then
			if HB.ResetPartyPosition then HB.ResetPartyPosition() end
		else
			print_("team frame on this toon: " .. tostring(HB.db.teamFrame) .. ", scale " .. tostring(HB.db.partyScale)
				.. ". Use /hb frame auto|show|hide|lock|unlock|colors|scale <n>|solo|reset|order <names|off>")
			return
		end
		if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end
	elseif cmd == "who" then
		print_("you: " .. tostring(HB.UnitIdent("player")) .. "  target: " .. tostring(HB.UnitIdent("target"))
			.. "  realm: " .. tostring(myRealm))
	elseif cmd == "status" then
		print_("leader: " .. tostring(HB.Leader()) .. (HB.IAmLeader() and " (you)" or "")
			.. "  role: " .. tostring(HB.MyRole()) .. "  loot: " .. tostring(GetLootMethod and GetLootMethod()))
	elseif cmd == "options" or cmd == "config" then
		if HB.OpenOptions then HB.OpenOptions() end
	elseif cmd == "debug" then
		HB.db.debug = not HB.db.debug
		print_("debug " .. (HB.db.debug and "on" or "off"))
	else
		help()
	end
end
