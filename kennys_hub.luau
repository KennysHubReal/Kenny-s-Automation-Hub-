--[[
    👑 KENNY'S AUTOMATION HUB - CUSTOM CYBER-NEO SLEEK UI (V2)
    By Kenny
    - Prominent animated loading bar sequence on start
    - Precision Auto-Pamphlet Delivery (Fast nearest-walker sorting, zero misses)
    - Full features: Auto-Checkout, Store & Pets, Security, Player Boosts
--]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local parentGui = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui or PlayerGui

-- Clean up any previous UI
for _, old in ipairs(parentGui:GetChildren()) do
    if old.Name:find("Kennys") or old.Name:find("PetStore") then
        old:Destroy()
    end
end

-- Remotes & Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Checkout = Remotes:FindFirstChild("Checkout")
local PamphletsRemotes = Remotes:FindFirstChild("Pamphlets")
local EnclosuresRemotes = Remotes:FindFirstChild("Enclosures")
local BatRemotes = Remotes:FindFirstChild("Bat")
local MessRemotes = Remotes:FindFirstChild("Mess")

local CheckoutController = require(Modules:WaitForChild("CheckoutController"))
local CheckoutGamepad = require(Modules:WaitForChild("CheckoutGamepad"))
local CheckoutMoney = require(Modules:WaitForChild("CheckoutMoney"))
local PedestrianController = require(Modules:WaitForChild("PedestrianController"))

local WalkersTable = debug.getupvalue(PedestrianController.walkerNearRay, 1)

local ScanCurrentRE = Checkout and Checkout:FindFirstChild("ScanCurrent")
local AcceptPresentedPaymentRE = Checkout and Checkout:FindFirstChild("AcceptPresentedPayment")
local SubmitCashChangeRE = Checkout and Checkout:FindFirstChild("SubmitCashChange")
local SubmitCardAmountRE = Checkout and Checkout:FindFirstChild("SubmitCardAmount")

local GrabPamphletRE = PamphletsRemotes and PamphletsRemotes:FindFirstChild("Grab")
local GivePamphletRE = PamphletsRemotes and PamphletsRemotes:FindFirstChild("Give")

local MaintainRE = EnclosuresRemotes and EnclosuresRemotes:FindFirstChild("Maintain")
local CleanMessRE = MessRemotes and MessRemotes:FindFirstChild("Clean")
local SwingBatRE = BatRemotes and BatRemotes:FindFirstChild("Swing")

-- Automation Config
local Config = {
    AutoCheckout = false, -- Default to OFF per user request
    ScanDelay = 0.08,
    PaymentDelay = 0.12,
    LastScanTime = 0,
    LastPaymentTime = 0,
    LastEnterAttempt = 0,

    -- Pamphlet Settings
    AutoPamphlets = false,
    AutoTeleportWalkers = false,
    AutoGrabPamphlets = false,
    LastPamphletTime = 0,
    LastGrabTime = 0,
    LastTeleportTime = 0,

    AutoPetCare = false,
    LastCareTime = 0,

    AutoCleanMesses = false,
    LastCleanTime = 0,

    AutoBatThieves = false,
    LastSwingTime = 0,

    ToggleKey = Enum.KeyCode.RightControl,
    AutoLoadConfig = true
}

-- Denominations for Cash Change
local DenomHierarchy = {
    { id = "bill100", cents = 10000 },
    { id = "bill50",  cents = 5000 },
    { id = "bill20",  cents = 2000 },
    { id = "bill10",  cents = 1000 },
    { id = "bill5",   cents = 500 },
    { id = "bill1",   cents = 100 },
    { id = "coin50",  cents = 50 },
    { id = "coin25",  cents = 25 },
    { id = "coin10",  cents = 10 },
    { id = "coin5",   cents = 5 },
    { id = "coin1",   cents = 1 }
}

local function calculateExactChange(centsDue)
    local counts = {}
    local remaining = centsDue or 0
    for _, denom in ipairs(DenomHierarchy) do
        if remaining >= denom.cents then
            local count = math.floor(remaining / denom.cents)
            counts[denom.id] = count
            remaining = remaining - (count * denom.cents)
        end
    end
    return counts
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId or plot:GetAttribute("Owner") == LocalPlayer.Name or plot.Name:find(LocalPlayer.Name) then
            return plot
        end
    end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:FindFirstChild("Checkout") then return plot end
    end
    return nil
end

local function getPamphletStand()
    local plot = getMyPlot()
    if not plot then return nil end
    local items = plot:FindFirstChild("Items")
    if items and items:FindFirstChild("PamphletStand") then
        return items:FindFirstChild("PamphletStand")
    end
    return plot:FindFirstChild("PamphletStand")
end

local function enterRegister(till)
    if not till then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local playerPoint = till:FindFirstChild("PlayerPoint")
    local screen = till:FindFirstChild("RegisterScreen") or till:FindFirstChild("Computer") or till:FindFirstChild("Desk")

    if hrp and playerPoint and screen then
        hrp.CFrame = CFrame.lookAt(playerPoint.Position + Vector3.new(0, 1, 0), screen.Position)
        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), screen.Position)
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end
end

-- ==========================================
-- CREATE SCREEN GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KennysCustomHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- ==========================================
-- CINEMATIC LOADING CARD & PROGRESS BAR
-- ==========================================
local Splash = Instance.new("CanvasGroup")
Splash.Name = "Splash"
Splash.Size = UDim2.new(0, 420, 0, 220)
Splash.Position = UDim2.new(0.5, -210, 0.45, -110)
Splash.BackgroundColor3 = Color3.fromRGB(11, 13, 19)
Splash.BorderSizePixel = 0
Splash.Visible = false
Splash.GroupTransparency = 1
Splash.ClipsDescendants = true
Splash.Parent = ScreenGui

local SplashScale = Instance.new("UIScale")
SplashScale.Scale = 0.88
SplashScale.Parent = Splash

local SplashCorner = Instance.new("UICorner")
SplashCorner.CornerRadius = UDim.new(0, 16)
SplashCorner.Parent = Splash

local SplashStroke = Instance.new("UIStroke")
SplashStroke.Color = Color3.fromRGB(0, 210, 255)
SplashStroke.Thickness = 1.8
SplashStroke.Parent = Splash

local SplashGlow = Instance.new("UIGradient")
SplashGlow.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 90, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 255))
}
SplashGlow.Parent = SplashStroke

local SplashBadge = Instance.new("TextLabel")
SplashBadge.Text = "👑 KENNY'S AUTOMATION HUB"
SplashBadge.Font = Enum.Font.GothamBlack
SplashBadge.TextSize = 17
SplashBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashBadge.BackgroundTransparency = 1
SplashBadge.Position = UDim2.new(0, 0, 0, 28)
SplashBadge.Size = UDim2.new(1, 0, 0, 24)
SplashBadge.Parent = Splash

