local VirtualInputManager = game:GetService("VirtualInputManager")
print("[Flux] Script Started - Successfully sent Virtual MeeleAttack event.")
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)

local OrionLib = loadstring(game:HttpGet("https://pastefy.app/2S5288c2/raw"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

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

local function getCustomJobName(targetPlayer)
    if not targetPlayer.Team then return "Citizen" end
    
    local name = string.lower(targetPlayer.Team.Name)
    local color = targetPlayer.Team.TeamColor.Color
    
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
    
    local r, g, b = color.R, color.G, color.B
    if r > 0.8 and g > 0.8 and b > 0.8 then
        return "Citizen"
    elseif b > r and b > g then
        return "Police"
    elseif r > g and r > b and g < 0.4 then
        return "Fire / Medic"
    elseif r > 0.7 and g > 0.3 and g < 0.7 and b < 0.2 then
        return "Mechanic / Tow"
    elseif g > r and g > b then
        return "Prisoner"
    end
    
    return targetPlayer.Team.Name
end

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
    
    if #goodServers > 0 then
        return goodServers[math.random(1, #goodServers)]
    elseif #anyServers > 0 then
        return anyServers[math.random(1, #anyServers)]
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
    end

    task.wait(0.5)

    local newServer = findNewServer()
    if newServer then
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, newServer.id, player)
        end)
        if not success then
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
        end
    else
        task.wait(1)
        pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
    end
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if policeDetectionEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local myRoot = player.Character.HumanoidRootPart
            
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if getCustomJobName(otherPlayer) == "Police" then
                        local distance = (myRoot.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude
                        if distance <= 50 then
                            print(string.format("[Flux] Police Detected! Fleeing to serverhop position..."))
                            
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

                            local escapeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
                            local escapeTween = TweenService:Create(myRoot, escapeTweenInfo, {CFrame = endCFrame})
                            escapeTween:Play()
                            escapeTween.Completed:Wait()
                            
                            task.wait(0.3)
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
        task.wait(0.05)
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
                local lootTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Linear)
                local lootTween = TweenService:Create(hrp, lootTweenInfo, {CFrame = CFrame.new(itemPos)})
                lootTween:Play()
                lootTween.Completed:Wait()
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
                        
                        local attackTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
                        local attackTween = TweenService:Create(hrp, attackTweenInfo, {CFrame = CFrame.lookAt(targetPos, hitbox.Position)})
                        attackTween:Play()
                        attackTween.Completed:Wait()
                    end)
                    meleeRemote:FireServer()
                end
            end
        end

        if not foundSomething then
            print("[Flux] Autorob: No Loot found on the map! Tweening to End Coordinates...")
            
            local f = 0.5 
            local tweenInfoEnd = TweenInfo.new(f, Enum.EasingStyle.Linear)
            
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

local InfoTab = Window:MakeTab({
    Name = "Info",
    Icon = "rbxassetid://110571167375107",
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

MainTab:AddToggle({
    Name = "Police Detection",
    Default = true,
    Callback = function(state)
        policeDetectionEnabled = state
        print("[Flux] Police Detection status:", state)
    end
})

EMOTE_ID        = "94292601332790"
STOP_ON_MOVE    = false
ALLOW_INVISIBLE = true
FADE_IN         = 0.1
FADE_OUT        = 0.1
WEIGHT          = 1
SPEED           = 1
TIME_POSITION   = 0

cloneref = (type(cloneref) == "function") and cloneref or function(...) return ... end
InvServices = setmetatable({}, { __index = function(_, n) return cloneref(game:GetService(n)) end })

RunService = InvServices.RunService
player     = game:GetService("Players").LocalPlayer

invCharacter = player.Character or player.CharacterAdded:Wait()
invHumanoid  = invCharacter:WaitForChild("Humanoid")

local CurrentTrack
lastPosition       = invCharacter.PrimaryPart and invCharacter.PrimaryPart.Position or Vector3.new()
originalCollisions = {}
invisibleEnabled   = false

local function saveCollisions()
    originalCollisions = {}
    for _, p in ipairs(invCharacter:GetDescendants()) do
        if p:IsA("BasePart") then
            originalCollisions[p] = p.CanCollide
        end
    end
end

local function disableCollisions()
    for _, p in ipairs(invCharacter:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = false
        end
    end
end

local function restoreCollisions()
    for p, state in pairs(originalCollisions) do
        if p and p.Parent then
            p.CanCollide = state
        end
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
        if objs and #objs > 0 and objs[1]:IsA("Animation") then
            animId = objs[1].AnimationId
        end
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
    if CurrentTrack then
        CurrentTrack:Stop(FADE_OUT)
        CurrentTrack = nil
    end
    restoreCollisions()
end

player.CharacterAdded:Connect(function(c)
    invCharacter = c
    invHumanoid  = c:WaitForChild("Humanoid")
end)

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

MainTab:AddToggle({
    Name     = "Invisible [Emote] (NOT RECOMMENDED)",
    Default  = false,
    Callback = function(value)
        invisibleEnabled = value
        if value then
            startEmote()
        else
            stopEmote()
        end
    end,
})

MainTab:AddParagraph("How to use the Autorob!","The script automatically triggers the virtual punch at the start and then runs the loop.")

InfoTab:AddParagraph("Developers & Credits","Made by zzkxnsti, Shellcode and Maxi. Thanks to everyone who contributed to testing and improving the script!")
InfoTab:AddParagraph("Join the Community!","Join our Discord!: https://discord.gg/zRTh9knFQb")

OrionLib:Init()
