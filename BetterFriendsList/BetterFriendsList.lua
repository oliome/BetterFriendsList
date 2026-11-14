local FOREVER_PROJECT = WOW_PROJECT_CAMELOT or 18
if WOW_PROJECT_ID ~= FOREVER_PROJECT then
    return
end

local friendLevel = Enum.BattleNetFriendLevel
local tabs = {
    { label = "All" },
    { label = "WoW Friends", levels = { [friendLevel.Title] = true } },
    { label = "Battle.net", levels = { [friendLevel.RealID] = true, [friendLevel.BattleTag] = true } },
}

local sections = {
    { key = "forever", label = "WoW: Forever" },
    { key = "wow", label = "In-Game WoW Friends" },
    { key = "other", label = "Other" },
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
    local rulesetText = friendRuleset or "Ruleset unknown"
    if friendRuleset and friendRuleset == playerRuleset then
        rulesetText = ColorText("91e3ad", friendRuleset .. " (same)")
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
    local groups = { forever = {}, wow = {}, other = {} }
    local total = BNGetNumFriends()
    if not IsReadable(total) or type(total) ~= "number" then
        return groups
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
                    local online = IsReadable(game.isOnline) and game.isOnline == true
                    local isWoWFriend = IsReadable(level) and level == friendLevel.Title
                    local isForever = online and ReadText(game.clientProgram) == BNET_CLIENT_WOW
                        and IsReadable(game.wowProjectID) and game.wowProjectID == FOREVER_PROJECT
                    local key = isWoWFriend and "wow" or (isForever and "forever" or "other")
                    local rows = groups[key]
                    rows[#rows + 1] = {
                        name = name,
                        sortName = name:lower(),
                        character = character,
                        game = game,
                        online = online,
                        isWoWFriend = isWoWFriend,
                        away = (IsReadable(account.isAFK) and account.isAFK == true)
                            or (IsReadable(game.isGameAFK) and game.isGameAFK == true),
                        busy = (IsReadable(account.isDND) and account.isDND == true)
                            or (IsReadable(game.isGameBusy) and game.isGameBusy == true),
                    }
                end
            end
        end
    end

    for _, rows in pairs(groups) do
        table.sort(rows, function(a, b)
            if a.online ~= b.online then
                return a.online
            end
            return a.sortName < b.sortName
        end)
    end
    return groups
end

local function PositionRow(frame, offset)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 0, -offset)
    frame:SetPoint("TOPRIGHT", 0, -offset)
end

