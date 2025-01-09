local addonName, addon = ...

-- Saved variables
FriendManagerDB = FriendManagerDB or {}

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")

-- Register addon prefix for communication
C_ChatInfo.RegisterAddonMessagePrefix("FriendManager")

-- Helper function to print colored messages
local function PrintColoredMessage(message, color)
    local colorCodes = {
        red = "|cFFFF0000",
        green = "|cFF00FF00",
        teal = "|cFF00FFFF",
        reset = "|r"
    }
    print((colorCodes[color] or "") .. message .. colorCodes.reset)
end

-- Normalize profile names to ensure case-insensitive matching
local function NormalizeProfileName(profile)
    return profile and profile:lower() or nil
end

-- Find a profile by name (case-insensitive)
local function FindProfileByName(profile)
    local normalized = NormalizeProfileName(profile)
    for savedProfileName in pairs(FriendManagerDB) do
        if NormalizeProfileName(savedProfileName) == normalized then
            return savedProfileName
        end
    end
    return nil
end

-- Import friends list
local function ImportFriends()
    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            -- Ensure we store a list (table) of friends for each profile
            if not FriendManagerDB[info.name] then
                FriendManagerDB[info.name] = {}  -- Initialize as a table
            end
            table.insert(FriendManagerDB[info.name], info.name)
        end
    end
    print("Friends list imported!")
end

-- Save current friends list
local function SaveCurrentFriends(profile)
    -- If the profile is blank, prompt for a profile name
    if not profile or profile == "" then
        print("Please provide a profile name. Usage: /fm save <profileName>")
        return
    end

    -- Normalize profile name to lowercase to ensure case insensitivity
    profile = NormalizeProfileName(profile)

    -- Initialize an empty table for this profile
    FriendManagerDB[profile] = {}

    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            table.insert(FriendManagerDB[profile], info.name)
        end
    end
    PrintColoredMessage("Saved friends list as profile '" .. profile .. "'.", "green")
end

-- Delete a profile (case-sensitive)
local function DeleteProfile(profile)
    -- Don't normalize profile name for case-sensitivity
    if FriendManagerDB[profile] then
        FriendManagerDB[profile] = nil
        PrintColoredMessage("Deleted profile '" .. profile .. "'.", "red")
    else
        print("Profile '" .. profile .. "' does not exist.")
    end
end

-- Rename a profile
local function RenameProfile(oldProfile, newProfile)
    oldProfile = NormalizeProfileName(oldProfile)
    newProfile = NormalizeProfileName(newProfile)

    if not FriendManagerDB[oldProfile] then
        print("Profile '" .. oldProfile .. "' does not exist.")
        return
    end

    if FriendManagerDB[newProfile] then
        print("Profile '" .. newProfile .. "' already exists.")
        return
    end

    FriendManagerDB[newProfile] = FriendManagerDB[oldProfile]
    FriendManagerDB[oldProfile] = nil
    PrintColoredMessage("Renamed profile '" .. oldProfile .. "' to '" .. newProfile .. "'.", "teal")
end

-- List all saved profiles
local function ListProfiles()
    if next(FriendManagerDB) == nil then
        print("No saved profiles.")
    else
        PrintColoredMessage("Saved Profiles:", "teal")
        for profileName in pairs(FriendManagerDB) do
            print(profileName)
        end
    end
end

-- Show names in a specific profile
local function ShowProfileFriends(profile)
    profile = NormalizeProfileName(profile)  -- Normalize the profile name to lowercase

    if profile and profile ~= "" then
        -- Show names in the specified profile
        if FriendManagerDB[profile] and type(FriendManagerDB[profile]) == "table" then
            local message = "|cFF00FFFFFriends in profile|r " .. profile .. ":"
            print(message)
            for _, name in ipairs(FriendManagerDB[profile]) do
                print(" - " .. name)
            end
        else
            print("Profile '" .. profile .. "' does not exist.")
        end
    else
        print("You must provide a valid profile name to show friends.")
    end
