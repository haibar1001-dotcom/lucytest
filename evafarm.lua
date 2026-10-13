--[[
    ═════════════════════════════════════════════════════════════════════
    🐉 KAIJU ALPHA - AUTO FARM EVA (NATURAL & LEGIT SPEED SPRINT)
    ═════════════════════════════════════════════════════════════════════
    คุณสมบัติหลัก:
      1. ยืนรอในวงประตูวาปตลอดเวลาที่ตำแหน่ง Vector3.new(1918, 72, 863)
      2. อ่านเวลาบอสเกิดและจำนวนคิวคนจาก:
         Workspace/Map/BossPortal/BillboardAttach/BossTimer/TextLabel
      3. ตรวจเช็คจำนวนคนในเซิร์ฟเวอร์: ถ้าคนน้อยกว่า 5 คน จะ Hop หาเซิร์ฟเวอร์คนเยอะใหม่อัตโนมัติ
      4. ฟาร์มบอส Eva แบบธรรมชาติ 100%:
         - ไม่ใช้ Tween ลอยฟ้า ไม่ใช้ Speed Hack
         - ตัวละครวิ่ง (Sprint / IsRunning) ตลอดเวลา
         - เมื่อเกมวาร์ปเข้าห้องบอส + Eva เกิด: ยืนรอนิ่งๆ 15 วินาทีก่อนเริ่มตี
         - เมื่อครบ 15 วิ: วิ่งเข้าไปหาบอส Eva และสแปมสกิลใส่เมื่อเข้าใกล้ระยะตี
         - สกิลไหนที่เกมล็อคขา ก็ปล่อยให้ล็อคขาตามแอนิเมชันปกติ เนียนที่สุดจนคนดูไม่ออก
      5. หน้าต่าง UI บอกสถานะการฟาร์มอย่างละเอียด (เวลาบอส, จำนวนคน, จำนวน Eva ที่ฆ่า, Token)
      6. Discord Webhook แจ้งเตือนเมื่อฆ่า Eva สำเร็จ พร้อมสรุปจำนวนบอสและ Token
    ═════════════════════════════════════════════════════════════════════
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Compatibility layer: ไม่ผูกสคริปต์กับ executor เจ้าใดเจ้าหนึ่ง
-- ตัวรันที่ไม่มี getgenv จะใช้ _G แทน และความสามารถเสริมที่ไม่มีจะถูกข้าม
local getgenv = type(getgenv) == "function" and getgenv or function()
    return _G
end

--------------------------------------------------------------------------------
-- 0. CONFIGURATION
--------------------------------------------------------------------------------
local Config = {
    -- 🎯 ตำแหน่งศูนย์กลางวงประตูวาป Antarctica
    -- 🎯 ตำแหน่งศูนย์กลางวงประตูวาป Antarctica
    PortalWaitPosition  = Vector3.new(1918, 72, 863),

    -- เส้นทางเข้า Portal แบบเนียน เมื่อมีผู้เล่นอื่นอยู่ใกล้ Portal
    PortalStealthStart = Vector3.new(1467, 87, 815),
    PortalStealthWaypoints = {
        Vector3.new(1474, 46, 936),
        Vector3.new(1814, 62, 883),
        Vector3.new(1918, 72, 863),
    },
    PortalPlayerCheckRadius = 300,
    -- ถือว่ามาถึง Portal แล้วเมื่อเข้าใกล้รัศมีนี้ ไม่ต้องยืนทับจุดกลางเป๊ะๆ
    PortalArrivalRadius = 18,
    -- แตะบริเวณใกล้วงแล้วให้ล็อกยืนรอทันที ป้องกันเส้นทางสั่งเดินออกจากวงภายหลัง
    PortalHoldRadius = 30,

    -- ความเร็วเสริมขณะระบบกำลังสั่งให้ตัวละครวิ่ง (studs/วินาที)
    RunSpeedBoost = 20,
    -- อัตราเร่ง WalkSpeed แบบค่อยเป็นค่อยไป ป้องกันภาพกระชาก/สไลด์
    RunSpeedAcceleration = 34,

    -- ความนุ่มของการหันเฉพาะตัวละครเข้าหา Eva (ไม่บังคับกล้อง)
    AimTurnSmoothness = 5,
    CharacterTurnLerpAlpha = 0.16,
    CharacterTurnSpeed = 7.5,
    AimMaxAngularVelocity = 2.6,
    BeamAimUpdateInterval = 0.04,
    -- ปิด metatable hook เป็นค่าเริ่มต้นเพื่อรองรับตัวรัน PC ที่บล็อก hook
    -- ระบบเล็งผ่าน Remote ยังทำงานตามปกติ
    EnableMouseMetatableHook = false,
    -- สแกนข้อความ Portal/Boss ถี่ขึ้นเพื่อให้ตัดสินใจ Hop ได้เร็ว (แยก task จากลูปฟาร์ม)
    -- สแกนประตูถี่ขึ้น แต่ไม่ใช้ลูป busy-wait เพื่อไม่ให้มือถือค้าง
    CriticalTextScanInterval = 0.02,
    -- Hop ต่อไปจนกว่าจะเจอห้องที่เวลา Boss Spawn เหลือไม่เกินจำนวนนี้ (นาที)
    MaxBossSpawnMinutes = 10, -- เวลาเกิดบอส
    PlayerAvoidDistance = 55,
    PlayerAvoidStrength = 1.15,
    ObstacleProbeDistance = 65,
    StuckCheckInterval = 0.5,
    StuckMinimumMovement = 1.25,
    -- ตรวจพบว่าวิ่งหา Eva แต่ตำแหน่งไม่ขยับ ให้รีตัวทันทีในรอบตรวจแรก
    StuckTimeout = 0,
    ObstacleTurnDuration = 1.1,
    SkillCooldownMultiplier = 0,
    FPSBoostEnabled = true,
    FPSCap = 120,

    -- 🚪 ตำแหน่งจุดเกิดในห้องบอส (กรณีเข้าเซิร์ฟมาตอนบอสเริ่มสู้แล้วเข้าประตูไม่ทัน ให้วาปมาจุดนี้แล้วปล่อยหล่น)
    BossBattleSpawnPosition = Vector3.new(-9740, 1205, -4703),

    -- 🎯 ไคจูที่ต้องการเลือกเล่นก่อนกด Play (แก้ชื่อตัวที่จะเล่นได้ที่นี่)
    SelectedKaiju       = "Thermonuclear Godzilla",

    -- เกาะเกิดเริ่มต้น
    SpawnIsland         = "Skull Island",
    IslandNames         = { "Tokyo", "Isla de Mara", "Antarctica", "Desert", "Skull Island" },

    -- 👥 ระบบตรวจเช็คคนในเซิร์ฟเวอร์ (ถ้าน้อยกว่าค่านี้ ให้ Hop เซิร์ฟใหม่ทันที)
    MinPlayersRequired  = 5,
    -- เว้นช่วง Teleport ให้พอสำหรับมือถือ ไม่ยิงคำขอซ้ำจนแอปเด้ง
    ServerHopCooldown   = 1, -- วินาที: Hop หนึ่งครั้งแล้วเว้น 1 วิ
    TeleportAttemptTimeout = 3,
    HopRetryDelay = 1,

    -- 🛒 AUTO BUY EVENT BOOST
    -- เปิดใช้งานและใส่ชื่อได้หลายรายการ ระบบจะซื้อทีละรายการตามลำดับแล้ววนใหม่
    AutoBuyBoostEnabled = false,
    AutoBuyBoosts = {
        -- "60 Minutes Cell Boost",
        -- "60 Minutes Exp Boost",
        -- "30 Minutes Cell Boost",
        -- "30 Minutes Exp Boost",
    },
    AutoBuyBoostAmount = 1,
    AutoBuyBoostDelay = 0.8,
    AutoBuyBoostCycleDelay = 3,

    -- 📦 ใช้ไอเท็ม EXP ทั้งหมดกับ Kaiju ที่เลือกฟาร์ม (ไม่แตะไอเท็ม Boost)
    AutoUseExpEnabled = false,
    AutoUseExpDelay = 0.6,
    AutoUseExpScanInterval = 5,

    -- ⏱️ หน่วงเวลาก่อนเริ่มโจมตีเมื่อ Eva เกิด (วินาที)
    EvaEngageDelay      = 0,

    -- ⚔️ ระยะเข้าใกล้บอสเพื่อเริ่มสแปมสกิล (studs)
    AttackDistance      = 22,
    -- บีมเปิดใช้ได้ทุกระยะ (คงค่าไว้เพื่อความเข้ากันได้กับส่วนตั้งค่าเดิม)
    BeamOnlyBeyondDistance = 0,

    -- 📊 DISCORD WEBHOOK CONFIGURATION
    DiscordWebhookURL   = "https://discord.com/api/webhooks/1554722338090647592/re9xP_GoTzNN4ogWH5wZ656tVKcd5UcBzjsAHLgkgSZy7hAXm81K1rFDN2SIRS6GUh5-",
    DiscordWebhookEnabled = true,

    -- 🛑 สกิลที่ไม่ต้องการให้กดใช้
    ExcludedSkills = {
        Roar1  = true,
        Flight = true,
    },

    -- 📋 รายชื่อไคจูทั้งหมดในเกมสำหรับเลือกใส่ใน SelectedKaiju:
    AllKaijusList = {
        "Gojira 1954", "Anguirus", "Minilla", "Gorosaurus", "Gezora",
        "Mothra Larva", "Showa Rodan", "Gojira 1955", "Anguirus 1955", "Megalon",
        "Showa Gigan", "Showa Jet Jaguar", "Heisei Godzilla", "Junior Godzilla",
        "Rose Biollante", "Heisei Rodan", "Biollante", "Volcanic Biollante",
        "Burning Godzilla", "Destoroyah Aggregate", "Destoroyah Flying Form",
        "Destoroyah Final Form", "Space Godzilla", "Jet Jaguar Beta", "Kamata Kun",
        "Shinagawa Kun", "Shin Godzilla", "Godzilla Minus One", "GodzillaAquatilis",
        "Godzilla Amphibia", "Godzilla Terrestris", "Godzilla Ultima", "Godzilla 2000",
        "Millennian", "Zilla", "Orga (Second Form)", "Kiryu Type 3", "Monster X",
        "Final Wars Godzilla", "Suko", "Kong 2017", "Behemoth", "Scylla",
        "Titanus Rodan", "Godzilla 2014", "Titanus Doug", "Godzilla 2019",
        "Monster Zero", "King Ghidorah 2019", "Kong 2021", "Mechagodzilla 2021",
        "Thermonuclear Godzilla", "Mecha-King Ghidorah", "Scar King", "Shimo",
        "Godzilla Evolved", "Beast Glove Kong", "Shin Eva Godzilla"
    },
}

-- รองรับการตั้งค่าจาก loader: วาง getgenv().LucyHubConfig ไว้ก่อน loadstring
local RuntimeConfigOverrides = getgenv().LucyHubConfig

--------------------------------------------------------------------------------
-- 1. SERVICES & VARIABLES
--------------------------------------------------------------------------------
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local ConfigFileName = "LucyHub_Eva_Config.json"

local function GetHttpRequestFunction()
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http) == "table" and type(http.request) == "function" then return http.request end
    if type(http_request) == "function" then return http_request end
    if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
    if type(request) == "function" then return request end
    return nil
end

local function LoadSavedConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(ConfigFileName) then return end
    local ok, saved = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigFileName))
    end)
    if ok and type(saved) == "table" then
        if type(saved.WebhookURL) == "string" then Config.DiscordWebhookURL = saved.WebhookURL end
        if type(saved.WebhookEnabled) == "boolean" then Config.DiscordWebhookEnabled = saved.WebhookEnabled end
    end
end

local function SaveConfig()
    if type(writefile) ~= "function" then return false end
    return pcall(function()
        writefile(ConfigFileName, HttpService:JSONEncode({
            WebhookURL = Config.DiscordWebhookURL or "",
            WebhookEnabled = Config.DiscordWebhookEnabled == true,
        }))
    end)
end

LoadSavedConfig()

-- Config ที่ประกาศเหนือ loader มีสิทธิ์ทับค่าจากไฟล์ auto-save
if type(RuntimeConfigOverrides) == "table" then
    for configName, configValue in pairs(RuntimeConfigOverrides) do
        if Config[configName] ~= nil and configValue ~= nil then
            Config[configName] = configValue
        end
    end
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local RunToken = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))
getgenv().KaijuEvaFarm_RunToken = RunToken

local State = {
    Current = "Initializing",
    EvaDefeatedCount = 0,
    InitialTokens = nil,
    CurrentTokens = 0,
    TokensGained = 0,
    EvaSpawnTime = 0,
    IsEngagedWithEva = false,
    LastSkillCastTimes = {},
    LastHopAttempt = 0,
    IsHopping = false,
    BossTimerText = "Scanning...",
    ActiveEvaModel = nil,
    IsDroppingIntoBossRoom = false,
    BossDropStartedAt = 0,
    AutoWalking = false,
    DesiredMoveDirection = Vector3.zero,
    MouseLockEnabled = true,
    PortalRouteActive = false,
    PortalRouteIndex = 1,
    PortalHoldLocked = false,
    -- เริ่มต้นแบบระวังไว้ก่อน ป้องกันวาร์ปตรงระหว่างข้อมูลผู้เล่นยังโหลดไม่ครบ
    LastPortalPlayerSeen = os.clock(),
    LastWalkPosition = nil,
    LastWalkCheckAt = 0,
    StuckSince = nil,
    ObstacleAvoidUntil = 0,
    ObstacleAvoidSide = 1,
    ObstacleDetourPosition = nil,
    ObstacleDetourModel = nil,
    ReturningToLobby = false,
    PostEvaProcessing = false,
    SpawnInProgress = false,
    LastSpawnAttemptAt = 0,
    WaitingForPlayersDetected = false,
    WaitingForPlayersText = "",
    LastTokenReadAt = 0,
}

local NormalWalkSpeedByHumanoid = setmetatable({}, { __mode = "k" })
local LastAppliedWalkSpeed = setmetatable({}, { __mode = "k" })
local ExternalSlowScaleByHumanoid = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- 1.1 FPS BOOST (DISABLE HEAVY CLIENT-SIDE VFX)
--------------------------------------------------------------------------------
local OriginalVFXStates = setmetatable({}, { __mode = "k" })
local FPSBoostConnections = {}

local function OptimizeVFXInstance(instance)
    if not Config.FPSBoostEnabled or not instance then return end
    if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
        or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")
        or instance:IsA("PostEffect") or instance:IsA("PointLight")
        or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        if OriginalVFXStates[instance] == nil then
            OriginalVFXStates[instance] = instance.Enabled
        end
        instance.Enabled = false
    elseif instance:IsA("Explosion") then
        if OriginalVFXStates[instance] == nil then
            OriginalVFXStates[instance] = instance.Visible
        end
        instance.Visible = false
    elseif instance:IsA("BasePart") then
        instance.CastShadow = false
        if instance:IsA("MeshPart") then
            pcall(function() instance.RenderFidelity = Enum.RenderFidelity.Performance end)
        end
    end
