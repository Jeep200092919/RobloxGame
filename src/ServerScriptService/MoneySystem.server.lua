-- MoneySystem.server.lua (ServerScriptService)
-- Handles money awards, DataStore persistence, and car purchases.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarData        = require(ReplicatedStorage:WaitForChild("CarData"))
local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local MoneyUpdated   = Remotes:WaitForChild("MoneyUpdated")
local GetMoney       = Remotes:WaitForChild("GetMoney")
local BuyCar         = Remotes:WaitForChild("BuyCar")
local OwnedCarsUpdated = Remotes:WaitForChild("OwnedCarsUpdated")

local MoneyStore     = DataStoreService:GetDataStore("PlayerMoney_v1")
local OwnedCarsStore = DataStoreService:GetDataStore("PlayerOwnedCars_v1")

local MONEY_PER_INTERVAL = 10  -- $ awarded every interval
local AWARD_INTERVAL     = 5   -- seconds between awards

local moneyCache     = {}  -- { [userId] = number }
local ownedCarsCache = {}  -- { [userId] = { carId = true } }

-- Car lookup table
local carById = {}
for _, car in ipairs(CarData) do
    carById[car.id] = car
end

-- ── Money helpers ─────────────────────────────────────────────────────────────

local function loadMoney(player)
    local key = "player_" .. player.UserId
    local ok, data = pcall(function() return MoneyStore:GetAsync(key) end)
    local amount = (ok and type(data) == "number") and data or 0
    moneyCache[player.UserId] = amount
    return amount
end

local function saveMoney(player)
    local amount = moneyCache[player.UserId]
    if amount == nil then return end
    pcall(function() MoneyStore:SetAsync("player_" .. player.UserId, amount) end)
end

local function setMoney(player, amount)
    moneyCache[player.UserId] = amount
    local ls = player:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Money") then
        ls.Money.Value = amount
    end
    MoneyUpdated:FireClient(player, amount)
end

local function addMoney(player, amount)
    setMoney(player, (moneyCache[player.UserId] or 0) + amount)
end

-- ── Owned cars helpers ────────────────────────────────────────────────────────

local function loadOwnedCars(player)
    local key = "owned_" .. player.UserId
    local ok, data = pcall(function() return OwnedCarsStore:GetAsync(key) end)
    local owned = { BasicCar = true }
    if ok and type(data) == "table" then
        for _, carId in ipairs(data) do
            owned[carId] = true
        end
    end
    ownedCarsCache[player.UserId] = owned
    return owned
end

local function saveOwnedCars(player)
    local owned = ownedCarsCache[player.UserId]
    if not owned then return end
    local list = {}
    for carId in pairs(owned) do table.insert(list, carId) end
    pcall(function() OwnedCarsStore:SetAsync("owned_" .. player.UserId, list) end)
end

local function getOwnedList(player)
    local owned = ownedCarsCache[player.UserId] or {}
    local list = {}
    for carId in pairs(owned) do table.insert(list, carId) end
    return list
end

-- ── Leaderstats ───────────────────────────────────────────────────────────────

local function setupLeaderstats(player)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local moneyValue = Instance.new("IntValue")
    moneyValue.Name = "Money"
    moneyValue.Value = 0
    moneyValue.Parent = ls
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function onPlayerAdded(player)
    setupLeaderstats(player)
    local amount = loadMoney(player)
    setMoney(player, amount)
    loadOwnedCars(player)
    OwnedCarsUpdated:FireClient(player, getOwnedList(player))
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    saveMoney(player)
    saveOwnedCars(player)
    moneyCache[player.UserId] = nil
    ownedCarsCache[player.UserId] = nil
end)

-- Handle players already in game when script loads
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- ── Remotes ───────────────────────────────────────────────────────────────────

GetMoney.OnServerInvoke = function(player)
    return moneyCache[player.UserId] or 0
end

BuyCar.OnServerInvoke = function(player, carId)
    local car = carById[carId]
    if not car then
        return { success = false, message = "Unknown car." }
    end

    local owned = ownedCarsCache[player.UserId]
    if not owned then
        return { success = false, message = "Player data not loaded yet." }
    end
    if owned[carId] then
        return { success = false, message = "You already own this car!" }
    end

    local currentMoney = moneyCache[player.UserId] or 0
    if currentMoney < car.price then
        return {
            success = false,
            message = "Not enough money! Need $" .. car.price .. ", you have $" .. currentMoney .. ".",
        }
    end

    setMoney(player, currentMoney - car.price)
    owned[carId] = true
    saveOwnedCars(player)

    local newList = getOwnedList(player)
    OwnedCarsUpdated:FireClient(player, newList)

    -- Spawn the car near the player
    if car.modelId and car.modelId ~= 0 then
        local ok, model = pcall(function()
            return game:GetService("InsertService"):LoadAsset(car.modelId)
        end)
        if ok and model then
            local vehicle = model:FindFirstChildWhichIsA("Model")
            if vehicle then
                local spawnPos = Vector3.new(0, 5, 0)
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    spawnPos = player.Character.HumanoidRootPart.Position + Vector3.new(0, 5, -10)
                end
                vehicle:SetPrimaryPartCFrame(CFrame.new(spawnPos))
                vehicle.Parent = workspace
            end
            model:Destroy()
        end
    end

    return { success = true, message = "You bought the " .. car.name .. "!" }
end

-- ── Money award loop ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(AWARD_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            addMoney(player, MONEY_PER_INTERVAL)
        end
    end
end)