end

-- Merges two profiles together (combining friendlists)
local function MergeProfileFriends(profile1, profile2, targetProfile)
    -- Normalize profile names
    profile1 = NormalizeProfileName(profile1)
    profile2 = NormalizeProfileName(profile2)
    targetProfile = NormalizeProfileName(targetProfile)

    -- Validate profiles
    if not FriendManagerDB[profile1] then
        print("Profile '" .. profile1 .. "' does not exist.")
        return
    end
    if not FriendManagerDB[profile2] then
        print("Profile '" .. profile2 .. "' does not exist.")
        return
    end
    if not targetProfile or targetProfile == "" then
        print("You must provide a valid target profile name.")
        return
    end

    -- Initialize the target profile if it doesn't already exist
    FriendManagerDB[targetProfile] = FriendManagerDB[targetProfile] or {}

    -- Use a set to avoid duplicate friends
    local mergedFriendsSet = {}

    -- Add friends from profile1
    for _, name in ipairs(FriendManagerDB[profile1]) do
        mergedFriendsSet[name] = true
    end

    -- Add friends from profile2
    for _, name in ipairs(FriendManagerDB[profile2]) do
        mergedFriendsSet[name] = true
    end

    -- Add existing friends from the target profile
    for _, name in ipairs(FriendManagerDB[targetProfile]) do
        mergedFriendsSet[name] = true
    end

    -- Populate the target profile with unique friends
    FriendManagerDB[targetProfile] = {}
    for name in pairs(mergedFriendsSet) do
        table.insert(FriendManagerDB[targetProfile], name)
    end

    -- Sort the merged friend list for consistency (optional)
    table.sort(FriendManagerDB[targetProfile])

    PrintColoredMessage(
        "Successfully merged profiles '" .. profile1 .. "' and '" .. profile2 .. "' into '" .. targetProfile .. "'.",
        "teal"
    )
end

-- Load friends from a profile (adding and removing based on the profile's friends)
local function LoadProfileFriends(profile)
    -- Normalize the profile name
    profile = NormalizeProfileName(profile)

    if not profile or profile == "" then
        print("You must provide a valid profile name to load friends.")
        return
    end

    -- Check if the profile exists
    if not FriendManagerDB[profile] then
        print("Profile '" .. profile .. "' does not exist.")
        return
    end

    -- Create a table of target friends from the profile
    local targetFriends = {}
    for _, name in ipairs(FriendManagerDB[profile]) do
        targetFriends[name] = true
    end

    -- Remove friends who are not in the profile
    local numFriends = C_FriendList.GetNumFriends()
    for i = numFriends, 1, -1 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name and not targetFriends[info.name] then
            C_FriendList.RemoveFriend(info.name)
            PrintColoredMessage("Removed '" .. info.name .. "' as it is not in profile '" .. profile .. "'.", "red")
        end
    end

    -- Add friends from the profile who are not already in the friend list
    for _, name in ipairs(FriendManagerDB[profile]) do
        local isFriend = false
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name == name then
                isFriend = true
                break
            end
        end
        if not isFriend then
            C_FriendList.AddFriend(name)
            PrintColoredMessage("Added '" .. name .. "' from profile '" .. profile .. "'.", "green")
        end
    end

    PrintColoredMessage("Loaded friends from profile '" .. profile .. "'.", "teal")
end

-- Share profile with another player
local function ShareProfile(profile, targetPlayer)
    profile = NormalizeProfileName(profile)

    if not profile or profile == "" then
        print("You must provide a valid profile name to share.")
        return
    end

    if not targetPlayer or targetPlayer == "" then
        print("You must provide a valid target player name.")
        return
    end

    if not FriendManagerDB[profile] then
        print("Profile '" .. profile .. "' does not exist.")
        return
    end

    local profileData = FriendManagerDB[profile]
    local serializedData = table.concat(profileData, ",")

    C_ChatInfo.SendAddonMessage("FriendManager", "SHARE_PROFILE:" .. profile .. ":" .. serializedData, "WHISPER", targetPlayer)
    PrintColoredMessage("Shared profile '" .. profile .. "' with " .. targetPlayer .. ".", "teal")
end

-- Import a shared profile
local function ImportSharedProfile(profile)
    profile = NormalizeProfileName(profile)

    if not profile or profile == "" then
        print("You must provide a valid profile name to import.")
        return
    end

    if not FriendManagerDB[profile] then
        print("Profile '" .. profile .. "' does not exist.")
        return
    end

    PrintColoredMessage("Imported shared profile '" .. profile .. "'.", "teal")
end

-- Handle incoming addon messages
local function OnAddonMessage(prefix, message, distribution, sender)
    if prefix == "FriendManager" then
        local command, profile, data = strsplit(":", message, 3)
        if command == "SHARE_PROFILE" and profile and data then
            local friendsList = { strsplit(",", data) }
            FriendManagerDB[profile] = friendsList
            PrintColoredMessage("Received profile '" .. profile .. "' from " .. sender .. ".", "teal")
        end
    end
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        FriendManagerDB = FriendManagerDB or {}
        print("FriendManager loaded! Use /fm commands to manage your friends.")
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, distribution, sender = ...
        OnAddonMessage(prefix, message, distribution, sender)
    end
end)