local SplashSub = Instance.new("TextLabel")
SplashSub.Text = "PET STORE TYCOON  •  ULTIMATE AUTOMATION"
SplashSub.Font = Enum.Font.GothamBold
SplashSub.TextSize = 10
SplashSub.TextColor3 = Color3.fromRGB(0, 210, 255)
SplashSub.BackgroundTransparency = 1
SplashSub.Position = UDim2.new(0, 0, 0, 54)
SplashSub.Size = UDim2.new(1, 0, 0, 16)
SplashSub.Parent = Splash

local SplashStatus = Instance.new("TextLabel")
SplashStatus.Text = "Connecting to game services..."
SplashStatus.Font = Enum.Font.GothamMedium
SplashStatus.TextSize = 11
SplashStatus.TextColor3 = Color3.fromRGB(170, 185, 210)
SplashStatus.BackgroundTransparency = 1
SplashStatus.Position = UDim2.new(0, 36, 0, 108)
SplashStatus.Size = UDim2.new(1, -72, 0, 18)
SplashStatus.TextXAlignment = Enum.TextXAlignment.Left
SplashStatus.Parent = Splash

local SplashPercent = Instance.new("TextLabel")
SplashPercent.Text = "0%"
SplashPercent.Font = Enum.Font.GothamBold
SplashPercent.TextSize = 11
SplashPercent.TextColor3 = Color3.fromRGB(0, 220, 255)
SplashPercent.BackgroundTransparency = 1
SplashPercent.Position = UDim2.new(1, -96, 0, 108)
SplashPercent.Size = UDim2.new(0, 60, 0, 18)
SplashPercent.TextXAlignment = Enum.TextXAlignment.Right
SplashPercent.Parent = Splash

-- Modern Loading Bar
local BarOuter = Instance.new("Frame")
BarOuter.Size = UDim2.new(1, -72, 0, 10)
BarOuter.Position = UDim2.new(0, 36, 0, 134)
BarOuter.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
BarOuter.BorderSizePixel = 0
BarOuter.Parent = Splash

local BarOuterCorner = Instance.new("UICorner")
BarOuterCorner.CornerRadius = UDim.new(1, 0)
BarOuterCorner.Parent = BarOuter

local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
BarFill.BorderSizePixel = 0
BarFill.Parent = BarOuter

local BarFillCorner = Instance.new("UICorner")
BarFillCorner.CornerRadius = UDim.new(1, 0)
BarFillCorner.Parent = BarFill

local BarGrad = Instance.new("UIGradient")
BarGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(150, 90, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255))
}
BarGrad.Parent = BarFill

-- ==========================================
-- SUPPORTED GAMES CATALOG MODAL
-- ==========================================
local SupportedGames = {
    {
        Name = "Pet Store Tycoon",
        PlaceId = 118845698633260,
        Icon = "rbxassetid://99408848325145",
        Perks = "Auto Cashier • Fast Flyers • Enclosure Care • Shoplifter Defense",
        IsCurrent = true
    }
}

local CatalogModal = Instance.new("CanvasGroup")
CatalogModal.Name = "SupportedGamesCatalog"
CatalogModal.Size = UDim2.new(0, 520, 0, 220)
CatalogModal.Position = UDim2.new(0.5, -260, 0.45, -110)
CatalogModal.BackgroundColor3 = Color3.fromRGB(11, 13, 19)
CatalogModal.BorderSizePixel = 0
CatalogModal.GroupTransparency = 1
CatalogModal.ClipsDescendants = true
CatalogModal.Parent = ScreenGui

local CatalogScale = Instance.new("UIScale")
CatalogScale.Scale = 0.88
CatalogScale.Parent = CatalogModal

local CatalogCorner = Instance.new("UICorner")
CatalogCorner.CornerRadius = UDim.new(0, 16)
CatalogCorner.Parent = CatalogModal

local CatalogStroke = Instance.new("UIStroke")
CatalogStroke.Color = Color3.fromRGB(0, 210, 255)
CatalogStroke.Thickness = 1.8
CatalogStroke.Parent = CatalogModal

local CatalogGlow = Instance.new("UIGradient")
CatalogGlow.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 90, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 255))
}
CatalogGlow.Parent = CatalogStroke

local CatalogBadge = Instance.new("TextLabel")
CatalogBadge.Text = "👑 KENNY'S AUTOMATION HUB"
CatalogBadge.Font = Enum.Font.GothamBlack
CatalogBadge.TextSize = 16
CatalogBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
CatalogBadge.BackgroundTransparency = 1
CatalogBadge.Position = UDim2.new(0, 20, 0, 16)
CatalogBadge.Size = UDim2.new(1, -40, 0, 22)
CatalogBadge.TextXAlignment = Enum.TextXAlignment.Left
CatalogBadge.Parent = CatalogModal

local CatalogSub = Instance.new("TextLabel")
CatalogSub.Text = "SUPPORTED GAMES CATALOG  •  SELECT OR AUTO-LAUNCH"
CatalogSub.Font = Enum.Font.GothamBold
CatalogSub.TextSize = 10
CatalogSub.TextColor3 = Color3.fromRGB(0, 210, 255)
CatalogSub.BackgroundTransparency = 1
CatalogSub.Position = UDim2.new(0, 20, 0, 38)
CatalogSub.Size = UDim2.new(1, -40, 0, 14)
CatalogSub.TextXAlignment = Enum.TextXAlignment.Left
CatalogSub.Parent = CatalogModal

local CatalogDiv = Instance.new("Frame")
CatalogDiv.Size = UDim2.new(1, -40, 0, 1)
CatalogDiv.Position = UDim2.new(0, 20, 0, 58)
CatalogDiv.BackgroundColor3 = Color3.fromRGB(30, 38, 54)
CatalogDiv.BorderSizePixel = 0
CatalogDiv.Parent = CatalogModal

local GamesScroll = Instance.new("ScrollingFrame")
GamesScroll.Name = "GamesScroll"
GamesScroll.Size = UDim2.new(1, -40, 0, 86)
GamesScroll.Position = UDim2.new(0, 20, 0, 68)
GamesScroll.BackgroundTransparency = 1
GamesScroll.BorderSizePixel = 0
GamesScroll.ScrollBarThickness = 3
GamesScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 210, 255)
GamesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
GamesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
GamesScroll.Parent = CatalogModal

local GamesLayout = Instance.new("UIListLayout")
GamesLayout.Padding = UDim.new(0, 8)
GamesLayout.SortOrder = Enum.SortOrder.LayoutOrder
GamesLayout.Parent = GamesScroll

-- Bottom Action Bar
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -40, 0, 42)
BottomBar.Position = UDim2.new(0, 20, 1, -54)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = CatalogModal

local CountdownLabel = Instance.new("TextLabel")
CountdownLabel.Text = "Select a game to launch automation..."
CountdownLabel.Font = Enum.Font.GothamMedium
CountdownLabel.TextSize = 11
CountdownLabel.TextColor3 = Color3.fromRGB(160, 180, 210)
CountdownLabel.BackgroundTransparency = 1
CountdownLabel.Position = UDim2.new(0, 4, 0, 0)
CountdownLabel.Size = UDim2.new(1, -150, 1, 0)
CountdownLabel.TextXAlignment = Enum.TextXAlignment.Left
CountdownLabel.Parent = BottomBar

