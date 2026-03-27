-- CarShopGui.client.lua  (StarterGui > CarShopGui  — LocalScript)
-- Builds and manages the Car Shop GUI entirely from code.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CarData  = require(ReplicatedStorage:WaitForChild("CarData"))
local Remotes  = ReplicatedStorage:WaitForChild("Remotes")
local BuyCar   = Remotes:WaitForChild("BuyCar")
local GetMoney = Remotes:WaitForChild("GetMoney")
local MoneyUpdated    = Remotes:WaitForChild("MoneyUpdated")
local OwnedCarsUpdated = Remotes:WaitForChild("OwnedCarsUpdated")

-- ── State ─────────────────────────────────────────────────────────────────────
local currentMoney = 0
local ownedCars    = { BasicCar = true }   -- local mirror updated by server events
local cardButtons  = {}                    -- { [carId] = buyButton }

-- ── Color palette ─────────────────────────────────────────────────────────────
local C = {
    bg        = Color3.fromRGB(15,  15,  20),
    panel     = Color3.fromRGB(25,  25,  35),
    card      = Color3.fromRGB(30,  30,  45),
    cardHover = Color3.fromRGB(40,  40,  60),
    accent    = Color3.fromRGB(255, 200, 50),
    green     = Color3.fromRGB(50,  200, 100),
    red       = Color3.fromRGB(220, 60,  60),
    text      = Color3.fromRGB(240, 240, 255),
    subtext   = Color3.fromRGB(160, 160, 190),
    owned     = Color3.fromRGB(40,  120, 60),
    ownedText = Color3.fromRGB(100, 255, 130),
    topbar    = Color3.fromRGB(20,  20,  30),
}

-- ── UI helpers ────────────────────────────────────────────────────────────────

local function make(className, props, parent)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end

local function uiCorner(radius, parent)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function uiPadding(t, b, l, r, parent)
    return make("UIPadding", {
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
    }, parent)
end

local function uiStroke(thickness, color, parent)
    return make("UIStroke", {
        Thickness   = thickness,
        Color       = color,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

-- ── Build ScreenGui ───────────────────────────────────────────────────────────

local screenGui = make("ScreenGui", {
    Name             = "CarShop",
    ResetOnSpawn     = false,
    ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset   = true,
    Parent           = playerGui,
})

-- ── Toggle button (bottom-right) ──────────────────────────────────────────────

local toggleBtn = make("TextButton", {
    Name            = "ShopToggle",
    Size            = UDim2.new(0, 130, 0, 44),
    Position        = UDim2.new(1, -150, 1, -60),
    BackgroundColor3 = C.accent,
    Text            = "🚗  Car Shop",
    TextColor3      = Color3.fromRGB(20, 20, 20),
    TextScaled      = true,
    Font            = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent          = screenGui,
})
uiCorner(10, toggleBtn)
uiPadding(0, 0, 10, 10, toggleBtn)

-- ── Money HUD (top-left) ──────────────────────────────────────────────────────

local moneyFrame = make("Frame", {
    Name             = "MoneyHUD",
    Size             = UDim2.new(0, 160, 0, 44),
    Position         = UDim2.new(0, 16, 0, 16),
    BackgroundColor3 = C.topbar,
    BorderSizePixel  = 0,
    Parent           = screenGui,
})
uiCorner(10, moneyFrame)
uiStroke(1, C.accent, moneyFrame)

local moneyLabel = make("TextLabel", {
    Name            = "MoneyLabel",
    Size            = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text            = "💰  $0",
    TextColor3      = C.accent,
    TextScaled      = true,
    Font            = Enum.Font.GothamBold,
    Parent          = moneyFrame,
})
uiPadding(6, 6, 12, 12, moneyLabel)

-- ── Main shop panel ───────────────────────────────────────────────────────────

local shopPanel = make("Frame", {
    Name             = "ShopPanel",
    Size             = UDim2.new(0, 620, 0, 520),
    Position         = UDim2.new(0.5, -310, 0.5, -260),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    Visible          = false,
    Parent           = screenGui,
})
uiCorner(16, shopPanel)
uiStroke(2, C.accent, shopPanel)

-- Header bar
local header = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = C.topbar,
    BorderSizePixel  = 0,
    Parent           = shopPanel,
})
uiCorner(16, header)
-- Extend bottom corners to merge with panel
make("Frame", {
    Size             = UDim2.new(1, 0, 0, 16),
    Position         = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = C.topbar,
    BorderSizePixel  = 0,
    Parent           = header,
})

