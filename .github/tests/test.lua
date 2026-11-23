-- Execute the real addon with mock frames. Live rendering and protected actions need game QA.
local frames, Addon = {}, {}
local methods = {}
local realm = "CAMWOW EU5 Realm 9 RP PvP"
local restricted = false
local queued = {}
local tagEnabled = true
local picker
local connected, reportedTotal, pendingAccounts = true, nil, false
local timers = {}
function BNConnected() return connected end
C_Timer = {NewTimer = function(_, callback)
    local timer = {callback = callback}
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end}

for _, name in ipairs({
    "SetAllPoints", "SetFrameLevel", "EnableMouse", "EnableMouseWheel", "SetBackdrop",
    "SetBackdropColor", "SetSize", "SetHeight", "SetWidth", "SetAutoFocus", "SetTextColor",
    "SetJustifyH", "SetWordWrap", "SetAlpha", "SetColorTexture", "SetGradient",
    "SetNormalAtlas", "SetHighlightAtlas", "SetScrollChild", "SetMaxLetters", "RegisterEvent",
    "UnregisterAllEvents", "SetClampedToScreen", "SetFrameStrata",
}) do
    methods[name] = function() end
end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if point == "TOPLEFT" and type(relative) == "number" then self.offset = relativePoint end
end
function methods:ClearAllPoints() end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text or "" end
function methods:GetFrameLevel() return 5 end
function methods:GetWidth() return 370 end
function methods:GetVerticalScrollRange() return 0 end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(value)
    local prior = self.shown
    self.shown = value
    local handler = self.scripts[value and "OnShow" or "OnHide"]
    if prior ~= value and handler then handler(self) end
end
function methods:Hide() self:SetShown(false) end
function methods:Show() self:SetShown(true) end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local prior = self.scripts[event]
    self.scripts[event] = function(...)
        if prior then prior(...) end
        callback(...)
    end
