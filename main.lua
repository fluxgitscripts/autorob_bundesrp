local OrionLib = loadstring(game:HttpGet("https://pastefy.app/2S5288c2/raw"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Startkoordinaten (Polizei / Erster Punkt)
local startCFrame = CFrame.new(3919.955322265625, 26.611604690551758, 35.344295501708984)

-- Remotes
local meleeRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("MeeleAttack")
local collectRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("CollectLoot")
local lootFolder = workspace:WaitForChild("LootSpawned")

local botRunning = false
local botCoroutine = nil

-- Server Hop Funktion
local function performServerHop()
    print("[ServerHop] Starting Serverhop...")
    
    OrionLib:MakeNotification({
        Name = "Server Hop",
        Content = "Suche neuen Server... ServerHop startet automatisch!",
        Time = 5
    })
    
    local payload = [[
        repeat wait() until game:IsLoaded()
        wait(3)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/fluxgitscripts/autorob_bundesrp/refs/heads/main/main.lua"))()
    ]]
    
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if q then
        q(payload)
        print("[ServerHop] Auto-Execution für den nächsten Server registriert.")
    end

    local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(api)).data
    end)
    
    if success and result then
        for _, server in ipairs(result) do
            if server.playing and server.playing < server.maxPlayers and server.id ~= game.JobId then
                print(string.format("[ServerHop] Teleportiere zu Server: %s", server.id))
                
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                end)
                task.wait(5)
            end
        end
    end
    print("[ServerHop] Kein freier Server gefunden.")
end

local function getItemPosition(item)
    if not item or not item.Parent then return nil end
    return item:IsA("Model") and item:GetPivot().Position or (item:IsA("BasePart") and item.Position)
end

local function findNearestHitbox(itemPosition)
    local nearestHitbox = nil
    local shortestDistance = math.huge
    for _, desc in pairs(workspace:GetDescendants()) do
        if desc.Name == "Hitbox" and desc:IsA("BasePart") then
            local success, distance = pcall(function()
                return (itemPosition - desc.Position).Magnitude
            end)
            if success and distance < shortestDistance then
                shortestDistance = distance
                nearestHitbox = desc
            end
        end
    end
    return nearestHitbox
end

local function botLoop()
    while botRunning do
        task.wait(0.1)
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local lootItems = lootFolder:GetChildren()
        local foundSomething = false

        -- 1. Loot mit ID einsammeln
        local itemToCollect = nil
        local currentId = nil
        for _, item in pairs(lootItems) do
            if item and item.Parent then
                local targetId = item:GetAttribute("Id") or item:GetAttribute("id")
                if targetId then
                    itemToCollect = item
                    currentId = targetId
                    break
                end
            end
        end

        if itemToCollect and currentId then
            foundSomething = true
            local itemPos = getItemPosition(itemToCollect)
            if itemPos then
                hrp.CFrame = CFrame.new(itemPos)
            end
            local arguments = { [1] = currentId }
            collectRemote:FireServer(unpack(arguments))
            print(string.format("[LootBot]: Collected ID: %s", tostring(currentId)))
            continue
        end

        -- 2. Ungebrochenes Loot angreifen (keine ID)
        local itemToAttack = nil
        for _, item in pairs(lootItems) do
            local hasId = item:GetAttribute("Id") or item:GetAttribute("id")
            if item and item.Parent and not hasId then
                itemToAttack = item
                break
            end
        end

        if itemToAttack then
            foundSomething = true
            local itemPos = getItemPosition(itemToAttack)
            if itemPos then
                local hitbox = findNearestHitbox(itemPos)
                if hitbox and hitbox.Parent then
                    local doubleCheckId = itemToAttack:GetAttribute("Id") or itemToAttack:GetAttribute("id")
                    if doubleCheckId then continue end
                    pcall(function()
                        local direction = (hrp.Position - hitbox.Position).Unit
                        if direction.Magnitude ~= direction.Magnitude then direction = Vector3.new(0, 0, 1) end
                        local targetPos = hitbox.Position + (direction * 1.5)
                        targetPos = Vector3.new(targetPos.X, hitbox.Position.Y, targetPos.Z)
                        hrp.CFrame = CFrame.lookAt(targetPos, hitbox.Position)
                    end)
                    meleeRemote:FireServer()
                end
            end
        end

        -- 3. WENN NIX GEFUNDEN WURDE -> Zum zweiten Punkt tweenen
        if not foundSomething then
            print("[LootBot]: Kein Loot auf der Map! Tweene zu den End-Koordinaten...")
            
            local f = 0.5 -- Zeit für den End-Tween
            local tweenInfoEnd = TweenInfo.new(f, Enum.EasingStyle.Linear)
            local endCFrame = CFrame.new(3017.068359375, 257.3508605957031, 363.1561279296875)
            
            local endTween = TweenService:Create(hrp, tweenInfoEnd, {CFrame = endCFrame})
            endTween:Play()
            endTween.Completed:Wait() 
            
            task.wait(3) -- Wartet dort kurz 3 Sekunden ab
            
            local finalCheck = lootFolder:GetChildren()
            local immerNochNix = true
            for _, item in pairs(finalCheck) do
                if item and item.Parent then
                    immerNochNix = false
                    break
                end
            end
            
            if immerNochNix and botRunning then
                botRunning = false
                performServerHop()
                break
            end
        end
    end
end

-- 1. SCHNELLER, ABER SICHTBARER TWEEN ZU DEN STARTKOORDINATEN (AM ANFANG)
local f_start = 0.7 -- Erhöht von 0.1 auf 0.7 für einen echten, schnellen Tween
local tweenInfoStart = TweenInfo.new(f_start, Enum.EasingStyle.Linear)
local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart", 10)

if hrp then
    print("[LootBot]: Starte initialen Tween zur Position...")
    local tween = TweenService:Create(hrp, tweenInfoStart, {CFrame = startCFrame})
    tween:Play()
    tween.Completed:Wait() -- Wartet, bis der Charakter da ist, bevor das UI lädt
end

-- 2. ORION LIBRARY UI & AUTO-START
local Window = OrionLib:MakeWindow({
    Name = "Loot Bot", 
    HidePremium = true, 
    SaveConfig = false, 
    IntroText = "Night System"
})

local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345997",
    PremiumOnly = false
})

MainTab:AddToggle({
    Name = "Enable Autorob",
    Default = true, 
    Callback = function(state)
        botRunning = state
        if botRunning then
            if botCoroutine then coroutine.close(botCoroutine) end
            botCoroutine = coroutine.create(botLoop)
            coroutine.resume(botCoroutine)
            print("[LootBot]: Started")
        else
            if botCoroutine then
                coroutine.close(botCoroutine)
                botCoroutine = nil
            end
            print("[LootBot]: Stopped")
        end
    end
})

MainTab:AddParagraph("How to use the Autorob!","Enable the Autorob Toggle. Then punch 1 time to activate Autorob. Then it will automatically collect the Loot.")

OrionLib:Init()
