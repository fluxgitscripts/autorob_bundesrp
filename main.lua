-- // Services & Security Initialization
local cloneref = (type(cloneref) == "function") and cloneref or function(...) return ... end
local function getService(name) return cloneref(game:GetService(name)) end

local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local TweenService = getService("TweenService")
local HttpService = getService("HttpService")
local TeleportService = getService("TeleportService")
local RunService = getService("RunService")
local VirtualInputManager = getService("VirtualInputManager")
local Workspace = getService("Workspace")

local player = Players.LocalPlayer

-- // Simuliere initialen Schlag
print("[Flux] Script Started - Successfully sent Virtual MeeleAttack event.")
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)

-- // UI Library laden
local OrionLib = loadstring(game:HttpGet("https://pastefy.app/2S5288c2/raw"))()

-- // Konfigurationen & Konstanten
local startCFrame = CFrame.new(3919.955322265625, 26.611604690551758, 35.344295501708984)
local endCFrame = CFrame.new(3017.068359375, 257.3508605957031, 363.1561279296875)

local meleeRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("MeeleAttack")
local collectRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("CollectLoot")
local lootFolder = workspace:WaitForChild("LootSpawned")

local botRunning = false
local botCoroutine = nil
local policeDetectionEnabled = true

local SERVER_HISTORY_FILE = "Flux_ServerHistory.json"
local MAX_HISTORY_SIZE = 20

-- Emote Einstellungen
local EMOTE_ID = "94292601332790"
local STOP_ON_MOVE = false
local ALLOW_INVISIBLE = true
local FADE_IN, FADE_OUT = 0.1, 0.1
local WEIGHT, SPEED, TIME_POSITION = 1, 1, 0

-- Gecachte TweenInfos
local TWEEN_LOOT = TweenInfo.new(0.18, Enum.EasingStyle.Linear)
local TWEEN_ATTACK = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
local TWEEN_ESCAPE = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
local TWEEN_START = TweenInfo.new(0.7, Enum.EasingStyle.Linear)

-- // Character Variablen & Cache
local invCharacter = player.Character or player.CharacterAdded:Wait()
local invHumanoid = invCharacter:WaitForChild("Humanoid")
local CurrentTrack
local lastPosition = invCharacter.PrimaryPart and invCharacter.PrimaryPart.Position or Vector3.new()
local originalCollisions = {}
local invisibleEnabled = false

player.CharacterAdded:Connect(function(c)
    invCharacter = c
    invHumanoid = c:WaitForChild("Humanoid")
end)

-- // Hilfsfunktionen
local function getCustomJobName(targetPlayer)
    if not targetPlayer.Team then return "Citizen" end
    local name = string.lower(targetPlayer.Team.Name)
    
    if string.find(name, "poliz") or string.find(name, "police") or string.find(name, "cop") or string.find(name, "sheriff") or string.find(name, "sek") then
        return "Police"
    elseif string.find(name, "feuer") or string.find(name, "kranken") or string.find(name, "sani") or string.find(name, "medic") or string.find(name, "arzt") or string.find(name, "rettung") then
        return "Fire / Medic"
    elseif string.find(name, "abschlep") or string.find(name, "adac") or string.find(name, "mechanic") or string.find(name, "tow") then
        return "Mechanic / Tow"
    elseif string.find(name, "prison") or string.find(name, "gefangen") or string.find(name, "knast") or string.find(name, "häftling") then
        return "Prisoner"
    elseif string.find(name, "bürger") or string.find(name, "zivil") or string.find(name, "citizen") or string.find(name, "einwohner") then
        return "Citizen"
    end
    
    local color = targetPlayer.Team.TeamColor.Color
    local r, g, b = color.R, color.G, color.B
    if r > 0.8 and g > 0.8 and b > 0.8 then return "Citizen"
    elseif b > r and b > g then return "Police"
    elseif r > g and r > b and g < 0.4 then return "Fire / Medic"
    elseif r > 0.7 and g > 0.3 and g < 0.7 and b < 0.2 then return "Mechanic / Tow"
    elseif g > r and g > b then return "Prisoner" end
    
    return targetPlayer.Team.Name
