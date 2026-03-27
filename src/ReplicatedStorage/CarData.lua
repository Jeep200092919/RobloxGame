-- CarData.lua (ReplicatedStorage > CarData)
-- Shared between server and client.

local CarData = {
    {
        id        = "BasicCar",
        name      = "Basic Car",
        price     = 0,           -- Free starter car
        modelId   = 85772091207211,
        color     = Color3.fromRGB(100, 149, 237),
        desc      = "A reliable ride to get you started.",
    },
    {
        id        = "SportsCar",
        name      = "Sports Car",
        price     = 500,
        modelId   = 17278432178,
        color     = Color3.fromRGB(220, 50, 50),
        desc      = "Fast and agile — built for the track.",
    },
    {
        id        = "MuscleCar",
        name      = "Muscle Car",
        price     = 1000,
        modelId   = 18442680024,
        color     = Color3.fromRGB(50, 180, 50),
        desc      = "Raw power under the hood.",
    },
    {
        id        = "Supercar",
        name      = "Supercar",
        price     = 2500,
        modelId   = 18867643635,
        color     = Color3.fromRGB(230, 200, 30),
        desc      = "Turns heads at every corner.",
    },
}

return CarData