-- Create a frame for the Friend Manager UI
local friendManagerFrame = CreateFrame("Frame", "FriendManagerFrame", UIParent, "BackdropTemplate")
friendManagerFrame:SetSize(200, 285)  -- Adjusted frame size to fit more buttons
friendManagerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Center of the screen
friendManagerFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
friendManagerFrame:SetBackdropColor(0, 0, 0, 0.8)  -- Background color (black with transparency)
friendManagerFrame:SetBackdropBorderColor(0, 0, 0)  -- Border color
friendManagerFrame:SetMovable(true)
friendManagerFrame:EnableMouse(true)
friendManagerFrame:RegisterForDrag("LeftButton")
friendManagerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
friendManagerFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
friendManagerFrame:Hide()  -- Hide the frame after creation

-- Title text for the Friend Manager UI
local titleText = friendManagerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOP", friendManagerFrame, "TOP", 0, -10)
titleText:SetText("|cFF00FF00Friend Manager|r")  -- Green color

-- Function to hide all input prompts
local function HideAllInputPrompts()
    if saveInputBox then saveInputBox:Hide() end
    if saveAcceptButton then saveAcceptButton:Hide() end
    if deleteInputBox then deleteInputBox:Hide() end
    if deleteAcceptButton then deleteAcceptButton:Hide() end
    if renameInputBox then renameInputBox:Hide() end
    if renameAcceptButton then renameAcceptButton:Hide() end
    if mergeInputBox then mergeInputBox:Hide() end
    if mergeAcceptButton then mergeAcceptButton:Hide() end
    if loadInputBox then loadInputBox:Hide() end
    if loadAcceptButton then loadAcceptButton:Hide() end
    if shareInputBox then shareInputBox:Hide() end
    if shareAcceptButton then shareAcceptButton:Hide() end
    if importInputBox then importInputBox:Hide() end
    if importAcceptButton then importAcceptButton:Hide() end
end

-- Function to hide all frames
local function HideAllFrames()
    friendManagerFrame:Hide()
    if profileListFrame then profileListFrame:Hide() end
    if friendsListFrame then friendsListFrame:Hide() end
    HideAllInputPrompts()
end

-- Close button for the Friend Manager UI
local closeButton = CreateFrame("Button", nil, friendManagerFrame)
closeButton:SetPoint("TOPRIGHT", -5, -5)
closeButton:SetSize(24, 24)
closeButton:SetNormalTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
closeButton:SetHighlightTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
closeButton:SetPushedTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
closeButton:SetScript("OnClick", function()
    HideAllFrames()
end)

