local FOREVER_PROJECT = WOW_PROJECT_CAMELOT or 18
if WOW_PROJECT_ID ~= FOREVER_PROJECT then
    return
end

local friendLevel = Enum.BattleNetFriendLevel
local tabs = {
    { label = "WoW Friends", levels = { [friendLevel.Title] = true } },
    { label = "Battle.net", levels = { [friendLevel.RealID] = true, [friendLevel.BattleTag] = true } },
    { label = "All" },
}

local factionAtlases = {
    Horde = "communities-create-button-wow-horde",
    Alliance = "communities-create-button-wow-alliance",
}

local rulesets = {
    normal = "Normal",
    pve = "Normal",
    pvp = "PvP",
    rp = "RP",
    rppvp = "RP-PvP",
}

local function IsReadable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsReadableTable(value)
    return IsReadable(value) and type(value) == "table"
        and (not issecrettable or not issecrettable(value))
end

local function ReadText(value)
    return IsReadable(value) and type(value) == "string" and value or ""
end

local function ParseRealmRuleset(value, requireForeverRealm)
    local realm = ReadText(value):lower():match("^%s*(.-)%s*$")
    -- Forever reports both spaced and normalized CAMWOW realm names.
    local compactRealm = realm:gsub("[%s%-]", "")
    local suffix = compactRealm:match("^camwow%a+%d+realm%d+([a-z]+)$")
        or compactRealm:match("^camwow%a+%d+realm%d+([a-z]+)%([a-z]+%)%a*$")
    if suffix or requireForeverRealm then
        return rulesets[suffix]
    end

    local label = compactRealm:gsub("^forever", ""):gsub("^realm", "")
    return rulesets[label]
end

local function GetFriendRuleset(game)
    local ruleset = ParseRealmRuleset(game.realmName) or ParseRealmRuleset(game.realmDisplayName)
    if ruleset then
        return ruleset
    end

    local presence = ReadText(game.richPresence):lower()
    local label = presence:match("^forever %- (.-) %- %S")
        or presence:match("^forever · (.-) · %S")
    return ParseRealmRuleset(label) or ParseRealmRuleset(presence:match(".* %- (.+)$"), true)
end

local function ColorText(color, text)
    return "|cff" .. color .. text .. "|r"
end

local function GetRowDetails(game)
    if not IsReadableTable(game) or not IsReadable(game.isOnline) or not game.isOnline
        or ReadText(game.clientProgram) ~= BNET_CLIENT_WOW then
        return nil
    end

    local faction = ReadText(game.factionName)
    local factionText
    if faction == "Horde" then
        factionText = ColorText("ff8075", FACTION_HORDE or "Horde")
    elseif faction == "Alliance" then
        factionText = ColorText("83bbff", FACTION_ALLIANCE or "Alliance")
    end

    if not IsReadable(game.wowProjectID) or game.wowProjectID ~= FOREVER_PROJECT then
        return factionText
    end

    local friendRuleset = GetFriendRuleset(game)
    local playerRuleset = ParseRealmRuleset(GetRealmName()) or ParseRealmRuleset(GetNormalizedRealmName())
    local rulesetText
    if friendRuleset and playerRuleset then
        local sameRuleset = friendRuleset == playerRuleset
        rulesetText = ColorText(sameRuleset and "91e3ad" or "ffc579",
            friendRuleset .. (sameRuleset and " (same)" or " (different)"))
    else
        rulesetText = friendRuleset or "Ruleset unknown"
    end

    return (factionText or "Faction unknown") .. "  ·  " .. rulesetText
end

local function GetAccountName(account, game)
    local name = ReadText(account.accountName)
    if name == "" then
        name = ReadText(account.battleTag)
    end
    if name == "" then
        name = ReadText(game.characterName)
    end
    return name ~= "" and name or (UNKNOWN or "Unknown")
end