make("TextLabel", {
    Size                   = UDim2.new(1, -60, 1, 0),
    Position               = UDim2.new(0, 20, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "🚗  Car Shop",
    TextColor3             = C.accent,
    TextScaled             = true,
    Font                   = Enum.Font.GothamBold,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = header,
})

-- Close button
local closeBtn = make("TextButton", {
    Size             = UDim2.new(0, 36, 0, 36),
    Position         = UDim2.new(1, -46, 0, 10),
    BackgroundColor3 = C.red,
    Text             = "✕",
    TextColor3       = Color3.fromRGB(255, 255, 255),
    TextScaled       = true,
    Font             = Enum.Font.GothamBold,
    BorderSizePixel  = 0,
    Parent           = header,
})
uiCorner(8, closeBtn)

-- Subtitle / money display inside panel
local panelMoney = make("TextLabel", {
    Size                   = UDim2.new(1, -20, 0, 28),
    Position               = UDim2.new(0, 10, 0, 60),
    BackgroundTransparency = 1,
    Text                   = "Your balance:  $0",
    TextColor3             = C.subtext,
    TextScaled             = true,
    Font                   = Enum.Font.Gotham,
    TextXAlignment         = Enum.TextXAlignment.Right,
    Parent                 = shopPanel,
})

-- Scrolling car grid
local scrollFrame = make("ScrollingFrame", {
    Name                  = "CarGrid",
    Size                  = UDim2.new(1, -20, 1, -110),
    Position              = UDim2.new(0, 10, 0, 96),
    BackgroundTransparency = 1,
    BorderSizePixel       = 0,
    ScrollBarThickness    = 6,
    ScrollBarImageColor3  = C.accent,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    Parent                = shopPanel,
})

local gridLayout = make("UIGridLayout", {
    CellSize    = UDim2.new(0, 175, 0, 210),
    CellPadding = UDim2.new(0, 12, 0, 12),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Parent      = scrollFrame,
})

uiPadding(8, 8, 8, 8, scrollFrame)

-- ── Toast notification ────────────────────────────────────────────────────────

local toast = make("Frame", {
    Name             = "Toast",
    Size             = UDim2.new(0, 340, 0, 52),
    Position         = UDim2.new(0.5, -170, 0, -70),
    BackgroundColor3 = C.green,
    BorderSizePixel  = 0,
    Parent           = screenGui,
})
uiCorner(10, toast)

local toastLabel = make("TextLabel", {
    Size                   = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text                   = "",
    TextColor3             = Color3.fromRGB(255, 255, 255),
    TextScaled             = true,
    Font                   = Enum.Font.GothamBold,
    Parent                 = toast,
})
uiPadding(6, 6, 14, 14, toastLabel)

local toastTween = nil
local function showToast(message, success)
    if toastTween then toastTween:Cancel() end
    toast.BackgroundColor3 = success and C.green or C.red
    toastLabel.Text = message
    toast.Position  = UDim2.new(0.5, -170, 0, -70)

    local slideIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -170, 0, 20),
    })
    slideIn:Play()
    slideIn.Completed:Connect(function()
        task.wait(2.5)
        toastTween = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0.5, -170, 0, -70),
        })
        toastTween:Play()
    end)
end

-- ── Build car cards ───────────────────────────────────────────────────────────

local function updateCardState(carId)
    local btn = cardButtons[carId]
    if not btn then return end

    local car = nil
    for _, c in ipairs(CarData) do
        if c.id == carId then car = c break end
    end
    if not car then return end

    if ownedCars[carId] then
        btn.BackgroundColor3 = C.owned
        btn.TextColor3       = C.ownedText
        btn.Text             = "✔  Owned"
        btn.Active           = false
        btn.AutoButtonColor  = false
    elseif currentMoney >= car.price then
        btn.BackgroundColor3 = C.green
        btn.TextColor3       = Color3.fromRGB(255, 255, 255)
        btn.Text             = "Buy  $" .. car.price
        btn.Active           = true
        btn.AutoButtonColor  = true
    else
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        btn.TextColor3       = C.subtext
        btn.Text             = "💸  $" .. car.price
        btn.Active           = false
        btn.AutoButtonColor  = false
    end
end

