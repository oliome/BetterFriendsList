local _, Addon = ...
local FOREVER_PROJECT = WOW_PROJECT_CAMELOT or 18
if WOW_PROJECT_ID ~= FOREVER_PROJECT then
    return
end

local friendLevel = Enum.BattleNetFriendLevel

local sections = {
    { key = "Normal", label = "WoW: Forever — Normal" },
    { key = "PvP", label = "WoW: Forever — PvP" },
    { key = "RP", label = "WoW: Forever — RP" },
    { key = "RP-PvP", label = "WoW: Forever — RP-PvP" },
    { key = "unknown", label = "WoW: Forever — Unknown Ruleset" },
    { key = "other", label = "Other" },
}
Addon.sections = sections

local function GetSectionOrder(playerRuleset)
    local ordered = {}
    for _, section in ipairs(sections) do
        if section.key == playerRuleset then
            ordered[1] = section
            break
        end
    end
    for _, section in ipairs(sections) do
        if section.key ~= playerRuleset then
            ordered[#ordered + 1] = section
        end
    end
    return ordered
end

local statusFilters = {
    { key = "online", label = SOCIAL_UI_PRESENCE_TYPE_LABEL_ONLINE or "Online" },
    { key = "away", label = SOCIAL_UI_PRESENCE_TYPE_LABEL_AWAY or "Away" },
    { key = "busy", label = SOCIAL_UI_PRESENCE_TYPE_LABEL_BUSY or "Busy" },
    { key = "offline", label = SOCIAL_UI_PRESENCE_TYPE_LABEL_OFFLINE or "Offline" },
    { key = "queued", label = SOCIAL_UI_FRIENDS_LIST_IN_QUEUE_FILTER_LABEL or "In Queue" },
    { key = "joinable", label = SOCIAL_UI_FRIENDS_LIST_AVAILABLE_FOR_QUEUE_FILTER_LABEL or "Available for Queue" },
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
    roleplay = "RP",
    roleplaying = "RP",
    roleplaypvp = "RP-PvP",
    roleplayingpvp = "RP-PvP",
    rpvp = "RP-PvP",
    normale = "Normal",
    jcj = "PvP",
    jxj = "PvP",
    jdr = "RP",
    gdr = "RP",
    rollenspiel = "RP",
    jdrjcj = "RP-PvP",
    gdrpvp = "RP-PvP",
    rollenspielpvp = "RP-PvP",
    ["일반"] = "Normal",
    ["普通"] = "Normal",
    ["一般"] = "Normal",
    ["전쟁"] = "PvP",
    ["역할극"] = "RP",
    ["角色扮演"] = "RP",
    ["역할극전쟁"] = "RP-PvP",
    ["角色扮演pvp"] = "RP-PvP",
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

local function NormalizeRulesetText(value)
    return ReadText(value):gsub(" ", " "):gsub(" ", " "):gsub("‐", "-"):gsub("‑", "-")
        :gsub("–", "-"):gsub("—", "-"):gsub("[A-Z]", function(letter)
            return string.char(letter:byte() + 32)
        end)
end

local function ParseRealmRuleset(value, requireForeverRealm)
    local realm = NormalizeRulesetText(value):match("^%s*(.-)%s*$")
    local compactRealm = realm:gsub("[%s%-:,]", "")
    local suffix = compactRealm:match("^camwow%a+%d+realm%d+(.+)$")
    if suffix then
        -- Live realm labels can append a parenthesized type and population.
        local label = suffix:match("^(.-)%(") or suffix
        return rulesets[label]
    end

    if requireForeverRealm then
        return nil
    end
    local legacyType = compactRealm:match("^classicbeta([a-z]+)%d*$")
    local label = compactRealm:gsub("^wowforever", ""):gsub("^forever", ""):gsub("^realm", "")
    return rulesets[legacyType or label]
end

local function GetFriendRuleset(game)
    local ruleset = ParseRealmRuleset(game.realmName) or ParseRealmRuleset(game.realmDisplayName)
    if ruleset then
        return ruleset
    end

    local presence = NormalizeRulesetText(game.richPresence)
    local normalized = presence:gsub("%s*·%s*", " - "):gsub("%s+%-%s+", " - ")
    local product, detail = normalized:match("^%s*(.-) %- (.+)$")
    if product == "forever" or product == "wow forever" or product == "wow: forever" then
        local label = detail:match("^(.-) %- ") or detail
        local ruleset = ParseRealmRuleset(label)
        if ruleset then
            return ruleset
        end
    end
    return ParseRealmRuleset(normalized:match(".* %- (camwow.+)$"), true)
end

local function ReadGameRule(name)
    local rule = Enum.GameRule and Enum.GameRule[name]
    if not rule or not C_GameRules or not C_GameRules.IsGameRuleActive then
        return nil
    end
    local ok, active = pcall(C_GameRules.IsGameRuleActive, rule)
    if ok and IsReadable(active) and type(active) == "boolean" then
        return active
    end
end

local function GetPlayerRuleset()
    local ruleset = ParseRealmRuleset(GetRealmName()) or ParseRealmRuleset(GetNormalizedRealmName())
    if ruleset then
        return ruleset
    end
    local pvp, rp = ReadGameRule("PvPRuleset"), ReadGameRule("RPRuleset")
    if pvp ~= nil and rp ~= nil and ReadGameRule("HardcoreRuleset") == false then
        if pvp then
            return rp and "RP-PvP" or "PvP"
        end
        return rp and "RP" or "Normal"
    end
end

local function GetRefreshedRuleset(game)
    local id = game.gameAccountID
    if not IsReadable(id) or type(id) ~= "number" or id <= 0 then
        return nil
    end
    local fresh = C_BattleNet.GetGameAccountInfoByID(id)
    if not IsReadableTable(fresh) or not IsReadable(fresh.gameAccountID) or fresh.gameAccountID ~= id
        or ReadText(fresh.clientProgram) ~= BNET_CLIENT_WOW or not IsReadable(fresh.wowProjectID)
        or fresh.wowProjectID ~= FOREVER_PROJECT or not IsReadable(fresh.isOnline) or not fresh.isOnline then
        return nil
    end
    local guid, freshGuid = ReadText(game.playerGuid), ReadText(fresh.playerGuid)
    if guid ~= "" and freshGuid ~= "" and guid ~= freshGuid then
        return nil
    end
    return GetFriendRuleset(fresh)
end

local function GetRealmKey(game)
    local region, realm = game.regionID, game.realmID
    if IsReadable(region) and type(region) == "number" and region > 0
        and IsReadable(realm) and type(realm) == "number" and realm > 0 then
        return region .. ":" .. realm
    end
end

local function ResolveMissingRulesets(groups)
    local realmRulesets = {}
    for _, section in ipairs(sections) do
        for _, friend in ipairs(groups[section.key]) do
            local key = friend.ruleset and GetRealmKey(friend.game)
            if key then
                local previous = realmRulesets[key]
                realmRulesets[key] = (previous == nil or previous == friend.ruleset) and friend.ruleset or false
            end
        end
    end
    local unresolved = {}
    local playerRuleset = GetPlayerRuleset()
    local playerRealm = GetRealmID()
    for _, friend in ipairs(groups.unknown) do
        local game = friend.game
        local key = GetRealmKey(game)
        local ruleset = key and realmRulesets[key]
        if not ruleset and playerRuleset and IsReadable(playerRealm) and type(playerRealm) == "number"
            and playerRealm > 0 and IsReadable(game.realmID) and game.realmID == playerRealm
            and IsReadable(game.isInCurrentRegion) and game.isInCurrentRegion == true then
            ruleset = playerRuleset
        end
        if ruleset then
            friend.ruleset = ruleset
            local target = groups[ruleset]
            target[#target + 1] = friend
        else
            unresolved[#unresolved + 1] = friend
        end
    end
    groups.unknown = unresolved
end

local function ColorText(color, text)
    return "|cff" .. color .. text .. "|r"
end

local function GetRowDetails(game, friendRuleset, playerRuleset)
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

    local rulesetText = friendRuleset or "Ruleset unknown"
    if friendRuleset and friendRuleset == playerRuleset then
        rulesetText = ColorText("91e3ad", friendRuleset)
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

local function MatchesStatus(filters, friend)
    if not next(filters) then
        return true
    end
    if (filters.offline and not friend.online) or (friend.online
        and (filters.online or (filters.away and friend.away) or (filters.busy and friend.busy))) then
        return true
    end
    if not friend.online or not (filters.queued or filters.joinable) or not C_SocialQueue.IsSystemSupported() then
        return false
    end
    local guid = ReadText(friend.game.playerGuid)
    local group = guid ~= "" and C_SocialQueue.GetGroupForPlayer(guid)
    if not IsReadable(group) or not group then
        return false
    end
    local canJoin, numQueues = C_SocialQueue.GetGroupInfo(group)
    return IsReadable(numQueues) and type(numQueues) == "number" and numQueues > 0
        and (filters.queued or (filters.joinable and IsReadable(canJoin) and canJoin))
end

local function MatchesTags(filters, tags)
    if not next(filters) then
        return true
    end
    if IsReadableTable(tags) then
        for _, tag in ipairs(tags) do
            if IsReadable(tag) and filters[tag] then
                return true
            end
        end
    end
    return false
end

local function CollectFriends(search, filters)
    local groups = {}
    for _, section in ipairs(sections) do
        groups[section.key] = {}
    end
    local total = BNGetNumFriends()
    if not IsReadable(total) or type(total) ~= "number" then
        return groups, 0, 0
    end

    local loaded = 0
    for index = 1, total do
        local account = C_BattleNet.GetFriendAccountInfo(index)
        if IsReadableTable(account) then
            loaded = loaded + 1
            local level = account.friendLevel
            local game = account.gameAccountInfo
            game = IsReadableTable(game) and game or {}
            local name = GetAccountName(account, game)
            local sortName = name:lower()
            local character = ReadText(game.characterName)
            local battleTag = ReadText(account.battleTag)
            if (search == "" or sortName:find(search, 1, true)
                or character:lower():find(search, 1, true) or battleTag:lower():find(search, 1, true))
                and MatchesTags(filters.tags, account.friendTags) then
                local online = IsReadable(game.isOnline) and game.isOnline == true
                local isWoWFriend = IsReadable(level) and level == friendLevel.Title
                local isForever = online and ReadText(game.clientProgram) == BNET_CLIENT_WOW
                    and IsReadable(game.wowProjectID) and game.wowProjectID == FOREVER_PROJECT
                local ruleset = isForever and (GetFriendRuleset(game) or GetRefreshedRuleset(game)) or nil
                local friend = {
                    bnetAccountID = account.bnetAccountID,
                    accountName = account.accountName,
                    name = name,
                    sortName = sortName,
                    character = character,
                    game = game,
                    online = online,
                    isWoWFriend = isWoWFriend,
                    ruleset = ruleset,
                    away = (IsReadable(account.isAFK) and account.isAFK == true)
                        or (IsReadable(game.isGameAFK) and game.isGameAFK == true),
                    busy = (IsReadable(account.isDND) and account.isDND == true)
                        or (IsReadable(game.isGameBusy) and game.isGameBusy == true),
                }
                if MatchesStatus(filters.status, friend) then
                    local key = isForever and (ruleset or "unknown") or "other"
                    local rows = groups[key]
                    rows[#rows + 1] = friend
                end
            end
        end
    end

    ResolveMissingRulesets(groups)
    Addon.unknownRulesets = groups.unknown
    for _, rows in pairs(groups) do
        table.sort(rows, function(a, b)
            if a.isWoWFriend ~= b.isWoWFriend then
                return a.isWoWFriend
            end
            if a.online ~= b.online then
                return a.online
            end
            return a.sortName < b.sortName
        end)
    end
    return groups, total, loaded
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
    header.icon = header:CreateTexture(nil, "ARTWORK")
    header.icon:SetPoint("RIGHT", -7, 0)
    header.label:SetPoint("LEFT", 8, 0)
    header.label:SetPoint("RIGHT", header.icon, "LEFT", -6, 0)
    header.label:SetJustifyH("LEFT")
    header.label:SetWordWrap(false)
    return header
end

local function LayoutFriendLink(link, height)
    if height <= 0 then
        return
    end
    local text = link.Text
    local size = math.max(1, math.ceil(height))
    text:SetFont(STANDARD_TEXT_FONT, size, "")
    while text:GetLineHeight() > height and size > 1 do
        size = math.max(1, math.min(size - 1, math.floor(size * height / text:GetLineHeight())))
        text:SetFont(STANDARD_TEXT_FONT, size, "")
    end
    text:SetPoint("BOTTOMRIGHT", link, "BOTTOMRIGHT", size * 2 + 12, 0)
end

local function BindFriendLink(row, friend)
    local link, id, name = row.FriendLink, friend.bnetAccountID, friend.accountName
    row.friendData = friend
    if link.pressedID and link.pressedID ~= id then
        link:Hide()
        row:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("RightButton") then
                self:SetScript("OnUpdate", nil)
                link.pressedID = nil
                BindFriendLink(self, self.friendData)
            end
        end)
        return
    end
    local validID = IsReadable(id) and type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
    local validName = not IsReadable(name) or (type(name) == "string" and name ~= ""
        and not name:find("[:%c]") and (not name:find("|", 1, true) or name:match("^|K[%w]+|k$")))
    if not validID or not validName then
        link:Hide()
        link.Text:SetText("")
        link.accountID = nil
        return
    end
    -- Blizzard's inherited OnHyperlinkClick handles the hardware click in its own context.
    -- SetFormattedText also supports protected account names without concatenating them.
    link.Text:SetFormattedText("|HBNplayer:%s:%d:0:BN_WHISPER:%s|h%s|h",
        name, id, name, string.rep("M", 64))
    link.accountID = id
    link:Show()
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(70)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.hordeBackground = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hordeBackground:SetPoint("TOPLEFT", 1, -1)
    row.hordeBackground:SetPoint("BOTTOMRIGHT", -1, 1)
    row.hordeBackground:SetColorTexture(1, 1, 1)
    row.hordeBackground:SetGradient("HORIZONTAL", CreateColor(0.23, 0.055, 0.06), CreateColor(0.105, 0.022, 0.028))
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

    local link = CreateFrame("Frame", nil, row, "BetterFriendsListFriendLinkTemplate")
    link:SetAllPoints()
    link:SetClipsChildren(true)
    link:SetScript("OnHyperlinkEnter", nil)
    link:SetScript("OnHyperlinkLeave", nil)
    link.Text = link:CreateFontString(nil, "ARTWORK")
    link.Text:SetJustifyH("LEFT")
    link.Text:SetJustifyV("MIDDLE")
    link.Text:SetWordWrap(false)
    link.Text:SetAlpha(0)
    link.Text:SetPoint("TOPLEFT")
    link:SetScript("OnSizeChanged", function(self, _, height)
        LayoutFriendLink(self, height)
    end)
    link:HookScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            self.pressedID = self.accountID
        end
    end)
    link:HookScript("OnMouseUp", function(self)
        self.pressedID = nil
    end)
    row.FriendLink = link
    LayoutFriendLink(link, 70)
    return row
end

local function DisplayFriend(row, friend, playerRuleset)
    local game = friend.game
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[ReadText(game.classFilename)]
    local client = ReadText(game.clientProgram)
    local faction = client == BNET_CLIENT_WOW and ReadText(game.factionName)
    local background = friend.isWoWFriend and faction ~= "Alliance" and "friends-card-default" or "friends-card-battleNet"
    row.background:SetAtlas(friend.online and background or "friends-card-disabled")
    row.hordeBackground:SetShown(friend.online and faction == "Horde")
    local presence = friend.away and "away" or (friend.busy and "busy" or "online")
    row.presence:SetAtlas("friends-status-" .. (friend.online and presence or "offline"))
    row.name:SetText(friend.name)
    if friend.isWoWFriend and classColor then
        row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    elseif friend.isWoWFriend then
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
            character = character .. "  " .. (classColor and classColor:WrapTextInColorCode(className) or className)
        end
    else
        character = ""
    end
    row.character:SetText(character)

    local details = GetRowDetails(game, friend.ruleset, playerRuleset)
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
        if friend.isWoWFriend and classColor then
            row.character:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            row.character:SetTextColor(1, 0.82, 0)
        end
        row.details:SetText(status)
    end
    row.details:SetTextColor(0.63, 0.65, 0.67)

    local showIcon = friend.online and client ~= ""
    if showIcon then
        local subIcon = ReadText(game.subIcon)
        C_Texture.SetTitleIconTexture(row.gameIcon, client, Enum.TitleIconVersion.Small, subIcon ~= "" and subIcon or nil)
    end
    row.gameIcon:SetShown(showIcon)

    local isForever = IsReadable(game.wowProjectID) and game.wowProjectID == FOREVER_PROJECT
    local crest = showIcon and client == BNET_CLIENT_WOW and isForever
        and factionAtlases[faction]
    if crest then
        row.crest:SetAtlas(crest, false)
    end
    row.crest:SetShown(not not crest)
    BindFriendLink(row, friend)
    row:Show()
end

local function SetupFilterMenu(filter, filters, refresh)
    local function IsSelected(option)
        return option.values[option.key] == true
    end
    local function Toggle(option)
        local values, key = option.values, option.key
        if values[key] then
            values[key] = nil
        else
            values[key] = true
        end
        refresh()
    end
    local function AddTags(menu, title, tags)
        menu:CreateTitle(title)
        for _, tag in ipairs(tags) do
            menu:CreateCheckbox(SocialUIUtil.GetLabelForBattleNetFriendTag(tag), IsSelected, Toggle,
                { values = filters.tags, key = tag })
        end
    end

    function filter:GenerateFilterMenu(root)
        local statusMenu = root:CreateButton(SOCIAL_FILTER_DROPDOWN_STATUS or "Status")
        for _, option in ipairs(statusFilters) do
            statusMenu:CreateCheckbox(option.label, IsSelected, Toggle, { values = filters.status, key = option.key })
        end

        if C_BattleNet.AreFriendTagsEnabled() then
            local tagsMenu = root:CreateButton(SOCIAL_FILTER_DROPDOWN_TAGS or "Tags")
            AddTags(tagsMenu, SOCIAL_UI_BATTLE_NET_FRIEND_TAG_LABEL_INTERESTS or "Interests",
                SocialUIUtil.GetSupportedBattleNetFriendTagInterestsForCurrentGameType())
            tagsMenu:CreateDivider()
            AddTags(tagsMenu, SOCIAL_UI_BATTLE_NET_FRIEND_TAG_ROLES_LABEL or "Roles",
                SocialUIUtil.GetSupportedBattleNetFriendTagRolesForCurrentGameType())
        end
        root:CreateDivider()
        root:CreateButton("Section settings", function()
            Addon.OpenOptions()
        end)
    end
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

    local filter = CreateFrame("DropdownButton", nil, window, "SocialUISearchFilterDropdownTemplate")
    filter:SetPoint("TOPRIGHT", -15, -10)
    filter:SetSize(126, 30)
    local search = CreateFrame("EditBox", nil, window, "SocialUISearchBoxTemplate")
    search:SetPoint("LEFT", window, "TOPLEFT", 15, -25)
    search:SetPoint("RIGHT", filter, "LEFT", -10, 0)
    search:SetHeight(20)
    search:SetAutoFocus(false)

    local divider = window:CreateTexture(nil, "BORDER")
    divider:SetAtlas("perks-divider-short")
    divider:SetPoint("TOPLEFT", 8, -47)
    divider:SetPoint("TOPRIGHT", -8, -47)
    divider:SetHeight(3)

    local addFriend = CreateFrame("Button", nil, window, "SocialUIActionButtonTemplate")
    Mixin(addFriend, SocialUIAddFriendButtonMixin)
    addFriend:SetPoint("BOTTOM", 0, 12)
    addFriend.baseWidth = 206
    addFriend.maxWidth = 370
    addFriend:SetText(SOCIAL_UI_FRIENDS_LIST_ADD_FRIEND_BUTTON_LABEL or "Add New Friend")
    local footer = window:CreateTexture(nil, "BORDER")
    footer:SetAtlas("perks-divider-short")
    footer:SetPoint("BOTTOMLEFT", 5, 52)
    footer:SetPoint("BOTTOMRIGHT", -5, 52)
    footer:SetHeight(3)

    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", 14, -54)
    scroll:SetPoint("BOTTOMRIGHT", -27, 56)
    scroll:EnableMouseWheel(true)
    local scrollBar = CreateFrame("EventFrame", nil, window, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 5, -7)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5, 4)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
    scroll:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
        if self:GetVerticalScroll() > verticalRange then
            self:SetVerticalScroll(verticalRange)
        end
        scrollBar:SetShown(verticalRange > 0)
    end)
    scrollBar:Hide()
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

    local rows, headers = {}, {}
    local collapsed = {}
    local function IsSectionCollapsed(key, playerRuleset)
        if collapsed[key] ~= nil then
            return collapsed[key]
        end
        return key ~= playerRuleset
    end

    local filters = { status = {}, tags = {} }
    local showingBlizzard = false
    local Refresh
    local function UpdateVisibility()
        local friendsVisible = nativeView:IsVisible() and not C_SocialRestrictions.IsFriendsDisabled()
        local wasVisible = window:IsVisible()
        window:SetShown(friendsVisible and not showingBlizzard)
        launcher:SetShown(friendsVisible and showingBlizzard)
        if wasVisible and window:IsVisible() then
            Refresh()
        end
    end

    local function Render(groups)
        local rowIndex, offset = 0, 3
        local hasFriends = false
        local playerRuleset = GetPlayerRuleset()
        for _, section in ipairs(GetSectionOrder(playerRuleset)) do
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
                local style = Addon.GetSectionStyle(section.key)
                header.label:SetText(("%s  %d/%d"):format(style.label or section.label, online, #friends))
                header.label:SetTextColor(Addon.ColorRGB(style.textColor or "ffffff"))
                local background = header:GetNormalTexture()
                if style.backgroundColor then
                    background:SetColorTexture(Addon.ColorRGB(style.backgroundColor))
                else
                    header:SetNormalAtlas("common-button-list-collapseExpand")
                    background:SetVertexColor(1, 1, 1)
                end
                local isCollapsed = IsSectionCollapsed(section.key, playerRuleset)
                header.icon:SetAtlas(isCollapsed and "common-button-list-plus" or "common-button-list-minus", true)
                PositionRow(header, offset)
                offset = offset + 30
                if not isCollapsed then
                    for _, friend in ipairs(friends) do
                        rowIndex = rowIndex + 1
                        local row = rows[rowIndex] or CreateRow(content)
                        rows[rowIndex] = row
                        PositionRow(row, offset)
                        DisplayFriend(row, friend, playerRuleset)
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

    local groups, retryTimer
    local retryCount = 0
    local function CancelRetry()
        if retryTimer then
            retryTimer:Cancel()
            retryTimer = nil
        end
    end
    Refresh = function()
        CancelRetry()
        local query = search:GetText():lower():match("^%s*(.-)%s*$")
        local total, loaded
        groups, total, loaded = CollectFriends(query, filters)
        Render(groups)
        local connected = BNConnected()
        local pending = not connected or total == 0 or loaded < total
        if pending and retryCount < 10 then
            empty:SetText(connected and "Loading friends…" or "Connecting to Battle.net…")
            retryTimer = C_Timer.NewTimer(1, function()
                retryTimer = nil
                retryCount = retryCount + 1
                if window:IsVisible() then
                    Refresh()
                end
            end)
        else
            if not connected then
                empty:SetText("Battle.net is disconnected.")
            elseif loaded < total then
                empty:SetText("Friend data is still loading. Type /bfl refresh to retry.")
            else
                empty:SetText("No friends match your search or filters.")
            end
        end
        if not pending then
            retryCount = 0
        end
        Addon.status = ("Battle.net %s, friends %d, loaded %d"):format(connected and "connected" or "disconnected", total, loaded)
    end
    Addon.Refresh = function()
        if window:IsVisible() then
            retryCount = 0
            Refresh()
        end
    end

    for _, section in ipairs(sections) do
        local key = section.key
        local header = CreateSectionHeader(content)
        header:Hide()
        header:SetScript("OnClick", function()
            collapsed[key] = not IsSectionCollapsed(key, GetPlayerRuleset())
            Render(groups)
        end)
        headers[key] = header
    end

    local function ShowBlizzard(show)
        showingBlizzard = show
        UpdateVisibility()
    end

    launcher:SetScript("OnClick", function()
        ShowBlizzard(false)
    end)
    local function RefreshFromTop()
        if window:IsVisible() then
            scroll:SetVerticalScroll(0)
            Refresh()
        end
    end
    search.OnSearchTextChanged = RefreshFromTop
    SetupFilterMenu(filter, filters, RefreshFromTop)
    window:SetScript("OnShow", function()
        retryCount = 0
        Refresh()
    end)
    window:SetScript("OnHide", function()
        CancelRetry()
        search:ClearFocus()
    end)
    window:SetScript("OnEvent", function(self, event)
        if event == "BATTLE_NET_FRIEND_TAG_ENABLED_STATUS_UPDATED" and not C_BattleNet.AreFriendTagsEnabled() then
            wipe(filters.tags)
        end
        if self:IsVisible() and (event ~= "SOCIAL_QUEUE_UPDATE" or filters.status.queued or filters.status.joinable) then
            retryCount = 0
            Refresh()
        end
    end)
    window:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    window:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    window:RegisterEvent("BN_CONNECTED")
    window:RegisterEvent("BN_DISCONNECTED")
    window:RegisterEvent("BN_INFO_CHANGED")
    window:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    window:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    window:RegisterEvent("PLAYER_ENTERING_WORLD")
    window:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    window:RegisterEvent("BATTLE_NET_FRIEND_TAG_ENABLED_STATUS_UPDATED")
    window:RegisterEvent("SOCIAL_QUEUE_UPDATE")
    -- Observe Blizzard's view changes without modifying its frames or refresh path.
    hooksecurefunc(socialFrame, "SetActiveContentFrame", UpdateVisibility)
    UpdateVisibility()
    return ShowBlizzard
end

local showBlizzard
local function TryInstall()
    local socialFrame = SocialUIFrame
    if socialFrame and socialFrame.FriendsList and socialFrame.SetActiveContentFrame then
        showBlizzard = CreateFriendsView(socialFrame, socialFrame.FriendsList)
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
SlashCmdList.BETTERFRIENDSLIST = function(message)
    local command = ReadText(message):lower():match("^%s*(.-)%s*$")
    if command == "options" or command == "settings" then
        Addon.OpenOptions()
    elseif command == "rulesets" then
        print("Better Friends List rulesets: player realm=" .. ReadText(GetRealmName())
            .. ", realmID=" .. tostring(GetRealmID()))
        for index, friend in ipairs(Addon.unknownRulesets or {}) do
            if index > 3 then break end
            local game = friend.game
            for _, field in ipairs({"realmName", "realmDisplayName", "richPresence", "realmID", "regionID", "gameAccountID"}) do
                local value = game[field]
                local readable = IsReadable(value) and (type(value) == "string" or type(value) == "number")
                print("Unknown " .. index .. " " .. field .. "=" .. (readable and tostring(value):gsub("|", "||"):sub(1, 180) or "<unavailable>"))
            end
        end
    elseif command == "status" then
        print("Better Friends List " .. (C_AddOns.GetAddOnMetadata("BetterFriendsList", "Version") or "") .. ": "
            .. (Addon.status or "Open the Friends window to load the list."))
    elseif command == "refresh" and Addon.Refresh then
        Addon.Refresh()
    elseif showBlizzard and SocialUIFrame.FriendsList:IsVisible() then
        showBlizzard(ReadText(message):lower():match("^%s*blizzard%s*$") ~= nil)
    else
        print("Better Friends List: open the Friends tab in the Social window.")
    end
end