end

local function ApplyFPSBoost()
    if type(setfpscap) == "function" then
        pcall(function() setfpscap(Config.FPSCap) end)
    end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Workspace.Terrain.Decoration = false
    end)

    task.spawn(function()
        local processed = 0
        for _, instance in ipairs(game:GetDescendants()) do
            if not Config.FPSBoostEnabled then break end
            OptimizeVFXInstance(instance)
            processed = processed + 1
            if processed % 400 == 0 then task.wait() end
        end
    end)
end

local function RestoreVFX()
    for instance, originalValue in pairs(OriginalVFXStates) do
        if instance and instance.Parent then
            pcall(function()
                if instance:IsA("Explosion") then
                    instance.Visible = originalValue
                else
                    instance.Enabled = originalValue
                end
            end)
        end
        OriginalVFXStates[instance] = nil
    end
end

table.insert(FPSBoostConnections, Workspace.DescendantAdded:Connect(OptimizeVFXInstance))
table.insert(FPSBoostConnections, Lighting.DescendantAdded:Connect(OptimizeVFXInstance))
ApplyFPSBoost()

getgenv().ToggleEvaFarmFPSBoost = function(enabled)
    Config.FPSBoostEnabled = enabled == true
    if Config.FPSBoostEnabled then
        ApplyFPSBoost()
    else
        RestoreVFX()
    end
end

getgenv().SetEvaFarmFPSCap = function(value)
    Config.FPSCap = math.max(30, tonumber(value) or 120)
    if type(setfpscap) == "function" then
        pcall(function() setfpscap(Config.FPSCap) end)
    end
end

--------------------------------------------------------------------------------
-- 2. REMOTES DISCOVERY
--------------------------------------------------------------------------------
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)
local CombatRemote = nil
local GetMousePosRemote = nil
local ChangeKaijuRemote = nil
local UpgradeStatRemote = nil
local FireServerRemote = nil
local BeamRemote = nil

local function ResolveRemotes()
    if not RemotesFolder then
        RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    end
    if RemotesFolder then
        if not CombatRemote then CombatRemote = RemotesFolder:FindFirstChild("CombatRemote") end
        if not GetMousePosRemote then GetMousePosRemote = RemotesFolder:FindFirstChild("GetMousePos") end
        if not ChangeKaijuRemote then ChangeKaijuRemote = RemotesFolder:FindFirstChild("ChangeKaiju") end
        if not UpgradeStatRemote then UpgradeStatRemote = RemotesFolder:FindFirstChild("UpgradeStat") end
        if not FireServerRemote then FireServerRemote = RemotesFolder:FindFirstChild("FireServer") end
        if not BeamRemote then
            BeamRemote = RemotesFolder:FindFirstChild("Beam")
                or RemotesFolder:FindFirstChild("BeamRemote")
                or RemotesFolder:FindFirstChild("FireServer")
        end
    end
end

--------------------------------------------------------------------------------
-- 2.1 AUTO BUY EVENT BOOSTS
--------------------------------------------------------------------------------
local EventBoostData = {
    ["60 Minutes Cell Boost"] = { Tokens = 100, Stocks = 2 },
    ["60 Minutes Exp Boost"] = { Tokens = 100, Stocks = 2 },
    ["30 Minutes Cell Boost"] = { Tokens = 50, Stocks = 5 },
    ["30 Minutes Exp Boost"] = { Tokens = 50, Stocks = 5 },
}

local function GetEventPurchaseState()
    local dataFolder = ReplicatedStorage:FindFirstChild("Data")
    local playerData = dataFolder and dataFolder:FindFirstChild(LocalPlayer.UserId .. "_Data")
    local eventData = playerData and playerData:FindFirstChild("HalloweenSS1")
    return eventData and eventData:FindFirstChild("Tokens"), eventData and eventData:FindFirstChild("Purchased")
end

local function AutoBuyConfiguredBoosts()
    if not Config.AutoBuyBoostEnabled or type(Config.AutoBuyBoosts) ~= "table"
        or #Config.AutoBuyBoosts == 0 then return end

    local eventShopRemote = RemotesFolder and RemotesFolder:FindFirstChild("EventShopRemote")
    if not eventShopRemote or not eventShopRemote:IsA("RemoteFunction") then return end

    local tokensValue, purchasedFolder = GetEventPurchaseState()
    if not tokensValue or not purchasedFolder then return end

    for _, boostName in ipairs(Config.AutoBuyBoosts) do
        if getgenv().KaijuEvaFarm_RunToken ~= RunToken then return end
        local item = EventBoostData[tostring(boostName)]
        if item then
            local purchasedValue = purchasedFolder:FindFirstChild(boostName)
            local alreadyBought = purchasedValue and tonumber(purchasedValue.Value) or 0
            local remainingStock = math.max(item.Stocks - alreadyBought, 0)
            local requested = math.max(1, math.floor(tonumber(Config.AutoBuyBoostAmount) or 1))
            local affordable = math.floor((tonumber(tokensValue.Value) or 0) / item.Tokens)
            local amount = math.min(requested, remainingStock, affordable)

            if amount > 0 then
                State.Current = string.format("Buying %s x%d...", boostName, amount)
                local ok, success, message = pcall(function()
                    return eventShopRemote:InvokeServer(boostName, amount)
                end)
                if not ok or not success then
                    warn("[Auto Buy Boost] Buy failed:", boostName, message or success)
                end
                task.wait(math.max(0.25, tonumber(Config.AutoBuyBoostDelay) or 0.8))
            end
        else
            warn("[Auto Buy Boost] Unknown boost name:", tostring(boostName))
        end
    end
end

task.spawn(function()
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        pcall(AutoBuyConfiguredBoosts)
        task.wait(math.max(1, tonumber(Config.AutoBuyBoostCycleDelay) or 3))
    end
end)
ResolveRemotes()

--------------------------------------------------------------------------------
-- 3. CHARACTER HELPERS & REAL RUNNING (SPRINT)
--------------------------------------------------------------------------------
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRoot(char)
    char = char or GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function GetHumanoid(char)
    char = char or GetCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function IsAliveAndSpawned()
    local char = GetCharacter()
    if not char or not char.Parent then return false end
    local hum = GetHumanoid(char)
    local root = GetRoot(char)
    if not hum or not root then return false end
    if hum.Health <= 0 then return false end

    local live = Workspace:FindFirstChild("Live")
    if live and not char:IsDescendantOf(live) then
        return false
    end
    return true
end

-- สั่งให้ตัวละครวิ่ง (Sprint) ตลอดเวลาอย่างเป็นธรรมชาติผ่านระบบของเกมแท้ๆ
local function EnsureRunning()
    local char = GetCharacter()
    if not char then return end
    pcall(function()
        if char:GetAttribute("CanRun") and not char:GetAttribute("IsRunning") then
            char:SetAttribute("IsRunning", true)
        end
    end)
end

local function DisableRunning()
    local char = GetCharacter()
    if not char then return end
    pcall(function()
        if char:GetAttribute("IsRunning") then
            char:SetAttribute("IsRunning", false)
        end
    end)
end

local function IsMovementRestrictedByGame(character, humanoid)
    if not character or not humanoid then return true, "NoCharacter" end
    if humanoid.Health <= 0 or humanoid.PlatformStand then return true, "Disabled" end
    if humanoid.WalkSpeed <= 0.5 then return true, "WalkSpeedLocked" end
    local root = GetRoot(character)
    if root and root.Anchored then return true, "RootAnchored" end

    local falseMeansLocked = { "CanMove", "CanWalk", "MovementEnabled" }
    for _, name in ipairs(falseMeansLocked) do
        local value = character:GetAttribute(name)
        if value == nil then value = humanoid:GetAttribute(name) end
        if value ~= nil and value == false then
            return true, name
        end
    end

    local trueMeansLocked = {
        "MovementLocked", "MoveLocked", "Rooted", "Stunned", "IsStunned",
        "SkillMovementLocked", "AttackMovementLocked", "CastingLocked"
    }
    for _, name in ipairs(trueMeansLocked) do
        if character:GetAttribute(name) == true or humanoid:GetAttribute(name) == true then
            return true, name
        end
    end

    return false, nil
end

local function GetGameSlowScale(character)
    if not character then return 1 end
    local scale = 1
    local speedMulti = tonumber(character:GetAttribute("SpeedMulti"))
    if speedMulti and speedMulti < 1 then
        scale = math.min(scale, math.clamp(speedMulti, 0, 1))
    end
    local slowness = tonumber(character:GetAttribute("Slowness"))
    if slowness then
        if slowness > 1 then
            scale = math.min(scale, 1 / slowness)
        elseif slowness >= 0 and slowness < 1 then
            scale = math.min(scale, slowness)
        end
    end
    return scale
end

-- ใช้ Humanoid:Move เหมือนอินพุต WASD เพื่อให้ MoveDirection และอนิเมชันเดิน/วิ่งทำงาน
-- ฟังก์ชันนี้จะถูกเรียกเฉพาะตอนอยู่ในห้องบอสเท่านั้น
local function ReturnToLobby()
    if State.ReturningToLobby then return end
    State.ReturningToLobby = true
    State.Current = "Movement blocked - returning to Lobby..."
    State.AutoWalking = false
    State.DesiredMoveDirection = Vector3.zero

    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local combatRemote = remotes and remotes:FindFirstChild("CombatRemote")
        if combatRemote and combatRemote:IsA("RemoteEvent") then
            combatRemote:FireServer("Death")
        end
    end)

    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local menuGui = playerGui:FindFirstChild("Menu") or playerGui:FindFirstChild("MainMenu")
            if menuGui and menuGui:IsA("ScreenGui") then menuGui.Enabled = true end
            for _, button in ipairs(playerGui:GetDescendants()) do
                if (button:IsA("TextButton") or button:IsA("ImageButton")) and button.Visible then
                    local name = button.Name:lower()
                    local text = button:IsA("TextButton") and button.Text:lower() or ""
                    if name:find("menu", 1, true) or name:find("lobby", 1, true)
                        or text:find("menu", 1, true) or text:find("lobby", 1, true) then
                        if firesignal then
                            pcall(function()
                                firesignal(button.Activated)
                                if button:IsA("TextButton") then firesignal(button.MouseButton1Click) end
                            end)
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then humanoid.Health = 0 end
    end)
    task.delay(8, function() State.ReturningToLobby = false end)
end

local function WalkNaturallyToward(humanoid, root, targetPosition)
    if not humanoid or not root then return false end
    local flatDirection = Vector3.new(
        targetPosition.X - root.Position.X,
        0,
        targetPosition.Z - root.Position.Z
    )
    if flatDirection.Magnitude < 0.05 then
        State.AutoWalking = false
        State.DesiredMoveDirection = Vector3.zero
        humanoid:Move(Vector3.zero, false)
        return false
    end
    local desiredDirection = flatDirection.Unit

    -- เดินตรงแบบธรรมชาติเท่านั้น; ถ้าตำแหน่งไม่ขยับ ให้กลับ Lobbyแทนการเลี้ยวสไลด์
    if State.IsEngagedWithEva then
        local now = os.clock()
        local currentPosition = Vector3.new(root.Position.X, 0, root.Position.Z)
        if not State.LastWalkPosition then
            State.LastWalkPosition = currentPosition
            State.LastWalkCheckAt = now
        elseif now - State.LastWalkCheckAt >= Config.StuckCheckInterval then
            local moved = (currentPosition - State.LastWalkPosition).Magnitude
            if moved < Config.StuckMinimumMovement and flatDirection.Magnitude > Config.AttackDistance then
                -- นับเฉพาะการติดจริงต่อเนื่อง; การหยุดสั้น ๆ ระหว่างอนิเมชัน/สกิลไม่รีทันที
                State.StuckSince = State.StuckSince or now
                if now - State.StuckSince >= Config.StuckTimeout then
                    ReturnToLobby()
                    return false
                end
            else
                State.StuckSince = nil
            end
            State.LastWalkPosition = currentPosition
            State.LastWalkCheckAt = now
        end
    end

    State.DesiredMoveDirection = desiredDirection
    State.AutoWalking = true

    -- MoveTo ช่วยรองรับคอนโทรลเลอร์ของไคจูบางตัว ส่วน RenderStep ด้านล่าง
    -- จะย้ำ MoveDirection หลัง PlayerModule เพื่อไม่ให้คำสั่งถูกเขียนทับ
    humanoid:Move(State.DesiredMoveDirection, false)
    return true
end

local function StopNaturalWalk(humanoid)
    State.AutoWalking = false
    State.DesiredMoveDirection = Vector3.zero
    State.LastWalkPosition = nil
    State.LastWalkCheckAt = 0
    State.StuckSince = nil
    State.ObstacleDetourPosition = nil
    State.ObstacleDetourModel = nil
    if humanoid and LastAppliedWalkSpeed and LastAppliedWalkSpeed[humanoid] then
        humanoid.WalkSpeed = NormalWalkSpeedByHumanoid[humanoid] or humanoid.WalkSpeed
        LastAppliedWalkSpeed[humanoid] = nil
        ExternalSlowScaleByHumanoid[humanoid] = nil
    end
    if humanoid then
        humanoid:Move(Vector3.zero, false)
    end
end

-- ปิด collision ของผู้เล่นอื่นเฉพาะฝั่ง client ระหว่างตาม Eva
-- เพื่อให้เดินผ่านกันได้โดยไม่ติดร่าง และเก็บค่าเดิมไว้คืนภายหลัง
local PlayerCollisionOriginal = setmetatable({}, { __mode = "k" })
local LastPlayerCollisionUpdate = 0

local function RestoreOtherPlayerCollisions()
    for part, originalValue in pairs(PlayerCollisionOriginal) do
        if part and part.Parent then
            pcall(function() part.CanCollide = originalValue end)
        end
        PlayerCollisionOriginal[part] = nil
    end
end