-- Function to create input box
local function CreateInputBox(parent, label, onAccept)
    local inputFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    inputFrame:SetSize(200, 60)
    inputFrame:SetPoint("TOP", parent, "BOTTOM", 0, -10)
    inputFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    inputFrame:SetBackdropColor(0, 0, 0, 0.8)
    inputFrame:SetBackdropBorderColor(0, 0, 0)

    local inputLabel = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("TOP", inputFrame, "TOP", 0, -10)
    inputLabel:SetText(label)

    local inputBox = CreateFrame("EditBox", nil, inputFrame, "InputBoxTemplate")
    inputBox:SetSize(140, 20)
    inputBox:SetPoint("CENTER", inputFrame, "CENTER", 0, -10)
    inputBox:SetAutoFocus(true)

    local acceptButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    acceptButton:SetSize(60, 20)
    acceptButton:SetPoint("TOP", inputFrame, "BOTTOM", 0, -10)
    acceptButton:SetText("Accept")
    acceptButton:SetScript("OnClick", function()
        local inputText = inputBox:GetText()
        if inputText == "" then
            print("Input required: " .. label)
        else
            onAccept(inputText)
            inputFrame:Hide()
            acceptButton:Hide()
        end
    end)

    local closeButton = CreateFrame("Button", nil, inputFrame)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetNormalTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetHighlightTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetPushedTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetScript("OnClick", function()
        inputFrame:Hide()
        acceptButton:Hide()
    end)

    inputFrame:Hide()
    acceptButton:Hide()
    return inputFrame, acceptButton
end

-- Function to create dual input box
local function CreateDualInputBox(parent, label1, label2, onAccept)
    local inputFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    inputFrame:SetSize(180, 100)
    inputFrame:SetPoint("TOP", parent, "BOTTOM", 0, -10)
    inputFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    inputFrame:SetBackdropColor(0, 0, 0, 0.8)
    inputFrame:SetBackdropBorderColor(0, 0, 0)

    local inputLabel1 = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel1:SetPoint("TOPLEFT", inputFrame, "TOPLEFT", 10, -10)
    inputLabel1:SetText(label1)

    local inputBox1 = CreateFrame("EditBox", nil, inputFrame, "InputBoxTemplate")
    inputBox1:SetSize(140, 20)
    inputBox1:SetPoint("TOPLEFT", inputLabel1, "BOTTOMLEFT", 0, -5)
    inputBox1:SetAutoFocus(true)

    local inputLabel2 = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel2:SetPoint("TOPLEFT", inputBox1, "BOTTOMLEFT", 0, -10)
    inputLabel2:SetText(label2)

    local inputBox2 = CreateFrame("EditBox", nil, inputFrame, "InputBoxTemplate")
    inputBox2:SetSize(140, 20)
    inputBox2:SetPoint("TOPLEFT", inputLabel2, "BOTTOMLEFT", 0, -5)

    local acceptButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    acceptButton:SetSize(60, 20)
    acceptButton:SetPoint("TOP", inputFrame, "BOTTOM", 0, -10)
    acceptButton:SetText("Accept")
    acceptButton:SetScript("OnClick", function()
        local inputText1 = inputBox1:GetText()
        local inputText2 = inputBox2:GetText()
        if inputText1 == "" or inputText2 == "" then
            print("Both inputs are required.")
        else
            onAccept(inputText1, inputText2)
            inputFrame:Hide()
            acceptButton:Hide()

        end
    end)

    local closeButton = CreateFrame("Button", nil, inputFrame)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetNormalTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetHighlightTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetPushedTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
    closeButton:SetScript("OnClick", function()
        inputFrame:Hide()
        acceptButton:Hide()
    end)

    inputFrame:Hide()
    acceptButton:Hide()
    return inputFrame, acceptButton
end