local LaunchBtn = Instance.new("TextButton")
LaunchBtn.Name = "LaunchBtn"
LaunchBtn.Text = "Launch Hub ▶"
LaunchBtn.Font = Enum.Font.GothamBold
LaunchBtn.TextSize = 12
LaunchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LaunchBtn.BackgroundColor3 = Color3.fromRGB(0, 190, 240)
LaunchBtn.Size = UDim2.new(0, 130, 0, 34)
LaunchBtn.Position = UDim2.new(1, -130, 0.5, -17)
LaunchBtn.BorderSizePixel = 0
LaunchBtn.Parent = BottomBar

local LaunchCorner = Instance.new("UICorner")
LaunchCorner.CornerRadius = UDim.new(0, 8)
LaunchCorner.Parent = LaunchBtn

local LaunchGrad = Instance.new("UIGradient")
LaunchGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 70, 255))
}
LaunchGrad.Parent = LaunchBtn

local triggerInitiationLoad

for i, gameData in ipairs(SupportedGames) do
    local isCurrent = (game.PlaceId == gameData.PlaceId) or (gameData.Name == "Pet Store Tycoon")
    
    local card = Instance.new("TextButton")
    card.Name = "GameCard_" .. gameData.Name
    card.Text = ""
    card.Size = UDim2.new(1, -6, 0, 66)
    card.BackgroundColor3 = isCurrent and Color3.fromRGB(16, 23, 36) or Color3.fromRGB(14, 17, 26)
    card.BorderSizePixel = 0
    card.AutoButtonColor = false
    card.LayoutOrder = i
    card.Parent = GamesScroll

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = isCurrent and Color3.fromRGB(0, 210, 255) or Color3.fromRGB(30, 38, 54)
    cardStroke.Thickness = isCurrent and 1.2 or 1
    cardStroke.Parent = card

    -- Game Icon Thumbnail
    local iconBg = Instance.new("Frame")
    iconBg.Size = UDim2.new(0, 48, 0, 48)
    iconBg.Position = UDim2.new(0, 9, 0.5, -24)
    iconBg.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    iconBg.BorderSizePixel = 0
    iconBg.Parent = card

    local iconBgCorner = Instance.new("UICorner")
    iconBgCorner.CornerRadius = UDim.new(0, 8)
    iconBgCorner.Parent = iconBg

    local iconImg = Instance.new("ImageLabel")
    iconImg.Size = UDim2.new(1, 0, 1, 0)
    iconImg.BackgroundTransparency = 1
    iconImg.Image = gameData.Icon
    iconImg.Parent = iconBg

    local iconImgCorner = Instance.new("UICorner")
    iconImgCorner.CornerRadius = UDim.new(0, 8)
    iconImgCorner.Parent = iconImg

    if gameData.PlaceId then
        task.spawn(function()
            local s, r = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(gameData.PlaceId) end)
            if s and r and r.IconImageAssetId and r.IconImageAssetId > 0 then
                iconImg.Image = "rbxassetid://" .. string.format("%.0f", r.IconImageAssetId)
            end
        end)
    end

    -- Text Details
    local title = Instance.new("TextLabel")
    title.Text = gameData.Name
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 68, 0, 0)
    title.Size = UDim2.new(1, -190, 1, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    if isCurrent then
        local cardAction = Instance.new("TextButton")
        cardAction.Text = "LAUNCH ▶"
        cardAction.Font = Enum.Font.GothamBold
        cardAction.TextSize = 11
        cardAction.TextColor3 = Color3.fromRGB(255, 255, 255)
        cardAction.BackgroundColor3 = Color3.fromRGB(0, 190, 235)
        cardAction.Size = UDim2.new(0, 88, 0, 28)
        cardAction.Position = UDim2.new(1, -98, 0.5, -14)
        cardAction.BorderSizePixel = 0
        cardAction.Parent = card

        local actionCorner = Instance.new("UICorner")
        actionCorner.CornerRadius = UDim.new(0, 7)
        actionCorner.Parent = cardAction

        local actionGrad = Instance.new("UIGradient")
        actionGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 70, 255))
        }
        actionGrad.Parent = cardAction

        cardAction.MouseButton1Click:Connect(function()
            if triggerInitiationLoad then triggerInitiationLoad() end
        end)
        card.MouseButton1Click:Connect(function()
            if triggerInitiationLoad then triggerInitiationLoad() end
        end)
    end
end

-- ==========================================
-- MAIN HUD WINDOW
-- ==========================================
local Main = Instance.new("CanvasGroup")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, 530, 0, 350)
Main.Position = UDim2.new(0.5, -265, 0.45, -175)
Main.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
Main.BorderSizePixel = 0
Main.Visible = false
Main.GroupTransparency = 1
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.85
MainScale.Parent = Main

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(42, 52, 76)
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 44)
Topbar.BackgroundColor3 = Color3.fromRGB(19, 23, 35)
Topbar.BorderSizePixel = 0
Topbar.Parent = Main

local TopbarCorner = Instance.new("UICorner")
TopbarCorner.CornerRadius = UDim.new(0, 14)
TopbarCorner.Parent = Topbar

local TopbarCover = Instance.new("Frame")
TopbarCover.Size = UDim2.new(1, 0, 0, 12)
TopbarCover.Position = UDim2.new(0, 0, 1, -12)
TopbarCover.BackgroundColor3 = Color3.fromRGB(19, 23, 35)
TopbarCover.BorderSizePixel = 0
TopbarCover.Parent = Topbar

local AppTitle = Instance.new("TextLabel")
AppTitle.Text = "👑 KENNY'S AUTOMATION HUB"
AppTitle.Font = Enum.Font.GothamBold
AppTitle.TextSize = 13
AppTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
AppTitle.BackgroundTransparency = 1
AppTitle.Position = UDim2.new(0, 16, 0, 6)
AppTitle.Size = UDim2.new(0, 280, 0, 18)
AppTitle.TextXAlignment = Enum.TextXAlignment.Left
AppTitle.Parent = Topbar

local AuthorTag = Instance.new("TextLabel")
AuthorTag.Text = "BY KENNY  •  PET STORE TYCOON"
AuthorTag.Font = Enum.Font.GothamMedium
AuthorTag.TextSize = 9
AuthorTag.TextColor3 = Color3.fromRGB(0, 210, 255)
AuthorTag.BackgroundTransparency = 1
AuthorTag.Position = UDim2.new(0, 16, 0, 24)
AuthorTag.Size = UDim2.new(0, 280, 0, 14)
AuthorTag.TextXAlignment = Enum.TextXAlignment.Left
AuthorTag.Parent = Topbar

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 13
MinBtn.TextColor3 = Color3.fromRGB(160, 175, 200)
MinBtn.BackgroundColor3 = Color3.fromRGB(27, 33, 47)
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0, 9)
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Topbar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Color3.fromRGB(230, 100, 100)
CloseBtn.BackgroundColor3 = Color3.fromRGB(36, 24, 30)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0, 9)
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Topbar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Draggable Logic
local dragging, dragInput, dragStart, startPos
Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

