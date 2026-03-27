-- NascarTrack.server.lua (ServerScriptService)
-- Builds a NASCAR oval track with pit lane and pit stalls at game start.
-- TIP: Move the SpawnLocation in Workspace to around (-140, 5, 0)
--      so players spawn near the front straight.

-- ── Parameters ───────────────────────────────────────────────────────────────
local R        = 140   -- turn centerline radius (studs)
local SH       = 220   -- half-length of each straight (each straight = 440 studs)
local TW       = 26    -- track surface width
local WH       = 9     -- outer wall height
local WT       = 2     -- wall thickness
local TSEGS    = 24    -- segments per 180° turn (more = smoother curve)

-- Pit stop
local PW       = 14    -- pit road width
local PSTALLS  = 5     -- number of pit stalls
local PSTALL_L = 20    -- length of each stall

-- ── Colors ────────────────────────────────────────────────────────────────────
local C = {
    asphalt = Color3.fromRGB(55,  55,  62),
    pit     = Color3.fromRGB(180, 168, 148),
    wall    = Color3.fromRGB(218, 218, 218),
    grass   = Color3.fromRGB(58,  145, 58),
    white   = Color3.fromRGB(255, 255, 255),
    stalls  = {
        Color3.fromRGB(30,  60,  160),
        Color3.fromRGB(180, 30,  30),
        Color3.fromRGB(20,  130, 50),
        Color3.fromRGB(160, 130, 0),
        Color3.fromRGB(120, 20,  140),
    },
}

-- ── Setup ─────────────────────────────────────────────────────────────────────
local folder = Instance.new("Folder")
folder.Name   = "NascarTrack"
folder.Parent = workspace

local function make(name, size, cf, color, mat)
    local pt = Instance.new("Part")
    pt.Anchored      = true
    pt.CastShadow    = false
    pt.Name          = name
    pt.Size          = size
    pt.CFrame        = cf
    pt.Color         = color or C.asphalt
    pt.Material      = mat or Enum.Material.SmoothPlastic
    pt.TopSurface    = Enum.SurfaceType.Smooth
    pt.BottomSurface = Enum.SurfaceType.Smooth
    pt.Parent        = folder
    return pt
end

-- Builds one track piece with optional outer wall (local -X) and inner wall (local +X).
-- The CFrame's +Z axis is the direction of travel along the track.
local function seg(cf, len, surfColor, outerWH, innerWH)
    make("Track",   Vector3.new(TW, 0.4, len), cf, surfColor or C.asphalt)
    if outerWH and outerWH > 0 then
        make("WallOut", Vector3.new(WT, outerWH, len),
            cf * CFrame.new(-TW/2 - WT/2, outerWH/2, 0), C.wall)
    end
    if innerWH and innerWH > 0 then
        make("WallIn", Vector3.new(WT, innerWH, len),
            cf * CFrame.new(TW/2 + WT/2, innerWH/2, 0), C.wall)
    end
end

-- ── Front straight ───────────────────────────────────────────────────────────
-- Centerline: X = -R, direction: +Z.  No inner wall — pit wall takes its place.
seg(CFrame.new(-R, 0, 0), SH * 2, C.asphalt, WH, 0)

-- ── Back straight ────────────────────────────────────────────────────────────
-- Centerline: X = +R, direction: -Z (rotate 180° around Y).
seg(
    CFrame.new(R, 0, 0) * CFrame.Angles(0, math.pi, 0),
    SH * 2, C.asphalt, WH, WH * 0.5
)

-- ── North turn (center at world Z = +SH) ─────────────────────────────────────
-- alpha sweeps π → 0: pos = (R·cosα, 0, SH + R·sinα)
-- heading θ = atan2(sinα, -cosα)
local turnSegLen = math.pi * R / TSEGS
for i = 0, TSEGS - 1 do
    local a = math.pi - (i + 0.5) / TSEGS * math.pi
    seg(
        CFrame.new(R * math.cos(a), 0, SH + R * math.sin(a))
            * CFrame.Angles(0, math.atan2(math.sin(a), -math.cos(a)), 0),
        turnSegLen, C.asphalt, WH, WH * 0.5
    )
end

-- ── South turn (center at world Z = -SH) ─────────────────────────────────────
-- beta sweeps 0 → π: pos = (R·cosβ, 0, -SH - R·sinβ)
-- heading θ = atan2(-sinβ, -cosβ)
for i = 0, TSEGS - 1 do
    local b = (i + 0.5) / TSEGS * math.pi
    seg(
        CFrame.new(R * math.cos(b), 0, -SH - R * math.sin(b))
            * CFrame.Angles(0, math.atan2(-math.sin(b), -math.cos(b)), 0),
        turnSegLen, C.asphalt, WH, WH * 0.5
    )
end

-- ── Pit lane (infield side of front straight) ────────────────────────────────
-- Sits to the +X side of the front straight centerline.
-- Track inner edge:  X = -R + TW/2
-- Gap + wall:        + WT + 2
-- Pit road center:   + PW/2
local pitX = -R + TW/2 + WT + 2 + PW/2  -- ≈ -109

-- Pit road surface
make("PitRoad",  Vector3.new(PW, 0.4, SH * 2),
    CFrame.new(pitX, 0, 0), C.pit)

-- Wall separating track from pit road
make("PitWall",  Vector3.new(WT, WH * 0.45, SH * 2),
    CFrame.new(-R + TW/2 + WT/2, WH * 0.22, 0), C.wall)

-- Outer pit barrier
make("PitOuter", Vector3.new(WT, 4, SH * 2),
    CFrame.new(pitX + PW/2 + WT/2, 2, 0), C.wall)

-- ── Pit stalls ────────────────────────────────────────────────────────────────
local stallDepth   = 16
local stallSpacing = PSTALL_L + 2
local stallZStart  = -(PSTALLS - 1) * stallSpacing / 2  -- center stalls along Z=0

for i = 0, PSTALLS - 1 do
    local z   = stallZStart + i * stallSpacing
    local col = C.stalls[(i % #C.stalls) + 1]
    local stX = pitX + PW/2 + stallDepth / 2

    -- Stall floor (extends inward from pit road)
    make("Stall"   .. i, Vector3.new(stallDepth, 0.4, PSTALL_L),
        CFrame.new(stX, 0, z), col)

    -- Stall side divider wall
    make("Divider" .. i, Vector3.new(stallDepth, 3, WT),
        CFrame.new(stX, 1.5, z - PSTALL_L / 2), C.wall)

    -- Colored marker post at front of stall
    make("Post"    .. i, Vector3.new(1, 5, 1),
        CFrame.new(pitX + PW/2 + 1, 2.5, z), col)
end

-- ── Start / finish line ───────────────────────────────────────────────────────
make("StartFinish", Vector3.new(TW, 0.5, 1.5),
    CFrame.new(-R, 0.2, 0), C.white)

-- Pit entry line (where cars peel off into the pit lane)
make("PitEntry", Vector3.new(TW + PW + WT * 2, 0.5, 1),
    CFrame.new(pitX, 0.2, -SH * 0.55), C.white)

-- ── Infield grass ─────────────────────────────────────────────────────────────
make("Infield",
    Vector3.new(R * 2 - TW - WT * 2 - 6, 0.3, SH * 2),
    CFrame.new(0, -0.1, 0), C.grass, Enum.Material.Grass)

-- ── Outer ground ─────────────────────────────────────────────────────────────
make("Ground",
    Vector3.new((R + TW + WH + 80) * 2, 0.3, (SH + R + 80) * 2),
    CFrame.new(0, -0.25, 0), C.grass, Enum.Material.Grass)
