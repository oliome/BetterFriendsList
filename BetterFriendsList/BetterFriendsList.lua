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

local function UpdateFriendRow(row)
    local data = row.elementData
    local account = data and data.accountInfo
    if not IsReadableTable(account) or not row.Location then
        return
    end

    local game = account.gameAccountInfo
    local details = GetRowDetails(game)
    if details then
        local location = ReadText(row.Location:GetText())
        row.Location:SetText(location == "" and details or details .. "  ·  " .. location)
    end

    local holder = row.GameIconHolder
    local atlas
    if details and holder and holder:IsShown() and IsReadable(game.wowProjectID)
        and game.wowProjectID == FOREVER_PROJECT then
        atlas = factionAtlases[ReadText(game.factionName)]
    end

    local crest = row.BetterFriendsListFactionCrest
    if not atlas then
        if crest then
            crest:Hide()
        end
        return
    end

    if not crest then
        crest = holder:CreateTexture(nil, "ARTWORK")
        crest:SetPoint("RIGHT", holder, "LEFT", -3, 0)
        row.BetterFriendsListFactionCrest = crest
    end
    local size = holder:GetHeight()
    crest:SetAtlas(atlas, false)
    crest:SetSize(size, size)
    crest:Show()

    -- Reserve space for the crest and let Blizzard recalculate text truncation.
    local rightOffset = row.textHolderRightXOffset
    row.textHolderRightXOffset = rightOffset - size - 3
    row:LayoutScaledContent()
    row.textHolderRightXOffset = rightOffset
end

local function MatchesTab(levels, account)
    return IsReadableTable(account) and IsReadable(account.friendLevel)
        and levels[account.friendLevel]
end

local function AddFriendTabs(view)
    local scrollBox = view.ScrollBox
    local tabBar = CreateFrame("Frame", nil, view)
    tabBar:SetPoint("TOPLEFT", 10, -8)
    tabBar:SetPoint("TOPRIGHT", -10, -8)
    tabBar:SetHeight(26)

    view.FilterBar:ClearAllPoints()
    view.FilterBar:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", -10, 0)
    view.FilterBar:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 10, 0)

    local activeTab = 1
    local buttons = {}
    local empty = scrollBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 12, -28)
    empty:SetPoint("TOPRIGHT", -12, -28)
    empty:Hide()

    local function UpdateTabs()
        for index, button in ipairs(buttons) do
            local selected = index == activeTab
            button.Selected:SetShown(selected)
            button.Label:SetTextColor(1, selected and 0.87 or 0.79, selected and 0.49 or 0.28)
        end
    end

    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, tabBar)
        button:SetSize(index == 1 and 111 or 80, 26)
        button:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
        button:GetNormalTexture():SetVertexColor(0.12, 0.10, 0.08, 0.9)
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        button:GetHighlightTexture():SetVertexColor(0.88, 0.64, 0.27, 0.17)
        button.Selected = button:CreateTexture(nil, "ARTWORK")
        button.Selected:SetColorTexture(1, 0.7, 0.27)
        button.Selected:SetPoint("BOTTOMLEFT", 4, 0)
        button.Selected:SetPoint("BOTTOMRIGHT", -4, 0)
        button.Selected:SetHeight(2)
        button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.Label:SetPoint("CENTER", 0, 1)
        button.Label:SetText(tab.label)
        if index == 1 then
            button:SetPoint("TOPLEFT", tabBar)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 3, 0)
        end
        buttons[index] = button

        button:SetScript("OnClick", function()
            if activeTab ~= index then
                activeTab = index
                UpdateTabs()
                view:Refresh(ScrollBoxConstants.DiscardScrollPosition)
            end
        end)
    end

    -- Filter search results before Blizzard creates headers and counts favorites.
    local insertFriends = view.InsertFriendsIntoDataProvider
    function view:InsertFriendsIntoDataProvider(provider, friends)
        local levels = tabs[activeTab].levels
        if not levels then
            return insertFriends(self, provider, friends)
        end

        local matchingFriends = {}
        for _, friendIndex in ipairs(friends) do
            if MatchesTab(levels, C_BattleNet.GetFriendAccountInfo(friendIndex)) then
                matchingFriends[#matchingFriends + 1] = friendIndex
            end
        end
        return insertFriends(self, provider, matchingFriends)
    end

    ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row)
        UpdateFriendRow(row)
    end, tabBar)

    hooksecurefunc(scrollBox, "SetDataProvider", function(self)
        empty:SetText("No friends to display in " .. tabs[activeTab].label .. ".")
        empty:SetShown(self:GetDataProviderSize() == 0)
    end)

    UpdateTabs()
    if view:IsVisible() then
        view:Refresh(ScrollBoxConstants.DiscardScrollPosition)
    end
end

local function TryInstall()
    local view = SocialUIFrame and SocialUIFrame.FriendsList
    if not view or not view.InsertFriendsIntoDataProvider or not view.FilterBar then
        return false
    end

    AddFriendTabs(view)
    return true
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