local function DisableOtherPlayerCollisions()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, descendant in ipairs(player.Character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if PlayerCollisionOriginal[descendant] == nil then
                        PlayerCollisionOriginal[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
        end
    end
end

local PlayerNoCollisionConnection = RunService.Heartbeat:Connect(function()
    if getgenv().KaijuEvaFarm_RunToken ~= RunToken then return end
    local shouldDisable = State.IsEngagedWithEva and State.AutoWalking
    if shouldDisable then
        local now = os.clock()
        if now - LastPlayerCollisionUpdate >= 0.15 then
            LastPlayerCollisionUpdate = now
            DisableOtherPlayerCollisions()
        end
    elseif next(PlayerCollisionOriginal) ~= nil then
        RestoreOtherPlayerCollisions()
    end
end)

local function HasOtherPlayerNearPortal()
    local portal2D = Vector2.new(Config.PortalWaitPosition.X, Config.PortalWaitPosition.Z)

    local function GetModelPosition(model)
        if not model then return nil end
        local primaryPart = model:IsA("Model") and model.PrimaryPart or nil
        local root = model:FindFirstChild("HumanoidRootPart", true) or primaryPart
        if root and root:IsA("BasePart") then
            return root.Position
        end
        local ok, pivot = pcall(function()
            return model:GetPivot()
        end)
        return ok and pivot.Position or nil
    end

    local function IsInsideRadius(model)
        local position = GetModelPosition(model)
        if not position then return false end
        -- ใช้ระยะแนวราบ X/Z เพราะระดับความสูงของไคจูแต่ละตัวต่างกันมาก
        local distance2D = (Vector2.new(position.X, position.Z) - portal2D).Magnitude
        return distance2D <= Config.PortalPlayerCheckRadius
    end

    local live = Workspace:FindFirstChild("Live")
    local checkedModels = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character then checkedModels[character] = true end
            if character and IsInsideRadius(character) then
                State.LastPortalPlayerSeen = os.clock()
                return true
            end

            -- บางครั้งเกมเก็บร่างไคจูไว้ใน workspace.Live แต่ Player.Character ยังไม่ชี้มาที่ร่างนั้น
            if live then
                local liveCharacter = live:FindFirstChild(player.Name)
                    or live:FindFirstChild(tostring(player.UserId))
                if liveCharacter and liveCharacter ~= character and IsInsideRadius(liveCharacter) then
                    State.LastPortalPlayerSeen = os.clock()
                    return true
                end

                for _, model in ipairs(live:GetChildren()) do
                    if model:IsA("Model") and model ~= character then
                        local ownerId = tonumber(model:GetAttribute("UserId")
                            or model:GetAttribute("PlayerUserId")
                            or model:GetAttribute("OwnerUserId"))
                        if ownerId == player.UserId and IsInsideRadius(model) then
                            State.LastPortalPlayerSeen = os.clock()
                            return true
                        end
                    end
                end
            end
        end
    end

    -- สแกนทุกร่างใน workspace.Live อีกชั้นโดยไม่พึ่งชื่อ/OwnerId
    -- เกมบางรอบไม่ผูก Player.Character หรือใช้ชื่อโมเดลที่ไม่ตรงกับชื่อผู้เล่น
    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character and not checkedModels[model] then
                local hasCharacterBody = model:FindFirstChildOfClass("Humanoid") ~= nil
                    or model:FindFirstChild("HumanoidRootPart", true) ~= nil
                if hasCharacterBody and IsInsideRadius(model) then
                    State.LastPortalPlayerSeen = os.clock()
                    return true
                end
            end
        end
    end

    -- Latch 3 วินาที: ถ้าโมเดลผู้เล่นหายชั่วคราวตอน respawn/streaming ก็ยังห้ามวาร์ปตรง
    return (os.clock() - State.LastPortalPlayerSeen) <= 3
end

-- ต้องตรวจว่า Portal ว่างต่อเนื่องหลายครั้งก่อนอนุญาตให้วาร์ปตรง
-- ป้องกัน Player.Character/ร่างไคจูโหลดช้าหรือหายชั่วคราวจาก streaming
local function ConfirmPortalClearForDirectWarp()
    for checkIndex = 1, 3 do
        if HasOtherPlayerNearPortal() then
            return false
        end
        if checkIndex < 3 then
            task.wait(0.15)
        end
    end
    return not HasOtherPlayerNearPortal()
end

-- PlayerModule จะเขียนทับ Humanoid:Move ทุกเฟรม จึงส่งคำสั่งหลังระบบควบคุมปกติ
-- ทำงานเฉพาะเมื่อโหมดตาม Eva เปิดอยู่เท่านั้น
local MovementRenderStepName = "KaijuEvaNaturalWalk_" .. RunToken
RunService:BindToRenderStep(MovementRenderStepName, Enum.RenderPriority.Character.Value + 1, function(dt)
    if getgenv().KaijuEvaFarm_RunToken ~= RunToken or not State.AutoWalking then
        return
    end

    local char = GetCharacter()
    local hum = GetHumanoid(char)
    local restricted = char and hum and IsMovementRestrictedByGame(char, hum)
    if restricted then
        hum:Move(Vector3.zero, false)
        return
    end
    if hum and hum.Health > 0 then
        -- ย้ำ WalkSpeed หลัง PlayerModule เพื่อไม่ให้ระบบเกมเขียนค่าบูสต์ทับ
        -- ใช้ค่าที่เก็บแยกไว้เพื่อให้เร่งต่อเนื่อง แม้เกมรีเซ็ต WalkSpeed ในเฟรมถัดไป
        local baseline = NormalWalkSpeedByHumanoid[hum]
        if not baseline then
            baseline = hum.WalkSpeed
            NormalWalkSpeedByHumanoid[hum] = baseline
        end
        local slowScale = GetGameSlowScale(char)
        local targetSpeed = (baseline + Config.RunSpeedBoost) * slowScale
        local currentSpeed = LastAppliedWalkSpeed[hum] or baseline
        local maxChange = (Config.RunSpeedAcceleration or 34) * math.max(dt or (1 / 60), 0)
        local nextSpeed = currentSpeed + math.clamp(targetSpeed - currentSpeed, -maxChange, maxChange)
        hum.WalkSpeed = nextSpeed
        LastAppliedWalkSpeed[hum] = nextSpeed
        hum:Move(State.DesiredMoveDirection, false)
    end
end)

-- เพิ่มระยะเคลื่อนที่อีก +13 studs/วินาทีตาม MoveDirection
-- ทำงานเฉพาะตอน AutoWalking เพื่อไม่รบกวนการบังคับตัวละครด้วยมือ
local SpeedBoostEnabled = true
local SpeedBoostConnection = RunService.Heartbeat:Connect(function(dt)
    if getgenv().KaijuEvaFarm_RunToken ~= RunToken then
        return
    end

    local char = GetCharacter()
    local hum = GetHumanoid(char)
    local root = GetRoot(char)
    if not char or not hum or not root or hum.Health <= 0 then return end
    if not SpeedBoostEnabled or not State.AutoWalking then
        if LastAppliedWalkSpeed[hum]
            and math.abs(hum.WalkSpeed - LastAppliedWalkSpeed[hum]) < 0.1 then
            hum.WalkSpeed = NormalWalkSpeedByHumanoid[hum] or hum.WalkSpeed
        end
        LastAppliedWalkSpeed[hum] = nil
        ExternalSlowScaleByHumanoid[hum] = nil
        return
    end
    local restricted = IsMovementRestrictedByGame(char, hum)
    if restricted then
        if LastAppliedWalkSpeed[hum] then
            hum.WalkSpeed = NormalWalkSpeedByHumanoid[hum] or hum.WalkSpeed
        end
        LastAppliedWalkSpeed[hum] = nil
        ExternalSlowScaleByHumanoid[hum] = nil
        return
    end
    local slowScale = GetGameSlowScale(char)
    local baseline = NormalWalkSpeedByHumanoid[hum]
    if not baseline then
        baseline = hum.WalkSpeed
        NormalWalkSpeedByHumanoid[hum] = baseline
    end
    local previousApplied = LastAppliedWalkSpeed[hum]
    if previousApplied and math.abs(hum.WalkSpeed - previousApplied) > 0.1
        and hum.WalkSpeed < baseline * 0.9 then
        ExternalSlowScaleByHumanoid[hum] = math.clamp(hum.WalkSpeed / baseline, 0, 1)
    elseif hum.WalkSpeed >= baseline * 0.9 then
        ExternalSlowScaleByHumanoid[hum] = nil
    end
    if ExternalSlowScaleByHumanoid[hum] then
        slowScale = math.min(slowScale, ExternalSlowScaleByHumanoid[hum])
    end
    local targetWalkSpeed = (baseline + Config.RunSpeedBoost) * slowScale
    if math.abs(hum.WalkSpeed - targetWalkSpeed) > 0.1 then
        -- เพิ่มความเร็วผ่าน Humanoid เท่านั้น และไล่ความเร็วแบบ smooth ตามเวลา
        -- ไม่ดัน CFrame/Velocity จึงยังใช้แอนิเมชันวิ่งปกติและไม่สไลด์
        local difference = targetWalkSpeed - hum.WalkSpeed
        local maxChange = (Config.RunSpeedAcceleration or 34) * math.max(dt, 0)
        hum.WalkSpeed = hum.WalkSpeed + math.clamp(difference, -maxChange, maxChange)
    end
    LastAppliedWalkSpeed[hum] = hum.WalkSpeed
end)

getgenv().SetEvaFarmSpeedBoost = function(value)
    Config.RunSpeedBoost = math.max(0, tonumber(value) or 20)
end

getgenv().ToggleEvaFarmSpeedBoost = function(enabled)
    SpeedBoostEnabled = enabled == true
end

local function InstantWarp(cf)
    local char = GetCharacter()
    local root = GetRoot(char)
    if not root then return end
    root.Anchored = false
    if char and char:IsA("Model") then
        pcall(function() char:PivotTo(cf) end)
    end
    root.CFrame = cf
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

--------------------------------------------------------------------------------
-- 4. READ TOKENS & GAME DATA
--------------------------------------------------------------------------------
local function GetPlayerTokens()
    local tokens = 0
    pcall(function()
        local dataFolder = ReplicatedStorage:FindFirstChild("Data")
        if dataFolder then
            local pData = dataFolder:FindFirstChild(LocalPlayer.UserId .. "_Data")
            if pData then
                -- 1. Direct Tokens Value
                local tVal = pData:FindFirstChild("Tokens")
                if tVal and (tVal:IsA("IntValue") or tVal:IsA("NumberValue") or tVal:IsA("StringValue")) then
                    tokens = tonumber(tVal.Value) or 0
                    return
                end
                -- 2. Event Folders (HalloweenSS1, Event, Season)
                for _, child in ipairs(pData:GetChildren()) do
                    if child:IsA("Folder") or child:IsA("Configuration") then
                        local subT = child:FindFirstChild("Tokens")
                        if subT and (subT:IsA("IntValue") or subT:IsA("NumberValue") or subT:IsA("StringValue")) then
                            tokens = tonumber(subT.Value) or 0
                            return
                        end
                    end
                end
                -- 3. Any descendant named Tokens
                for _, desc in ipairs(pData:GetDescendants()) do
                    if desc.Name == "Tokens" and (desc:IsA("IntValue") or desc:IsA("NumberValue") or desc:IsA("StringValue")) then
                        tokens = tonumber(desc.Value) or 0
                        return
                    end
                end
            end
        end

        -- 4. Check UI if ReplicatedStorage data is masked
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            for _, desc in ipairs(pGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible and desc.Text:find("Tokens") then
                    local numStr = desc.Text:gsub("%D", "")
                    if numStr ~= "" then
                        tokens = tonumber(numStr) or tokens
                        return
                    end
                end
            end
        end
    end)
    return tokens
end

-- Initialize token baseline
task.spawn(function()
    task.wait(2)
    State.InitialTokens = GetPlayerTokens()
    State.CurrentTokens = State.InitialTokens
end)

--------------------------------------------------------------------------------
-- 5. READ BOSS TIMER & QUEUE (BILLBOARD TEXTLABEL)
-- Path: Workspace/Map/BossPortal/BillboardAttach/BossTimer/TextLabel
--------------------------------------------------------------------------------
local function UpdateBossTimerText()
    local text = ""
    pcall(function()
        local bp = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("BossPortal")
        if not bp then bp = Workspace:FindFirstChild("BossPortal", true) end
        if bp then
            local bbAttach = bp:FindFirstChild("BillboardAttach") or bp:FindFirstChild("BillboardAttach", true)
            local bTimer = bbAttach and (bbAttach:FindFirstChild("BossTimer") or bbAttach:FindFirstChild("BossTimer", true))
            local txtLbl = bTimer and (bTimer:FindFirstChild("TextLabel") or bTimer:FindFirstChildOfClass("TextLabel"))
            if txtLbl and txtLbl:IsA("TextLabel") and txtLbl.Text ~= "" then
                text = txtLbl.Text
            else
                for _, desc in ipairs(bp:GetDescendants()) do
                    local lowerText = desc:IsA("TextLabel") and desc.Text:lower() or ""
                    if desc:IsA("TextLabel") and desc.Visible
                        and ((lowerText:find("boss", 1, true) and lowerText:find("spawn", 1, true))
                            or lowerText:match("%d+%s*:%s*%d+")) then
                        text = desc.Text
                        break
                    end
                end
            end
        end
    end)

    if text ~= "" then
        -- แปลงข้อความหลายบรรทัดให้อยู่ในบรรทัดเดียวสวยๆ
        local clean = text:gsub("\n", " | "):gsub("%s+", " ")
        State.BossTimerText = clean
    else
        State.BossTimerText = "Not Detected"
    end
    return State.BossTimerText
end

local function IsWaitingForPlayersText(text)
    local compact = tostring(text or ""):lower():gsub("%s+", " ")
    return compact:find("waiting for players", 1, true) ~= nil
        or compact:gsub("[^%w]", ""):find("waitingforplayers", 1, true) ~= nil
end

local function ScanCriticalBossText()
    local detected, matchedText = false, ""
    local function scanContainer(container)
        if not container or detected then return end
        -- ตรวจจุดข้อความที่เกมใช้จริงก่อน (เร็วกว่าไล่ descendants ทั้งต้นไม้มาก)
        local direct = container:FindFirstChild("TextLabel", true)
        if direct and direct:IsA("TextLabel") and direct.Visible and IsWaitingForPlayersText(direct.Text) then
            detected, matchedText = true, direct.Text
            return
        end
        for _, desc in ipairs(container:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible
                and IsWaitingForPlayersText(desc.Text) then
                detected = true
                matchedText = desc.Text
                return
            end
        end
    end

    pcall(function()
        scanContainer(LocalPlayer:FindFirstChild("PlayerGui"))
        local map = Workspace:FindFirstChild("Map")
        scanContainer(map and map:FindFirstChild("Colosseum"))
        scanContainer(map and map:FindFirstChild("BossPortal"))
    end)

    State.WaitingForPlayersDetected = detected
    State.WaitingForPlayersText = matchedText:gsub("\n", " | "):gsub("%s+", " ")
    if detected then State.BossTimerText = State.WaitingForPlayersText end
    return detected
end

task.spawn(function()
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        ScanCriticalBossText()
        task.wait(Config.CriticalTextScanInterval)
    end
end)

local function GetBossSpawnSeconds()
    local text = tostring(State.BossTimerText or ""):lower()
    -- อ่านเฉพาะสถานะนับถอยหลัง Boss Spawn In เพื่อไม่สับสนกับข้อความอื่น
    local compact = text:gsub("%s+", " ")
    if not compact:find("boss") or not compact:find("spawn") then
        return nil
    end
    local minutes, seconds = compact:match("(%d+)%s*:%s*(%d+)")
    minutes, seconds = tonumber(minutes), tonumber(seconds)
    if not minutes or not seconds or seconds > 59 then return nil end
    return (minutes * 60) + seconds
end

--------------------------------------------------------------------------------
-- 6. AUTO SPAWN & SELECT KAIJU (AUTO PLAY ALWAYS ACTIVE AT LOBBY)
--------------------------------------------------------------------------------
local function SafeClickUI(btn)
    if not btn or not btn:IsA("GuiObject") then return false end
    local clicked = false
    pcall(function()
        -- รองรับ executor/อุปกรณ์มือถือที่ไม่มี firesignal หรือ getconnections
        if btn:IsA("GuiButton") then
            btn:Activate()
            clicked = true
        end
        if firesignal and btn:IsA("GuiButton") then
            firesignal(btn.Activated)
            if btn:IsA("TextButton") then firesignal(btn.MouseButton1Click) end
            clicked = true
        end
        local events = { "Activated", "MouseButton1Click", "MouseButton1Down" }
        for _, ev in ipairs(events) do
            if getconnections and btn[ev] then
                for _, conn in ipairs(getconnections(btn[ev])) do
                    conn:Fire()
                    clicked = true
                end
            end
        end
    end)
    return clicked
end

local function GetExactOwnedKaijuName(targetName)
    local pData = ReplicatedStorage:FindFirstChild("Data") and ReplicatedStorage.Data:FindFirstChild(LocalPlayer.UserId .. "_Data")
    local kInv = pData and pData:FindFirstChild("KaijuInventory")
    if kInv then
        if kInv:FindFirstChild(targetName) then
            return targetName
        end
        local targetClean = targetName:lower():gsub("%s+", "")
        for _, child in ipairs(kInv:GetChildren()) do
            if child.Name:lower():gsub("%s+", "") == targetClean then
                return child.Name
            end
        end
        for _, child in ipairs(kInv:GetChildren()) do
            if child.Name:lower():find(targetName:lower(), 1, true) then
                return child.Name
            end
        end
    end
    return targetName
end

local function PrepareSelectedKaiju()
    ResolveRemotes()
    local fireRemote = FireServerRemote or (RemotesFolder and RemotesFolder:FindFirstChild("FireServer"))
    if not fireRemote then return false end
    local targetKaiju = GetExactOwnedKaijuName(Config.SelectedKaiju or "Thermonuclear Godzilla")
    pcall(function()
        fireRemote:FireServer("Select", targetKaiju)
    end)
    return true
end

--------------------------------------------------------------------------------
-- 6.1 AUTO USE EXP ITEMS ON SELECTED FARM KAIJU
--------------------------------------------------------------------------------
local AutoUseExpBusy = false

local function IsConsumableExpItem(item)
    if not item then return false end
    local name = tostring(item.Name)
    local lower = name:lower()
    return lower:find("exp", 1, true) ~= nil
        and lower:find("boost", 1, true) == nil
        and tonumber(name:match("%d+")) ~= nil
end

local function GetInventoryItemAmount(item)
    if item:IsA("ValueBase") then
        return math.max(0, math.floor(tonumber(item.Value) or 0))
    end
    local amountValue = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
    if amountValue and amountValue:IsA("ValueBase") then
        return math.max(0, math.floor(tonumber(amountValue.Value) or 0))
    end
    return 1
end

local function AutoUseAllExpItems()
    if AutoUseExpBusy or not Config.AutoUseExpEnabled then return end
    AutoUseExpBusy = true

    pcall(function()
        ResolveRemotes()
        local confirmRemote = FireServerRemote or (RemotesFolder and RemotesFolder:FindFirstChild("FireServer"))
        if not confirmRemote or not confirmRemote:IsA("RemoteEvent") then return end

        local dataFolder = ReplicatedStorage:FindFirstChild("Data")
        local playerData = dataFolder and dataFolder:FindFirstChild(LocalPlayer.UserId .. "_Data")
        local inventory = playerData and playerData:FindFirstChild("MainInventory")
        if not inventory then return end

        local targetKaiju = GetExactOwnedKaijuName(Config.SelectedKaiju or "Thermonuclear Godzilla")
        for _, item in ipairs(inventory:GetChildren()) do
            if getgenv().KaijuEvaFarm_RunToken ~= RunToken then return end
            if IsConsumableExpItem(item) then
                local amount = GetInventoryItemAmount(item)
                for _ = 1, amount do
                    if not item.Parent or getgenv().KaijuEvaFarm_RunToken ~= RunToken then break end
                    State.Current = string.format("Using %s on %s...", item.Name, targetKaiju)
                    confirmRemote:FireServer("Confirm", item.Name, targetKaiju)
                    task.wait(math.max(0.5, tonumber(Config.AutoUseExpDelay) or 0.6))
                end
            end
        end
    end)

    AutoUseExpBusy = false
end

task.spawn(function()
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        AutoUseAllExpItems()
        task.wait(math.max(1, tonumber(Config.AutoUseExpScanInterval) or 5))
    end
end)

local function SelectIslandInMap(mapFrame)
    local desired = Config.SpawnIsland or "Tokyo"
    local desiredIndex = table.find(Config.IslandNames, desired)
    if not desiredIndex then return false end

    -- โครงสร้างจริงจาก Menu.InitSpawn: Map.Tap.Frame.TextLabel + ปุ่ม Left/Right
    -- ใช้ path นี้ก่อน เพื่อไม่ให้ตัวสแกนเดาปุ่มผิดบนมือถือ
    local tap = mapFrame:FindFirstChild("Tap")
    local frame = tap and tap:FindFirstChild("Frame")
    local label = frame and frame:FindFirstChild("TextLabel")
    local right = mapFrame:FindFirstChild("Right", true)
    if label and right and right:IsA("GuiButton") then
        for _ = 1, (#Config.IslandNames + 1) do
            local current = tostring(label.Text):lower():gsub("%s+", "")
            local wanted = tostring(desired):lower():gsub("%s+", "")
            if current == wanted or current == wanted:upper():lower() then
                return true
            end
            SafeClickUI(right)
            task.wait(0.18)
        end
        local current = tostring(label.Text):lower():gsub("%s+", "")
        return current == tostring(desired):lower():gsub("%s+", "")
    end

    local function findNextButton()
        for _, desc in ipairs(mapFrame:GetDescendants()) do
            if desc:IsA("GuiButton") and desc.Visible then
                local name = desc.Name:lower()
                local text = desc:IsA("TextButton") and desc.Text or ""
                if name == "right" or name == "next" or name == "rightarrow" or text == ">" then
                    return desc
                end
            end
        end
    end

    local function getCurrentIsland()
        local bestName, bestScore = nil, -math.huge
        for _, desc in ipairs(mapFrame:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
                local islandIndex = table.find(Config.IslandNames, desc.Text)
                if islandIndex then
                    local objectName = desc.Name:lower()
                    local score = desc:IsA("TextLabel") and 3 or 0
                    if objectName:find("island", 1, true) or objectName:find("map", 1, true)
                        or objectName:find("name", 1, true) or objectName:find("selected", 1, true) then
                        score = score + 10
                    end
                    score = score + math.min(desc.AbsoluteSize.X / 100, 3)
                    if desc.AbsolutePosition.Y >= mapFrame.AbsolutePosition.Y + mapFrame.AbsoluteSize.Y * 0.55 then
                        score = score + 8
                    end
                    if score > bestScore then bestName, bestScore = desc.Text, score end
                end
            end
        end
        return bestName
    end

    local nextButton = findNextButton()
    if not nextButton then return getCurrentIsland() == desired end

    -- ถ้า UI มีปุ่มเลือกเกาะโดยตรง ให้เลือกจากชื่อก่อน
    for _, desc in ipairs(mapFrame:GetDescendants()) do
        if desc:IsA("TextButton") and desc.Visible and desc.Text == desired then
            SafeClickUI(desc)
            task.wait(0.3)
            if getCurrentIsland() == desired then return true end
        end
    end

    -- อ่านชื่อใหม่หลังคลิกทุกครั้ง ไม่ยิงปุ่มติดกันจน UI รับไม่ครบ
    for _ = 1, (#Config.IslandNames + 2) do
        local current = getCurrentIsland()
        if current == desired then return true end
        SafeClickUI(nextButton)
        task.wait(0.3)
    end
    return getCurrentIsland() == desired
end

local function AutoSpawnCharacter()
    if IsAliveAndSpawned() or State.SpawnInProgress then return end
    if os.clock() - State.LastSpawnAttemptAt < 1.5 then return end
    State.LastSpawnAttemptAt = os.clock()
    State.SpawnInProgress = true
    pcall(function()
        PrepareSelectedKaiju()

        -- ใช้ Remote Spawn โดยตรงตามระบบของเกมก่อน UI เพื่อไม่ให้หน้า Map วนเปลี่ยนเกาะ
        ResolveRemotes()
        local spawnIsland = Config.SpawnIsland or "Tokyo"
        local selectedKaiju = GetExactOwnedKaijuName(Config.SelectedKaiju or "Thermonuclear Godzilla")
        if FireServerRemote then
            pcall(function()
                if FireServerRemote:IsA("RemoteEvent") then
                    FireServerRemote:FireServer("Spawn", selectedKaiju, spawnIsland)
                elseif FireServerRemote:IsA("RemoteFunction") then
                    FireServerRemote:InvokeServer("Spawn", selectedKaiju, spawnIsland)
                end
            end)
            task.wait(0.25)
            if IsAliveAndSpawned() then return end
        end

        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pGui then return end
        local menuGui = pGui:FindFirstChild("Menu")
        if not menuGui then return end

        local mapFrame = menuGui:FindFirstChild("Map")
        if mapFrame and mapFrame.Visible then
            -- เลือกเกาะให้ตรงก่อน แล้วกด Spawn เพียงครั้งเดียว
            if not SelectIslandInMap(mapFrame) then
                State.Current = "Waiting for correct spawn island: " .. tostring(Config.SpawnIsland)
                return
            end

            -- ปุ่มจริงของเกมอยู่ที่ Map.Tap.Frame.Spawn (รองรับมือถือด้วย Activate)
            local tap = mapFrame:FindFirstChild("Tap")
            local frame = tap and tap:FindFirstChild("Frame")
            local exactSpawn = frame and frame:FindFirstChild("Spawn")
            if exactSpawn and exactSpawn:IsA("GuiButton") and exactSpawn.Visible then
                State.Current = "Spawning at " .. tostring(Config.SpawnIsland) .. "..."
                SafeClickUI(exactSpawn)
                return
            end
            for _, desc in ipairs(mapFrame:GetDescendants()) do
                local buttonText = ""
                if desc:IsA("TextButton") then buttonText = desc.Text:lower() end
                if desc:IsA("GuiButton") then
                    for _, child in ipairs(desc:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            buttonText = buttonText .. " " .. tostring(child.Text):lower()
                        end
                    end
                end
                local isSpawnButton = desc:IsA("GuiButton") and desc.Visible
                    and (desc.Name:lower():find("spawn", 1, true) ~= nil
                        or buttonText:find("spawn", 1, true) ~= nil)
                if isSpawnButton then
                    State.Current = "Spawning immediately..."
                    SafeClickUI(desc)
                    return
                end
            end

            -- มือถือบางเวอร์ชันใช้ ImageButton ชื่อทั่วไปและซ่อนข้อความไว้ใน Canvas
            -- เลือกปุ่ม GuiButton ขนาดใหญ่บริเวณกึ่งกลางด้านล่างเป็น fallback
            local fallbackButton, fallbackScore = nil, -math.huge
            local mapBottom = mapFrame.AbsolutePosition.Y + mapFrame.AbsoluteSize.Y
            local mapCenter = mapFrame.AbsolutePosition.X + mapFrame.AbsoluteSize.X * 0.5
            for _, desc in ipairs(mapFrame:GetDescendants()) do
                if desc:IsA("GuiButton") and desc.Visible then
                    local size, pos = desc.AbsoluteSize, desc.AbsolutePosition
                    local centerX = pos.X + size.X * 0.5
                    local score = 0
                    if pos.Y + size.Y >= mapBottom - mapFrame.AbsoluteSize.Y * 0.3 then score = score + 5 end
                    if math.abs(centerX - mapCenter) <= mapFrame.AbsoluteSize.X * 0.25 then score = score + 5 end
                    if size.X >= 100 and size.Y >= 25 then score = score + 4 end
                    if score > fallbackScore then fallbackButton, fallbackScore = desc, score end
                end
            end
            if fallbackButton and fallbackScore >= 9 then
                State.Current = "Spawning immediately (mobile fallback)..."
                SafeClickUI(fallbackButton)
                return
            end
        end

        local menuFrame = menuGui:FindFirstChild("Menu")
        if menuFrame and menuFrame.Visible then
            for _, desc in ipairs(menuFrame:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible
                    and (desc.Name:lower() == "play"
                        or (desc:IsA("TextButton") and desc.Text:lower():find("play", 1, true) ~= nil)) then
                    SafeClickUI(desc)
                    return
                end
            end
        end
    end)
    State.SpawnInProgress = false
end

-- Task ตรวจสอบและกด Auto Play อัตโนมัติทันทีที่อยู่หน้า Lobby
task.spawn(function()
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        task.wait(0.1)
        if not IsAliveAndSpawned() and not State.PostEvaProcessing and not State.IsHopping then
            AutoSpawnCharacter()
        end
    end
end)

-- ร่างใหม่เกิดแล้วปลด state ที่ค้างจากร่างเก่าทันที ไม่ยืนรอโดยไม่จำเป็น
local CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(character)
    State.ReturningToLobby = false
    State.AutoWalking = false
    State.DesiredMoveDirection = Vector3.zero
    State.LastWalkPosition = nil
    State.LastWalkCheckAt = 0
    State.StuckSince = nil
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 3)
        local root = character:WaitForChild("HumanoidRootPart", 3) or character.PrimaryPart
        if humanoid and root and humanoid.Health > 0 then
            State.Current = "Respawned - resuming farm immediately..."
        end
    end)
end)

--------------------------------------------------------------------------------
-- 7. EVA BOSS DETECTION
--------------------------------------------------------------------------------
local function IsInBossRoom()
    if LocalPlayer:GetAttribute("InBossRoom") == true then
        return true
    end

    -- ใช้โมเดลห้องบอสจริง workspace.Map.Colosseum เป็นขอบเขตหลัก
    local root = GetRoot()
    if root then
        local map = Workspace:FindFirstChild("Map")
        local colosseum = map and map:FindFirstChild("Colosseum")
        if colosseum then
            local ok, roomCF, roomSize = pcall(function()
                return colosseum:GetBoundingBox()
            end)
            if ok and roomCF and roomSize then
                local localPos = roomCF:PointToObjectSpace(root.Position)
                local padding = 75
                if math.abs(localPos.X) <= (roomSize.X * 0.5 + padding)
                    and math.abs(localPos.Y) <= (roomSize.Y * 0.5 + padding)
                    and math.abs(localPos.Z) <= (roomSize.Z * 0.5 + padding) then
                    return true
                end
            end
        end

        -- สำรองกรณีโมเดล Colosseum ยังโหลดไม่ครบ
        local flatDistance = (Vector2.new(root.Position.X, root.Position.Z)
            - Vector2.new(Config.BossBattleSpawnPosition.X, Config.BossBattleSpawnPosition.Z)).Magnitude
        return flatDistance <= 1200
    end
    return false
end

-- ตรวจสอบว่าในวงประตูวาปขึ้นข้อความ "In Boss Battle" หรือไม่
local function IsBossBattleInProgress()
    local inBattle = false
    local function IsBattleStatusText(text)
        local compact = tostring(text or ""):lower():gsub("[^%w]", "")
        if compact:find("bossspawnin", 1, true) then
            return false
        end
        return compact:find("inbossbattle", 1, true) ~= nil
            or compact:find("bossinbattle", 1, true) ~= nil
            or compact:find("bossisinbattle", 1, true) ~= nil
            or compact:find("bossbattleinprogress", 1, true) ~= nil
    end

    pcall(function()
        local bp = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("BossPortal")
        if not bp then bp = Workspace:FindFirstChild("BossPortal", true) end
        if bp then
            local bbAttach = bp:FindFirstChild("BillboardAttach") or bp:FindFirstChild("BillboardAttach", true)
            local bTimer = bbAttach and (bbAttach:FindFirstChild("BossTimer") or bbAttach:FindFirstChild("BossTimer", true))
            local txtLbl = bTimer and (bTimer:FindFirstChild("TextLabel") or bTimer:FindFirstChildOfClass("TextLabel"))
            if txtLbl and txtLbl:IsA("TextLabel") and txtLbl.Text ~= "" then
                if IsBattleStatusText(txtLbl.Text) then
                    inBattle = true
                end
            else
                for _, desc in ipairs(bp:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Visible then
                        if IsBattleStatusText(desc.Text) then
                            inBattle = true
                            break
                        end
                    end
                end
            end
        end
    end)
    return inBattle
end

local function GetBossEvaModel()
    -- 1. ตรวจสอบจาก Tag "BossBarTarget"
    for _, obj in ipairs(CollectionService:GetTagged("BossBarTarget")) do
        if obj:IsA("Model") and obj.Parent and obj ~= GetCharacter() and not Players:GetPlayerFromCharacter(obj) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then
                local bName = obj:GetAttribute("BossName")
                local name = obj.Name:lower()
                if (bName and tostring(bName):lower():find("eva")) or name:find("shin eva") or name:find("shin_eva") or (name:find("eva") and name:find("godzilla")) then
                    return obj
                end
            end
        end
    end

    -- 2. ตรวจสอบจาก Attribute "BossName" ใน Workspace
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= GetCharacter() and not Players:GetPlayerFromCharacter(obj) then
            local bNameAttr = obj:GetAttribute("BossName")
            if bNameAttr and tostring(bNameAttr):lower():find("eva") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health > 0 then
                    return obj
                end
            end
        end
    end

    -- 3. ตรวจสอบใน Workspace.Live
    local live = Workspace:FindFirstChild("Live")
    if live then
        for _, m in ipairs(live:GetChildren()) do
            if m:IsA("Model") and m ~= GetCharacter() and not Players:GetPlayerFromCharacter(m) then
                local name = m.Name:lower()
                if name:find("shin eva") or name:find("shin_eva") or (name:find("eva") and name:find("godzilla")) then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health > 0 then
                        return m
                    end
                end
            end
        end
    end

    return nil
end

local function IsEvaTrulyAlive()
    local detected = GetBossEvaModel()
    if detected and detected.Parent then
        local hum = detected:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health > 0 then
            State.ActiveEvaModel = detected
            return true, detected
        end
    end

    if IsInBossRoom() and State.ActiveEvaModel and State.ActiveEvaModel.Parent then
        local hum = State.ActiveEvaModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health > 0 then
            return true, State.ActiveEvaModel
        end
    end

    return false, nil
end

--------------------------------------------------------------------------------
-- 7.1 EVA MOUSE LOCK (Q TOGGLE)
--------------------------------------------------------------------------------
local MouseLockRenderStepName = "KaijuEvaMouseLock_" .. RunToken
local Mouse = LocalPlayer:GetMouse()
local CurrentEvaAimPart = nil
local LastBeamAimSent = 0

local function SendEvaAimToRemotes(targetPosition, includeBeam)
    if not targetPosition then return end
    ResolveRemotes()
    if GetMousePosRemote then
        pcall(function() GetMousePosRemote:FireServer(targetPosition) end)
    end
    if includeBeam and BeamRemote then
        pcall(function() BeamRemote:FireServer(targetPosition) end)
    end
end

-- รองรับสกิลที่อ่าน Mouse.Hit/Mouse.Target โดยตรงจาก LocalScript ของเกม
if Config.EnableMouseMetatableHook and type(getrawmetatable) == "function" and type(setreadonly) == "function"
    and type(newcclosure) == "function" and type(checkcaller) == "function" then
    pcall(function()
        local meta = getrawmetatable(game)
        local oldIndex = meta.__index
        setreadonly(meta, false)
        local replacement = newcclosure(function(self, key)
            if not checkcaller()
                and self == Mouse
                and (key == "Hit" or key == "Target")
                and getgenv().KaijuEvaFarm_RunToken == RunToken
                and State.MouseLockEnabled
                and CurrentEvaAimPart
                and CurrentEvaAimPart.Parent then
                if key == "Hit" then
                    return CFrame.new(CurrentEvaAimPart.Position)
                end
                return CurrentEvaAimPart
            end
            return oldIndex(self, key)
        end)
        local assigned = pcall(function()
            meta.__index = replacement
        end)
        pcall(function() setreadonly(meta, true) end)
        if not assigned then
            warn("[Kaiju Eva Farm] Mouse metatable hook unavailable; remote aim lock remains active.")
        end
    end)
end

local MouseLockInputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Q then
        State.MouseLockEnabled = not State.MouseLockEnabled
        print(string.format(
            "[Kaiju Eva Farm] Eva mouse lock: %s (press Q to toggle)",
            State.MouseLockEnabled and "ON" or "OFF"
        ))
        return
    end

    if State.MouseLockEnabled and CurrentEvaAimPart and CurrentEvaAimPart.Parent then
        local key = input.KeyCode
        local isSkill = key == Enum.KeyCode.One or key == Enum.KeyCode.Two
            or key == Enum.KeyCode.Three or key == Enum.KeyCode.Four
            or key == Enum.KeyCode.Five or key == Enum.KeyCode.R
            or key == Enum.KeyCode.T or key == Enum.KeyCode.V
            or key == Enum.KeyCode.C
            or input.UserInputType == Enum.UserInputType.MouseButton1
        if isSkill then
            local myRoot = GetRoot()
            local distance = myRoot and (myRoot.Position - CurrentEvaAimPart.Position).Magnitude or math.huge
            SendEvaAimToRemotes(CurrentEvaAimPart.Position, true)
        end
    end
end)

local AimAttachment = nil
local AimOrientation = nil

local function DisableSmoothCharacterAim()
    if AimOrientation then AimOrientation.Enabled = false end
    local humanoid = GetHumanoid()
    if humanoid then humanoid.AutoRotate = true end
end

local function UpdateSmoothCharacterAim(root, humanoid, targetPosition, dt)
    if not root or not humanoid then return end
    if not AimAttachment or AimAttachment.Parent ~= root then
        if AimAttachment then AimAttachment:Destroy() end
        AimAttachment = Instance.new("Attachment")
        AimAttachment.Name = "EvaSmoothAimAttachment"
        AimAttachment.Parent = root

        AimOrientation = Instance.new("AlignOrientation")
        AimOrientation.Name = "EvaSmoothAimOrientation"
        AimOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        AimOrientation.Attachment0 = AimAttachment
        AimOrientation.RigidityEnabled = false
        AimOrientation.Responsiveness = Config.AimTurnSmoothness
        AimOrientation.MaxAngularVelocity = Config.AimMaxAngularVelocity
        AimOrientation.MaxTorque = math.huge
        AimOrientation.Parent = root
    end

    local flatDirection = Vector3.new(
        targetPosition.X - root.Position.X,
        0,
        targetPosition.Z - root.Position.Z
    )
    if flatDirection.Magnitude > 0.1 then
        humanoid.AutoRotate = false
        -- ใช้ Lerp ที่ตัว root โดยตรงเพื่อให้หันตาม Eva ได้แม้กำลังเดินเฉียง
        -- และปิด AlignOrientation ไม่ให้ระบบฟิสิกส์อีกตัวมาแย่งการหมุน
        if AimOrientation then AimOrientation.Enabled = false end
        -- หมุนเฉพาะแกน Y ด้วยค่าที่อิง dt เพื่อให้หันกลับหลังแบบค่อยๆ หมุน
        -- ไม่ snap ตามเป้าหมายและไม่เปลี่ยนตำแหน่งตัวละคร
        local desiredYaw = math.atan2(-flatDirection.X, -flatDirection.Z)
        local _, currentYaw, _ = root.CFrame:ToOrientation()
        local deltaYaw = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
        local turnAlpha = 1 - math.exp(-(Config.CharacterTurnSpeed or 7.5) * math.max(tonumber(dt) or (1 / 60), 0))
        local nextYaw = currentYaw + deltaYaw * math.clamp(turnAlpha, 0, 1)
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, nextYaw, 0)
    end
end

-- หันเฉพาะตัวละครแบบ physics-smooth; ไม่เขียนทับ Camera.CFrame
RunService:BindToRenderStep(MouseLockRenderStepName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if getgenv().KaijuEvaFarm_RunToken ~= RunToken
        or not State.MouseLockEnabled
        or not IsInBossRoom() then
        CurrentEvaAimPart = nil
        DisableSmoothCharacterAim()
        return
    end

    local target = State.ActiveEvaModel
    if not target or not target.Parent then
        CurrentEvaAimPart = nil
        DisableSmoothCharacterAim()
        return
    end

    local targetPart = target:FindFirstChild("HumanoidRootPart")
        or target:FindFirstChild("UpperTorso")
        or target.PrimaryPart
    local camera = Workspace.CurrentCamera
    if not targetPart or not camera then return end
    CurrentEvaAimPart = targetPart

    local char = GetCharacter()
    local root = GetRoot(char)
    local humanoid = GetHumanoid(char)
    local targetPosition = targetPart.Position

    local aimMovementRestricted = IsMovementRestrictedByGame(char, humanoid)
    if aimMovementRestricted then
        DisableSmoothCharacterAim()
    else
        UpdateSmoothCharacterAim(root, humanoid, targetPosition, dt)
    end

    local targetDistance = root and (root.Position - targetPosition).Magnitude or math.huge
    if os.clock() - LastBeamAimSent >= Config.BeamAimUpdateInterval then
        LastBeamAimSent = os.clock()
        SendEvaAimToRemotes(targetPosition, true)
    end

    local screenPoint, visible = camera:WorldToViewportPoint(targetPart.Position)
    if visible and screenPoint.Z > 0 then
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(
                math.floor(screenPoint.X + 0.5),
                math.floor(screenPoint.Y + 0.5),
                game
            )
        end)
    end
end)

--------------------------------------------------------------------------------
-- 8. SKILL SPAMMER (LEGIT ANIMATION LOCK RESPECT)
--------------------------------------------------------------------------------
local SkillCooldowns = {
    Attack1 = 0.85, Attack2 = 1.35, Attack3 = 2.20,
    Attack4 = 3.20, Attack5 = 4.20, Roar2 = 12.0,
    Utility = 7.0,  Overdrive = 22.0
}
local SkillKeyCooldowns = {}
local SkillKeyBindings = {
    { "Attack1", Enum.KeyCode.One },
    { "Attack2", Enum.KeyCode.Two },
    { "Attack3", Enum.KeyCode.Three },
    { "Attack4", Enum.KeyCode.Four },
    { "Attack5", Enum.KeyCode.Five },
    { "Roar2", Enum.KeyCode.R },
    { "Utility", Enum.KeyCode.T },
    { "Overdrive", Enum.KeyCode.V },
}

local function ExecuteSkillIfReady(skillName, aimPos)
    ResolveRemotes()
    if not CombatRemote then return false end
    if Config.ExcludedSkills[skillName] then return false end

    local now = os.clock()
    local last = State.LastSkillCastTimes[skillName] or 0
    local cd = (SkillCooldowns[skillName] or 1.5) * Config.SkillCooldownMultiplier

    if (now - last) >= cd then
        State.LastSkillCastTimes[skillName] = now
        pcall(function()
            if aimPos and GetMousePosRemote then
                GetMousePosRemote:FireServer(aimPos)
            end
            CombatRemote:FireServer("UseSkill", skillName)
            CombatRemote:FireServer("HitBox", skillName)
        end)
        return true
    end
    return false
end

local function SpamSkillsAtEva(aimPos, targetDistance)
    -- ให้สกิลแรง 4/5 ได้สิทธิ์กดก่อน เพื่อไม่ถูก animation lock จาก 1-3 กลืนคิว
    local heavyFirst = math.random(1, 2) == 1
    local skills = heavyFirst
        and { "Attack4", "Attack5", "Attack1", "Attack2", "Attack3", "Roar2", "Utility", "Overdrive" }
        or  { "Attack5", "Attack4", "Attack1", "Attack2", "Attack3", "Roar2", "Utility", "Overdrive" }
    for _, s in ipairs(skills) do
        ExecuteSkillIfReady(s, aimPos)
    end

    -- กดปุ่มจริงของทุกช่องด้วย เพื่อรองรับไคจูที่ใช้ชื่อสกิลภายในไม่เหมือนกัน
    local now = os.clock()
    -- ส่ง 4/5 ก่อนเสมอ (สุ่มว่าอันไหนก่อน) แล้วค่อยสุ่ม 1-3 และช่องเสริม
    local randomizedBindings = {}
    randomizedBindings[1] = SkillKeyBindings[heavyFirst and 4 or 5]
    randomizedBindings[2] = SkillKeyBindings[heavyFirst and 5 or 4]
    local lightBindings = { SkillKeyBindings[1], SkillKeyBindings[2], SkillKeyBindings[3] }
    for index = #lightBindings, 2, -1 do
        local swapIndex = math.random(1, index)
        lightBindings[index], lightBindings[swapIndex] = lightBindings[swapIndex], lightBindings[index]
    end
    for _, binding in ipairs(lightBindings) do table.insert(randomizedBindings, binding) end
    for index = 6, #SkillKeyBindings do table.insert(randomizedBindings, SkillKeyBindings[index]) end
    for _, binding in ipairs(randomizedBindings) do
        local skillName, keyCode = binding[1], binding[2]
        if not Config.ExcludedSkills[skillName] then
            local last = SkillKeyCooldowns[skillName] or 0
            local cooldown = (SkillCooldowns[skillName] or 1.5) * Config.SkillCooldownMultiplier
            if now - last >= cooldown then
                SkillKeyCooldowns[skillName] = now
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.004)
                    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                end)
                -- คิวสั้นลงเพื่อวนสกิลไวขึ้น แต่ยังส่ง key-down/key-up ปกติ
                task.wait(0.004)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 9. DISCORD WEBHOOK REPORTER
--------------------------------------------------------------------------------
local function SendDiscordWebhook()
    if not Config.DiscordWebhookEnabled or not Config.DiscordWebhookURL or Config.DiscordWebhookURL == "" then
        return
    end

    local tokensNow = GetPlayerTokens()
    State.CurrentTokens = tokensNow
    if State.InitialTokens then
        State.TokensGained = tokensNow - State.InitialTokens
    end

    local requestFunc = GetHttpRequestFunction()
    if not requestFunc then return end

    local payload = {
        username = "Kaiju Alpha - Eva Hunter",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=150&height=150&format=png",
        embeds = {
            {
                title = "🏆 Boss Eva Defeated Successfully!",
                description = string.format("ผู้เล่น **%s** สังหาร Boss Eva สำเร็จเรียบร้อย!", LocalPlayer.Name),
                color = 0x55ff55,
                fields = {
                    { name = "🐉 Boss Defeated", value = string.format("**%d** ตัว", State.EvaDefeatedCount), inline = true },
                    { name = "🪙 Current Tokens", value = string.format("**%s** Tokens", tostring(State.CurrentTokens)), inline = true },
                    { name = "📈 Tokens Gained", value = string.format("**+%s** Tokens", tostring(State.TokensGained)), inline = true },
                    { name = "👥 Server Players", value = string.format("%d คน", #Players:GetPlayers()), inline = true },
                    { name = "⏳ Portal Status", value = State.BossTimerText, inline = true },
                    { name = "🕒 Time", value = os.date("%H:%M:%S"), inline = true },
                },
                footer = { text = "Kaiju Alpha Legit Eva Farm • " .. tostring(game.JobId) }
            }
        }
    }

    pcall(function()
        requestFunc({
            Url = Config.DiscordWebhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

--------------------------------------------------------------------------------
-- 10. SERVER HOPPER (IF PLAYERS < 5)
--------------------------------------------------------------------------------
local function HopServer(forceHop, reason)
    if State.IsHopping then return end
    local now = os.clock()
    if not forceHop and (now - State.LastHopAttempt) < Config.ServerHopCooldown then return end
    State.LastHopAttempt = now
    State.IsHopping = true
    State.AutoWalking = false
    State.DesiredMoveDirection = Vector3.zero
    StopNaturalWalk(GetHumanoid())
    DisableRunning()
    State.Current = reason or "Hopping Server (< 5 Players)..."

    local placeId = game.PlaceId
    local currentJobId = game.JobId

    local requestFunc = GetHttpRequestFunction()

    print(string.format("[Kaiju Eva Farm] 🏃 %s Searching for another server...", reason or "Player count too low."))

    task.spawn(function()
        local serverFound = false
        local teleportFailed = false
        local failureConnection = TeleportService.TeleportInitFailed:Connect(function(player)
            if player == LocalPlayer then teleportFailed = true end
        end)
        if requestFunc then
            local cursor = ""
            for _ = 1, 4 do
                local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100%s", tostring(placeId), cursor ~= "" and ("&cursor=" .. cursor) or "")
                local success, res = pcall(function()
                    return requestFunc({ Url = url, Method = "GET" })
                end)

                if success and res and res.Body then
                    local jsonSuccess, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
                    if jsonSuccess and data and data.data then
                        for _, s in ipairs(data.data) do
                            -- หาเซิร์ฟเวอร์ที่มีคนอย่างน้อย 6 คน และยังไม่เต็ม
                            if s.id ~= currentJobId and s.playing and s.maxPlayers
                                and s.playing >= 6 and s.playing <= (s.maxPlayers - 2) then
                                print(string.format("[Kaiju Eva Farm] Verified server %s (%d/%d, at least 2 slots free). Teleporting...", tostring(s.id), s.playing, s.maxPlayers))
                                teleportFailed = false
                                State.Current = string.format("Hop %d/%d - trying next server...", s.playing, s.maxPlayers)
                                local teleportStarted = pcall(function()
                                    TeleportService:TeleportToPlaceInstance(placeId, s.id, LocalPlayer)
                                end)
                                if teleportStarted then
                                    -- ถ้า server full/error จะมี TeleportInitFailed แล้ววนยิงหาห้องถัดไปทันที
                                    local waitStarted = os.clock()
                                    repeat task.wait(0.12) until teleportFailed
                                        or os.clock() - waitStarted >= (Config.TeleportAttemptTimeout or 3)
                                    if not teleportFailed then
                                        serverFound = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if serverFound then break end
                    if data and data.nextPageCursor then
                        cursor = data.nextPageCursor
                    else
                        break
                    end
                end
            end
        end

        if failureConnection then failureConnection:Disconnect() end

        if not serverFound then
            -- แนวทางเดียวกับ AutoHop.lua: ถ้า API ไม่มีข้อมูล ให้ fallback เป็น Hop ปกติ
            State.Current = "No server data - fallback Hop..."
            task.wait(0.3)
            pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
        end

        if not serverFound then
            task.wait(Config.HopRetryDelay or 3)
            State.IsHopping = false
        else
            -- ถ้าคำขอ Teleport ถูกยอมรับแต่ยังไม่ย้ายจริง (เช่นห้องเต็มระหว่างทาง) ให้ค้นใหม่
            task.delay(Config.HopRetryDelay or 3, function()
                if getgenv().KaijuEvaFarm_RunToken == RunToken and game.JobId == currentJobId then
                    State.IsHopping = false
                    HopServer(true, "Teleport stalled/full - retrying rapidly...")
                end
            end)
        end
    end)
end

--------------------------------------------------------------------------------
-- 11. SIMPLE & CLEAN STATUS UI
--------------------------------------------------------------------------------
local ScreenGui = nil

local function GetExecutorLabel()
    local name = "Executor"
    pcall(function()
        if type(identifyexecutor) == "function" then
            name = tostring(identifyexecutor())
        elseif type(getexecutorname) == "function" then
            name = tostring(getexecutorname())
        end
    end)
    name = name:gsub("%s+", " "):sub(1, 18)
    return name ~= "" and name or "Executor"
end

local function CreateStatusUI()
    pcall(function()
        if ScreenGui then ScreenGui:Destroy() end
    end)

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KaijuEvaFarmUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 290, 0, 255)
    mainFrame.Position = UDim2.new(0, 20, 0, 40)
    mainFrame.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 65, 85)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame

    -- Header Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "⚡ KAIJU ALPHA • EVA FARM"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, -20, 0, 16)
    subTitle.Position = UDim2.new(0, 10, 0, 36)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "Legit Sprint & Natural Combat Mode"
    subTitle.TextColor3 = Color3.fromRGB(150, 155, 175)
    subTitle.Font = Enum.Font.Gotham
    subTitle.TextSize = 11
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.Parent = mainFrame

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 56)
    divider.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
    divider.BorderSizePixel = 0
    divider.Parent = mainFrame

    -- Status Container
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 5)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 175)
    container.Position = UDim2.new(0, 10, 0, 65)
    container.BackgroundTransparency = 1
    container.Parent = mainFrame
    list.Parent = container

    local function CreateRow(order, labelText, defaultVal, valColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 105, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(170, 175, 195)
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 11.5
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local val = Instance.new("TextLabel")
        val.Name = "Val"
        val.Size = UDim2.new(1, -110, 1, 0)
        val.Position = UDim2.new(0, 110, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = defaultVal
        val.TextColor3 = valColor or Color3.fromRGB(240, 240, 245)
        val.Font = Enum.Font.Gotham
        val.TextSize = 11.5
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.Parent = row

        return val
    end

    local uiStatus   = CreateRow(1, "Status:", "Standing at Portal", Color3.fromRGB(80, 230, 120))
    local uiPortal   = CreateRow(2, "Portal Queue:", "Scanning...", Color3.fromRGB(255, 190, 80))
    local uiPlayers  = CreateRow(3, "Server Players:", "0", Color3.fromRGB(120, 200, 255))
    local uiDefeated = CreateRow(4, "Eva Defeated:", "0", Color3.fromRGB(255, 100, 100))
    local uiTokens   = CreateRow(5, "Tokens:", "0 (+0)", Color3.fromRGB(255, 230, 100))
    local uiKaiju    = CreateRow(6, "Current Kaiju:", Config.SelectedKaiju, Color3.fromRGB(200, 180, 255))
    local uiMouseLock = CreateRow(7, "Mouse Lock [Q]:", "ON", Color3.fromRGB(100, 235, 255))

    pcall(function()
        local coreGui = game:GetService("CoreGui")
        ScreenGui.Parent = coreGui
    end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Update UI Task
    task.spawn(function()
        while getgenv().KaijuEvaFarm_RunToken == RunToken do
            task.wait(0.5)
            pcall(function()
                uiStatus.Text = State.Current
                uiPortal.Text = State.BossTimerText
                uiPlayers.Text = string.format("%d คน (Min: %d)", #Players:GetPlayers(), Config.MinPlayersRequired)
                uiDefeated.Text = tostring(State.EvaDefeatedCount) .. " ตัว"
                uiTokens.Text = string.format("%d (+%d)", State.CurrentTokens, State.TokensGained)
                uiKaiju.Text = tostring(LocalPlayer:GetAttribute("Kaiju") or Config.SelectedKaiju)
                uiMouseLock.Text = State.MouseLockEnabled and "ON (tracking Eva)" or "OFF"
                uiMouseLock.TextColor3 = State.MouseLockEnabled
                    and Color3.fromRGB(100, 235, 255)
                    or Color3.fromRGB(255, 120, 120)
            end)
        end
    end)
end

local function CreateLucyStatusUI()
    pcall(function() if ScreenGui then ScreenGui:Destroy() end end)

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LucyHubEvaUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.fromOffset(330, 286)
    main.Position = UDim2.fromOffset(22, 48)
    main.BackgroundColor3 = Color3.fromRGB(17, 18, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = ScreenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 13)
    local outline = Instance.new("UIStroke", main)
    outline.Color = Color3.fromRGB(112, 76, 255)
    outline.Transparency = 0.25
    outline.Thickness = 1.4

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.fromOffset(43, 43)
    logo.Position = UDim2.fromOffset(14, 12)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://136613723442373"
    logo.Parent = main
    Instance.new("UICorner", logo).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -112, 0, 25)
    title.Position = UDim2.fromOffset(68, 11)
    title.BackgroundTransparency = 1
    title.Text = "Lucy HUB"
    title.TextColor3 = Color3.fromRGB(245, 243, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -112, 0, 18)
    subtitle.Position = UDim2.fromOffset(68, 35)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Free Version • " .. GetExecutorLabel()
    subtitle.TextColor3 = Color3.fromRGB(162, 144, 255)
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = main

    local collapseButton = Instance.new("TextButton")
    collapseButton.Name = "Collapse"
    collapseButton.Size = UDim2.fromOffset(28, 28)
    collapseButton.Position = UDim2.new(1, -38, 0, 10)
    collapseButton.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
    collapseButton.BorderSizePixel = 0
    collapseButton.Text = "−"
    collapseButton.TextColor3 = Color3.fromRGB(230, 230, 240)
    collapseButton.Font = Enum.Font.GothamBold
    collapseButton.TextSize = 18
    collapseButton.Parent = main
    Instance.new("UICorner", collapseButton).CornerRadius = UDim.new(1, 0)

    local statusCard = Instance.new("Frame")
    statusCard.Size = UDim2.new(1, -28, 0, 118)
    statusCard.Position = UDim2.fromOffset(14, 66)
    statusCard.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
    statusCard.BorderSizePixel = 0
    statusCard.Parent = main
    Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 9)

    local statusList = Instance.new("UIListLayout", statusCard)
    statusList.Padding = UDim.new(0, 2)
    statusList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statusList.VerticalAlignment = Enum.VerticalAlignment.Center

    local function row(labelText, defaultText, color)
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, -20, 0, 25)
        line.BackgroundTransparency = 1
        line.Parent = statusCard
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 75, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(150, 153, 170)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = line
        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(1, -78, 1, 0)
        value.Position = UDim2.fromOffset(78, 0)
        value.BackgroundTransparency = 1
        value.Text = defaultText
        value.TextColor3 = color
        value.Font = Enum.Font.GothamSemibold
        value.TextSize = 11
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.TextTruncate = Enum.TextTruncate.AtEnd
        value.Parent = line
        return value
    end

    local statusValue = row("STATUS", "Starting...", Color3.fromRGB(103, 235, 164))
    local portalValue = row("PORTAL", "Scanning...", Color3.fromRGB(255, 196, 99))
    local playerValue = row("PLAYERS", "0", Color3.fromRGB(111, 190, 255))
    local resultValue = row("RESULT", "Eva 0  •  Tokens 0", Color3.fromRGB(210, 190, 255))

    local webhookBox = Instance.new("TextBox")
    webhookBox.Size = UDim2.new(1, -92, 0, 35)
    webhookBox.Position = UDim2.fromOffset(14, 197)
    webhookBox.BackgroundColor3 = Color3.fromRGB(27, 29, 40)
    webhookBox.BorderSizePixel = 0
    webhookBox.ClearTextOnFocus = false
    webhookBox.PlaceholderText = "Discord webhook URL"
    webhookBox.Text = Config.DiscordWebhookURL or ""
    webhookBox.TextColor3 = Color3.fromRGB(230, 230, 238)
    webhookBox.PlaceholderColor3 = Color3.fromRGB(105, 108, 125)
    webhookBox.Font = Enum.Font.Gotham
    webhookBox.TextSize = 10
    webhookBox.TextXAlignment = Enum.TextXAlignment.Left
    webhookBox.TextTruncate = Enum.TextTruncate.AtEnd
    webhookBox.ClipsDescendants = true
    webhookBox.Parent = main
    Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0, 8)

    local saveButton = Instance.new("TextButton")
    saveButton.Size = UDim2.fromOffset(58, 35)
    saveButton.Position = UDim2.new(1, -72, 0, 197)
    saveButton.BackgroundColor3 = Color3.fromRGB(104, 72, 235)
    saveButton.BorderSizePixel = 0
    saveButton.Text = "SAVE"
    saveButton.TextColor3 = Color3.new(1, 1, 1)
    saveButton.Font = Enum.Font.GothamBold
    saveButton.TextSize = 11
    saveButton.Parent = main
    Instance.new("UICorner", saveButton).CornerRadius = UDim.new(0, 8)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 28)
    hint.Position = UDim2.fromOffset(14, 242)
    hint.BackgroundTransparency = 1
    hint.Text = "Q  Aim lock   •   Config auto-loads next run"
    hint.TextColor3 = Color3.fromRGB(112, 115, 132)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 10
    hint.Parent = main

    saveButton.Activated:Connect(function()
        Config.DiscordWebhookURL = webhookBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        Config.DiscordWebhookEnabled = Config.DiscordWebhookURL ~= ""
        local saved = SaveConfig()
        saveButton.Text = saved and "SAVED" or "ERROR"
        saveButton.BackgroundColor3 = saved and Color3.fromRGB(65, 190, 125) or Color3.fromRGB(220, 80, 90)
        task.delay(1.2, function()
            if saveButton and saveButton.Parent then
                saveButton.Text = "SAVE"
                saveButton.BackgroundColor3 = Color3.fromRGB(104, 72, 235)
            end
        end)
    end)

    local collapsed = false
    collapseButton.Activated:Connect(function()
        collapsed = not collapsed
        collapseButton.Text = collapsed and "+" or "−"
        for _, child in ipairs(main:GetChildren()) do
            if child:IsA("GuiObject") and child ~= collapseButton and child ~= logo and child ~= title and child ~= subtitle
                and not child:IsA("UICorner") and not child:IsA("UIStroke") then
                child.Visible = not collapsed
            end
        end
        main.Size = collapsed and UDim2.fromOffset(330, 68) or UDim2.fromOffset(330, 286)
    end)

    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local scale = Instance.new("UIScale", main)
    local mobileLayout = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    scale.Scale = mobileLayout and 0.68 or 0.78
    main.BackgroundTransparency = 1
    TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(main, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()

    task.spawn(function()
        while getgenv().KaijuEvaFarm_RunToken == RunToken and ScreenGui and ScreenGui.Parent do
            task.wait(0.35)
            statusValue.Text = State.Current
            portalValue.Text = State.BossTimerText
            playerValue.Text = tostring(#Players:GetPlayers())
            resultValue.Text = string.format("Eva %d  •  Tokens %d (+%d)", State.EvaDefeatedCount, State.CurrentTokens, State.TokensGained)
        end
    end)
end

CreateLucyStatusUI()

--------------------------------------------------------------------------------
-- 12. AUTO SKIP CUTSCENE & AUTO CLAIM REWARDS
--------------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local function ClickGuiButton(button)
    if not button or not button:IsA("GuiButton") then return false end
    local clicked = false
    pcall(function()
        if firesignal then
            firesignal(button.Activated)
            if button:IsA("TextButton") then firesignal(button.MouseButton1Click) end
            clicked = true
        end
        if getconnections then
            for _, eventName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
                local signal = button[eventName]
                if signal then
                    for _, connection in ipairs(getconnections(signal)) do
                        connection:Fire()
                        clicked = true
                    end
                end
            end
        end
    end)
    return clicked
end

local function TrySkipEvaCutscene()
    if not PlayerGui then return false end
    local skipped = false

    pcall(function()
        local cutsceneGui = PlayerGui:FindFirstChild("CutsceneGui")
        local skipButton = cutsceneGui and cutsceneGui:FindFirstChild("Skip", true)
        if skipButton and skipButton:IsA("GuiButton") and skipButton.Visible then
            local text = skipButton:IsA("TextButton") and skipButton.Text or ""
            if not text:find("✓", 1, true) then
                skipped = ClickGuiButton(skipButton) or skipped
            end
        end
    end)

    if not skipped then
        pcall(function()
            for _, descendant in ipairs(PlayerGui:GetDescendants()) do
                if descendant:IsA("TextButton") and descendant.Visible then
                    local text = descendant.Text:lower()
                    if text:find("skip", 1, true) and not text:find("✓", 1, true) then
                        skipped = ClickGuiButton(descendant) or skipped
                        if skipped then break end
                    end
                end
            end
        end)
    end

    pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Cutscene")
        local remotes = folder and folder:FindFirstChild("Remotes")
        local voteSkip = remotes and remotes:FindFirstChild("VoteSkip")
        if voteSkip and voteSkip:IsA("RemoteEvent") then
            for _, sceneName in ipairs({ "EvaCutscene", "BossIntro", "Cutscene" }) do
                voteSkip:FireServer(sceneName, true)
            end
        end
    end)

    if skipped then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
    return skipped
end

local function ClaimFinishedQuests()
    if not PlayerGui then return 0 end
    local claimedCount = 0
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local invokeQuest = remotes and remotes:FindFirstChild("InvokeQuest")
    local claimBattlepass = remotes and remotes:FindFirstChild("ClaimBattlepassReward")

    if invokeQuest and invokeQuest:IsA("RemoteFunction") then
        pcall(function()
            local questData = invokeQuest:InvokeServer("GetQuests")
            if type(questData) ~= "table" then return end
            for _, category in ipairs({ "Daily", "Weekly", "Premium" }) do
                local list = questData[category]
                if type(list) == "table" then
                    for _, quest in ipairs(list) do
                        local progress = tonumber(quest.Progress) or 0
                        local goal = tonumber(quest.Goal) or math.huge
                        if (quest.Completed == true or progress >= goal) and not quest.Claimed then
                            local ok = pcall(function()
                                invokeQuest:InvokeServer("Claim", category, tostring(quest.Id))
                            end)
                            if ok then claimedCount = claimedCount + 1 end
                        end
                    end
                end
            end
        end)
    end

    pcall(function()
        for _, descendant in ipairs(PlayerGui:GetDescendants()) do
            if descendant:IsA("GuiButton") and descendant.Visible then
                local text = descendant:IsA("TextButton") and descendant.Text:lower() or descendant.Name:lower()
                if text:find("claim", 1, true) and not text:find("claimed", 1, true)
                    and ClickGuiButton(descendant) then
                    claimedCount = claimedCount + 1
                end
            end
        end
    end)

    if claimBattlepass and claimBattlepass:IsA("RemoteEvent") then
        pcall(function()
            for level = 1, 50 do
                claimBattlepass:FireServer(level)
            end
        end)
    end
    return claimedCount
end

task.spawn(function()
    print("[Auto Skip] Eva cutscene listener started!")
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        task.wait(0.2)
        pcall(TrySkipEvaCutscene)
    end
end)

task.spawn(function()
    print("[Auto Claim] Quest reward listener started!")
    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        task.wait(3)
        pcall(ClaimFinishedQuests)
    end
end)

getgenv().ClaimAllQuestsNow = function()
    local count = ClaimFinishedQuests()
    print("[Auto Claim] Claimed quest rewards:", count)
    return count
end

--------------------------------------------------------------------------------
-- 12.4 CLAIM FREE KAIJUS ONCE BEFORE FARM STARTS
--------------------------------------------------------------------------------
local FreeKaijuList = {
    "Gojira 1954", "Gojira 1955", "Anguirus 1955", "Anguirus", "Gezora",
    "Junior Godzilla", "Kamata Kun", "Shinagawa Kun", "Minilla",
    "Skeleton Godzilla 1954", "Godzilla In Hell",
}

local function ClaimAllFreeKaijusOnce()
    State.Current = "Claiming free Kaijus..."
    ResolveRemotes()
    local dataFolder = ReplicatedStorage:WaitForChild("Data", 8)
    local playerData = dataFolder and dataFolder:FindFirstChild(tostring(LocalPlayer.UserId) .. "_Data")
    local inventory = playerData and playerData:FindFirstChild("KaijuInventory")

    if FireServerRemote and FireServerRemote:IsA("RemoteEvent") then
        for _, kaijuName in ipairs(FreeKaijuList) do
            if not inventory or not inventory:FindFirstChild(kaijuName) then
                pcall(function() FireServerRemote:FireServer("Buy", kaijuName) end)
                task.wait(0.08)
            end
        end
    end

    local claimBattlepass = RemotesFolder and RemotesFolder:FindFirstChild("ClaimBattlepassReward")
    if claimBattlepass then
        for tier = 1, 60 do
            pcall(function()
                if claimBattlepass:IsA("RemoteFunction") then
                    claimBattlepass:InvokeServer(tier)
                elseif claimBattlepass:IsA("RemoteEvent") then
                    claimBattlepass:FireServer(tier)
                end
            end)
            task.wait(0.025)
        end
    end
    State.Current = "Free rewards checked - starting farm..."
end

pcall(ClaimAllFreeKaijusOnce)

--------------------------------------------------------------------------------
-- 12.5 AUTO UPSTAT หลัง Eva ตาย (ทำที่หน้า Lobby ก่อน Hop)
--------------------------------------------------------------------------------
local AutoStatPriority = { "Regen", "Energy", "Damage", "Strength", "Health", "Speed" }

local function AutoUpgradeStatsAfterEva()
    local gui, menuGui
    local deadline = os.clock() + 8
    repeat
        gui = LocalPlayer:FindFirstChild("PlayerGui")
        menuGui = gui and (gui:FindFirstChild("Menu") or gui:FindFirstChild("MainMenu"))
        if menuGui then break end
        task.wait(0.25)
    until os.clock() >= deadline
    local kaijuFrame = menuGui and menuGui:FindFirstChild("Kaiju", true)
    local frame = kaijuFrame and kaijuFrame:FindFirstChild("Frame")
    local statsInfo = frame and frame:FindFirstChild("Skill_Points")
    statsInfo = statsInfo and statsInfo:FindFirstChild("StatsInfo")
    if not statsInfo then
        warn("[AutoStat] ไม่พบหน้าอัปสเตตัสใน Lobby - ข้ามการอัปครั้งนี้")
        return 0
    end

    local data = ReplicatedStorage:FindFirstChild("Data")
    local playerData = data and data:FindFirstChild(tostring(LocalPlayer.UserId) .. "_Data")
    local inventory = playerData and playerData:FindFirstChild("KaijuInventory")
    local kaijuName = (Config.SelectedKaiju and tostring(Config.SelectedKaiju))
    local kaijuData = inventory and inventory:FindFirstChild(kaijuName)
    local statFolder = kaijuData and kaijuData:FindFirstChild("Stats")
    local pointsObj = statFolder and statFolder:FindFirstChild("Skill_Points")
    local upgraded = 0

    pcall(function()
        kaijuFrame.Visible = true
        local tab = statsInfo.Parent
        tab.Visible = true
    end)

    local function remaining()
        if pointsObj and tonumber(pointsObj.Value) then return tonumber(pointsObj.Value) end
        local p = statsInfo.Parent:FindFirstChild("Points")
        return p and tonumber(tostring(p.Text):match("%d+")) or 0
    end

    local function findStat(name)
        local direct = statsInfo:FindFirstChild(name)
        if direct and direct:FindFirstChild("Point") then return direct end
        for _, child in ipairs(statsInfo:GetChildren()) do
            if child:IsA("Frame") and child:FindFirstChild("Point")
                and child.Name:lower():find(name:lower(), 1, true) then return child end
        end
    end

    ResolveRemotes()
    for _, statName in ipairs(AutoStatPriority) do
        if remaining() <= 0 then break end
        local statFrame = findStat(statName)
        local pointFrame = statFrame and statFrame:FindFirstChild("Point")
        local buttons = {}
        if pointFrame then
            for _, child in ipairs(pointFrame:GetChildren()) do
                if child:IsA("GuiButton") then table.insert(buttons, child) end
            end
            table.sort(buttons, function(a,b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
        end
        for _, button in ipairs(buttons) do
            if remaining() <= 0 then break end
            pcall(function()
                if firesignal then firesignal(button.Activated); firesignal(button.MouseButton1Click) end
            end)
            if UpgradeStatRemote and UpgradeStatRemote:IsA("RemoteEvent") then
                pcall(function() UpgradeStatRemote:FireServer(kaijuName, statName, button.Name) end)
            elseif FireServerRemote and FireServerRemote:IsA("RemoteEvent") then
                pcall(function() FireServerRemote:FireServer("UpdateStat", kaijuName, statName, button.Name) end)
            end
            upgraded = upgraded + 1
            task.wait(0.1)
        end
    end
    print(string.format("[AutoStat] อัปสเตตัสหลัง Eva ตายแล้ว %d จุด", upgraded))
    return upgraded
end

--------------------------------------------------------------------------------
-- 13. MAIN EVA FARMING STATE MACHINE
--------------------------------------------------------------------------------
task.spawn(function()
    print("[Kaiju Eva Farm] Starting Legit Eva Farming Script...")

    while getgenv().KaijuEvaFarm_RunToken == RunToken do
        -- รอบสกิลถี่ขึ้นเพื่อให้กดต่อเนื่องไวขึ้น โดยยังผ่านระบบสกิลเดิมของเกม
        -- ลดภาระ CPU จากการสแกนข้อมูล/GUI ทุกเฟรม แต่ตัวสแกนข้อความฉุกเฉินยังทำงานถี่แยกต่างหาก
        task.wait(0.08)
        if getgenv().KaijuEvaFarm_RunToken ~= RunToken then break end

        -- อัพเดตข้อความ Boss Timer จาก Billboard ประตูวาป
        UpdateBossTimerText()

        -- อัพเดต Token ปัจจุบัน
        if os.clock() - State.LastTokenReadAt >= 1 then
            State.LastTokenReadAt = os.clock()
            State.CurrentTokens = GetPlayerTokens()
        end
        local tokensNow = State.CurrentTokens
        if State.InitialTokens then
            State.TokensGained = math.max(0, tokensNow - State.InitialTokens)
        else
            State.InitialTokens = tokensNow
        end

        -- ถ้ากำลังอยู่ในขั้นตอนย้ายเซิร์ฟเวอร์ ให้พัก
        if State.IsHopping then
            local hopChar = GetCharacter()
            local hopHum = GetHumanoid(hopChar)
            local hopRoot = GetRoot(hopChar)
            StopNaturalWalk(hopHum)
            DisableRunning()
            if hopHum then hopHum:Move(Vector3.zero, false) end
            if hopRoot then
                hopRoot.AssemblyLinearVelocity = Vector3.zero
                hopRoot.AssemblyAngularVelocity = Vector3.zero
            end
            task.wait(0.1)
            continue
        end
        if State.WaitingForPlayersDetected and not State.PortalHoldLocked then
            StopNaturalWalk(GetHumanoid())
            DisableRunning()
            State.PortalRouteActive = false
            State.PortalRouteIndex = 1
            State.PortalHoldLocked = false
            HopServer(true, "Waiting for players detected - hopping now...")
            task.wait(0.1)
            continue
        end
        if State.ReturningToLobby then
            task.wait(0.5)
            continue
        end
        if State.PostEvaProcessing then
            task.wait(0.5)
            continue
        end

        -- ตรวจสอบการเกิดของตัวละคร
        if not IsAliveAndSpawned() then
            State.Current = "Spawning Kaiju..."
            AutoSpawnCharacter()
            task.wait(0.1)
            continue
        end

        local myChar = GetCharacter()
        local myRoot = GetRoot(myChar)
        local myHum = GetHumanoid(myChar)
        if not myRoot or not myHum then continue end

        local inBossRoom = IsInBossRoom()
        local isEvaAlive, evaTarget = IsEvaTrulyAlive()

        local bossSpawnSeconds = GetBossSpawnSeconds()
        if not inBossRoom and not State.PortalHoldLocked and bossSpawnSeconds
            and bossSpawnSeconds > (Config.MaxBossSpawnMinutes * 60) then
            StopNaturalWalk(myHum)
            DisableRunning()
            HopServer(true, string.format(
                "Boss timer %02d:%02d exceeds target %d:00 - finding verified server...",
                math.floor(bossSpawnSeconds / 60),
                bossSpawnSeconds % 60,
                Config.MaxBossSpawnMinutes
            ))
            task.wait(1)
            continue
        end

        -- ถ้าเหลือต่ำกว่า 1 นาที แต่ยังไม่มีผู้เล่นอื่นมารอในรัศมี 300 studs
        -- ให้ย้ายไปหาเซิร์ฟเวอร์ที่ตรวจสอบแล้วทันที
        if not inBossRoom and not State.PortalHoldLocked and bossSpawnSeconds
            and bossSpawnSeconds < 60
            and not HasOtherPlayerNearPortal() then
            StopNaturalWalk(myHum)
            DisableRunning()
            State.PortalRouteActive = false
            State.PortalRouteIndex = 1
            HopServer(true, string.format(
                "Boss timer %02d:%02d and no players near Portal - hopping...",
                math.floor(bossSpawnSeconds / 60),
                bossSpawnSeconds % 60
            ))
            task.wait(1)
            continue
        end

        ------------------------------------------------------------------------
        -- ถ้าขึ้นข้อความ "In Boss Battle" และเรายังไม่ได้เข้าห้อง ให้ Hop ทันที
        -- ไม่วาร์ปเข้าห้องกลางคัน เพราะการเข้าไม่ทันประตูจะไม่ได้ Token
        ------------------------------------------------------------------------
        if not inBossRoom and IsBossBattleInProgress() then
            StopNaturalWalk(myHum)
            DisableRunning()
            State.PortalRouteActive = false
            State.PortalRouteIndex = 1
            HopServer(true, "In Boss Battle detected - hopping now...")
            task.wait(1)
            continue
        end

        ------------------------------------------------------------------------
        -- สภาวะที่ 1: บอส EVA เกิด หรือ อยู่ในห้องบอสแล้ว
        ------------------------------------------------------------------------
        if inBossRoom then
            State.IsEngagedWithEva = true
            State.PortalRouteActive = false
            State.PortalRouteIndex = 1
            State.PortalHoldLocked = false

            -- เริ่มจับเวลาตามค่าที่ตั้งไว้ (ค่าเริ่มต้น 0 = เข้าต่อสู้ทันทีหลังลงพื้น)
            if State.EvaSpawnTime == 0 then
                State.EvaSpawnTime = os.clock()
                print("[Kaiju Eva Farm] 🐉 Eva detected! Engaging after landing...")
            end

            local elapsedSinceSpawn = os.clock() - State.EvaSpawnTime

            if elapsedSinceSpawn < Config.EvaEngageDelay then
                local remaining = math.ceil(Config.EvaEngageDelay - elapsedSinceSpawn)
                State.Current = string.format("Eva Spawned! Waiting %ds...", remaining)

                -- หันหน้ามองไปทางบอสแบบธรรมชาติ
                local target = evaTarget or State.ActiveEvaModel
                if target and target.Parent then
                    local bRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                    if bRoot then
                        UpdateSmoothCharacterAim(myRoot, myHum, bRoot.Position)
                    end
                end
                task.wait(0.1)
                continue
            end

            --------------------------------------------------------------------
            -- ลงพื้นแล้ว: วิ่งเข้าไปหาบอส Eva และสแปมสกิลใส่เมื่อเข้าใกล้ระยะตี
            -- 🛑 วิ่งติดพื้นตลอดเวลา 100% ไม่กระโดดตาม Eva แม้บอสจะลอยหรืออยู่สูง
            --------------------------------------------------------------------
            local target = evaTarget or State.ActiveEvaModel
            local bRoot = target and target.Parent and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)

            if bRoot then
                -- คำนวณพิกัดเป้าหมายบนระนาบพื้น (Y เดียวกับเท้าตัวละคร) เพื่อไม่ให้ Humanoid วิ่งลอยหรือกระโดด
                local groundTargetPos = Vector3.new(bRoot.Position.X, myRoot.Position.Y, bRoot.Position.Z)
                local horizDist = (Vector2.new(myRoot.Position.X, myRoot.Position.Z) - Vector2.new(bRoot.Position.X, bRoot.Position.Z)).Magnitude

                -- ปิดการกระโดดของ Humanoid ทุกกรณี และตัดแรงดีดในแนวแกน Y ทิ้งเพื่อให้อยู่ติดพื้น
                if myHum.Jump then myHum.Jump = false end
                pcall(function()
                    myHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                end)
                if myRoot.AssemblyLinearVelocity.Y > 0.5 then
                    myRoot.AssemblyLinearVelocity = Vector3.new(myRoot.AssemblyLinearVelocity.X, -2, myRoot.AssemblyLinearVelocity.Z)
                end

                local movementRestricted, restrictionReason = IsMovementRestrictedByGame(myChar, myHum)

                if movementRestricted then
                    StopNaturalWalk(myHum)
                    DisableRunning()
                    State.Current = "Skill movement lock: " .. tostring(restrictionReason)
                elseif horizDist > Config.AttackDistance then
                    -- ส่งทิศทางผ่าน Humanoid เหมือนกด WASD เพื่อให้อนิเมชันเดิน/วิ่งเล่นตามปกติ
                    EnsureRunning()
                    State.Current = string.format("Sprinting on ground to Eva (%d studs)...", math.floor(horizDist))
                    WalkNaturallyToward(myHum, myRoot, groundTargetPos)
                else
                    -- ระยะโจมตี: หันหน้าตามแนวราบระดับพื้น และสแปมสกิลใส่บอส
                    -- ⚠️ ถ้าสกิลไหนล็อคขา ก็ปล่อยให้ระบบเกมและแอนิเมชันล็อคขาตามปกติ เท้าติดพื้นเนียนที่สุด 100%
                    State.Current = "Attacking Eva (Grounded Combat)!"
                    StopNaturalWalk(myHum)
                    UpdateSmoothCharacterAim(myRoot, myHum, bRoot.Position)

                    SpamSkillsAtEva(bRoot.Position, horizDist)
                end
            else
                State.Current = "In Boss Room (Waiting for Eva target)..."
                StopNaturalWalk(myHum)
            end

            continue

        ------------------------------------------------------------------------
        -- สภาวะสิ้นสุดการต่อสู้: บอส EVA ถูกสังหารแล้ว
        ------------------------------------------------------------------------
        elseif State.IsEngagedWithEva then
            print("[Kaiju Eva Farm] 🏆 Eva defeated! Recording stats and sending Webhook...")
            State.EvaDefeatedCount = State.EvaDefeatedCount + 1
            State.IsEngagedWithEva = false
            State.EvaSpawnTime = 0
            State.ActiveEvaModel = nil
            State.IsDroppingIntoBossRoom = false
            State.BossDropStartedAt = 0
            State.Current = "Eva Defeated! Reporting..."
            StopNaturalWalk(myHum)
            DisableRunning()
            pcall(function()
                myHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end)

            -- ส่งรายงาน Discord Webhook
            task.spawn(SendDiscordWebhook)

            -- หลังบอสตาย: กลับ Lobby ก่อน อัปสเตตัส แล้วจึง Hop เซิร์ฟใหม่
            State.PostEvaProcessing = true
            task.spawn(function()
                State.Current = "Eva defeated - returning to Lobby in 4s..."
                task.wait(4)
                State.Current = "Returning to Lobby for auto upstat..."
                ReturnToLobby()
                task.wait(2.5)
                State.Current = "Auto upgrading stats..."
                pcall(AutoUpgradeStatsAfterEva)
                task.wait(0.8)
                State.Current = "Upstat complete - hopping verified server..."
                State.PortalRouteActive = false
                State.PortalRouteIndex = 1
                State.PostEvaProcessing = false
                HopServer(true, "Eva defeated - upstat completed")
            end)
            task.wait(0.5)
            continue

        else
            State.EvaSpawnTime = 0
            pcall(function()
                myHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end)

            -- 👥 ตรวจสอบจำนวนคนในเซิร์ฟเวอร์: ถ้าคนน้อยกว่า 5 คน ให้ Hop หาเซิร์ฟเวอร์ใหม่
            if #Players:GetPlayers() < Config.MinPlayersRequired then
                HopServer()
                task.wait(1.0)
                continue
            end

            -- ตรวจสอบระยะห่างจากตำแหน่งศูนย์กลางวงประตูวาป 1918, 72, 863
            -- ใช้ระยะแนวราบและยอมรับพื้นที่รอบ Portal ไม่บังคับเดินทับจุดกลาง
            local distToPortal = (Vector2.new(myRoot.Position.X, myRoot.Position.Z)
                - Vector2.new(Config.PortalWaitPosition.X, Config.PortalWaitPosition.Z)).Magnitude
            -- เมื่อเข้ามาใกล้วงครั้งแรกแล้ว ให้ล็อกสถานะยืนรอไว้จนกว่าจะถูกวาร์ปเข้าห้องบอส
            -- ไม่ประเมินเส้นทางใหม่แม้ระยะจะแกว่งจากฟิสิกส์หรือมีผู้เล่นชน
            if State.PortalHoldLocked or distToPortal <= Config.PortalHoldRadius then
                State.PortalHoldLocked = true
                State.PortalRouteActive = false
                State.PortalRouteIndex = 1
                StopNaturalWalk(myHum)
                DisableRunning()
                State.Current = string.format("Inside Portal area - holding still (%d studs)", math.floor(distToPortal))
                myRoot.Anchored = false
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myHum:Move(Vector3.zero, false)
            elseif distToPortal > Config.PortalArrivalRadius then
                -- ถ้ามีผู้เล่นอื่นในเซิร์ฟเวอร์ ให้ใช้เส้นทางเดินเสมอ
                -- เป็นโหมดปลอดภัยสูงสุด: ไม่มีกรณีวาร์ปตรงขณะมีคนอยู่
                if State.PortalRouteActive or #Players:GetPlayers() > 1 or HasOtherPlayerNearPortal() then
                    if not State.PortalRouteActive then
                        State.PortalRouteActive = true
                        State.PortalRouteIndex = 1
                        State.Current = "Player near Portal - using natural route..."
                        StopNaturalWalk(myHum)
                        InstantWarp(CFrame.new(Config.PortalStealthStart))
                        task.wait(0.25)
                    end

                    local waypoint = Config.PortalStealthWaypoints[State.PortalRouteIndex]
                    if waypoint then
                        local waypointDistance = (myRoot.Position - waypoint).Magnitude
                        if waypointDistance <= 15 then
                            State.PortalRouteIndex = State.PortalRouteIndex + 1
                            waypoint = Config.PortalStealthWaypoints[State.PortalRouteIndex]
                        end

                        if waypoint then
                            EnsureRunning()
                            State.Current = string.format(
                                "Running natural Portal route (%d/%d)...",
                                State.PortalRouteIndex,
                                #Config.PortalStealthWaypoints
                            )
                            WalkNaturallyToward(myHum, myRoot, waypoint)
                        end
                    end
                else
                    State.PortalRouteActive = false
                    State.PortalRouteIndex = 1
                    StopNaturalWalk(myHum)
                    DisableRunning()

                    -- ตรวจซ้ำวินาทีสุดท้ายก่อนวาร์ป: ถ้ามีผู้เล่น ห้ามวาร์ปไป Portal เด็ดขาด
                    if not ConfirmPortalClearForDirectWarp() then
                        -- ปล่อยให้รอบถัดไปเริ่มเส้นทางจาก PortalStealthStart อย่างถูกลำดับ
                        State.PortalRouteActive = false
                        State.PortalRouteIndex = 1
                        State.Current = "Player detected - direct Portal warp blocked!"
                        task.wait(0.05)
                    else
                        State.Current = "Portal clear - moving to Portal..."
                        InstantWarp(CFrame.new(Config.PortalWaitPosition))
                        task.wait(0.2)
                    end
                end
            else
                -- ยืนรอในวงประตูวาปอย่างสงบ ปล่อยฟิสิกส์ธรรมชาติ รอเกมพาเทเลพอร์ตเข้าห้องบอส
                State.PortalRouteActive = false
                State.PortalRouteIndex = 1
                StopNaturalWalk(myHum)
                DisableRunning()
                State.Current = string.format("Near Portal (Ready, %d studs)", math.floor(distToPortal))
                myRoot.Anchored = false
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 14. CLEANUP HANDLER
--------------------------------------------------------------------------------
getgenv().KaijuEvaFarm_Cleanup = function()
    pcall(function()
        RunService:UnbindFromRenderStep(MovementRenderStepName)
        RunService:UnbindFromRenderStep(MouseLockRenderStepName)
    end)
    if MouseLockInputConnection then
        MouseLockInputConnection:Disconnect()
        MouseLockInputConnection = nil
    end
    if CharacterAddedConnection then
        CharacterAddedConnection:Disconnect()
        CharacterAddedConnection = nil
    end
    if SpeedBoostConnection then
        SpeedBoostConnection:Disconnect()
        SpeedBoostConnection = nil
    end
    for humanoid, baseline in pairs(NormalWalkSpeedByHumanoid) do
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = baseline end)
        end
    end
    table.clear(LastAppliedWalkSpeed)
    table.clear(ExternalSlowScaleByHumanoid)
    if PlayerNoCollisionConnection then
        PlayerNoCollisionConnection:Disconnect()
        PlayerNoCollisionConnection = nil
    end
    RestoreOtherPlayerCollisions()
    for _, connection in ipairs(FPSBoostConnections) do
        connection:Disconnect()
    end
    table.clear(FPSBoostConnections)
    RestoreVFX()
    SpeedBoostEnabled = false
    State.AutoWalking = false
    State.DesiredMoveDirection = Vector3.zero
    State.ReturningToLobby = false
    CurrentEvaAimPart = nil
    local cleanupHumanoid = GetHumanoid()
    if cleanupHumanoid then
        cleanupHumanoid.AutoRotate = true
    end
    if AimOrientation then
        AimOrientation:Destroy()
        AimOrientation = nil
    end
    if AimAttachment then
        AimAttachment:Destroy()
        AimAttachment = nil
    end
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
    if getgenv().KaijuEvaFarm_RunToken == RunToken then
        getgenv().KaijuEvaFarm_RunToken = nil
    end
    print("[Kaiju Eva Farm] Script stopped and cleaned up.")
end