Topbar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Sidebar Tabs
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 19, 29)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -130, 1, -44)
Content.Position = UDim2.new(0, 130, 0, 44)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Tabs = {}
local TabButtons = {}
local TabNames = { "Register", "Pamphlets", "Store & Pets", "Security", "Settings" }

local function createTabContent(name)
    local page = Instance.new("CanvasGroup")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -20, 1, -20)
    page.Position = UDim2.new(0, 10, 0, 10)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.GroupTransparency = 0
    page.Visible = false
    page.Parent = Content

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(55, 70, 100)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = page

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = scroll

    Tabs[name] = scroll
    Tabs[name .. "_Container"] = page
    return scroll
end

local currentTab = nil
local function switchTab(selected)
    if currentTab == selected then return end
    currentTab = selected

    for name, btn in pairs(TabButtons) do
        if name == selected then
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(0, 180, 255),
                TextColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(22, 26, 38),
                TextColor3 = Color3.fromRGB(150, 165, 185)
            }):Play()
        end
    end

    for name, _ in pairs(TabButtons) do
        local container = Tabs[name .. "_Container"]
        if container then
            if name ~= selected then
                container.Visible = false
                container.GroupTransparency = 1
            end
        end
    end

    local targetContainer = Tabs[selected .. "_Container"]
    if targetContainer then
        targetContainer.Position = UDim2.new(0, 10, 0, 18)
        targetContainer.GroupTransparency = 1
        targetContainer.Visible = true

        TweenService:Create(targetContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 10, 0, 10),
            GroupTransparency = 0
        }):Play()
    end
end

for i, name in ipairs(TabNames) do
    createTabContent(name)

    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Text = name
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(150, 165, 185)
    btn.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, 12 + ((i - 1) * 38))
    btn.BorderSizePixel = 0
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)

    TabButtons[name] = btn
end

-- ==========================================
-- UI HELPER CREATORS
-- ==========================================
local ToggleRefs = {}

local function createToggle(parent, title, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(38, 48, 70)
    s.Thickness = 1
    s.Parent = frame

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(220, 230, 245)
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -70, 1, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Text = ""
    toggleBtn.Size = UDim2.new(0, 44, 0, 22)
    toggleBtn.Position = UDim2.new(1, -56, 0.5, -11)
    toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(40, 48, 65)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 16, 0, 16)
    pill.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    pill.BorderSizePixel = 0
    pill.Parent = toggleBtn

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = pill

    local state = defaultState

    local function setValue(newState, skipCallback)
        state = newState
        TweenService:Create(pill, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(40, 48, 65)
        }):Play()
        if not skipCallback then
            callback(state)
        end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        setValue(not state)
    end)

    return {
        Frame = frame,
        SetValue = setValue,
        GetValue = function() return state end
    }
end

local function createActionBtn(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = color or Color3.fromRGB(0, 140, 230)
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BorderSizePixel = 0
    btn.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createStatusCard(parent, title, desc)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 52)
    frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(36, 44, 64)
    s.Thickness = 1
    s.Parent = frame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = Color3.fromRGB(0, 210, 255)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 12, 0, 8)
    titleLbl.Size = UDim2.new(1, -24, 0, 16)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = frame

    local descLbl = Instance.new("TextLabel")
    descLbl.Text = desc
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 10
    descLbl.TextColor3 = Color3.fromRGB(160, 175, 200)
    descLbl.BackgroundTransparency = 1
    descLbl.Position = UDim2.new(0, 12, 0, 26)
    descLbl.Size = UDim2.new(1, -24, 0, 18)
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.Parent = frame

    return descLbl
end

local function createKeybind(parent, title, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(38, 48, 70)
    s.Thickness = 1
    s.Parent = frame

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(220, 230, 245)
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -110, 1, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local currentKey = defaultKey
    local keyBtn = Instance.new("TextButton")
    keyBtn.Text = defaultKey.Name
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 11
    keyBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
    keyBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    keyBtn.Size = UDim2.new(0, 86, 0, 26)
    keyBtn.Position = UDim2.new(1, -96, 0.5, -13)
    keyBtn.BorderSizePixel = 0
    keyBtn.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 6)
    keyCorner.Parent = keyBtn

    local function setKey(newKey, skipCallback)
        currentKey = newKey
        keyBtn.Text = newKey.Name
        keyBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
        if not skipCallback then
            callback(newKey)
        end
    end

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Color3.fromRGB(255, 220, 80)
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if listening and not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            setKey(input.KeyCode)
        end
    end)

    return {
        Frame = frame,
        SetKey = setKey,
        GetKey = function() return currentKey end
    }
end

local function createDropdown(parent, title, defaultOption, options, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = false
    frame.ZIndex = 10
    frame.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(38, 48, 70)
    s.Thickness = 1
    s.Parent = frame

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(220, 230, 245)
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -150, 0, 42)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 11
    label.Parent = frame

    local dropBtn = Instance.new("TextButton")
    dropBtn.Text = (defaultOption or "Select Config") .. "  ▼"
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.TextSize = 10
    dropBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
    dropBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    dropBtn.Size = UDim2.new(0, 130, 0, 26)
    dropBtn.Position = UDim2.new(1, -138, 0, 8)
    dropBtn.BorderSizePixel = 0
    dropBtn.ZIndex = 12
    dropBtn.Parent = frame

    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 6)
    dropCorner.Parent = dropBtn

    local dropStroke = Instance.new("UIStroke")
    dropStroke.Color = Color3.fromRGB(45, 58, 85)
    dropStroke.Thickness = 1
    dropStroke.Parent = dropBtn

    local menu = Instance.new("ScrollingFrame")
    menu.Name = "DropdownMenu"
    menu.Size = UDim2.new(0, 130, 0, 0)
    menu.Position = UDim2.new(1, -138, 0, 36)
    menu.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ZIndex = 30
    menu.ScrollBarThickness = 3
    menu.ScrollBarImageColor3 = Color3.fromRGB(0, 210, 255)
    menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
    menu.CanvasSize = UDim2.new(0, 0, 0, 0)
    menu.Parent = frame

    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 6)
    menuCorner.Parent = menu

    local menuStroke = Instance.new("UIStroke")
    menuStroke.Color = Color3.fromRGB(0, 210, 255)
    menuStroke.Thickness = 1
    menuStroke.Parent = menu

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.Padding = UDim.new(0, 2)
    menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    menuLayout.Parent = menu

    local isOpen = false
    local currentSelected = defaultOption
    local currentOptions = options or {}

    local function updateOptions(newOptions)
        currentOptions = newOptions or {}
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local totalHeight = 0
        for i, optName in ipairs(currentOptions) do
            local itemBtn = Instance.new("TextButton")
            itemBtn.Text = optName
            itemBtn.Font = Enum.Font.GothamMedium
            itemBtn.TextSize = 10
            itemBtn.TextColor3 = (optName == currentSelected) and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 215, 235)
            itemBtn.BackgroundColor3 = (optName == currentSelected) and Color3.fromRGB(25, 36, 54) or Color3.fromRGB(20, 25, 38)
            itemBtn.Size = UDim2.new(1, -4, 0, 24)
            itemBtn.BorderSizePixel = 0
            itemBtn.ZIndex = 31
            itemBtn.Parent = menu

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 4)
            itemCorner.Parent = itemBtn

            itemBtn.MouseButton1Click:Connect(function()
                currentSelected = optName
                dropBtn.Text = optName .. "  ▼"
                isOpen = false
                menu.Visible = false
                menu.Size = UDim2.new(0, 130, 0, 0)
                updateOptions(currentOptions)
                if callback then callback(optName) end
            end)

            totalHeight = totalHeight + 26
        end

        local calcHeight = math.min(totalHeight, 110)
        if isOpen then
            menu.Size = UDim2.new(0, 130, 0, calcHeight)
        end
    end

    local function toggleMenu()
        isOpen = not isOpen
        if isOpen then
            menu.Visible = true
            local totalH = math.min(#currentOptions * 26, 110)
            TweenService:Create(menu, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 130, 0, totalH)
            }):Play()
            dropBtn.Text = currentSelected .. "  ▲"
        else
            local t = TweenService:Create(menu, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 130, 0, 0)
            })
            t:Play()
            t.Completed:Connect(function()
                if not isOpen then menu.Visible = false end
            end)
            dropBtn.Text = currentSelected .. "  ▼"
        end
    end

    dropBtn.MouseButton1Click:Connect(toggleMenu)
    updateOptions(currentOptions)

    return {
        Frame = frame,
        SetOptions = function(newOpts, selectOpt)
            if selectOpt then currentSelected = selectOpt end
            dropBtn.Text = currentSelected .. "  ▼"
            updateOptions(newOpts)
        end,
        GetSelected = function() return currentSelected end,
        SetSelected = function(optName)
            currentSelected = optName
            dropBtn.Text = optName .. "  ▼"
            updateOptions(currentOptions)
        end
    }
