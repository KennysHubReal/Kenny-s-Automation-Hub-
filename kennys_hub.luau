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

local Checkout = Remotes:WaitForChild("Checkout")
local PamphletsRemotes = Remotes:WaitForChild("Pamphlets")
local EnclosuresRemotes = Remotes:WaitForChild("Enclosures")
local BatRemotes = Remotes:WaitForChild("Bat")
local MessRemotes = Remotes:WaitForChild("Mess")

local CheckoutController = require(Modules:WaitForChild("CheckoutController"))
local CheckoutGamepad = require(Modules:WaitForChild("CheckoutGamepad"))
local CheckoutMoney = require(Modules:WaitForChild("CheckoutMoney"))
local PedestrianController = require(Modules:WaitForChild("PedestrianController"))

local WalkersTable = debug.getupvalue(PedestrianController.walkerNearRay, 1)

local ScanCurrentRE = Checkout:WaitForChild("ScanCurrent")
local AcceptPresentedPaymentRE = Checkout:WaitForChild("AcceptPresentedPayment")
local SubmitCashChangeRE = Checkout:WaitForChild("SubmitCashChange")
local SubmitCardAmountRE = Checkout:WaitForChild("SubmitCardAmount")

local GrabPamphletRE = PamphletsRemotes:WaitForChild("Grab")
local GivePamphletRE = PamphletsRemotes:WaitForChild("Give")

local MaintainRE = EnclosuresRemotes:WaitForChild("Maintain")
local CleanMessRE = MessRemotes:WaitForChild("Clean")
local SwingBatRE = BatRemotes:WaitForChild("Swing")

-- Automation Config
local Config = {
    AutoCheckout = true,
    ScanDelay = 0.08,
    PaymentDelay = 0.12,
    LastScanTime = 0,
    LastPaymentTime = 0,
    LastEnterAttempt = 0,

    -- Pamphlet Settings
    AutoPamphlets = false,
    AutoTeleportWalkers = false,
    AutoGrabPamphlets = true,
    LastPamphletTime = 0,
    LastGrabTime = 0,
    LastTeleportTime = 0,

    AutoPetCare = false,
    LastCareTime = 0,

    AutoCleanMesses = false,
    LastCleanTime = 0,

    AutoBatThieves = false,
    LastSwingTime = 0,

    ToggleKey = Enum.KeyCode.RightControl
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
local Splash = Instance.new("Frame")
Splash.Name = "Splash"
Splash.Size = UDim2.new(0, 420, 0, 220)
Splash.Position = UDim2.new(0.5, -210, 0.45, -110)
Splash.BackgroundColor3 = Color3.fromRGB(11, 13, 19)
Splash.BorderSizePixel = 0
Splash.ClipsDescendants = true
Splash.Parent = ScreenGui

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

    -- Animate Tab Buttons
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

    -- Hide all other tabs immediately so they never overlay
    for name, _ in pairs(TabButtons) do
        local container = Tabs[name .. "_Container"]
        if container then
            if name ~= selected then
                container.Visible = false
                container.GroupTransparency = 1
            end
        end
    end

    -- Animate selected tab smoothly in
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
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(40, 48, 65)
        }):Play()
        callback(state)
    end)

    return frame
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

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Color3.fromRGB(255, 220, 80)
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if listening and not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            keyBtn.Text = input.KeyCode.Name
            keyBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
            callback(input.KeyCode)
        end
    end)

    return frame
end

-- ==========================================
-- POPULATE PAGES
-- ==========================================
-- 1. Register Page
local RegisterStatusLabel = createStatusCard(Tabs["Register"], "CASHIER SYSTEM STATUS", "Manning Register • Waiting for Customer")

createToggle(Tabs["Register"], "Auto Checkout (Scan & Pay)", Config.AutoCheckout, function(val)
    Config.AutoCheckout = val
end)

createActionBtn(Tabs["Register"], "⚡ Hop On Register (Auto E)", Color3.fromRGB(0, 140, 230), function()
    local plot = getMyPlot()
    local till = plot and plot:FindFirstChild("Checkout")
    enterRegister(till)
end)

-- 2. Pamphlet Page
local PamphletStatusLabel = createStatusCard(Tabs["Pamphlets"], "PAMPHLET STATUS", "Count: 0 | Idle")

createToggle(Tabs["Pamphlets"], "⚡ Fast Auto-Teleport to Walkers & Give", Config.AutoTeleportWalkers, function(val)
    Config.AutoTeleportWalkers = val
    Config.AutoPamphlets = val
end)

createToggle(Tabs["Pamphlets"], "Auto-Give Pamphlets (Aura Only)", Config.AutoPamphlets, function(val)
    Config.AutoPamphlets = val
end)

createToggle(Tabs["Pamphlets"], "Auto-Refill At Pamphlet Stand", Config.AutoGrabPamphlets, function(val)
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

createToggle(Tabs["Store & Pets"], "Auto-Care Pet Enclosures (Feed/Water)", Config.AutoPetCare, function(val)
    Config.AutoPetCare = val
end)

createToggle(Tabs["Store & Pets"], "Auto-Clean Spills & Messes", Config.AutoCleanMesses, function(val)
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

createToggle(Tabs["Security"], "Auto-Swing Bat at Thieves (Anti-Theft)", Config.AutoBatThieves, function(val)
    Config.AutoBatThieves = val
end)

createActionBtn(Tabs["Security"], "Equip Bat Now", Color3.fromRGB(220, 80, 80), function()
    pcall(function() BatRemotes.Grab:FireServer() end)
end)

-- 5. Settings Page
createStatusCard(Tabs["Settings"], "HUB SETTINGS & KEYBINDS", "Customize hotkeys and menu controls")

createKeybind(Tabs["Settings"], "Toggle UI Keybind", Config.ToggleKey, function(newKey)
    Config.ToggleKey = newKey
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
-- LOADING SEQUENCE WITH ANIMATED PROGRESS BAR
-- ==========================================
task.spawn(function()
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
    -- Smooth fade out
    TweenService:Create(Splash, TweenInfo.new(0.35), { Position = UDim2.new(0.5, -210, 0.38, -110), BackgroundTransparency = 1 }):Play()
    TweenService:Create(SplashStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    for _, desc in ipairs(Splash:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("Frame") then
            TweenService:Create(desc, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
            if desc:IsA("TextLabel") then
                TweenService:Create(desc, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
            end
        end
    end

    task.wait(0.35)
    Splash:Destroy()

    -- Pop in main dashboard with smooth transition
    setUIVisibility(true)
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
    if Config.AutoPetCare and plot then
        local now = tick()
        if now - Config.LastCareTime >= 3.0 then
            Config.LastCareTime = now
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
    end

    -- 3. CLEAN MESSES
    if Config.AutoCleanMesses and plot and hrp then
        local now = tick()
        if now - Config.LastCleanTime >= 1.0 then
            Config.LastCleanTime = now
            local messesFolder = plot:FindFirstChild("Messes")
            if messesFolder then
                for _, mess in ipairs(messesFolder:GetChildren()) do
                    pcall(function() CleanMessRE:FireServer(mess) end)
                end
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
