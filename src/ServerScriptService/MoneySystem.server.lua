-- MoneySystem.server.lua (ServerScriptService)
-- Awards money every 5 seconds to every player in the game.
-- Persists money with DataStoreService.

local Players         = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoneyStore      = DataStoreService:GetDataStore("PlayerMoney_v1")
local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local MoneyUpdated    = Remotes:WaitForChild("MoneyUpdated")
local GetMoney        = Remotes:WaitForChild("GetMoney")

local MONEY_PER_INTERVAL = 10   -- $ awarded every interval
local AWARD_INTERVAL      = 5   -- seconds between awards
local DEFAULT_MONEY       = 0

-- In-memory cache so we don't hit DataStore on every tick
local moneyCache = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function loadMoney(player)
    local key = "player_" .. player.UserId
    local success, data = pcall(function()
        return MoneyStore:GetAsync(key)
    end)
    local amount = (success and type(data) == "number") and data or DEFAULT_MONEY
    moneyCache[player.UserId] = amount
    return amount
end

local function saveMoney(player)
    local amount = moneyCache[player.UserId]
    if amount == nil then return end
    local key = "player_" .. player.UserId
    pcall(function()
        MoneyStore:SetAsync(key, amount)
    end)
end

local function setMoney(player, amount)
    moneyCache[player.UserId] = amount
    -- Update leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local moneyValue = ls:FindFirstChild("Money")
        if moneyValue then
            moneyValue.Value = amount
        end
    end
    -- Notify the client
    MoneyUpdated:FireClient(player, amount)
end

local function addMoney(player, amount)
    local current = moneyCache[player.UserId] or 0
    setMoney(player, current + amount)
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

Players.PlayerAdded:Connect(function(player)
    setupLeaderstats(player)
    local amount = loadMoney(player)
    setMoney(player, amount)
end)

Players.PlayerRemoving:Connect(function(player)
    saveMoney(player)
    moneyCache[player.UserId] = nil
end)

-- Handle existing players (in case script loads after some players joined)
for _, player in ipairs(Players:GetPlayers()) do
    if not player:FindFirstChild("leaderstats") then
        setupLeaderstats(player)
    end
    local amount = loadMoney(player)
    setMoney(player, amount)
end

-- ── Remote: GetMoney ─────────────────────────────────────────────────────────

GetMoney.OnServerInvoke = function(player)
    return moneyCache[player.UserId] or 0
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

-- ── Expose helpers for CarShopHandler ────────────────────────────────────────

-- We share a module-style table via _G so CarShopHandler can call setMoney/addMoney.
-- (In a larger project you'd use a ModuleScript instead.)
_G.MoneySystem = {
    getMoney  = function(player) return moneyCache[player.UserId] or 0 end,
    setMoney  = setMoney,
    addMoney  = addMoney,
}