end

-- ==========================================
-- POPULATE PAGES
-- ==========================================
-- 1. Register Page
local RegisterStatusLabel = createStatusCard(Tabs["Register"], "CASHIER SYSTEM STATUS", "Manning Register • Waiting for Customer")

ToggleRefs.AutoCheckout = createToggle(Tabs["Register"], "Auto Checkout (Scan & Pay)", Config.AutoCheckout, function(val)
    Config.AutoCheckout = val
end)

createActionBtn(Tabs["Register"], "⚡ Hop On Register (Auto E)", Color3.fromRGB(0, 140, 230), function()
    local plot = getMyPlot()
    local till = plot and plot:FindFirstChild("Checkout")
    enterRegister(till)
end)

-- 2. Pamphlet Page
local PamphletStatusLabel = createStatusCard(Tabs["Pamphlets"], "PAMPHLET STATUS", "Count: 0 | Idle")

ToggleRefs.AutoTeleportWalkers = createToggle(Tabs["Pamphlets"], "⚡ Fast Auto-Teleport to Walkers & Give", Config.AutoTeleportWalkers, function(val)
    Config.AutoTeleportWalkers = val
    Config.AutoPamphlets = val
end)

ToggleRefs.AutoPamphlets = createToggle(Tabs["Pamphlets"], "Auto-Give Pamphlets (Aura Only)", Config.AutoPamphlets, function(val)
    Config.AutoPamphlets = val
end)

ToggleRefs.AutoGrabPamphlets = createToggle(Tabs["Pamphlets"], "Auto-Refill At Pamphlet Stand", Config.AutoGrabPamphlets, function(val)
    Config.AutoGrabPamphlets = val
end)

createActionBtn(Tabs["Pamphlets"], "⚡ Teleport to Stand & Refill", Color3.fromRGB(130, 70, 230), function()
    local stand = getPamphletStand()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if stand and hrp then
        hrp.CFrame = stand:GetPivot() + Vector3.new(0, 3, 0)
        GrabPamphletRE:FireServer()
    end
end)

-- 3. Store & Pets Page
createStatusCard(Tabs["Store & Pets"], "STORE AUTOMATION", "Enclosure feeds, water refills & floor cleanup")

ToggleRefs.AutoPetCare = createToggle(Tabs["Store & Pets"], "Auto-Care Pet Enclosures (Feed/Water)", Config.AutoPetCare, function(val)
    Config.AutoPetCare = val
end)

ToggleRefs.AutoCleanMesses = createToggle(Tabs["Store & Pets"], "Auto-Clean Spills & Messes", Config.AutoCleanMesses, function(val)
    Config.AutoCleanMesses = val
end)

createActionBtn(Tabs["Store & Pets"], "Care For All Pens Immediately", Color3.fromRGB(0, 180, 140), function()
    local plot = getMyPlot()
    if plot then
        for _, desc in ipairs(plot:GetDescendants()) do
            if desc:IsA("Model") and (desc:GetAttribute("EnclosureId") or desc:GetAttribute("PenId")) then
                pcall(function()
                    MaintainRE:FireServer(desc, "Feed")
                    MaintainRE:FireServer(desc, "Water")
                    MaintainRE:FireServer(desc, "Filter")
                end)
            end
        end
    end
end)

-- 4. Security Page
createStatusCard(Tabs["Security"], "STORE DEFENSE", "Equips bat and stops shoplifters")

ToggleRefs.AutoBatThieves = createToggle(Tabs["Security"], "Auto-Swing Bat at Thieves (Anti-Theft)", Config.AutoBatThieves, function(val)
    Config.AutoBatThieves = val
end)

createActionBtn(Tabs["Security"], "Equip Bat Now", Color3.fromRGB(220, 80, 80), function()
    pcall(function() BatRemotes.Grab:FireServer() end)
end)

-- 5. Settings Page
createStatusCard(Tabs["Settings"], "HUB SETTINGS & KEYBINDS", "Customize hotkeys and menu controls")

local KeybindRef = createKeybind(Tabs["Settings"], "Toggle UI Keybind", Config.ToggleKey, function(newKey)
    Config.ToggleKey = newKey
end)

-- CONFIG MANAGER (SAVE & LOAD WITH DROPDOWN)
createStatusCard(Tabs["Settings"], "CONFIG MANAGER", "Select config, save, or load custom settings")

local activeConfig = "default"

local function getSavedConfigs()
    local configs = { "default" }
    if listfiles then
        local s, files = pcall(function() return listfiles() end)
        if s and files then
            for _, f in ipairs(files) do
                local name = f:match("KennysHub_([%w_%-]+)%.json$") or f:match("([%w_%-]+)%.json$")
                if name and not table.find(configs, name) then
                    table.insert(configs, name)
                end
            end
        end
    end
    return configs
end

local ConfigDropdownRef

local ConfigStatusLabel = Instance.new("TextLabel")
ConfigStatusLabel.Text = "Active Config: default"
ConfigStatusLabel.Font = Enum.Font.GothamMedium
ConfigStatusLabel.TextSize = 10
ConfigStatusLabel.TextColor3 = Color3.fromRGB(160, 180, 210)
ConfigStatusLabel.BackgroundTransparency = 1
ConfigStatusLabel.Size = UDim2.new(1, 0, 0, 18)
ConfigStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
ConfigStatusLabel.Parent = Tabs["Settings"]

