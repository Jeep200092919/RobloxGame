-- CarShopHandler.server.lua (ServerScriptService)
-- Handles car purchase requests from clients.
-- Stores owned cars in DataStore and spawns the purchased car for the player.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarData           = require(ReplicatedStorage:WaitForChild("CarData"))
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local BuyCar            = Remotes:WaitForChild("BuyCar")
local OwnedCarsUpdated  = Remotes:WaitForChild("OwnedCarsUpdated")

local OwnedCarsStore = DataStoreService:GetDataStore("PlayerOwnedCars_v1")

-- In-memory cache of owned cars per player  { [userId] = {carId = true, ...} }
local ownedCarsCache = {}

-- ── Build a lookup table for car data ────────────────────────────────────────

local carById = {}
for _, car in ipairs(CarData) do
    carById[car.id] = car
end

-- ── DataStore helpers ─────────────────────────────────────────────────────────

local function loadOwnedCars(player)
    local key = "owned_" .. player.UserId
    local success, data = pcall(function()
        return OwnedCarsStore:GetAsync(key)
    end)
    local owned = {}
    if success and type(data) == "table" then
        for _, carId in ipairs(data) do
            owned[carId] = true
        end
    end
    -- Everyone starts with the free car
    owned["BasicCar"] = true
    ownedCarsCache[player.UserId] = owned
    return owned
end

local function saveOwnedCars(player)
    local owned = ownedCarsCache[player.UserId]
    if not owned then return end
    local list = {}
    for carId in pairs(owned) do
        table.insert(list, carId)
    end
    local key = "owned_" .. player.UserId
    pcall(function()
        OwnedCarsStore:SetAsync(key, list)
    end)
end

local function getOwnedList(player)
    local owned = ownedCarsCache[player.UserId] or {}
    local list = {}
    for carId in pairs(owned) do
        table.insert(list, carId)
    end
    return list
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    local owned = loadOwnedCars(player)
    OwnedCarsUpdated:FireClient(player, getOwnedList(player))
end)

Players.PlayerRemoving:Connect(function(player)
    saveOwnedCars(player)
    ownedCarsCache[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    if not ownedCarsCache[player.UserId] then
        loadOwnedCars(player)
        OwnedCarsUpdated:FireClient(player, getOwnedList(player))
    end
end

-- ── Remote: BuyCar ───────────────────────────────────────────────────────────
-- Returns: { success = bool, message = string, ownedCars = table }

BuyCar.OnServerInvoke = function(player, carId)
    -- Validate car exists
    local car = carById[carId]
    if not car then
        return { success = false, message = "Unknown car." }
    end

    -- Check already owned
    local owned = ownedCarsCache[player.UserId]
    if not owned then
        return { success = false, message = "Player data not loaded yet." }
    end
    if owned[carId] then
        return { success = false, message = "You already own this car!" }
    end

    -- Wait for MoneySystem to be ready
    local ms = _G.MoneySystem
    if not ms then
        return { success = false, message = "Money system not ready." }
    end

    -- Check funds
    local currentMoney = ms.getMoney(player)
    if currentMoney < car.price then
        return {
            success = false,
            message = "Not enough money! Need $" .. car.price .. ", you have $" .. currentMoney .. ".",
        }
    end

    -- Deduct money and grant car
    ms.setMoney(player, currentMoney - car.price)
    owned[carId] = true
    saveOwnedCars(player)

    local newList = getOwnedList(player)
    OwnedCarsUpdated:FireClient(player, newList)

    -- ── Spawn the car ─────────────────────────────────────────────────────────
    if car.modelId and car.modelId ~= 0 then
        local insertService = game:GetService("InsertService")
        local loadOk, model = pcall(function()
            return insertService:LoadAsset(car.modelId)
        end)
        if loadOk and model then
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

    return {
        success   = true,
        message   = "You bought the " .. car.name .. "!",
        ownedCars = newList,
    }
end
