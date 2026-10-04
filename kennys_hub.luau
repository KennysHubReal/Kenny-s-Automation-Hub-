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