ConfigDropdownRef = createDropdown(Tabs["Settings"], "Selected Config", "default", getSavedConfigs(), function(selected)
    activeConfig = selected
    ConfigStatusLabel.Text = "Selected Config: " .. activeConfig
    ConfigStatusLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
end)

local configRow = Instance.new("Frame")
configRow.Size = UDim2.new(1, 0, 0, 34)
configRow.BackgroundTransparency = 1
configRow.Parent = Tabs["Settings"]

local configRowLayout = Instance.new("UIListLayout")
configRowLayout.FillDirection = Enum.FillDirection.Horizontal
configRowLayout.Padding = UDim.new(0, 6)
configRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
configRowLayout.Parent = configRow

local saveBtn = Instance.new("TextButton")
saveBtn.Text = "💾 Save"
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 11
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 130)
saveBtn.Size = UDim2.new(0.32, -4, 1, 0)
saveBtn.BorderSizePixel = 0
saveBtn.Parent = configRow

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 7)
saveCorner.Parent = saveBtn

local loadBtn = Instance.new("TextButton")
loadBtn.Text = "📂 Load"
loadBtn.Font = Enum.Font.GothamBold
loadBtn.TextSize = 11
loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
loadBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 230)
loadBtn.Size = UDim2.new(0.32, -4, 1, 0)
loadBtn.BorderSizePixel = 0
loadBtn.Parent = configRow

local loadCorner = Instance.new("UICorner")
loadCorner.CornerRadius = UDim.new(0, 7)
loadCorner.Parent = loadBtn

local resetBtn = Instance.new("TextButton")
resetBtn.Text = "🔄 Reset"
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 11
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.BackgroundColor3 = Color3.fromRGB(48, 56, 76)
resetBtn.Size = UDim2.new(0.36, -4, 1, 0)
resetBtn.BorderSizePixel = 0
resetBtn.Parent = configRow

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 7)
resetCorner.Parent = resetBtn

ToggleRefs.AutoLoadConfig = createToggle(Tabs["Settings"], "Auto-Load Active Config on Launch", Config.AutoLoadConfig, function(val)
    Config.AutoLoadConfig = val
end)

local function getConfigFileName(configName)
    return "KennysHub_" .. (configName or "default") .. ".json"
end

local function saveConfig()
    local fileName = getConfigFileName(activeConfig)
    local data = {
        ConfigName = activeConfig,
        AutoCheckout = Config.AutoCheckout,
        AutoTeleportWalkers = Config.AutoTeleportWalkers,
        AutoPamphlets = Config.AutoPamphlets,
        AutoGrabPamphlets = Config.AutoGrabPamphlets,
        AutoPetCare = Config.AutoPetCare,
        AutoCleanMesses = Config.AutoCleanMesses,
        AutoBatThieves = Config.AutoBatThieves,
        ToggleKey = Config.ToggleKey.Name,
        AutoLoadConfig = Config.AutoLoadConfig
    }
    local json = HttpService:JSONEncode(data)
    if writefile then
        local s, err = pcall(function() writefile(fileName, json) end)
        if s then
            ConfigStatusLabel.Text = "✅ Saved config: " .. activeConfig
            ConfigStatusLabel.TextColor3 = Color3.fromRGB(0, 230, 150)
            if ConfigDropdownRef then ConfigDropdownRef.SetOptions(getSavedConfigs(), activeConfig) end
        else
            ConfigStatusLabel.Text = "❌ Save error: " .. tostring(err)
            ConfigStatusLabel.TextColor3 = Color3.fromRGB(240, 90, 90)
        end
    else
        ConfigStatusLabel.Text = "⚠️ writefile() unavailable"
        ConfigStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
    end
end

local function loadConfig(configName, silent)
    local targetConfig = configName or activeConfig
    local fileName = getConfigFileName(targetConfig)
    local json
    if isfile and readfile and isfile(fileName) then
        local s, res = pcall(function() return readfile(fileName) end)
        if s then json = res end
    end
    if not json then
        if not silent then
            ConfigStatusLabel.Text = "⚠️ No config found for '" .. targetConfig .. "'"
            ConfigStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
        end
        return false
    end

    local s, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not s or type(data) ~= "table" then
        if not silent then
            ConfigStatusLabel.Text = "❌ Invalid config format in '" .. targetConfig .. "'"
            ConfigStatusLabel.TextColor3 = Color3.fromRGB(240, 90, 90)
        end
        return false
    end

    if data.AutoCheckout ~= nil and ToggleRefs.AutoCheckout then
        ToggleRefs.AutoCheckout.SetValue(data.AutoCheckout)
    end
    if data.AutoTeleportWalkers ~= nil and ToggleRefs.AutoTeleportWalkers then
        ToggleRefs.AutoTeleportWalkers.SetValue(data.AutoTeleportWalkers)
    end
    if data.AutoPamphlets ~= nil and ToggleRefs.AutoPamphlets then
        ToggleRefs.AutoPamphlets.SetValue(data.AutoPamphlets)
    end
    if data.AutoGrabPamphlets ~= nil and ToggleRefs.AutoGrabPamphlets then
        ToggleRefs.AutoGrabPamphlets.SetValue(data.AutoGrabPamphlets)
    end
    if data.AutoPetCare ~= nil and ToggleRefs.AutoPetCare then
        ToggleRefs.AutoPetCare.SetValue(data.AutoPetCare)
    end
    if data.AutoCleanMesses ~= nil and ToggleRefs.AutoCleanMesses then
        ToggleRefs.AutoCleanMesses.SetValue(data.AutoCleanMesses)
    end
    if data.AutoBatThieves ~= nil and ToggleRefs.AutoBatThieves then
        ToggleRefs.AutoBatThieves.SetValue(data.AutoBatThieves)
    end
    if data.ToggleKey and KeybindRef then
        local code = Enum.KeyCode[data.ToggleKey]
        if code then KeybindRef.SetKey(code) end
    end
    if data.AutoLoadConfig ~= nil and ToggleRefs.AutoLoadConfig then
        ToggleRefs.AutoLoadConfig.SetValue(data.AutoLoadConfig)
    end

    activeConfig = targetConfig
    if ConfigDropdownRef then ConfigDropdownRef.SetSelected(activeConfig) end
    ConfigStatusLabel.Text = "✅ Loaded config: " .. activeConfig
    ConfigStatusLabel.TextColor3 = Color3.fromRGB(0, 230, 150)
    return true
end