local function CollectFriends(tab, search)
    local rows = {}
    local total = BNGetNumFriends()
    if not IsReadable(total) or type(total) ~= "number" then
        return rows
    end

    for index = 1, total do
        local account = C_BattleNet.GetFriendAccountInfo(index)
        if IsReadableTable(account) then
            local level = account.friendLevel
            if not tab.levels or (IsReadable(level) and tab.levels[level]) then
                local game = account.gameAccountInfo
                game = IsReadableTable(game) and game or {}
                local name = GetAccountName(account, game)
                local character = ReadText(game.characterName)
                local battleTag = ReadText(account.battleTag)
                if search == "" or name:lower():find(search, 1, true)
                    or character:lower():find(search, 1, true) or battleTag:lower():find(search, 1, true) then
                    rows[#rows + 1] = {
                        name = name,
                        character = character,
                        game = game,
                        online = IsReadable(game.isOnline) and game.isOnline == true,
                    }
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return a.name:lower() < b.name:lower()
    end)
    return rows
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 45)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * 45)
    row:SetHeight(42)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.11, 0.17, 0.9)

    row.gameIcon = row:CreateTexture(nil, "ARTWORK")
    row.gameIcon:SetSize(22, 22)
    row.gameIcon:SetPoint("RIGHT", -9, 0)
    row.crest = row:CreateTexture(nil, "ARTWORK")
    row.crest:SetSize(19, 19)
    row.crest:SetPoint("RIGHT", row.gameIcon, "LEFT", -5, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 9, -6)
    row.name:SetPoint("RIGHT", row.crest, "LEFT", -7, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.details = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.details:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.details:SetPoint("RIGHT", row.crest, "LEFT", -7, 0)
    row.details:SetJustifyH("LEFT")
    row.details:SetWordWrap(false)
    return row
end

local function DisplayFriend(row, friend)
    local game = friend.game
    local name = friend.name
    if friend.online and friend.character ~= "" and friend.character ~= name then
        name = name .. "  ·  " .. friend.character
    end
    row.name:SetText(name)
    row.name:SetAlpha(friend.online and 1 or 0.55)

    local details = GetRowDetails(game)
    local location = ReadText(game.areaName)
    if location == "" and not details then
        location = ReadText(game.richPresence)
    end
    if details and location ~= "" then
        details = details .. "  ·  " .. location
    end
    row.details:SetText(friend.online and (details or location) or (FRIENDS_LIST_OFFLINE or "Offline"))

    local client = ReadText(game.clientProgram)
    local showIcon = friend.online and client ~= ""
    if showIcon then
        local subIcon = ReadText(game.subIcon)
        C_Texture.SetTitleIconTexture(row.gameIcon, client, Enum.TitleIconVersion.Small, subIcon ~= "" and subIcon or nil)
    end
    row.gameIcon:SetShown(showIcon)

    local isForever = IsReadable(game.wowProjectID) and game.wowProjectID == FOREVER_PROJECT
    local crest = showIcon and client == BNET_CLIENT_WOW and isForever
        and factionAtlases[ReadText(game.factionName)]
    if crest then
        row.crest:SetAtlas(crest, false)
    end
    row.crest:SetShown(not not crest)
    row:Show()
end

local function CreateFriendsWindow()
    local window = CreateFrame("Frame", "BetterFriendsListWindow", UIParent, "BackdropTemplate")
    window:SetSize(410, 560)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    window:SetBackdropColor(0.025, 0.025, 0.035, 1)
    window:Hide()
    table.insert(UISpecialFrames, window:GetName())

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        window:Hide()
    end)
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Better Friends List")

    local search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 20, -80)
    search:SetPoint("TOPRIGHT", -16, -80)
    search:SetHeight(22)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(SEARCH or "Search")

    local scroll = CreateFrame("ScrollFrame", "BetterFriendsListScrollFrame", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -112)
    scroll:SetPoint("BOTTOMRIGHT", -31, 15)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(365, 1)
    scroll:SetScrollChild(content)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOP", 0, -25)
    empty:SetText("No friends to display.")

    local activeTab = 1
    local rows, buttons = {}, {}
    local function Refresh()
        local query = search:GetText():lower():match("^%s*(.-)%s*$")
        local friends = CollectFriends(tabs[activeTab], query)
        for index, friend in ipairs(friends) do
            rows[index] = rows[index] or CreateRow(content, index)
            DisplayFriend(rows[index], friend)
        end
        for index = #friends + 1, #rows do
            rows[index]:Hide()
        end
        content:SetHeight(math.max(#friends * 45, 1))
        empty:SetShown(#friends == 0)
    end

    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(116, 24)
        button:SetPoint("TOPLEFT", 14 + (index - 1) * 121, -45)
        button:SetText(tab.label)
        buttons[index] = button
        button:SetEnabled(index ~= activeTab)
        button:SetScript("OnClick", function()
            buttons[activeTab]:Enable()
            activeTab = index
            button:Disable()
            scroll.ScrollBar:SetValue(0)
            Refresh()
        end)
    end

    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        scroll.ScrollBar:SetValue(0)
        Refresh()
    end)
    window:SetScript("OnShow", Refresh)
    window:SetScript("OnEvent", function(self)
        if self:IsShown() then
            Refresh()
        end
    end)
    window:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    window:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    window:RegisterEvent("BN_CONNECTED")
    window:RegisterEvent("BN_DISCONNECTED")
    return window
end

local window
SLASH_BETTERFRIENDSLIST1 = "/bfl"
SLASH_BETTERFRIENDSLIST2 = "/betterfriendslist"
SlashCmdList.BETTERFRIENDSLIST = function()
    window = window or CreateFriendsWindow()
    window:SetShown(not window:IsShown())
end