-- Function to ensure friendsListFrame is initialized
local function EnsureFriendsListFrame()
    if not friendsListFrame then
        friendsListFrame = CreateFrame("ScrollFrame", "FriendsListFrame", UIParent, "UIPanelScrollFrameTemplate, BackdropTemplate")
        friendsListFrame:SetSize(210, 285)
        friendsListFrame:SetPoint("LEFT", profileListFrame, "RIGHT", 10, 0)
        friendsListFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        friendsListFrame:SetBackdropColor(0, 0, 0, 0.8)
        friendsListFrame:SetBackdropBorderColor(0, 0, 0)

        friendsListTitle = friendsListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        friendsListTitle:SetPoint("TOP", friendsListFrame, "TOP", 0, -10)
        friendsListTitle:SetText("|cFF00FF00List of|r")  -- Green color  "Profile list of"

        friendsListCloseButton = CreateFrame("Button", nil, friendsListFrame)
        friendsListCloseButton:SetPoint("TOPRIGHT", -5, -5)
        friendsListCloseButton:SetSize(24, 24)
        friendsListCloseButton:SetNormalTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        friendsListCloseButton:SetHighlightTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        friendsListCloseButton:SetPushedTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        friendsListCloseButton:SetScript("OnClick", function()
            friendsListFrame:Hide()
            HideAllInputPrompts()
        end)

        friendsListScrollChild = CreateFrame("Frame", nil, friendsListFrame)
        friendsListScrollChild:SetSize(180, 240)
        friendsListFrame:SetScrollChild(friendsListScrollChild)
    end
end

-- Function to update the friends list
local function UpdateFriendsList(profile)
    EnsureFriendsListFrame()

    friendsListScrollChild:Hide()
    friendsListScrollChild = CreateFrame("Frame", nil, friendsListFrame)
    friendsListScrollChild:SetSize(180, 240)
    friendsListFrame:SetScrollChild(friendsListScrollChild)

    friendsListTitle:SetText("|cFF00FF00Profile List of " .. profile .. "|r")  -- Green color

    local yOffset = -30
    if FriendManagerDB[profile] then
        for _, friendName in ipairs(FriendManagerDB[profile]) do
            local friendText = friendsListScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            friendText:SetPoint("TOP", friendsListScrollChild, "TOP", 0, yOffset)
            friendText:SetText(friendName)
            yOffset = yOffset - 15
        end
    end
    friendsListScrollChild:Show()
    friendsListFrame:Show()
end

-- Function to ensure profileListFrame is initialized
local function EnsureProfileListFrame()
    if not profileListFrame then
        profileListFrame = CreateFrame("Frame", "ProfileListFrame", UIParent, "BackdropTemplate")
        profileListFrame:SetSize(200, 285)
        profileListFrame:SetPoint("LEFT", friendManagerFrame, "RIGHT", 10, 0)
        profileListFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        profileListFrame:SetBackdropColor(0, 0, 0, 0.8)
        profileListFrame:SetBackdropBorderColor(0, 0, 0)

        local profileListTitle = profileListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        profileListTitle:SetPoint("TOP", profileListFrame, "TOP", 0, -5)  -- Adjusted position to avoid overlapping
        profileListTitle:SetText("|cFF00FF00List of Profiles|r")  -- Green color

        local profileListCloseButton = CreateFrame("Button", nil, profileListFrame)
        profileListCloseButton:SetPoint("TOPRIGHT", -5, -5)
        profileListCloseButton:SetSize(24, 24)
        profileListCloseButton:SetNormalTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        profileListCloseButton:SetHighlightTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        profileListCloseButton:SetPushedTexture("Interface\\AddOns\\FriendManager\\Textures\\close.png")
        profileListCloseButton:SetScript("OnClick", function()
            profileListFrame:Hide()
            friendsListFrame:Hide()
            HideAllInputPrompts()
        end)
    end
end