local function resetConfig()
    if ToggleRefs.AutoCheckout then ToggleRefs.AutoCheckout.SetValue(false) end
    if ToggleRefs.AutoTeleportWalkers then ToggleRefs.AutoTeleportWalkers.SetValue(false) end
    if ToggleRefs.AutoPamphlets then ToggleRefs.AutoPamphlets.SetValue(false) end
    if ToggleRefs.AutoGrabPamphlets then ToggleRefs.AutoGrabPamphlets.SetValue(false) end
    if ToggleRefs.AutoPetCare then ToggleRefs.AutoPetCare.SetValue(false) end
    if ToggleRefs.AutoCleanMesses then ToggleRefs.AutoCleanMesses.SetValue(false) end
    if ToggleRefs.AutoBatThieves then ToggleRefs.AutoBatThieves.SetValue(false) end
    if KeybindRef then KeybindRef.SetKey(Enum.KeyCode.RightControl) end
    local fileName = getConfigFileName(activeConfig)
    if delfile and isfile and isfile(fileName) then
        pcall(function() delfile(fileName) end)
    end
    ConfigStatusLabel.Text = "🔄 Reset config '" .. activeConfig .. "' to defaults"
    ConfigStatusLabel.TextColor3 = Color3.fromRGB(160, 180, 210)
end

saveBtn.MouseButton1Click:Connect(saveConfig)
loadBtn.MouseButton1Click:Connect(function() loadConfig(activeConfig, false) end)
resetBtn.MouseButton1Click:Connect(resetConfig)

-- Auto-load on launch if enabled
task.spawn(function()
    task.wait(0.2)
    local fileName = getConfigFileName("default")
    if isfile and isfile(fileName) then
        loadConfig("default", true)
    end
end)

local isUIOpen = false
local uiTweening = false

local function setUIVisibility(visible)
    if uiTweening then return end
    uiTweening = true
    if visible then
        isUIOpen = true
        Main.Visible = true
        Main.Position = UDim2.new(0.5, -265, 0.45, -175)
        Main.Size = UDim2.new(0, 530, 0, 350)
        MainScale.Scale = 0.82
        Main.GroupTransparency = 1
        
        local tScale = TweenService:Create(MainScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        local tAlpha = TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
        tScale:Play()
        tAlpha:Play()
        tScale.Completed:Connect(function()
            uiTweening = false
        end)
    else
        isUIOpen = false
        local tScale = TweenService:Create(MainScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
        local tAlpha = TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        tScale:Play()
        tAlpha:Play()
        tAlpha.Completed:Connect(function()
            if not isUIOpen then
                Main.Visible = false
            end
            uiTweening = false
        end)
    end
end

local function toggleUI()
    setUIVisibility(not isUIOpen)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Config.ToggleKey then
            toggleUI()
        end
    end
end)

-- Window Control Buttons
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MinBtn.Text = "+"
        TweenService:Create(Main, TweenInfo.new(0.2), { Size = UDim2.new(0, 530, 0, 44) }):Play()
    else
        MinBtn.Text = "—"
        TweenService:Create(Main, TweenInfo.new(0.2), { Size = UDim2.new(0, 530, 0, 350) }):Play()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    setUIVisibility(false)
end)

switchTab("Register")