local function buildCard(car)
    local card = make("Frame", {
        BackgroundColor3 = C.card,
        BorderSizePixel  = 0,
        Parent           = scrollFrame,
    })
    uiCorner(12, card)
    uiStroke(1, Color3.fromRGB(60, 60, 80), card)

    -- Color swatch / "preview"
    local swatch = make("Frame", {
        Size             = UDim2.new(1, -16, 0, 90),
        Position         = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = car.color,
        BorderSizePixel  = 0,
        Parent           = card,
    })
    uiCorner(8, swatch)

    -- Car icon label
    make("TextLabel", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "🚗",
        TextScaled             = true,
        Font                   = Enum.Font.GothamBold,
        Parent                 = swatch,
    })

    -- Car name
    make("TextLabel", {
        Size                   = UDim2.new(1, -8, 0, 22),
        Position               = UDim2.new(0, 4, 0, 104),
        BackgroundTransparency = 1,
        Text                   = car.name,
        TextColor3             = C.text,
        TextScaled             = true,
        Font                   = Enum.Font.GothamBold,
        Parent                 = card,
    })

    -- Description
    make("TextLabel", {
        Size                   = UDim2.new(1, -8, 0, 32),
        Position               = UDim2.new(0, 4, 0, 128),
        BackgroundTransparency = 1,
        Text                   = car.desc,
        TextColor3             = C.subtext,
        TextScaled             = true,
        Font                   = Enum.Font.Gotham,
        TextWrapped            = true,
        Parent                 = card,
    })

    -- Buy / Owned button
    local buyBtn = make("TextButton", {
        Size             = UDim2.new(1, -16, 0, 32),
        Position         = UDim2.new(0, 8, 1, -40),
        BorderSizePixel  = 0,
        Text             = "Buy  $" .. car.price,
        TextScaled       = true,
        Font             = Enum.Font.GothamBold,
        BackgroundColor3 = C.green,
        TextColor3       = Color3.fromRGB(255, 255, 255),
        Parent           = card,
    })
    uiCorner(8, buyBtn)

    cardButtons[car.id] = buyBtn

    buyBtn.MouseButton1Click:Connect(function()
        if not buyBtn.Active then return end
        buyBtn.Active = false
        buyBtn.Text   = "..."

        local result = BuyCar:InvokeServer(car.id)
        if result then
            showToast(result.message, result.success)
        end

        -- State is updated via OwnedCarsUpdated / MoneyUpdated events
        task.wait(0.5)
        updateCardState(car.id)
    end)

    -- Hover glow
    card.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.15), {
            BackgroundColor3 = C.cardHover,
        }):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.15), {
            BackgroundColor3 = C.card,
        }):Play()
    end)
end

for _, car in ipairs(CarData) do
    buildCard(car)
end

-- ── Update all cards ──────────────────────────────────────────────────────────

local function refreshAllCards()
    for _, car in ipairs(CarData) do
        updateCardState(car.id)
    end
end

-- ── Remote event listeners ────────────────────────────────────────────────────

MoneyUpdated.OnClientEvent:Connect(function(amount)
    currentMoney = amount
    moneyLabel.Text  = "💰  $" .. tostring(amount)
    panelMoney.Text  = "Your balance:  $" .. tostring(amount)
    refreshAllCards()
end)

OwnedCarsUpdated.OnClientEvent:Connect(function(list)
    ownedCars = {}
    for _, carId in ipairs(list) do
        ownedCars[carId] = true
    end
    refreshAllCards()
end)

-- ── Toggle logic ──────────────────────────────────────────────────────────────

local isOpen = false

local function setShopVisible(open)
    isOpen = open
    if open then
        shopPanel.Visible = true
        shopPanel.Size    = UDim2.new(0, 0, 0, 0)
        shopPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(shopPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Size     = UDim2.new(0, 620, 0, 520),
            Position = UDim2.new(0.5, -310, 0.5, -260),
        }):Play()
    else
        TweenService:Create(shopPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size     = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()
        task.delay(0.22, function() shopPanel.Visible = false end)
    end
end

toggleBtn.MouseButton1Click:Connect(function()
    setShopVisible(not isOpen)
end)
closeBtn.MouseButton1Click:Connect(function()
    setShopVisible(false)
end)

-- ── Init: fetch current money on join ────────────────────────────────────────

task.spawn(function()
    task.wait(1)   -- let server scripts load
    local money = GetMoney:InvokeServer()
    if money then
        currentMoney = money
        moneyLabel.Text = "💰  $" .. tostring(money)
        panelMoney.Text = "Your balance:  $" .. tostring(money)
        refreshAllCards()
    end
end)