end

local function loadServerHistory()
    if isfile and isfile(SERVER_HISTORY_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(SERVER_HISTORY_FILE))
        end)
        if success and type(data) == "table" then return data end
    end
    return {}
end

local function saveServerHistory(history)
    if writefile then
        pcall(function() writefile(SERVER_HISTORY_FILE, HttpService:JSONEncode(history)) end)
    end
end

local function addCurrentServerToHistory()
    local currentJobId = game.JobId
    if not currentJobId then return end
    
    local history = loadServerHistory()
    
    local exists = false
    for i = 1, #history do
        if history[i] == currentJobId then
            exists = true
            break
        end
    end
    if exists then return end
    
    table.insert(history, 1, currentJobId)
    if #history > MAX_HISTORY_SIZE then table.remove(history, #history) end
    saveServerHistory(history)
end

local function findNewServer()
    local history = loadServerHistory()
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if not success or not result or not result.data then return nil end
    
    local goodServers, anyServers = {}, {}
    for _, server in ipairs(result.data) do
        if server.id and server.playing and server.maxPlayers then
            local serverId = tostring(server.id)
            
            local inHistory = false
            for i = 1, #history do
                if history[i] == serverId then
                    inHistory = true
                    break
                end
            end
            
            if server.playing < server.maxPlayers and server.playing > 0 and not inHistory then
                table.insert(anyServers, server)
                if server.playing >= 15 then table.insert(goodServers, server) end
            end
        end
    end
    
    if #goodServers > 0 then return goodServers[math.random(1, #goodServers)]
    elseif #anyServers > 0 then return anyServers[math.random(1, #anyServers)] end
    return nil
end

local function performServerHop()
    print("[ServerHop] Starting Serverhop...")
    OrionLib:MakeNotification({
        Name = "Server Hop",
        Content = "Searching for servers... ServerHop will start automatically!",
        Time = 5
    })
    
    addCurrentServerToHistory()
    
    local payload = [[
        repeat task.wait() until game:IsLoaded()
        task.wait(2)
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/fluxgitscripts/autorob_bundesrp/refs/heads/main/main.lua"))()
        end)
    ]]
    
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if q then q(payload) end
    task.wait(0.5)

    local newServer = findNewServer()
    if newServer then
        local success = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, newServer.id, player) end)
        if not success then task.wait(1) pcall(function() TeleportService:Teleport(game.PlaceId, player) end) end
    else
        pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
    end
end