-- Function to update the profile list
local function UpdateProfileList()
    EnsureProfileListFrame()
    for _, child in ipairs({profileListFrame:GetChildren()}) do
        child:Hide()
    end

    local yOffset = -30  -- Adjusted to avoid overlapping with the title
    for profileName in pairs(FriendManagerDB) do
        local profileButton = CreateFrame("Button", nil, profileListFrame)
        profileButton:SetSize(210, 20)
        profileButton:SetPoint("TOP", profileListFrame, "TOP", 0, yOffset)
        profileButton:SetText(profileName)
        profileButton:SetNormalFontObject("GameFontNormal")
        profileButton:SetHighlightFontObject("GameFontHighlight")
        profileButton:SetScript("OnClick", function()
            UpdateFriendsList(profileName)
        end)
        yOffset = yOffset - 25
    end
end

-- Create input boxes for commands
local saveInputBox, saveAcceptButton = CreateInputBox(friendManagerFrame, "Enter profile to save:", function(profile)
    SaveCurrentFriends(profile)
end)

local deleteInputBox, deleteAcceptButton = CreateInputBox(friendManagerFrame, "Enter profile to delete:", function(profile)
    DeleteProfile(profile)
end)

local renameInputBox, renameAcceptButton = CreateDualInputBox(friendManagerFrame, "Enter old profile name:", "Enter new profile name:", function(oldProfile, newProfile)
    RenameProfile(oldProfile, newProfile)
    UpdateProfileList()  -- Ensure the profile list is updated after renaming
end)

local mergeInputBox, mergeAcceptButton = CreateDualInputBox(friendManagerFrame, "1st profile to merge:", "2nd profile to merge:", function(profile1, profile2)
    local targetProfileInputBox, targetProfileAcceptButton = CreateInputBox(friendManagerFrame, "Enter target profile name:", function(targetProfile)
        MergeProfileFriends(profile1, profile2, targetProfile)
        UpdateProfileList()  -- Ensure the profile list is updated after merging
    end)
    targetProfileInputBox:Show()
    targetProfileAcceptButton:Show()
end)

local loadInputBox, loadAcceptButton = CreateInputBox(friendManagerFrame, "Enter profile to load:", function(profile)
    LoadProfileFriends(profile)
end)

local shareInputBox, shareAcceptButton = CreateDualInputBox(friendManagerFrame, "Enter profile to share:", "Enter target player name:", function(profile, targetPlayer)
    ShareProfile(profile, targetPlayer)
    UpdateProfileList()  -- Ensure the profile list is updated after sharing
end)

local importInputBox, importAcceptButton = CreateInputBox(friendManagerFrame, "Enter profile to import:", function(profile)
    ImportSharedProfile(profile)
end)

-- Function to hide all input prompts
local function HideAllInputPrompts()
    if saveInputBox then saveInputBox:Hide() end
    if saveAcceptButton then saveAcceptButton:Hide() end
    if deleteInputBox then deleteInputBox:Hide() end
    if deleteAcceptButton then deleteAcceptButton:Hide() end
    if renameInputBox then renameInputBox:Hide() end
    if renameAcceptButton then renameAcceptButton:Hide() end
    if mergeInputBox then mergeInputBox:Hide() end
    if mergeAcceptButton then mergeAcceptButton:Hide() end
    if loadInputBox then loadInputBox:Hide() end
    if loadAcceptButton then loadAcceptButton:Hide() end
    if shareInputBox then shareInputBox:Hide() end
    if shareAcceptButton then shareAcceptButton:Hide() end
    if importInputBox then importInputBox:Hide() end
    if importAcceptButton then importAcceptButton:Hide() end
end

-- Create buttons for each command
local buttons = {
    { text = "Save", inputBox = saveInputBox, acceptButton = saveAcceptButton },
    { text = "Delete", inputBox = deleteInputBox, acceptButton = deleteAcceptButton },
    { text = "Rename", inputBox = renameInputBox, acceptButton = renameAcceptButton },
    { text = "Merge", inputBox = mergeInputBox, acceptButton = mergeAcceptButton },
    { text = "Load", inputBox = loadInputBox, acceptButton = loadAcceptButton },
    { text = "Share", inputBox = shareInputBox, acceptButton = shareAcceptButton },
    { text = "Import", inputBox = importInputBox, acceptButton = importAcceptButton },
}

