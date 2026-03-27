-- MoneySystem.server.lua (ServerScriptService)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService     = game:GetService("InsertService")

local CarData          = require(ReplicatedStorage:WaitForChild("CarData"))
local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local MoneyUpdated     = Remotes:WaitForChild("MoneyUpdated")
local GetMoney         = Remotes:WaitForChild("GetMoney")
local BuyCar           = Remotes:WaitForChild("BuyCar")
local OwnedCarsUpdated = Remotes:WaitForChild("OwnedCarsUpdated")

-- Car lookup
local carById = {}
for _, car in ipairs(CarData) do
    carById[car.id] = car
end

-- Per-player data (session only — no DataStore so it works in Studio without API access)
local moneyCache     = {}  -- { [userId] = number }
local ownedCarsCache = {}  -- { [userId] = { carId = true } }

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function setMoney(player, amount)
    moneyCache[player.UserId] = amount
    local ls = player:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Money") then
        ls.Money.Value = amount
    end
    MoneyUpdated:FireClient(player, amount)
end

local function setupPlayer(player)
    -- Leaderstats
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local moneyVal = Instance.new("IntValue")
    moneyVal.Name = "Money"
    moneyVal.Value = 0
    moneyVal.Parent = ls

    -- Starting data
    moneyCache[player.UserId] = 0
    ownedCarsCache[player.UserId] = { BasicCar = true }

    MoneyUpdated:FireClient(player, 0)
    OwnedCarsUpdated:FireClient(player, {"BasicCar"})
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    moneyCache[player.UserId] = nil
    ownedCarsCache[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

-- ── Money loop: +1 every second ───────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local current = moneyCache[player.UserId] or 0
            setMoney(player, current + 1)
        end
    end
end)

-- ── RemoteFunction: GetMoney ──────────────────────────────────────────────────

GetMoney.OnServerInvoke = function(player)
    return moneyCache[player.UserId] or 0
end

-- ── RemoteFunction: BuyCar ───────────────────────────────────────────────────

BuyCar.OnServerInvoke = function(player, carId)
    local car = carById[carId]
    if not car then
        return { success = false, message = "Unknown car." }
    end

    local owned = ownedCarsCache[player.UserId]
    if not owned then
        return { success = false, message = "Data not ready, try again." }
    end
    if owned[carId] then
        return { success = false, message = "You already own this car!" }
    end

    local money = moneyCache[player.UserId] or 0
    if money < car.price then
        return { success = false, message = "Need $" .. car.price .. ", you have $" .. money .. "." }
    end

    -- Deduct and grant
    setMoney(player, money - car.price)
    owned[carId] = true

    local list = {}
    for id in pairs(owned) do table.insert(list, id) end
    OwnedCarsUpdated:FireClient(player, list)

    -- Spawn car
    if car.modelId and car.modelId ~= 0 then
        task.spawn(function()
            local ok, model = pcall(function()
                return InsertService:LoadAsset(car.modelId)
            end)
            if ok and model then
                local spawnPos = Vector3.new(0, 5, 0)
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    spawnPos = player.Character.HumanoidRootPart.Position + Vector3.new(0, 5, -10)
                end
                model:MoveTo(spawnPos)
                model.Parent = workspace
            end
        end)
    end

    return { success = true, message = "You bought the " .. car.name .. "!" }
end