-- // Schleife: Polizei-Erkennung (Aktiviert sich erst nach 10 Sekunden)
task.spawn(function()
    print("[Flux] Police Detection: Waiting 10 seconds before initializing...")
    task.wait(10) -- Wartet 10 Sekunden ab Skriptstart
    print("[Flux] Police Detection is now ACTIVE.")
    
    while true do
        task.wait(0.3)
        if policeDetectionEnabled and invCharacter and invCharacter:FindFirstChild("HumanoidRootPart") then
            local myRoot = invCharacter.HumanoidRootPart
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if getCustomJobName(otherPlayer) == "Police" then
                        if (myRoot.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude <= 50 then
                            print("[Flux] Police Detected! Escaping...")
                            OrionLib:MakeNotification({
                                Name = "Police Detected",
                                Content = "Police Detected, Doing Serverhop",
                                Time = 5
                            })
                            
                            botRunning = false
                            if botCoroutine then 
                                pcall(coroutine.close, botCoroutine) 
                                botCoroutine = nil
                            end
                            policeDetectionEnabled = false 

                            local escapeTween = TweenService:Create(myRoot, TWEEN_ESCAPE, {CFrame = endCFrame})
                            escapeTween:Play()
                            escapeTween.Completed:Wait()
                            
                            task.wait(0.2)
                            performServerHop()
                            break
                        end
                    end
                end
            end
        end
    end
end)

local function getItemPosition(item)
    if not item or not item.Parent then return nil end
    return item:IsA("Model") and item:GetPivot().Position or (item:IsA("BasePart") and item.Position)
end

local function findNearestHitbox(itemPosition, item)
    if not item then return nil end
    local directHitbox = item:FindFirstChild("Hitbox") or (item.Parent and item.Parent:FindFirstChild("Hitbox"))
    if directHitbox and directHitbox:IsA("BasePart") then return directHitbox end

    local success, nearbyParts = pcall(function()
        return Workspace:GetPartBoundsInRadius(itemPosition, 20)
    end)
    
    if success and type(nearbyParts) == "table" then
        local nearestHitbox = nil
        local shortestDistance = math.huge
        for i = 1, #nearbyParts do
            local part = nearbyParts[i]
            if part and part.Name == "Hitbox" and part:IsA("BasePart") then
                local dist = (itemPosition - part.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    nearestHitbox = part
                end
            end
        end
        return nearestHitbox
    end
    return nil
end

-- // Haupt-Bot-Schleife
local function botLoop()
    while botRunning do
        task.wait(0.05)
        local hrp = invCharacter and invCharacter:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local lootItems = lootFolder:GetChildren()
        local itemToCollect, collectId = nil, nil
        local itemToAttack = nil

        for _, item in ipairs(lootItems) do
            if item and item.Parent then
                local targetId = item:GetAttribute("Id") or item:GetAttribute("id")
                if targetId then
                    if not itemToCollect then
                        itemToCollect = item
                        collectId = targetId
                    end
                else
                    if not itemToAttack then
                        itemToAttack = item
                    end
                end
                if itemToCollect and itemToAttack then break end
            end
        end

        -- Aktion 1: Einsammeln
        if itemToCollect and collectId then
            local itemPos = getItemPosition(itemToCollect)
            if itemPos then
                local lootTween = TweenService:Create(hrp, TWEEN_LOOT, {CFrame = CFrame.new(itemPos)})
                lootTween:Play()
                lootTween.Completed:Wait()
            end
            collectRemote:FireServer(collectId)
            print(string.format("[Flux] Autorob: Collected ID: %s", tostring(collectId)))
            continue
        end

        -- Aktion 2: Angreifen
        if itemToAttack then
            local itemPos = getItemPosition(itemToAttack)
            if itemPos then
                local hitbox = findNearestHitbox(itemPos, itemToAttack)
                if hitbox and hitbox.Parent then
                    if itemToAttack:GetAttribute("Id") or itemToAttack:GetAttribute("id") then continue end
                    
                    pcall(function()
                        local direction = (hrp.Position - hitbox.Position).Unit
                        if direction.Magnitude ~= direction.Magnitude then direction = Vector3.new(0, 0, 1) end
                        local targetPos = hitbox.Position + (direction * 1.5)
                        targetPos = Vector3.new(targetPos.X, hitbox.Position.Y, targetPos.Z)
                        
                        local attackTween = TweenService:Create(hrp, TWEEN_ATTACK, {CFrame = CFrame.lookAt(targetPos, hitbox.Position)})
                        attackTween:Play()
                        attackTween.Completed:Wait()
                    end)
                    meleeRemote:FireServer()
                end
            end
            continue
        end

        -- Keine Beute auf der Map
        print("[Flux] Autorob: No Loot found! Tweening to End Coordinates...")
        local endTween = TweenService:Create(hrp, TWEEN_ESCAPE, {CFrame = endCFrame})
        endTween:Play()
        endTween.Completed:Wait() 
        
        task.wait(2.5) 
        
        local immerNochNix = true
        for _, item in ipairs(lootFolder:GetChildren()) do
            if item and item.Parent then immerNochNix = false break end
        end
        
        if immerNochNix and botRunning then
            botRunning = false
            performServerHop()
            break
        end
    end
end

-- Initialer Teleport zum Startpunkt
local startupHrp = invCharacter:WaitForChild("HumanoidRootPart", 10)
if startupHrp then
    print("[Flux] Autorob Started - Tweening to Start Position...")
    local tween = TweenService:Create(startupHrp, TWEEN_START, {CFrame = startCFrame})
    tween:Play()
    tween.Completed:Wait() 
end

-- // Invisibility / Collision Management
local function saveCollisions()
    originalCollisions = {}
    for _, p in ipairs(invCharacter:GetDescendants()) do
        if p:IsA("BasePart") then originalCollisions[p] = p.CanCollide end
    end
end

local function disableCollisions()
    for _, p in ipairs(invCharacter:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function restoreCollisions()
    for p, state in pairs(originalCollisions) do
        if p and p.Parent then p.CanCollide = state end
    end
    originalCollisions = {}
end

local function startEmote()
    if CurrentTrack then CurrentTrack:Stop(0) end
    local id = tonumber(EMOTE_ID) or tonumber(string.match(EMOTE_ID, "%d+"))
    if not id then return end

    local animId = "rbxassetid://" .. id
    pcall(function()
        local objs = game:GetObjects(animId)
        if objs and #objs > 0 and objs[1]:IsA("Animation") then animId = objs[1].AnimationId end
    end)

    local anim = Instance.new("Animation")
    anim.AnimationId = animId

    local track = invHumanoid:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action4
    track:Play(FADE_IN, WEIGHT == 0 and 0.001 or WEIGHT, SPEED)

    CurrentTrack = track
    CurrentTrack.TimePosition = math.clamp(TIME_POSITION, 0, 1) * CurrentTrack.Length

    if ALLOW_INVISIBLE then
        saveCollisions()
        disableCollisions()
    end
end

local function stopEmote()
    if CurrentTrack then CurrentTrack:Stop(FADE_OUT) CurrentTrack = nil end
    restoreCollisions()
end

-- // RenderStepped Connections
RunService.RenderStepped:Connect(function()
    if not invisibleEnabled then return end
    if STOP_ON_MOVE and CurrentTrack and CurrentTrack.IsPlaying and invCharacter.PrimaryPart then
        local currentPos = invCharacter.PrimaryPart.Position
        if (currentPos - lastPosition).Magnitude > 0.1 then
            stopEmote()
            invisibleEnabled = false
        end
        lastPosition = currentPos
    end
end)

RunService.Stepped:Connect(function()
    if invisibleEnabled and ALLOW_INVISIBLE and invCharacter and invCharacter.Parent then
        disableCollisions()
    end
end)

-- // UI Definition (Orion)
local Window = OrionLib:MakeWindow({
    Name = "Flux Autorob - Bundes RP", 
    HidePremium = true, 
    SaveConfig = false, 
    IntroText = "Flux Autorob, Loading...",
})

local MainTab = Window:MakeTab({ Name = "Main", Icon = "rbxassetid://76479561414083", PremiumOnly = false })
local InfoTab = Window:MakeTab({ Name = "Info", Icon = "rbxassetid://110571167375107", PremiumOnly = false })

MainTab:AddToggle({
    Name = "Enable Autorob",
    Default = true, 
    Callback = function(state)
        botRunning = state
        if botRunning then
            if botCoroutine then coroutine.close(botCoroutine) end
            botCoroutine = coroutine.create(botLoop)
            coroutine.resume(botCoroutine)
            print("[Flux] Autorob Started")
        else
            if botCoroutine then coroutine.close(botCoroutine) botCoroutine = nil end
            print("[Flux] Autorob Stopped")
        end
    end
})

MainTab:AddToggle({
    Name = "Police Detection",
    Default = true,
    Callback = function(state)
        policeDetectionEnabled = state
        print("[Flux] Police Detection status:", state)
    end
})

MainTab:AddToggle({
    Name     = "Invisible [Emote] (NOT RECOMMENDED)",
    Default  = false,
    Callback = function(value)
        invisibleEnabled = value
        if value then startEmote() else stopEmote() end
    end,
})

MainTab:AddParagraph("How to use the Autorob!","The script automatically triggers the virtual punch at the start and then runs the loop.")
InfoTab:AddParagraph("Developers & Credits","Made by zzkxnsti, Shellcode and Maxi. Thanks to everyone who contributed to testing and improving the script!")
InfoTab:AddParagraph("Join the Community!","Join our Discord!: https://discord.gg/zRTh9knFQb")

OrionLib:Init()