local function CreateSectionHeader(parent)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(24)
    header:SetNormalAtlas("common-button-list-collapseExpand")
    header:SetHighlightAtlas("common-button-list-collapseExpand")
    header.label = header:CreateFontString(nil, "OVERLAY", "Game15Font_Shadow")
    header.label:SetPoint("LEFT", 8, 0)
    header.icon = header:CreateTexture(nil, "ARTWORK")
    header.icon:SetPoint("RIGHT", -7, 0)
    return header
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(70)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.presence = row:CreateTexture(nil, "ARTWORK")
    row.presence:SetSize(14, 14)
    row.presence:SetPoint("CENTER", row, "TOPLEFT", 4, -4)

    row.gameIcon = row:CreateTexture(nil, "ARTWORK")
    row.gameIcon:SetSize(22, 22)
    row.gameIcon:SetPoint("RIGHT", -9, 0)
    row.crest = row:CreateTexture(nil, "ARTWORK")
    row.crest:SetSize(19, 19)
    row.crest:SetPoint("RIGHT", row.gameIcon, "LEFT", -5, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    row.name:SetPoint("TOPLEFT", 9, -10)
    row.name:SetPoint("RIGHT", row.crest, "LEFT", -7, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.character = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.character:SetPoint("TOPLEFT", 9, -32)
    row.character:SetPoint("RIGHT", row.crest, "LEFT", -7, 0)
    row.character:SetJustifyH("LEFT")
    row.character:SetWordWrap(false)

    row.details = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.details:SetPoint("TOPLEFT", 9, -51)
    row.details:SetPoint("RIGHT", row.crest, "LEFT", -7, 0)
    row.details:SetJustifyH("LEFT")
    row.details:SetWordWrap(false)
    return row
end

local function DisplayFriend(row, friend)
    local game = friend.game
    local background = friend.isWoWFriend and "friends-card-default" or "friends-card-battleNet"
    row.background:SetAtlas(friend.online and background or "friends-card-disabled")
    local presence = friend.away and "away" or (friend.busy and "busy" or "online")
    row.presence:SetAtlas("friends-status-" .. (friend.online and presence or "offline"))
    row.name:SetText(friend.name)
    if friend.isWoWFriend then
        row.name:SetTextColor(1, 1, 1)
    else
        row.name:SetTextColor(0.51, 0.77, 1)
    end
    row.name:SetAlpha(friend.online and 1 or 0.55)

    local character = friend.character
    if friend.online and character ~= "" then
        local level = game.characterLevel
        if IsReadable(level) and type(level) == "number" and level > 0 then
            character = character .. "  " .. ColorText("ffffff", "Lvl " .. level)
        end
        local className = ReadText(game.className)
        if className ~= "" then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[ReadText(game.classFilename)]
            character = character .. "  " .. (color and color:WrapTextInColorCode(className) or className)
        end
    else
        character = ""
    end
    row.character:SetText(character)

    local details = GetRowDetails(game)
    local location = ReadText(game.areaName)
    if location == "" and not details then
        location = ReadText(game.richPresence)
    end
    if details and location ~= "" then
        details = details .. "  ·  " .. location
    end
    local status = friend.online and (details or location) or (FRIENDS_LIST_OFFLINE or "Offline")
    if character == "" then
        row.character:SetText(status)
        row.details:SetText("")
        row.character:SetTextColor(0.63, 0.65, 0.67)
    else
        row.character:SetTextColor(1, 0.82, 0)
        row.details:SetText(status)
    end
    row.details:SetTextColor(0.63, 0.65, 0.67)

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

local function CreateFriendsView(socialFrame, nativeView)
    local window = CreateFrame("Frame", nil, socialFrame, "BackdropTemplate")
    window:SetAllPoints(nativeView)
    window:SetFrameLevel(nativeView:GetFrameLevel() + 20)
    window:EnableMouse(true)
    window:EnableMouseWheel(true)
    window:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    window:SetBackdropColor(0.012, 0.012, 0.016, 1)
    window:Hide()

    local launcher = CreateFrame("Button", nil, socialFrame, "UIPanelButtonTemplate")
    launcher:SetFrameLevel(window:GetFrameLevel())
    launcher:SetSize(101, 24)
    launcher:SetPoint("BOTTOMRIGHT", nativeView, "BOTTOMRIGHT", -8, 14)
    launcher:SetText("Better Friends")
    launcher:Hide()

    local search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 20, -47)
    search:SetPoint("TOPRIGHT", -16, -47)
    search:SetHeight(22)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(SEARCH or "Search")

    local divider = window:CreateTexture(nil, "BORDER")
    divider:SetAtlas("perks-divider-short")
    divider:SetPoint("TOPLEFT", 5, -75)
    divider:SetPoint("TOPRIGHT", -5, -75)
    divider:SetHeight(3)

    local scroll = CreateFrame("ScrollFrame", "BetterFriendsListScrollFrame", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -79)
    scroll:SetPoint("BOTTOMRIGHT", -31, 15)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)
    content:SetWidth(math.max(1, scroll:GetWidth()))
    scroll:SetScrollChild(content)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOP", 0, -25)
    empty:SetText("No friends to display.")

    local activeTab = 1
    local rows, buttons, headers = {}, {}, {}
    local collapsed = {}
    local showingBlizzard = false
    local function UpdateVisibility()
        local friendsVisible = nativeView:IsVisible() and not C_SocialRestrictions.IsFriendsDisabled()
        window:SetShown(friendsVisible and not showingBlizzard)
        launcher:SetShown(friendsVisible and showingBlizzard)
    end

    local function Render(groups)
        local rowIndex, offset = 0, 7
        local hasFriends = false
        for _, section in ipairs(sections) do
            local friends = groups[section.key]
            local header = headers[section.key]
            header:SetShown(#friends > 0)
            if #friends > 0 then
                hasFriends = true
                local online = 0
                for _, friend in ipairs(friends) do
                    if friend.online then
                        online = online + 1
                    end
                end
                header.label:SetText(("%s  %d/%d"):format(section.label, online, #friends))
                local isCollapsed = collapsed[section.key]
                header.icon:SetAtlas(isCollapsed and "common-button-list-plus" or "common-button-list-minus", true)
                PositionRow(header, offset)
                offset = offset + 30
                if not isCollapsed then
                    for _, friend in ipairs(friends) do
                        rowIndex = rowIndex + 1
                        local row = rows[rowIndex] or CreateRow(content)
                        rows[rowIndex] = row
                        PositionRow(row, offset)
                        DisplayFriend(row, friend)
                        offset = offset + 73
                    end
                end
            end
        end
        for index = rowIndex + 1, #rows do
            rows[index]:Hide()
        end
        content:SetHeight(offset)
        empty:SetShown(not hasFriends)
    end

    local groups
    local function Refresh()
        local query = search:GetText():lower():match("^%s*(.-)%s*$")
        groups = CollectFriends(tabs[activeTab], query)
        Render(groups)
    end

    for _, section in ipairs(sections) do
        local key = section.key
        local header = CreateSectionHeader(content)
        header:Hide()
        header:SetScript("OnClick", function()
            collapsed[key] = not collapsed[key]
            Render(groups)
            scroll.ScrollBar:SetValue(math.min(scroll.ScrollBar:GetValue(), scroll:GetVerticalScrollRange()))
        end)
        headers[key] = header
    end

    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(index == 1 and 56 or 101, 24)
        if index == 1 then
            button:SetPoint("TOPLEFT", 13, -11)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 5, 0)
        end
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

    local blizzardTab = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    blizzardTab:SetSize(94, 24)
    blizzardTab:SetPoint("LEFT", buttons[#buttons], "RIGHT", 5, 0)
    blizzardTab:SetText("Blizzard")
    blizzardTab:SetScript("OnClick", function()
        showingBlizzard = true
        UpdateVisibility()
    end)

    local function ShowBetterFriends()
        showingBlizzard = false
        UpdateVisibility()
    end
    launcher:SetScript("OnClick", ShowBetterFriends)

    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        scroll.ScrollBar:SetValue(0)
        Refresh()
    end)
    window:SetScript("OnShow", Refresh)
    window:SetScript("OnHide", function()
        search:ClearFocus()
    end)
    window:SetScript("OnEvent", function(self)
        if self:IsVisible() then
            Refresh()
        end
    end)
    window:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    window:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    window:RegisterEvent("BN_CONNECTED")
    window:RegisterEvent("BN_DISCONNECTED")
    -- Observe Blizzard's view changes without modifying its frames or refresh path.
    hooksecurefunc(socialFrame, "SetActiveContentFrame", UpdateVisibility)
    UpdateVisibility()
    return ShowBetterFriends
end

local showBetterFriends
local function TryInstall()
    local socialFrame = SocialUIFrame
    if socialFrame and socialFrame.FriendsList and socialFrame.SetActiveContentFrame then
        showBetterFriends = CreateFriendsView(socialFrame, socialFrame.FriendsList)
        return true
    end
end

if not TryInstall() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        if TryInstall() then
            self:UnregisterAllEvents()
        end
    end)
end

SLASH_BETTERFRIENDSLIST1 = "/bfl"
SLASH_BETTERFRIENDSLIST2 = "/betterfriendslist"
SlashCmdList.BETTERFRIENDSLIST = function()
    if showBetterFriends and SocialUIFrame.FriendsList:IsVisible() then
        showBetterFriends()
    else
        print("Better Friends List: open the Friends tab in the Social window.")
    end
end
