-- VIRTUELLER F-KLICK DIREKT BEIM START
local VirtualInputManager = game:GetService("VirtualInputManager")
print("[Flux] Skript gestartet – Sende sofortigen virtuellen F-Klick...")
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)

-- RESt DES SKRIPTS
local OrionLib = loadstring(game:HttpGet("https://pastefy.app/2S5288c2/raw"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

local startCFrame = CFrame.new(3919.955322265625, 26.611604690551758, 35.344295501708984)

local meleeRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("MeeleAttack")
local collectRemote = ReplicatedStorage:WaitForChild("shared/network@GlobalEvents"):WaitForChild("CollectLoot")
local lootFolder = workspace:WaitForChild("LootSpawned")

local botRunning = false
local botCoroutine = nil

local SERVER_HISTORY_FILE = "Flux_ServerHistory.json"
local MAX_HISTORY_SIZE = 20

local function loadServerHistory()
    if isfile and isfile(SERVER_HISTORY_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(SERVER_HISTORY_FILE))
        end)
        if success and type(data) == "table" then
            return data
        end
    end
    return {}
end

local function saveServerHistory(history)
    if writefile then
        pcall(function()
            writefile(SERVER_HISTORY_FILE, HttpService:JSONEncode(history))
        end)
    end
end

local function addCurrentServerToHistory()
    local currentJobId = game.JobId
    if not currentJobId then return end
    
    local history = loadServerHistory()
    
    for _, serverId in ipairs(history) do
        if serverId == currentJobId then
            return
        end
    end
    
    table.insert(history, 1, currentJobId)
    
    if #history > MAX_HISTORY_SIZE then
        table.remove(history)
    end
    
    saveServerHistory(history)
end

local function findNewServer()
    local currentJobId = game.JobId
    local history = loadServerHistory()
    
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
    
    local success, result = pcall(function()
        local response = game:HttpGet(url)
        return HttpService:JSONDecode(response)
    end)
    
    if not success or not result or not result.data then
        warn("[ServerHop] Failed to fetch server list: " .. tostring(result))
        return nil
    end
    
    local goodServers = {}
    local anyServers = {}    
    
    print(string.format("[ServerHop] Server Found! %d", #result.data))
    
    for _, server in ipairs(result.data) do
        if server.id and server.playing and server.maxPlayers then
            local serverId = tostring(server.id)
            
            local inHistory = false
            for _, histId in ipairs(history) do
                if histId == serverId then
                    inHistory = true
                    break
                end
            end
            
            if server.playing < server.maxPlayers and server.playing > 0 then
                table.insert(anyServers, server)
                if server.playing >= 15 then
                    table.insert(goodServers, server)
                end
            end
        end
    end
    
    print(string.format("[ServerHop] Available Servers: %d (Good Servers: %d)", #anyServers, #goodServers))
    
    if #goodServers > 0 then
        local selected = goodServers[math.random(1, #goodServers)]
        print(string.format("[ServerHop] A good server has been selected: %s (%d/%d players)", selected.id, selected.playing, selected.maxPlayers))
        return selected
    elseif #anyServers > 0 then
        local selected = anyServers[math.random(1, #anyServers)]
        print(string.format("[ServerHop] A server has been selected: %s (%d/%d players)", selected.id, selected.playing, selected.maxPlayers))
        return selected
    end
    
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
        task.wait(3)
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/fluxgitscripts/autorob_bundesrp/refs/heads/main/main.lua"))()
        end)
    ]]
    
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if q then
        q(payload)
        print("[ServerHop] Auto-Execution for the next server set up.")
    end

    task.wait(0.5)

    local newServer = findNewServer()
    
    if newServer then
        print(string.format("[ServerHop] Teleport attempt to server: %s", newServer.id))
        
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, newServer.id, player)
        end)
        
        if not success then
            warn("[ServerHop] Direkt-Teleport failed: " .. tostring(err))
            task.wait(2)
            pcall(function()
                TeleportService:Teleport(game.PlaceId, player)
            end)
        end
    else
        print("[ServerHop] No suitable server found. Retrying in 10 seconds...")
        task.wait(1)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
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
            print(string.format("[Flux] Autorob: Collected ID: %s", tostring(currentId)))
            continue
        end

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

        if not foundSomething then
            print("[Flux] Autorob: No Loot found on the map! Tweening to End Coordinates...")
            
            local f = 0.5 
            local tweenInfoEnd = TweenInfo.new(f, Enum.EasingStyle.Linear)
            local endCFrame = CFrame.new(3017.068359375, 257.3508605957031, 363.1561279296875)
            
            local endTween = TweenService:Create(hrp, tweenInfoEnd, {CFrame = endCFrame})
            endTween:Play()
            endTween.Completed:Wait() 
            
            task.wait(3) 
            
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

local f_start = 0.7 
local tweenInfoStart = TweenInfo.new(f_start, Enum.EasingStyle.Linear)
local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart", 10)

if hrp then
    print("[Flux] Autorob Started - Tweening to Start Position...")
    local tween = TweenService:Create(hrp, tweenInfoStart, {CFrame = startCFrame})
    tween:Play()
    tween.Completed:Wait() 
end

local Window = OrionLib:MakeWindow({
    Name = "Flux Autorob - Bundes RP", 
    HidePremium = true, 
    SaveConfig = false, 
    IntroText = "Flux Autorob, Loading...",
})

local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://76479561414083",
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
            print("[Flux] Autorob Started")
        else
            if botCoroutine then
                coroutine.close(botCoroutine)
                botCoroutine = nil
            end
            print("[Flux] Autorob Stopped")
        end
    end
})

MainTab:AddParagraph("How to use the Autorob!","The script automatically triggers the virtual punch at the start and then runs the loop.")

OrionLib:Init()