for i, buttonInfo in ipairs(buttons) do
    local button = CreateFrame("Button", nil, friendManagerFrame, "UIPanelButtonTemplate")
    button:SetSize(80, 22)
    button:SetPoint("TOP", friendManagerFrame, "TOP", 0, -40 - (i - 1) * 30)
    button:SetText(buttonInfo.text)
    button:SetScript("OnClick", function()
        HideAllInputPrompts()
        buttonInfo.inputBox:Show()
        buttonInfo.acceptButton:Show()
    end)
end

-- Create a "List" button
local listButton = CreateFrame("Button", nil, friendManagerFrame, "UIPanelButtonTemplate")
listButton:SetSize(80, 22)
listButton:SetPoint("TOP", friendManagerFrame, "TOP", 0, -40 - (#buttons * 30))
listButton:SetText("List")
listButton:SetScript("OnClick", function()
    EnsureProfileListFrame()
    EnsureFriendsListFrame()
    if profileListFrame:IsShown() then
        profileListFrame:Hide()
        friendsListFrame:Hide()
    else
        UpdateProfileList()
        profileListFrame:Show()
    end
end)

-- Add the "List" button to the buttons table
table.insert(buttons, { text = "List", inputBox = nil, acceptButton = nil })

-- Slash commands
SLASH_FRIENDMANAGER1 = "/fm"
SLASH_FRIENDMANAGER2 = "/fm menu"
SlashCmdList["FRIENDMANAGER"] = function(msg)
    EnsureProfileListFrame()
    EnsureFriendsListFrame()
    if msg == "menu" then
        if friendManagerFrame:IsShown() then
            friendManagerFrame:Hide()
        else
            friendManagerFrame:Show()
            profileListFrame:Hide()
            friendsListFrame:Hide()
        end
    else
        -- Normalize the input to lowercase
        local command, arg1, arg2 = msg:match("^(%S*)%s*(%S*)%s*(.-)$")
        command = NormalizeProfileName(command)  -- Normalize command to lowercase
        arg1 = NormalizeProfileName(arg1)        -- Normalize profile name to lowercase

        if command == "save" then
            SaveCurrentFriends(arg1)
        elseif command == "delete" then
            DeleteProfile(arg1)
        elseif command == "rename" then
            RenameProfile(arg1, arg2)
            UpdateProfileList()  -- Ensure the profile list is updated after renaming
        elseif command == "list" then
            ListProfiles()
        elseif command == "show" then
            ShowProfileFriends(arg1)
        elseif command == "merge" then
            MergeProfileFriends(arg1, arg2, arg1) -- Merge into the first profile by default
            UpdateProfileList()  -- Ensure the profile list is updated after merging
        elseif command == "load" then  -- Changed restore to load
            LoadProfileFriends(arg1)
        elseif command == "share" then
            ShareProfile(arg1, arg2)
            UpdateProfileList()  -- Ensure the profile list is updated after sharing
        elseif command == "import" then
            ImportSharedProfile(arg1)
        else
            PrintColoredMessage("FriendManager commands:", "teal")
            print("/fm save <profile> - Save current friends list to a profile.")
            print("/fm delete <profile> - Delete a saved profile.")
            print("/fm merge <profile1> <profile2> - Combine friends from profile2 into profile1.")
            print("/fm rename <oldProfile> <newProfile> - Rename a saved profile.")
            print("/fm list - List all saved profiles.")
            print("/fm show <profile> - List all friends in a specific profile.")
            print("/fm load <profile> - Load the profile's friends into your current friend list.")
            print("/fm share <profile> <player> - Share a profile with another player.")
            print("/fm import <profile> - Import a shared profile.")
            print("/fm menu - Show the Friend Manager UI.")
        end
    end
end