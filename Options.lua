local _, Addon = ...
local window

local function Settings()
    if type(BetterFriendsListDB) ~= "table" then
        BetterFriendsListDB = {}
    end
    if type(BetterFriendsListDB.sections) ~= "table" then
        BetterFriendsListDB.sections = {}
    end
    return BetterFriendsListDB.sections
end

local function ValidColor(value)
    return type(value) == "string" and #value == 6 and value:match("^%x+$") ~= nil
end

function Addon.ColorRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

function Addon.GetSectionStyle(key)
    local settings = Settings()
    if type(settings[key]) ~= "table" then
        settings[key] = {}
    end
    local style = settings[key]
    if type(style.label) ~= "string" or style.label:match("^%s*$") then
        style.label = nil
    end
    for _, field in ipairs({ "textColor", "backgroundColor" }) do
        if not ValidColor(style[field]) then
            style[field] = nil
        end
    end
    return style
end

local function Refresh()
    if Addon.Refresh then
        Addon.Refresh()
    end
    if window then
        window:Update()
    end
end

local function ChooseColor(key, field)
    if not ColorPickerFrame then
        C_AddOns.LoadAddOn("Blizzard_ColorPickerFrame")
    end
    local style = Addon.GetSectionStyle(key)
    local original = style[field]
    local r, g, b = Addon.ColorRGB(original or (field == "textColor" and "ffffff" or "261a0d"))
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            style[field] = ("%02x%02x%02x"):format(math.floor(red * 255 + 0.5),
                math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
            Refresh()
        end,
        cancelFunc = function()
            style[field] = original
            Refresh()
        end,
    })
end

local function ColorButton(parent, section, field, label, x)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, -28)
    button:SetSize(91, 23)
    button:SetText(label)
    button:SetScript("OnClick", function()
        ChooseColor(section.key, field)
    end)
    button.swatch = button:CreateTexture(nil, "OVERLAY")
    button.swatch:SetPoint("RIGHT", -5, 0)
    button.swatch:SetSize(8, 8)
    return button
end

function Addon.OpenOptions()
    if not window then
        window = CreateFrame("Frame", "BetterFriendsListOptions", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(550, 520)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true)
        window.TitleText:SetText("Better Friends List — Sections")
        table.insert(UISpecialFrames, "BetterFriendsListOptions")
        window.rows = {}

        for index, section in ipairs(Addon.sections) do
            local row = CreateFrame("Frame", nil, window)
            row:SetPoint("TOPLEFT", 20, -40 - (index - 1) * 72)
            row:SetSize(510, 62)
            local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOPLEFT", 0, 0)
            title:SetText(section.label)
            row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.input:SetPoint("TOPLEFT", 5, -28)
            row.input:SetSize(205, 23)
            row.input:SetAutoFocus(false)
            row.input:SetMaxLetters(80)
            local function Save(self)
                local value = self:GetText():gsub("|", ""):match("^%s*(.-)%s*$")
                Addon.GetSectionStyle(section.key).label = value ~= "" and value or nil
                Refresh()
            end
            row.input:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
            end)
            row.input:SetScript("OnEditFocusLost", Save)
            row.input:SetScript("OnEscapePressed", function(self)
                self:SetText(Addon.GetSectionStyle(section.key).label or section.label)
                self:ClearFocus()
            end)
            row.textColor = ColorButton(row, section, "textColor", "Text", 219)
            row.backgroundColor = ColorButton(row, section, "backgroundColor", "Background", 314)
            local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            reset:SetPoint("TOPLEFT", 409, -28)
            reset:SetSize(76, 23)
            reset:SetText("Reset")
            reset:SetScript("OnClick", function()
                if ColorPickerFrame then
                    ColorPickerFrame:Hide()
                end
                Settings()[section.key] = nil
                Refresh()
            end)
            row.key, row.label = section.key, section.label
            window.rows[index] = row
        end

        local help = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        help:SetPoint("BOTTOMLEFT", 22, 22)
        help:SetText("Press Enter to save a name. Clear it to restore the default.")
        function window:Update()
            for _, row in ipairs(self.rows) do
                local style = Addon.GetSectionStyle(row.key)
                if not row.input:HasFocus() then
                    row.input:SetText(style.label or row.label)
                end
                row.textColor.swatch:SetColorTexture(Addon.ColorRGB(style.textColor or "ffffff"))
                row.backgroundColor.swatch:SetColorTexture(Addon.ColorRGB(style.backgroundColor or "261a0d"))
            end
        end
        window:SetScript("OnShow", window.Update)
    end
    window:Update()
    window:Show()
end