-- ==========================================
-- SHOWCASE & INITIATION STARTUP SEQUENCE
-- ==========================================
task.spawn(function()
    local launched = false

    -- 1. Pop in Supported Games Catalog with smooth Cyber spring animation
    TweenService:Create(CatalogScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(CatalogModal, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()

    triggerInitiationLoad = function()
        if launched then return end
        launched = true

        -- Smoothly fade out and shrink Catalog
        TweenService:Create(CatalogScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
        local tCatalogOut = TweenService:Create(CatalogModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        tCatalogOut:Play()
        tCatalogOut.Completed:Wait()
        CatalogModal:Destroy()

        -- 2. Pop in Cinematic Initiation Loading Screen
        Splash.Visible = true
        TweenService:Create(SplashScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        TweenService:Create(Splash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()

        local playerName = LocalPlayer.DisplayName or LocalPlayer.Name
        local steps = {
            { pct = 8,  text = "Verifying security handshake...", delay = 0.55 },
            { pct = 22, text = "Connecting to game network remotes...", delay = 0.65 },
            { pct = 38, text = "Mapping cash register & plot items...", delay = 0.60 },
            { pct = 52, text = "Scanning store enclosures & mess nodes...", delay = 0.55 },
            { pct = 68, text = "Calibrating real-time pedestrian tracker...", delay = 0.70 },
            { pct = 84, text = "Optimizing flyer teleport algorithms...", delay = 0.60 },
            { pct = 95, text = "Injecting automation routines...", delay = 0.65 },
            { pct = 100, text = "Ready! Welcome, " .. playerName .. ".", delay = 0.85 }
        }

        for _, step in ipairs(steps) do
            SplashStatus.Text = step.text
            SplashPercent.Text = step.pct .. "%"
            TweenService:Create(BarFill, TweenInfo.new(step.delay * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(step.pct / 100, 0, 1, 0)
            }):Play()
            task.wait(step.delay)
        end

        task.wait(0.5)

        -- Smoothly fade out Splash
        TweenService:Create(SplashScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
        local tSplashOut = TweenService:Create(Splash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        tSplashOut:Play()
        tSplashOut.Completed:Wait()
        Splash:Destroy()

        -- 3. Pop in Main Dashboard with smooth spring transition
        setUIVisibility(true)
    end

    LaunchBtn.MouseButton1Click:Connect(triggerInitiationLoad)
    CountdownLabel.Text = "Select a game to launch automation..."
end)

-- ==========================================
-- OPTIMIZED HEARTBEAT LOOP
-- ==========================================
local DeliveredWalkers = {}

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local plot = getMyPlot()
    local till = CheckoutController.getMannedTill() or (plot and plot:FindFirstChild("Checkout"))
    local isManning = CheckoutController.isManning()
    local state = CheckoutController.getState()
    local pamphletCount = LocalPlayer:GetAttribute("Pamphlets") or 0

    -- 1. PAMPHLETS
    if Config.AutoPamphlets and hrp then
        PamphletStatusLabel.Text = string.format("Holding: %d Flyers | Auto-Delivering...", pamphletCount)

        -- If empty, auto-refill immediately
        if pamphletCount <= 0 and Config.AutoGrabPamphlets then
            local now = tick()
            if now - Config.LastGrabTime >= 0.8 then
                Config.LastGrabTime = now
                local stand = getPamphletStand()
                if Config.AutoTeleportWalkers and stand then
                    hrp.CFrame = stand:GetPivot() + Vector3.new(0, 3, 0)
                end
                pcall(function() GrabPamphletRE:FireServer() end)
            end
        end

        -- Deliver flyers
        if pamphletCount > 0 and WalkersTable then
            local now = tick()
            
            if Config.AutoTeleportWalkers and (now - Config.LastTeleportTime >= 0.28) then
                -- Find closest undelivered walker
                local bestWalker = nil
                local bestId = nil
                local bestDist = 9999

                local myPos = hrp.Position
                for id, walker in pairs(WalkersTable) do
                    if walker.root and not walker.ragdolled and not DeliveredWalkers[id] then
                        local d = (walker.root.Position - myPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestWalker = walker
                            bestId = id
                        end
                    end
                end

                -- Reset memory if everyone in town got one
                if not bestWalker then
                    DeliveredWalkers = {}
                    for id, walker in pairs(WalkersTable) do
                        if walker.root and not walker.ragdolled then
                            bestWalker = walker
                            bestId = id
                            break
                        end
                    end
                end

                if bestWalker and bestWalker.root then
                    Config.LastTeleportTime = now
                    DeliveredWalkers[bestId] = true

                    -- Teleport right next to them facing them
                    hrp.CFrame = CFrame.lookAt(bestWalker.root.Position + (bestWalker.root.CFrame.LookVector * 2.5) + Vector3.new(0, 0.5, 0), bestWalker.root.Position)
                    workspace.CurrentCamera.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), bestWalker.root.Position)
                    
                    GivePamphletRE:FireServer(bestId)
                end

            elseif not Config.AutoTeleportWalkers and (now - Config.LastPamphletTime >= 0.3) then
                local myPos = hrp.Position
                for walkerId, walker in pairs(WalkersTable) do
                    local root = walker.root
                    if root and not walker.ragdolled then
                        if (root.Position - myPos).Magnitude <= 12 then
                            Config.LastPamphletTime = now
                            GivePamphletRE:FireServer(walkerId)
                            break
                        end
                    end
                end
            end
        end
    end

    -- 2. PET CARE
    if Config.AutoPetCare then
        local now = tick()
        if now - Config.LastCareTime >= 2.0 then
            Config.LastCareTime = now
            -- Search plot and workspace for enclosure / pen models
            local targets = {}
            if plot then
                for _, desc in ipairs(plot:GetDescendants()) do
                    if desc:IsA("Model") or desc:IsA("Folder") or desc:IsA("BasePart") then
                        local n = desc.Name:lower()
                        if n:find("enclosure") or n:find("pen") or n:find("cage") or desc:GetAttribute("EnclosureId") or desc:GetAttribute("PenId") then
                            table.insert(targets, desc)
                        end
                    end
                end
            end
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("Model") and (desc.Name:lower():find("enclosure") or desc.Name:lower():find("pen")) then
                    if not table.find(targets, desc) then table.insert(targets, desc) end
                end
            end

            for _, target in ipairs(targets) do
                pcall(function()
                    MaintainRE:FireServer(target, "Feed")
                    MaintainRE:FireServer(target, "Water")
                    MaintainRE:FireServer(target, "Clean")
                    MaintainRE:FireServer(target, "Filter")
                    MaintainRE:FireServer(target, "Restock")
                    MaintainRE:FireServer(target)
                end)
            end
        end
    end

    -- 3. CLEAN MESSES
    if Config.AutoCleanMesses then
        local now = tick()
        if now - Config.LastCleanTime >= 0.5 then
            Config.LastCleanTime = now
            local messes = {}
            if plot then
                for _, desc in ipairs(plot:GetDescendants()) do
                    local n = desc.Name:lower()
                    if n:find("mess") or n:find("spill") or n:find("poop") or n:find("stain") or n:find("dirt") or desc:GetAttribute("IsMess") or desc:GetAttribute("MessId") then
                        table.insert(messes, desc)
                    end
                end
            end
            -- Also check global workspace for mess folders or items
            for _, desc in ipairs(workspace:GetDescendants()) do
                local n = desc.Name:lower()
                if (n:find("mess") or n:find("spill") or n:find("poop")) and not n:find("controller") and not n:find("remote") then
                    if not table.find(messes, desc) then table.insert(messes, desc) end
                end
            end

            for _, mess in ipairs(messes) do
                pcall(function()
                    CleanMessRE:FireServer(mess)
                    CleanMessRE:FireServer(mess.Parent)
                end)
            end
        end
    end

    -- 4. ANTI-THEFT
    if Config.AutoBatThieves and hrp and WalkersTable then
        local now = tick()
        if now - Config.LastSwingTime >= 0.5 then
            local myPos = hrp.Position
            for _, walker in pairs(WalkersTable) do
                local root = walker.root
                local inst = walker.instance
                if root and inst and not walker.ragdolled then
                    if inst:GetAttribute("Stealing") == true or inst:GetAttribute("IsThief") == true then
                        if (root.Position - myPos).Magnitude <= 12 then
                            Config.LastSwingTime = now
                            pcall(function()
                                BatRemotes.Grab:FireServer()
                                SwingBatRE:FireServer(inst)
                            end)
                            break
                        end
                    end
                end
            end
        end
    end

    -- 5. AUTO CHECKOUT
    if Config.AutoCheckout and not Config.AutoTeleportWalkers then
        if not isManning and till and hrp then
            local pivot = till:GetPivot()
            local dist = (pivot.Position - hrp.Position).Magnitude
            if dist <= 12 then
                local now = tick()
                if now - Config.LastEnterAttempt >= 1.0 then
                    Config.LastEnterAttempt = now
                    RegisterStatusLabel.Text = "Hopping on register..."
                    enterRegister(till)
                end
            else
                RegisterStatusLabel.Text = string.format("Walk to register (%.0f studs)", dist)
            end
            return
        end

        if isManning and state then
            local phase = state.phase

            if phase == "Scanning" then
                RegisterStatusLabel.Text = string.format("Scanning items (%d/%d)...", state.scannedCount or 0, state.itemCount or 0)
                local now = tick()
                if now - Config.LastScanTime >= Config.ScanDelay then
                    Config.LastScanTime = now
                    local itemToScan = CheckoutGamepad.nextItem(till, (state.scannedCount or 0) + 1, state.transactionId, state.scannedIndices)
                    if itemToScan then
                        pcall(function()
                            ScanCurrentRE:FireServer(itemToScan, state.transactionId, itemToScan:GetAttribute("CheckoutItemIndex"))
                        end)
                    end
                end

            elseif phase == "AwaitingPayment" then
                RegisterStatusLabel.Text = "Accepting customer payment..."
                local now = tick()
                if now - Config.LastPaymentTime >= Config.PaymentDelay then
                    Config.LastPaymentTime = now
                    pcall(function() AcceptPresentedPaymentRE:FireServer(true) end)
                end

            elseif phase == "CashChange" then
                local changeDue = state.changeDueCents or 0
                RegisterStatusLabel.Text = string.format("Dispensing change: $%.2f", changeDue / 100)
                local now = tick()
                if now - Config.LastPaymentTime >= Config.PaymentDelay then
                    Config.LastPaymentTime = now
                    local changeBreakdown = calculateExactChange(changeDue)
                    pcall(function() SubmitCashChangeRE:FireServer(changeBreakdown) end)
                end

            elseif phase == "CardEntry" then
                local totalCents = state.totalCents or 0
                RegisterStatusLabel.Text = string.format("Charging card: $%.2f", totalCents / 100)
                local now = tick()
                if now - Config.LastPaymentTime >= Config.PaymentDelay then
                    Config.LastPaymentTime = now
                    pcall(function() SubmitCardAmountRE:FireServer(totalCents) end)
                end

            elseif phase == "Paid" then
                RegisterStatusLabel.Text = "✅ Sale Complete! Next customer..."
            else
                RegisterStatusLabel.Text = "Manning register • Waiting for customer"
            end
        end
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
end)

print("[Kenny's Automation Hub] V2 Deployed!")
return true