end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:HasFocus() return self.focused end
function methods:ClearFocus()
    self.focused = false
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:GetNormalTexture() return self.normalTexture end
function methods:SetVertexColor(...) self.vertex = {...} end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({kind = kind, name = name, parent = parent, shown = true, scripts = {}}, {__index = methods})
    frames[#frames + 1] = frame
    if template == "BasicFrameTemplateWithInset" then
        frame.TitleText = CreateFrame("FontString", nil, frame)
    end
    frame.normalTexture = setmetatable({scripts = {}, shown = true}, {__index = methods})
    return frame
end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetNormalAtlas(atlas) self.normalTexture.atlas = atlas end

WOW_PROJECT_ID, BNET_CLIENT_WOW = 18, "WoW"
Enum = {BattleNetFriendLevel = {Title = 3}, TitleIconVersion = {Small = 1}}
SlashCmdList, UISpecialFrames = {}, {}
function CreateColor(...) return {...} end
function GetRealmName() return realm end
function GetNormalizedRealmName() return realm end
function GetRealmID() return 900 end
function Mixin(target, source) for key, value in pairs(source) do target[key] = value end end
function hooksecurefunc(owner, key, callback)
    local original = owner[key]
    owner[key] = function(...)
        original(...)
        callback(...)
    end
end
C_SocialRestrictions = {IsFriendsDisabled = function() return restricted end}
C_Texture = {SetTitleIconTexture = function() end}
C_SocialQueue = {
    IsSystemSupported = function() return true end,
    GetGroupForPlayer = function(guid) return queued[guid] and guid end,
    GetGroupInfo = function() return true, 1 end,
}
C_AddOns = {LoadAddOn = function()
    ColorPickerFrame = {
        SetupColorPickerAndShow = function(_, data) picker = data end,
        GetColorRGB = function() return 1, 0.5, 0 end,
        Hide = function() end,
    }
end}
SocialUIAddFriendButtonMixin = {}
local contacts = {}
local freshAccounts = {}
local function Contact(name, level, ruleset, online)
    return {accountName = name, friendLevel = level, gameAccountInfo = {
        isOnline = online, clientProgram = "WoW", wowProjectID = 18, realmName = ruleset,
        characterName = name, playerGuid = name,
    }}
end
contacts = {
    Contact("Title same", 3, "RP-PvP", true),
    Contact("Battle same", 1, "RP-PvP", true),
    Contact("Title other", 3, "Normal", true),
    Contact("Battle unknown", 1, "", true),
    Contact("Offline", 3, "", false),
}
function BNGetNumFriends() return reportedTotal or #contacts end
C_BattleNet = {
    GetFriendAccountInfo = function(index) return not pendingAccounts and contacts[index] or nil end,
    GetGameAccountInfoByID = function(id) return freshAccounts[id] end,
    AreFriendTagsEnabled = function() return tagEnabled end,
    SearchFriends = function() error("Restricted search used") end,
}
SocialUIUtil = {
    GetSupportedBattleNetFriendTagInterestsForCurrentGameType = function() return {1} end,
    GetSupportedBattleNetFriendTagRolesForCurrentGameType = function() return {2} end,
    GetLabelForBattleNetFriendTag = tostring,
}
ScrollUtil = {InitScrollFrameWithScrollBar = function() end}
SocialUIFrame = CreateFrame("Frame")
SocialUIFrame.FriendsList = CreateFrame("Frame", nil, SocialUIFrame)
function SocialUIFrame:SetActiveContentFrame() end

for _, file in ipairs({"Options.lua", "BetterFriendsList.lua"}) do
    assert(loadfile(file))("BetterFriendsList", Addon)
end
local function FindText(text)
    for _, frame in ipairs(frames) do
        if frame.text == text and frame:IsVisible() then return frame end
    end
end
local function Click(frame) assert(frame.scripts.OnClick)(frame) end
assert(#Addon.sections == 6)
assert(FindText("WoW: Forever — RP-PvP  2/2"), "Title and Battle.net friends must share the same section")
assert(FindText("Title same") and FindText("Battle same"))
assert(not FindText("Title other") and not FindText("Offline"), "Other sections start collapsed")
assert(FindText("WoW: Forever — Unknown Ruleset  1/1"))
local same = FindText("WoW: Forever — RP-PvP  2/2").parent
local normal = FindText("WoW: Forever — Normal  1/1").parent
assert(same.offset > normal.offset, "Current ruleset must be first")

-- Cover realm labels and explicit presence formats outside the original CAMWOW form.
local originalContacts = contacts
local expanded = {}
for i, contact in ipairs(contacts) do expanded[i] = contact end
local cases = {
    {realm = "Roleplaying-PvP"},
    {realm = "RP‑PvP"},
    {realm = "CAMWOW EU5 Realm 9 Roleplay PvP (RP PvP) New"},
    {realm = "ClassicBetaRPPvP2"},
    {presence = "WoW: Forever · RP-PvP · Hillsbrad Foothills"},
    {presence = "WoW Forever - RP-PvP - Ashenvale"},
    {presence = "Forever·RP-PvP·Durotar"},
}
for index, example in ipairs(cases) do
    local contact = Contact("Format " .. index, 1, example.realm or "", true)
    contact.gameAccountInfo.richPresence = example.presence
    expanded[#expanded + 1] = contact
end
contacts = expanded
Addon.Refresh()
assert(FindText("WoW: Forever — RP-PvP  9/9"), "Explicit roleplay PvP variants must join RP-PvP")
assert(FindText("WoW: Forever — Unknown Ruleset  1/1"), "Missing evidence must stay unknown")
contacts[#contacts + 1] = Contact("Not a realm", 1, "PVP_SUFFIX", true)
contacts[#contacts].gameAccountInfo.richPresence = "Battleground PvP"
Addon.Refresh()
assert(FindText("WoW: Forever — Unknown Ruleset  2/2"), "Zone/status text must not imply a ruleset")
contacts = originalContacts
Addon.Refresh()

-- Resolve absent realm names using matching game accounts and region-scoped realm IDs.
local recovered = Contact("Recovered", 1, "", true)
recovered.gameAccountInfo.gameAccountID = 501
recovered.gameAccountInfo.realmID = 701
recovered.gameAccountInfo.regionID = 1
local fresh = Contact("Recovered", 1, "RP-PvP", true).gameAccountInfo
fresh.gameAccountID = 501
freshAccounts[501] = fresh
local sameRealm = Contact("Same realm", 1, "", true)
sameRealm.gameAccountInfo.realmID, sameRealm.gameAccountInfo.regionID = 701, 1
local foreignRegion = Contact("Other region", 1, "", true)
foreignRegion.gameAccountInfo.realmID, foreignRegion.gameAccountInfo.regionID = 701, 3
local playerRealmFriend = Contact("Player realm", 1, "", true)
playerRealmFriend.gameAccountInfo.realmID = 900
playerRealmFriend.gameAccountInfo.isInCurrentRegion = true
contacts = {recovered, sameRealm, foreignRegion, playerRealmFriend}
Addon.Refresh()
assert(FindText("WoW: Forever — RP-PvP  3/3"), "Matching game account and realm IDs must recover missing names")
assert(FindText("WoW: Forever — Unknown Ruleset  1/1"), "Realm IDs from different regions must stay separate")
fresh.playerGuid = "Different character"
Addon.Refresh()
assert(FindText("WoW: Forever — RP-PvP  1/1"), "Fresh metadata for another character must not be used")
contacts = originalContacts
freshAccounts = {}
Addon.Refresh()
Click(normal)
assert(FindText("Title other"))

-- Editing settings exercises saved overrides, reset, picker cancellation, and reused headers.
BetterFriendsListDB = {sections = {Normal = {textColor = "bad", backgroundColor = false}, other = false}}
assert(Addon.GetSectionStyle("Normal").textColor == nil)
assert(type(Addon.GetSectionStyle("other")) == "table")
SlashCmdList.BETTERFRIENDSLIST("options")
local options
for _, frame in ipairs(frames) do if frame.name == "BetterFriendsListOptions" then options = frame end end
assert(options and #options.rows == 6)
local row = options.rows[1]
row.input:SetText("  My | Realms  ")
row.input.scripts.OnEditFocusLost(row.input)
assert(BetterFriendsListDB.sections.Normal.label == "My  Realms")
assert(FindText("My  Realms  1/1"))
Click(row.textColor)
picker.swatchFunc()
assert(BetterFriendsListDB.sections.Normal.textColor == "ff8000")
picker.cancelFunc()
assert(BetterFriendsListDB.sections.Normal.textColor == nil)
Click(row.backgroundColor)
picker.swatchFunc()
assert(BetterFriendsListDB.sections.Normal.backgroundColor == "ff8000")
assert(normal.normalTexture.color[1] == 1)
local reset
for _, frame in ipairs(frames) do if frame.parent == row and frame.text == "Reset" then reset = frame end end
Click(reset)
assert(FindText("WoW: Forever — Normal  1/1"))
assert(normal.normalTexture.atlas == "common-button-list-collapseExpand")
row.input:SetText("Renamed")
row.input.scripts.OnEditFocusLost(row.input)
assert(Addon.GetSectionStyle("Normal").label == "Renamed")

local menus, actions = {}, {}
local menu = {}
function menu:CreateButton(label, action) menus[label] = true; actions[label] = action; return self end
function menu:CreateTitle() end
function menu:CreateDivider() end
function menu:CreateCheckbox() end
local filter
for _, frame in ipairs(frames) do if frame.kind == "DropdownButton" then filter = frame end end
filter:GenerateFilterMenu(menu)
assert(actions["Section settings"])
actions["Section settings"]()

-- Recover from startup with an empty count, partial account data, and late reconnect.
local view
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent and frame.scripts.OnShow then view = frame end
end
assert(view)
reportedTotal = 0
view.scripts.OnEvent(view, "BN_CONNECTED")
assert(FindText("Loading friends…"))
local retry = timers[#timers]
reportedTotal = nil
pendingAccounts = true
retry.callback()
assert(FindText("Loading friends…") and Addon.status:find("loaded 0", 1, true))
retry = timers[#timers]
pendingAccounts = false
retry.callback()
assert(FindText("Title same"), "Timer must recover once friend account data arrives")
connected = false
view.scripts.OnEvent(view, "BN_DISCONNECTED")
retry = timers[#timers]
view:Hide()
assert(retry.cancelled, "Closing the view must cancel the retry")
connected = true
view:Show()
assert(FindText("Title same"))

-- Re-selecting Friends refreshes an already shown addon view.
contacts[1].accountName = "Updated title"
SocialUIFrame:SetActiveContentFrame()
assert(FindText("Updated title"))
restricted = true
SocialUIFrame:SetActiveContentFrame()
assert(not FindText("Updated title"), "Friends restriction must hide the addon view")
print("Grouping, settings, delayed friend loading, reconnect, view refresh, and restrictions passed")
