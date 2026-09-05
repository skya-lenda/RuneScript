workspace.FallenPartsDestroyHeight = -math.huge
local LURAPH_AAD = 119607431
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local RE = ReplicatedStorage:WaitForChild("RE")
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/XuungMath20/Kupi/refs/heads/main/Main.lua"))()
local Window = UI:MakeWindow({ Title = " Slayer Hub ", LoadText = "consegue skiddar nao?", Flags = "Slayer Hubb" })
Window:AddMinimizeButton({ Button = { Image = "rbxassetid://134266914727471", BackgroundTransparency = 1 }, Corner = { CornerRadius = UDim.new(35, 1) } })

local flags = {}
local connections = {}
local playerDropdownHandles = {}
local selectedPlayerName = nil
local selectedAvatarName = nil
local selectedKillMethod = "Couch"
local selectedMethod = "Couch"
local selectedSoundId = nil
local audioAllId = ""
local audioId = ""
local signText = ""
local carSpeed = 200
local carTurbo = 11.3
local rgbSpeed = 2
local protectedKinds = { Canoe = false, Jet = false, Heli = false, Ball = false, Sit = false }
local businessNames = { "Slayer Hub", "Slayer Hub On Top", "The Best Hub", "Slayer Hub is here", "hi Slayer" }

local function getRemote(name)
    return RE:FindFirstChild(name)
end

local function fireRemote(name, ...)
    local remote = getRemote(name)
    if not remote then return nil end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return true
    end
    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
    return nil
end

local function invokeRemote(name, ...)
    local remote = getRemote(name)
    if not remote then return nil end
    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return true
    end
    return nil
end

local function loadExternal(url)
    local source = game:HttpGet(url)
    local chunk = loadstring(source)
    if chunk then
        return chunk()
    end
    return nil
end

local function localCharacter()
    return LocalPlayer.Character
end

local function localHumanoid()
    local character = localCharacter()
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function localRoot()
    local character = localCharacter()
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function resolvePlayer(name)
    if not name or name == "" then return nil end
    return Players:FindFirstChild(name)
end

local function selectedPlayer()
    return resolvePlayer(selectedPlayerName)
end

local function playerRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function playerHumanoid(player)
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    table.sort(names)
    return names
end

local function refreshPlayerDropdowns()
    local options = getPlayerNames()
    for _, handle in ipairs(playerDropdownHandles) do
        if handle then
            if handle.Refresh then
                handle:Refresh(options)
            elseif handle.Set then
                handle:Set(options)
            end
        end
    end
    if selectedPlayerName and not Players:FindFirstChild(selectedPlayerName) then
        selectedPlayerName = nil
    end
    if selectedAvatarName and not Players:FindFirstChild(selectedAvatarName) then
        selectedAvatarName = nil
    end
end

local function rainbowColor()
    local period = math.max(0.05, tonumber(rgbSpeed) or 2)
    return Color3.fromHSV((os.clock() / period) % 1, 1, 1)
end

local function giveTool(toolName)
    return invokeRemote("1Too1l", "PickingTools", toolName)
end

local function clearTools()
    fireRemote("1Clea1rTool1s", "ClearAllTools")
end

local function findTool(toolName)
    local character = localCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    return (character and character:FindFirstChild(toolName)) or (backpack and backpack:FindFirstChild(toolName))
end

local function equipTool(toolName)
    giveTool(toolName)
    task.wait(0.25)
    local tool = findTool(toolName)
    local character = localCharacter()
    if tool and character then
        tool.Parent = character
    end
    return tool
end

local function findOwnedVehicle()
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then return nil end
    local exact = vehicles:FindFirstChild(LocalPlayer.Name .. "Car")
    if exact then return exact end
    local humanoid = localHumanoid()
    for _, model in ipairs(vehicles:GetChildren()) do
        local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat and humanoid and seat.Occupant == humanoid then
            return model
        end
    end
    return nil
end

local function vehicleRoot(vehicle)
    if not vehicle then return nil end
    return vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
end

local function spawnCar(kind)
    fireRemote("1Ca1r", "PickingCar", kind)
    task.wait(0.35)
    return findOwnedVehicle()
end

local function spawnBoat()
    fireRemote("1Ca1r", "PickingBoat", "MilitaryBoatFree")
    task.wait(0.35)
    return findOwnedVehicle()
end

local function deleteVehicles()
    fireRemote("1Ca1r", "DeleteAllVehicles")
end

local function moveVehicleToPlayer(vehicle, player, offset)
    local targetRoot = playerRoot(player)
    if not vehicle or not targetRoot then return false end
    local destination = targetRoot.CFrame * (offset or CFrame.new(0, 0, -2))
    if vehicle:IsA("Model") then
        vehicle:PivotTo(destination)
    else
        local part = vehicleRoot(vehicle)
        if part then part.CFrame = destination end
    end
    return true
end

local function flingWithVehicle(player, kind, power)
    if not player or player == LocalPlayer then return end
    local vehicle
    if kind == "Boat" or kind == "PoliceBoat" then
        vehicle = spawnBoat()
    else
        vehicle = spawnCar(kind == "TowTruck" and "TowTruck" or "SchoolBus")
    end
    local part = vehicleRoot(vehicle)
    local targetRoot = playerRoot(player)
    if not part or not targetRoot then return end
    moveVehicleToPlayer(vehicle, player, CFrame.new(0, 0, -1))
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "SlayerVehicleFlingVelocity"
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = Vector3.new(power or 2500, power or 2500, power or 2500)
    velocity.Parent = part
    local angular = Instance.new("BodyAngularVelocity")
    angular.Name = "SlayerVehicleFlingAngular"
    angular.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    angular.AngularVelocity = Vector3.new(0, power or 2500, 0)
    angular.Parent = part
    local started = os.clock()
    while os.clock() - started < 1.25 and targetRoot.Parent do
        part.CFrame = CFrame.new(targetRoot.Position + targetRoot.AssemblyLinearVelocity / 2)
        task.wait()
    end
    velocity:Destroy()
    angular:Destroy()
end

local function couchFlingPlayer(player, duration, power)
    if not player or player == LocalPlayer then return end
    local root = localRoot()
    local humanoid = localHumanoid()
    local targetRoot = playerRoot(player)
    if not root or not humanoid or not targetRoot then return end
    local saved = root.CFrame
    local oldSubject = Workspace.CurrentCamera.CameraSubject
    local couch = equipTool("Couch")
    if not couch then return end
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "SlayerCouchFlingVelocity"
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = Vector3.new(power, power, power)
    velocity.Parent = root
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    Workspace.CurrentCamera.CameraSubject = targetRoot
    local started = os.clock()
    while os.clock() - started < duration and targetRoot.Parent and root.Parent do
        root.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(30), 0, 0)
        root.AssemblyLinearVelocity = Vector3.new(power, power, power)
        root.AssemblyAngularVelocity = Vector3.new(power, power, power)
        task.wait()
    end
    velocity:Destroy()
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    root.CFrame = saved
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    Workspace.CurrentCamera.CameraSubject = oldSubject or humanoid
    humanoid:UnequipTools()
    clearTools()
end

local function flingBallPlayer(player)
    if not player or player == LocalPlayer then return end
    giveTool("SoccerBall")
    task.wait(0.2)
    local workspaceCom = Workspace:FindFirstChild("WorkspaceCom")
    local soccerFolder = workspaceCom and workspaceCom:FindFirstChild("001_SoccerBalls")
    local ball = soccerFolder and soccerFolder:FindFirstChild("Soccer" .. LocalPlayer.Name)
    local targetRoot = playerRoot(player)
    if not ball or not targetRoot or not ball:IsA("BasePart") then return end
    for _, child in ipairs(ball:GetChildren()) do
        if child:IsA("BodyMover") then child:Destroy() end
    end
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "SlayerBallFlingVelocity"
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = Vector3.new(5000, 5000, 5000)
    velocity.Parent = ball
    local started = os.clock()
    while os.clock() - started < 1.5 and targetRoot.Parent do
        ball.CFrame = CFrame.new(targetRoot.Position + targetRoot.AssemblyLinearVelocity / 1.5)
        task.wait()
    end
    velocity:Destroy()
end

local function flingCanoePlayer(player)
    if not player then return end
    giveTool("Canoe")
    task.wait(0.2)
    flingWithVehicle(player, "Boat", 3500)
end

local function flingBoatPlayer(player)
    flingWithVehicle(player, "Boat", 4000)
end

local function forEveryOtherPlayer(callback)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            callback(player)
            task.wait(0.15)
        end
    end
end

local function dispatchFling(player, method)
    if not player then return end
    if method == "Ball" then
        flingBallPlayer(player)
    elseif method == "Boat" or method == "PoliceBoat" then
        flingBoatPlayer(player)
    elseif method == "Bus" or method == "TowTruck" then
        flingWithVehicle(player, method, 3500)
    else
        couchFlingPlayer(player, 1.6, 900000000)
    end
end

local function killSelected()
    dispatchFling(selectedPlayer(), selectedMethod)
end

local function bringSelected()
    local player = selectedPlayer()
    if not player then return end
    if selectedMethod == "Couch" then
        local root = localRoot()
        local targetRoot = playerRoot(player)
        if root and targetRoot then targetRoot.CFrame = root.CFrame * CFrame.new(0, 0, -3) end
    else
        local vehicle = selectedMethod == "Boat" and spawnBoat() or spawnCar("SchoolBus")
        moveVehicleToPlayer(vehicle, player, CFrame.new(0, 0, -2))
    end
end

local function goToSelected()
    local root = localRoot()
    local targetRoot = playerRoot(selectedPlayer())
    if root and targetRoot then
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
    end
end

local function setConnection(key, connection)
    local previous = connections[key]
    if previous then previous:Disconnect() end
    connections[key] = connection
end

local function clearConnection(key)
    local connection = connections[key]
    if connection then connection:Disconnect() end
    connections[key] = nil
end

local function viewSelectedLoop(enabled)
    flags.viewSelected = enabled
    if enabled then
        setConnection("viewSelected", RunService.Heartbeat:Connect(function()
            local humanoid = playerHumanoid(selectedPlayer())
            if humanoid then Workspace.CurrentCamera.CameraSubject = humanoid end
        end))
    else
        clearConnection("viewSelected")
        local humanoid = localHumanoid()
        if humanoid then Workspace.CurrentCamera.CameraSubject = humanoid end
    end
end

local function spectateSelectedLoop(enabled)
    flags.spectateSelected = enabled
    viewSelectedLoop(enabled)
end

local function rgbNameBioLoop(enabled)
    flags.rgbNameBio = enabled
    if enabled then
        task.spawn(function()
            while flags.rgbNameBio do
                local color = rainbowColor()
                fireRemote("1RPNam1eColo1r", "PickingRPNameColor", color)
                fireRemote("1RPNam1eColo1r", "PickingRPBioColor", color)
                task.wait(0.03)
            end
        end)
    end
end

local function rgbNameLoop(enabled)
    flags.nameRgb = enabled
    if enabled then
        task.spawn(function()
            while flags.nameRgb do
                fireRemote("1RPNam1eColo1r", "PickingRPNameColor", rainbowColor())
                task.wait(0.03)
            end
        end)
    end
end

local function rgbBioLoop(enabled)
    flags.bioRgb = enabled
    if enabled then
        task.spawn(function()
            while flags.bioRgb do
                fireRemote("1RPNam1eColo1r", "PickingRPBioColor", rainbowColor())
                task.wait(0.03)
            end
        end)
    end
end

local function callback_7896(enabled)
    flags.rgbBicycle = enabled
    if enabled then
        task.spawn(function()
            while flags.rgbBicycle do
                fireRemote("1Player1sCa1r", "NoMotorColor", rainbowColor())
                task.wait(0.1)
            end
        end)
    end
end

local function radioRgbLoop(enabled)
    flags.radioRgb = enabled
    if enabled then
        task.spawn(function()
            while flags.radioRgb do
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local toolGui = playerGui and playerGui:FindFirstChild("ToolGui")
                local toolSettings = toolGui and toolGui:FindFirstChild("ToolSettings")
                local settings = toolSettings and toolSettings:FindFirstChild("Settings")
                if settings then
                    for _, descendant in ipairs(settings:GetDescendants()) do
                        if descendant.Name == "SetColor" and descendant:IsA("RemoteEvent") then
                            descendant:FireServer(rainbowColor())
                        end
                    end
                end
                task.wait(0.03)
            end
        end)
    end
end

local function rgbCharacterLoop(enabled)
    flags.rgbCharacter = enabled
    if enabled then
        task.spawn(function()
            while flags.rgbCharacter do
                local character = localCharacter()
                local color = rainbowColor()
                if character then
                    for _, descendant in ipairs(character:GetDescendants()) do
                        if descendant:IsA("BasePart") then descendant.Color = color end
                    end
                end
                task.wait(0.03)
            end
        end)
    end
end

local function setProtection(kind, enabled)
    protectedKinds[kind] = enabled
end

local function protectionTick()
    local humanoid = localHumanoid()
    if protectedKinds.Sit and humanoid and humanoid.Sit then
        humanoid.Sit = false
    end
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local name = descendant.Name
            local parentName = descendant.Parent and descendant.Parent.Name or ""
            local canoe = protectedKinds.Canoe and (name:find("Canoe") or parentName:find("Canoe"))
            local jet = protectedKinds.Jet and (name:find("Jet") or parentName:find("Jet"))
            local heli = protectedKinds.Heli and (name:find("Heli") or parentName:find("Heli"))
            local ball = protectedKinds.Ball and (name:find("Ball") or parentName:find("Ball"))
            if canoe or jet or heli or ball then descendant.CanCollide = false end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if protectedKinds.Sit or protectedKinds.Canoe or protectedKinds.Jet or protectedKinds.Heli or protectedKinds.Ball then
        protectionTick()
    end
end)

local function antiCanoe(enabled) setProtection("Canoe", enabled) end
local function antiJet(enabled) setProtection("Jet", enabled) end
local function antiHelicopter(enabled) setProtection("Heli", enabled) end
local function antiBall(enabled) setProtection("Ball", enabled) end
local function antiSit(enabled) setProtection("Sit", enabled) end

local function gravityOrbitLoop(enabled)
    flags.gravityOrbit = enabled
    if enabled then
        setConnection("gravityOrbit", RunService.Heartbeat:Connect(function()
            local root = localRoot()
            if root then
                local angle = os.clock() * 3
                root.AssemblyAngularVelocity = Vector3.new(math.sin(angle) * 8, 12, math.cos(angle) * 8)
            end
        end))
    else
        clearConnection("gravityOrbit")
        local root = localRoot()
        if root then root.AssemblyAngularVelocity = Vector3.zero end
    end
end

local function blackHoleFlingPlayerLoop(enabled)
    flags.blackHolePlayer = enabled
    if enabled then
        setConnection("blackHolePlayer", RunService.Heartbeat:Connect(function()
            local targetRoot = playerRoot(selectedPlayer())
            if not targetRoot then return end
            for _, part in ipairs(Workspace:GetPartBoundsInRadius(targetRoot.Position, 28)) do
                if part:IsA("BasePart") and not part.Anchored and not part:IsDescendantOf(localCharacter() or Workspace) then
                    part.AssemblyLinearVelocity = (targetRoot.Position - part.Position).Unit * 220
                end
            end
        end))
    else
        clearConnection("blackHolePlayer")
    end
end

local function findVehicleSeat(vehicle)
    return vehicle and vehicle:FindFirstChildWhichIsA("VehicleSeat", true) or nil
end

local function bringAllCars()
    local root = localRoot()
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not root or not vehicles then return end
    for _, vehicle in ipairs(vehicles:GetChildren()) do
        local seat = findVehicleSeat(vehicle)
        if seat and not seat.Occupant then
            if vehicle:IsA("Model") then vehicle:PivotTo(root.CFrame * CFrame.new(0, 0, -8)) end
            task.wait(0.05)
        end
    end
end

local function killAllCarsLoop(enabled)
    flags.killAllCars = enabled
    if enabled then
        task.spawn(function()
            local vehicles = Workspace:FindFirstChild("Vehicles")
            if not vehicles then return end
            for _, vehicle in ipairs(vehicles:GetChildren()) do
                if not flags.killAllCars then break end
                local seat = findVehicleSeat(vehicle)
                if seat and not seat.Occupant and vehicle:IsA("Model") then
                    vehicle:PivotTo(CFrame.new(0, Workspace.FallenPartsDestroyHeight + 100, 0))
                    task.wait(0.1)
                end
            end
            flags.killAllCars = false
        end)
    end
end

local function vehicleRgbLoop(enabled)
    flags.vehicleRgb = enabled
    if enabled then
        setConnection("vehicleRgb", RunService.RenderStepped:Connect(function()
            local vehicle = findOwnedVehicle()
            if vehicle then
                local color = rainbowColor()
                for _, descendant in ipairs(vehicle:GetDescendants()) do
                    if descendant:IsA("BasePart") then descendant.Color = color end
                end
            end
        end))
    else
        clearConnection("vehicleRgb")
    end
end

local function houseRgbLoop(enabled)
    flags.houseRgb = enabled
    if enabled then
        setConnection("houseRgb", RunService.RenderStepped:Connect(function()
            fireRemote("1Player1sHous1e", "ColorPickHouse", Color3.fromHSV(math.random(), 1, 1))
        end))
    else
        clearConnection("houseRgb")
    end
end

local function houseTextRgbLoop(enabled)
    flags.houseTextRgb = enabled
    if enabled then
        setConnection("houseTextRgb", RunService.RenderStepped:Connect(function()
            fireRemote("1RPHous1eEven1tColo1r", "PickingBusinessNameColor", Color3.fromHSV(math.random(), 1, 1))
        end))
    else
        clearConnection("houseTextRgb")
    end
end

local function hackedHouseTextLoop(enabled)
    flags.hackedHouseText = enabled
    local last = 0
    local alternate = false
    if enabled then
        setConnection("hackedHouseText", RunService.RenderStepped:Connect(function()
            if os.clock() - last < 0.35 then return end
            last = os.clock()
            alternate = not alternate
            local color = alternate and Color3.new(0, 0, 0) or Color3.new(0, 1, 0)
            local businessName = businessNames[math.random(1, #businessNames)]
            fireRemote("1RPHous1eEven1t", "BusinessName", businessName)
            fireRemote("1RPHous1eEven1tColo1r", "PickingBusinessNameColor", color)
        end))
    else
        clearConnection("hackedHouseText")
    end
end

local function removeHouseBans()
    local root = localRoot()
    if not root then return end
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant.Name == "BuyHouse" and descendant:IsA("ClickDetector") then
            local parent = descendant.Parent
            if parent and parent:IsA("BasePart") and (parent.Position - root.Position).Magnitude < 120 then
                fireclickdetector(descendant)
            end
        end
    end
end

local function garageLoop(enabled)
    flags.garageLoop = enabled
    if enabled then
        task.spawn(function()
            while flags.garageLoop do
                fireRemote("1Player1sHous1e", "GarageDoor")
                task.wait(7)
            end
        end)
    end
end

local function headSitLoop(enabled)
    flags.headSit = enabled
    if enabled then
        setConnection("headSit", RunService.Heartbeat:Connect(function()
            local root = localRoot()
            local humanoid = localHumanoid()
            local player = selectedPlayer()
            local head = player and player.Character and player.Character:FindFirstChild("Head")
            if root and humanoid and head then
                root.CFrame = head.CFrame * CFrame.new(0, 1.35, 0) * CFrame.Angles(0, math.rad(180), 0)
                humanoid.Sit = true
            end
        end))
    else
        clearConnection("headSit")
    end
end

local function applySignText()
    local tool = findTool("Sign") or equipTool("Sign")
    if not tool then return end
    local character = localCharacter()
    if character then tool.Parent = character end
    local ToolSound = tool:FindFirstChild("ToolSound", true)
    if ToolSound and ToolSound:IsA("RemoteEvent") then
        ToolSound:FireServer("Sign", "SignWords", signText)
    end
end

local function noclipLoop(enabled)
    flags.noclip = enabled
    if enabled then
        setConnection("noclip", RunService.Stepped:Connect(function()
            local character = localCharacter()
            if character then
                for _, descendant in ipairs(character:GetDescendants()) do
                    if descendant:IsA("BasePart") then descendant.CanCollide = false end
                end
            end
        end))
    else
        clearConnection("noclip")
    end
end

local function copyAvatar()
    local target = resolvePlayer(selectedAvatarName)
    local targetHumanoid = playerHumanoid(target)
    if not target or not targetHumanoid then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    local description = targetHumanoid:GetAppliedDescription()
    local wear = remotes:FindFirstChild("Wear")
    if wear then
        for _, accessory in ipairs(description:GetAccessories(true)) do
            if accessory.AssetId and tonumber(accessory.AssetId) then wear:InvokeServer(tonumber(accessory.AssetId)) end
        end
        for _, field in ipairs({ "Shirt", "Pants", "Face" }) do
            local asset = tonumber(description[field])
            if asset then wear:InvokeServer(asset) end
        end
    end
    local body = remotes:FindFirstChild("ChangeCharacterBody")
    if body then
        body:InvokeServer({ description.Torso, description.RightArm, description.LeftArm, description.RightLeg, description.LeftLeg, description.Head })
    end
    local colors = target.Character and target.Character:FindFirstChild("Body Colors")
    local changeColor = remotes:FindFirstChild("ChangeBodyColor")
    if colors and changeColor then changeColor:FireServer(tostring(colors.HeadColor)) end
    local bag = target:FindFirstChild("PlayersBag")
    local rpText = remotes:FindFirstChild("RPNameText")
    local rpColor = remotes:FindFirstChild("RPNameColor")
    if bag and rpText then
        local name = bag:FindFirstChild("RPName")
        local bio = bag:FindFirstChild("RPBio")
        if name and name.Value ~= "" then rpText:FireServer("RolePlayName", name.Value) end
        if bio and bio.Value ~= "" then rpText:FireServer("RolePlayBio", bio.Value) end
    end
    if bag and rpColor then
        local nameColor = bag:FindFirstChild("RPNameColor")
        local bioColor = bag:FindFirstChild("RPBioColor")
        if nameColor then rpColor:FireServer("PickingRPNameColor", nameColor.Value) end
        if bioColor then rpColor:FireServer("PickingRPBioColor", bioColor.Value) end
    end
end

local function playSound(soundId, looped)
    if not soundId or tostring(soundId) == "" then return nil end
    local normalized = tostring(soundId):gsub("rbxassetid://", "")
    local sound = Instance.new("Sound")
    sound.Name = "SlayerHubSound"
    sound.SoundId = "rbxassetid://" .. normalized
    sound.Volume = 3
    sound.Looped = looped == true
    sound.Parent = Workspace
    sound:Play()
    if not sound.Looped then
        sound.Ended:Connect(function() sound:Destroy() end)
    end
    return sound
end

local function stopSounds()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Sound") and child.Name == "SlayerHubSound" then child:Destroy() end
    end
end

local function playGlobalSound()
    return playSound(audioAllId ~= "" and audioAllId or selectedSoundId, false)
end

local function loopGlobalSound(enabled)
    flags.loopGlobalSound = enabled
    if enabled then
        task.spawn(function()
            while flags.loopGlobalSound do
                playGlobalSound()
                task.wait(3)
            end
        end)
    end
end

local function playSelectedSound()
    playSound(selectedSoundId or audioId, false)
end

local function loopSelectedSound(enabled)
    flags.loopSelectedSound = enabled
    if enabled then
        task.spawn(function()
            while flags.loopSelectedSound do
                playSound(selectedSoundId or audioId, false)
                task.wait(3)
            end
        end)
    end
end

local function teleportSelected()
    local root = localRoot()
    local targetRoot = playerRoot(selectedPlayer())
    if root and targetRoot then root.CFrame = targetRoot.CFrame end
end

local function loopTpSelected(enabled)
    flags.loopTp = enabled
    if enabled then
        setConnection("loopTp", RunService.Heartbeat:Connect(teleportSelected))
    else
        clearConnection("loopTp")
    end
end

local function couchMethodOneLoop(enabled)
    flags.couchMethodOne = enabled
    if enabled then
        task.spawn(function()
            while flags.couchMethodOne do
                couchFlingPlayer(selectedPlayer(), 1.2, 350000000)
                task.wait(0.15)
            end
        end)
    end
end

local function couchLoop(enabled)
    flags.couchLoop = enabled
    if enabled then
        task.spawn(function()
            while flags.couchLoop do
                couchFlingPlayer(selectedPlayer(), 1.5, 600000000)
                task.wait(0.1)
            end
        end)
    end
end

local function couchFastLoop(enabled)
    flags.couchFast = enabled
    if enabled then
        task.spawn(function()
            while flags.couchFast do
                couchFlingPlayer(selectedPlayer(), 0.75, 900000000)
                task.wait(0.05)
            end
        end)
    end
end

local function flingDoors()
    local target = selectedPlayer()
    local targetRoot = playerRoot(target)
    if not targetRoot then return end
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name:find("Door") and not descendant.Anchored then
            descendant.AssemblyLinearVelocity = (targetRoot.Position - descendant.Position).Unit * 300
        end
    end
end

local function flingBallCar()
    local target = selectedPlayer()
    if target then
        flingBallPlayer(target)
        flingWithVehicle(target, "Bus", 3200)
    end
end

local function carBring()
    local target = selectedPlayer()
    local vehicle = spawnCar("SchoolBus")
    moveVehicleToPlayer(vehicle, target, CFrame.new(0, 0, -2))
end

local function carKill()
    flingWithVehicle(selectedPlayer(), "Bus", 4200)
end

local function flingBoat()
    flingBoatPlayer(selectedPlayer())
end

local function flingBoatV2()
    local target = selectedPlayer()
    local vehicle = spawnBoat()
    local part = vehicleRoot(vehicle)
    local targetRoot = playerRoot(target)
    if not part or not targetRoot then return end
    local angular = Instance.new("BodyAngularVelocity")
    angular.Name = "SlayerBoatSpin"
    angular.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    angular.AngularVelocity = Vector3.new(0, 5000, 0)
    angular.Parent = part
    local started = os.clock()
    while os.clock() - started < 1.7 and targetRoot.Parent do
        part.CFrame = targetRoot.CFrame
        task.wait()
    end
    angular:Destroy()
end

local function glitchCouchAllPlayers(enabled)
    flags.glitchCouchAll = enabled
    if enabled then
        task.spawn(function()
            forEveryOtherPlayer(function(player)
                if flags.glitchCouchAll then couchFlingPlayer(player, 1.1, 900000000) end
            end)
            flags.glitchCouchAll = false
        end)
    end
end

local function couchSuperFastAllPlayers(enabled)
    flags.couchSuperFastAll = enabled
    if enabled then
        task.spawn(function()
            forEveryOtherPlayer(function(player)
                if flags.couchSuperFastAll then couchFlingPlayer(player, 0.55, 900000000) end
            end)
            flags.couchSuperFastAll = false
        end)
    end
end

local function canoeAllPlayers(enabled)
    flags.canoeAll = enabled
    if enabled then
        task.spawn(function()
            forEveryOtherPlayer(function(player)
                if flags.canoeAll then flingCanoePlayer(player) end
            end)
            flags.canoeAll = false
        end)
    end
end

local function boatAllPlayers(enabled)
    flags.boatAll = enabled
    if enabled then
        task.spawn(function()
            forEveryOtherPlayer(function(player)
                if flags.boatAll then flingBoatPlayer(player) end
            end)
            flags.boatAll = false
        end)
    end
end

local function boatV2AllPlayers(enabled)
    flags.boatV2All = enabled
    if enabled then
        task.spawn(function()
            forEveryOtherPlayer(function(player)
                if flags.boatV2All then
                    selectedPlayerName = player.Name
                    flingBoatV2()
                end
            end)
            flags.boatV2All = false
        end)
    end
end

local function fatalFlingLoop(enabled)
    flags.fatalFling = enabled
    if enabled then
        task.spawn(function()
            while flags.fatalFling do
                couchFlingPlayer(selectedPlayer(), 2.2, 900000000)
                task.wait(0.05)
            end
        end)
    end
end

local function autoFlingVelocityLoop(enabled)
    flags.autoFlingVelocity = enabled
    if enabled then
        task.spawn(function()
            while flags.autoFlingVelocity do
                local root = localRoot()
                local target = selectedPlayer()
                local targetRoot = playerRoot(target)
                if root and targetRoot then
                    local BodyVelocity = root:FindFirstChild("SlayerAutoFlingVelocity")
                    if not BodyVelocity then
                        BodyVelocity = Instance.new("BodyVelocity")
                        BodyVelocity.Name = "SlayerAutoFlingVelocity"
                        BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        BodyVelocity.Parent = root
                    end
                    BodyVelocity.Velocity = Vector3.new(900000000, 900000000, 900000000)
                    root.CFrame = targetRoot.CFrame * CFrame.new(0, 0.5, 0)
                end
                task.wait()
            end
            local root = localRoot()
            local mover = root and root:FindFirstChild("SlayerAutoFlingVelocity")
            if mover then mover:Destroy() end
        end)
    end
end

local function autoFlingVehicleLoop(enabled)
    flags.autoFlingVehicle = enabled
    if enabled then
        task.spawn(function()
            while flags.autoFlingVehicle do
                local target = selectedPlayer()
                if target then
                    if selectedMethod == "Couch" then
                        couchFlingPlayer(target, 0.9, 900000000)
                    else
                        flingWithVehicle(target, selectedMethod == "Boat" and "Boat" or "SchoolBus", 4200)
                    end
                end
                task.wait(0.2)
            end
        end)
    end
end

local function couchMethodTwoLoop(enabled)
    flags.couchMethodTwo = enabled
    if enabled then
        task.spawn(function()
            while flags.couchMethodTwo do
                couchFlingPlayer(selectedPlayer(), 1.8, 900000000)
                task.wait(0.08)
            end
        end)
    end
end

local function glitchCouchSelected()
    couchFlingPlayer(selectedPlayer(), 3, 900000000)
end

local function startFlingBoat()
    local vehicle = spawnBoat()
    local part = vehicleRoot(vehicle)
    if not part then return end
    local angular = Instance.new("BodyAngularVelocity")
    angular.Name = "SlayerBoatSpin"
    angular.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    angular.AngularVelocity = Vector3.new(0, 5000, 0)
    angular.Parent = part
end

local function stopFlingBoat()
    local root = localRoot()
    if root then
        for _, mover in ipairs(root:GetChildren()) do
            if mover:IsA("BodyAngularVelocity") or mover:IsA("BodyVelocity") then mover:Destroy() end
        end
    end
    local vehicle = findOwnedVehicle()
    local part = vehicleRoot(vehicle)
    if part then
        for _, mover in ipairs(part:GetChildren()) do
            if mover:IsA("BodyAngularVelocity") or mover:IsA("BodyVelocity") then mover:Destroy() end
        end
    end
    deleteVehicles()
end

local function clickFlingDoors()
    local mouse = LocalPlayer:GetMouse()
    local target = mouse.Target
    if not target then return end
    local door = target
    while door and door ~= Workspace and not door.Name:find("Door") do door = door.Parent end
    if not door or door == Workspace then return end
    local part = door:IsA("BasePart") and door or door:FindFirstChildWhichIsA("BasePart", true)
    local root = localRoot()
    if not part or not root or part.Anchored then return end
    local attachment = Instance.new("Attachment")
    attachment.Name = "Luscaa_Attached"
    attachment.Parent = part
    local align = Instance.new("AlignPosition")
    align.Name = "SlayerDoorAlignPosition"
    align.Attachment0 = attachment
    align.MaxForce = math.huge
    align.MaxVelocity = math.huge
    align.Position = root.Position
    align.Parent = part
    task.delay(2, function()
        if align.Parent then align:Destroy() end
        if attachment.Parent then attachment:Destroy() end
    end)
end

local function clickFlingBall()
    local mouse = LocalPlayer:GetMouse()
    local part = mouse.Target
    if not part or not part:IsA("BasePart") or part.Anchored then return end
    local direction = mouse.Hit.Position - part.Position
    if direction.Magnitude == 0 then direction = Vector3.new(0, 1, 0) end
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "SlayerClickBallVelocity"
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = direction.Unit * 5000
    velocity.Parent = part
    task.delay(1, function() if velocity.Parent then velocity:Destroy() end end)
end

local function killAllBus()
    task.spawn(function()
        forEveryOtherPlayer(function(player) flingWithVehicle(player, "SchoolBus", 5000) end)
        deleteVehicles()
    end)
end

local function banPlayerFromHouse(player)
    local character = player and player.Character
    if not player or not character then return end
    fireRemote("1Playe1rTrigge1rEven1t", "BanPlayerFromHouse", player, character)
end

local function houseBanKillSelected()
    local player = selectedPlayer()
    if not player then return end
    fireRemote("1Gettin1gHous1e", "PickingCustomHouse", "049_House")
    task.wait(0.25)
    banPlayerFromHouse(player)
end

local function houseBanKillAll()
    fireRemote("1Gettin1gHous1e", "PickingCustomHouse", "049_House")
    task.wait(0.25)
    local root = localRoot()
    if not root then return end
    local region = Region3.new(root.Position - Vector3.new(30, 30, 30), root.Position + Vector3.new(30, 30, 30))
    for _, part in ipairs(Workspace:FindPartsInRegion3(region, localCharacter(), 100)) do
        if part.Name == "HumanoidRootPart" and part.Parent then
            local player = Players:FindFirstChild(part.Parent.Name)
            if player and player ~= LocalPlayer then
                fireRemote("1Playe1rTrigge1rEven1t", "BanPlayerFromHouse", player, part.Parent)
            end
        end
    end
end

local function flingBoatAll()
    task.spawn(function() forEveryOtherPlayer(flingBoatPlayer) end)
end

local function autoFlingAll()
    task.spawn(function() forEveryOtherPlayer(function(player) dispatchFling(player, selectedMethod) end) end)
end

local function flingBallAll()
    task.spawn(function() forEveryOtherPlayer(flingBallPlayer) end)
end

local function applyVehicleSetting(setting, value)
    local numericValue = tonumber(value)
    if not numericValue then return end
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then return end
    for _, vehicle in ipairs(vehicles:GetChildren()) do
        local seats = vehicle:FindFirstChild("Seats")
        local seat = seats and seats:FindFirstChild("VehicleSeat")
        if seat then
            local child = seat:FindFirstChild(setting)
            if child then
                child.Value = numericValue
            else
                pcall(function()
                    seat[setting] = numericValue
                end)
            end
        end
    end
end

local function applySpeed()
    applyVehicleSetting("MaxSpeed", carSpeed)
end

local function applyTurbo()
    applyVehicleSetting("Turbo", carTurbo)
end

local function rejoinServer()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

local SOUND_LIBRARY = {
    { Name = "Trollface laugh", Id = "73753120048787" },
    { Name = "troll face sussy", Id = "9098738774" },
    { Name = "troll cut", Id = "8389041427" },
    { Name = "troll transition", Id = "7705506391" },
    { Name = "troll laugh", Id = "7816195044" },
    { Name = "Magic2", Id = "9066733515" },
    { Name = "homero brasileo", Id = "115224076671067" },
    { Name = "LOUD Youve been trolled", Id = "6787686247" },
    { Name = "Fart Meme Sound", Id = "6454805792" },
    { Name = "Metal Rattle 2 SFX", Id = "9116788555" },
    { Name = "Hentai wiaaaaan", Id = "88332347208779" },
    { Name = "iamete cunasai", Id = "108494476595033" },
    { Name = "dodichan onnn...", Id = "134640594695384" },
    { Name = "Toma jack", Id = "132603645477541" },
    { Name = "Toma jackV2", Id = "100446887985203" },
    { Name = "Toma jack no sol quente", Id = "97476487963273" },
    { Name = "ifood", Id = "133843750864059" },
    { Name = "pelo geito ela ta querendo ram", Id = "94395705857835" },
    { Name = "lula vai todo mundo", Id = "136804576009416" },
    { Name = "coringa", Id = "84663543883498" },
    { Name = "shoope", Id = "8747441609" },
    { Name = "quenojo", Id = "103440368630269" },
    { Name = "sai dai lava prato", Id = "101232400175829" },
    { Name = "se e loko numconpeça", Id = "78442476709262" },
    { Name = "mita sequer que eu too uma", Id = "94889439372168" },
    { Name = "Hoje vou ser tua mulher e tu", Id = "90844637105538" },
    { Name = "Deita aqui eu mandei vc deitar sirens", Id = "100291188941582" },
    { Name = "miau", Id = "131804436682424" },
    { Name = "skibidi", Id = "128771670035179" },
    { Name = "BIRULEIBI", Id = "121569761604968" },
    { Name = "sai", Id = "121169949217007" },
    { Name = "risada boa dms", Id = "127589011971759" },
    { Name = "vacilo perna de pau", Id = "106809680656199" },
    { Name = "gomo gomo no!!!", Id = "137067472449625" },
    { Name = "arroto", Id = "140203378050178" },
    { Name = "iraaaa", Id = "136752451575091" },
    { Name = "não fica se achando muito não", Id = "101588606280167" },
    { Name = "WhatsApp notificação", Id = "107004225739474" },
    { Name = "Samsung", Id = "123767635061073" },
    { Name = "Shiiii", Id = "120566727202986" },
    { Name = "ai_tomaa miku", Id = "139770074770361" },
    { Name = "kuru_kuru", Id = "122465710753374" },
    { Name = "PM ROCAM", Id = "96161547081609" },
    { Name = "cavalo!!", Id = "78871573440184" },
    { Name = "deixa os garoto brinca", Id = "80291355054807" },
    { Name = "flamengo", Id = "137774355552052" },
    { Name = "sai do mei satnas", Id = "127944706557246" },
    { Name = "namoral agora e a hora", Id = "120677947987369" },
    { Name = "n pode me chutar pq seu celebro e burro", Id = "82284055473737" },
    { Name = "vc ta fudido vou te pegar", Id = "120214772725166" },
    { Name = "deley", Id = "102906880476838" },
    { Name = "Tu e um beta", Id = "130233956349541" },
    { Name = "Porfavor n tira eu nao", Id = "85321374020324" },
    { Name = "Discord sus", Id = "122662798976905" },
    { Name = "rojao apito", Id = "6549021381" },
    { Name = "off", Id = "1778829098" },
    { Name = "Kazuma kazuma", Id = "127954653962405" },
    { Name = "sometourado", Id = "123592956882621" },
    { Name = "Estouradoespad", Id = "136179020015211" },
    { Name = "Alaku bommm", Id = "110796593805268" },
    { Name = "busss", Id = "139841197791567" },
    { Name = "Estourado wItb", Id = "137478052262430" },
    { Name = "sla", Id = "116672405522828" },
    { Name = "HA HA HA", Id = "138236682866721" },
}
local soundByName = {}
local soundNames = {}
for _, entry in ipairs(SOUND_LIBRARY) do
    soundByName[entry.Name] = entry.Id
    table.insert(soundNames, entry.Name)
end

local tabs = {}
tabs.Informations = Window:MakeTab({ "Informations", "info", Name = "Informations", Title = "Informations", Icon = "info" })
tabs.Rgbs = Window:MakeTab({ "Rgbs", "brush", Name = "Rgbs", Title = "Rgbs", Icon = "brush" })
tabs.Itens = Window:MakeTab({ "Itens", "swords", Name = "Itens", Title = "Itens", Icon = "swords" })
tabs.Vehicles_and_House = Window:MakeTab({ "Vehicles and House", "home", Name = "Vehicles and House", Title = "Vehicles and House", Icon = "home" })
tabs.Fun = Window:MakeTab({ "Fun", "fun", Name = "Fun", Title = "Fun", Icon = "fun" })
tabs.Avatar = Window:MakeTab({ "Avatar", "rbxassetid://10734952036", Name = "Avatar", Title = "Avatar", Icon = "rbxassetid://10734952036" })
tabs.Sound_All = Window:MakeTab({ "Sound All", "box", Name = "Sound All", Title = "Sound All", Icon = "box" })
tabs.Music = Window:MakeTab({ "Music", "music", Name = "Music", Title = "Music", Icon = "music" })
tabs.Troll_PLayers = Window:MakeTab({ "Troll PLayers", "rbxassetid://17718995610", Name = "Troll PLayers", Title = "Troll PLayers", Icon = "rbxassetid://17718995610" })
tabs.Scripts = Window:MakeTab({ "Scripts", "codesandbox", Name = "Scripts", Title = "Scripts", Icon = "codesandbox" })
tabs.Protections = Window:MakeTab({ "Protections", "shield", Name = "Protections", Title = "Protections", Icon = "shield" })

tabs.Informations:AddSection({ Name = "Internet Things" })
tabs.Informations:AddDiscordInvite({ Name = "Slayer Hub", Description = "Compre seu painel admin abaixo", Logo = "rbxassetid://103236620685520", Invite = "https://discord.gg/PdfP96QBHd" })
tabs.Informations:AddSection({ Name = "Credits" })
tabs.Informations:AddParagraph({ "Owners", "Slayer and Beca", Name = "Owners", Description = "Slayer and Beca" })
tabs.Informations:AddParagraph({ "Programmer", "Bazuka and CatDev", Name = "Programmer", Description = "Bazuka and CatDev" })
tabs.Informations:AddParagraph({ "Library Owner:", "My Brother CatDev", Name = "Library Owner:", Description = "My Brother CatDev" })
local usageTimeParagraph = tabs.Informations:AddParagraph({ "Script Usage Time:", "00:00:00", Name = "Script Usage Time:", Description = "00:00:00" })
local startedAt = os.clock()
task.spawn(function()
    while task.wait(1) do
        local elapsed = math.floor(os.clock() - startedAt)
        local text = string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
        usageTimeParagraph:Set({ "Script Usage Time:", text, Name = "Script Usage Time:", Description = text })
    end
end)

tabs.Fun:AddSection({ Name = "Placa" })
tabs.Fun:AddTextBox({ Name = "Texto", Title = "Texto", PlaceholderText = "Texto da placa", Placeholder = "Texto da placa", Callback = function(value) signText = tostring(value or "") end })
tabs.Sound_All:AddTextBox({ Name = "Insira o ID Audio All", Title = "Insira o ID Audio All", Description = "Digite o ID do som que deseja tocar globalmente", PlaceholderText = "Exemplo: 1234567890", Callback = function(value) audioAllId = tostring(value or "") end })
tabs.Music:AddTextBox({ Name = "ID da música", Title = "ID da música", PlaceholderText = "Digite o ID e pressione Enter", Callback = function(value) audioId = tostring(value or "") end })
tabs.Vehicles_and_House:AddTextBox({ Name = "Car Speed", Title = "Car Speed", Placeholder = "Example: 300", Callback = function(value) carSpeed = tonumber(value) or carSpeed end })
tabs.Vehicles_and_House:AddTextBox({ Name = "Turbo Power", Title = "Turbo Power", Placeholder = "Example: 15", Callback = function(value) carTurbo = tonumber(value) or carTurbo end })

tabs.Itens:AddButton({ Name = "Planador", Callback = function() giveTool("Glider") end })
tabs.Itens:AddButton({ Name = "Canhão", Callback = function() giveTool("Cannon") end })
tabs.Itens:AddButton({ Name = "ain neymar", Callback = function() giveTool("") end })
tabs.Itens:AddButton({ Name = "Bola de Basquete Dourada", Callback = function() giveTool("GoldenBasketball") end })
tabs.Itens:AddButton({ Name = "Balão de Água", Callback = function() fireRemote("1Playe1rTrigge1rEven1t", "AcceptedToolToServer", "Water Balloon", LocalPlayer) end })
tabs.Itens:AddButton({ Name = "Lançador de Ovo", Callback = function() giveTool("EggLauncher") end })
tabs.Itens:AddButton({ Name = "Cristal Verde", Callback = function() giveTool("UraniumRod") end })
tabs.Itens:AddButton({ Name = "Serra Elétrica", Callback = function() giveTool("Chainsaw") end })
tabs.Itens:AddButton({ Name = "Ski", Callback = function() giveTool("Skis") end })
tabs.Itens:AddButton({ Name = "Money Gun", Callback = function() giveTool("MoneyGun") end })
tabs.Itens:AddButton({ Name = "Snowboard", Callback = function() giveTool("Snowboard") end })
local musicCategoryMaps = {}
local musicCategoryOptions = {}
local function playMusicId(soundId)
    audioId = tostring(soundId or "")
    if audioId ~= "" then playSound(audioId, false) end
end
musicCategoryMaps["Forro e Sertanejo"] = {}
musicCategoryOptions["Forro e Sertanejo"] = {}
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro mt bom")
musicCategoryMaps["Forro e Sertanejo"]["forro mt bom"] = "106412079335663"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "ele tá no meu lugar mais nunca vai ser eu")
musicCategoryMaps["Forro e Sertanejo"]["ele tá no meu lugar mais nunca vai ser eu"] = "122871200237533"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "saudade bate")
musicCategoryMaps["Forro e Sertanejo"]["saudade bate"] = "139777248916220"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Notificacao perdida")
musicCategoryMaps["Forro e Sertanejo"]["Notificacao perdida"] = "90137280531474"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "lembranças")
musicCategoryMaps["Forro e Sertanejo"]["lembranças"] = "111551362636063"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Passinho do barão")
musicCategoryMaps["Forro e Sertanejo"]["Passinho do barão"] = "127786586963377"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Bloquinho Macumbeira")
musicCategoryMaps["Forro e Sertanejo"]["Bloquinho Macumbeira"] = "138345050819224"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "eu já tava bem")
musicCategoryMaps["Forro e Sertanejo"]["eu já tava bem"] = "93590122047380"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "PISEIRO ESTOURADO (20 sgds de intro)")
musicCategoryMaps["Forro e Sertanejo"]["PISEIRO ESTOURADO (20 sgds de intro)"] = "133190351316780"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro ja cansou")
musicCategoryMaps["Forro e Sertanejo"]["forro ja cansou"] = "74812784884330"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "GRELO E O FE")
musicCategoryMaps["Forro e Sertanejo"]["GRELO E O FE"] = "72200166265935"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "lenbro ate hoje")
musicCategoryMaps["Forro e Sertanejo"]["lenbro ate hoje"] = "71531533552899"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "escolha certa")
musicCategoryMaps["Forro e Sertanejo"]["escolha certa"] = "107088620814881"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro da rezenha")
musicCategoryMaps["Forro e Sertanejo"]["forro da rezenha"] = "120973520531216"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro dudu")
musicCategoryMaps["Forro e Sertanejo"]["forro dudu"] = "74404168179733"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro sao joao")
musicCategoryMaps["Forro e Sertanejo"]["forro sao joao"] = "106364874935196"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "forro engraçado paia")
musicCategoryMaps["Forro e Sertanejo"]["forro engraçado paia"] = "76524290482399"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "100% forro vaquejada")
musicCategoryMaps["Forro e Sertanejo"]["100% forro vaquejada"] = "92295159623916"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "PASTOR MIRIM E A LÍNGUA DOS ANJOS")
musicCategoryMaps["Forro e Sertanejo"]["PASTOR MIRIM E A LÍNGUA DOS ANJOS"] = "71153532555470"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "PARA NÃO ESQUECER QUEM SOMOS")
musicCategoryMaps["Forro e Sertanejo"]["PARA NÃO ESQUECER QUEM SOMOS"] = "88937498361674"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Uno zero")
musicCategoryMaps["Forro e Sertanejo"]["Uno zero"] = "112959083808887"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Iate do neymar")
musicCategoryMaps["Forro e Sertanejo"]["Iate do neymar"] = "135738534706063"
table.insert(musicCategoryOptions["Forro e Sertanejo"], "Batidao na aldeia")
musicCategoryMaps["Forro e Sertanejo"]["Batidao na aldeia"] = "79953696595578"
tabs.Music:AddDropdown({ Name = "Forro e Sertanejo", Options = musicCategoryOptions["Forro e Sertanejo"], Default = "Option 1", Callback = function(value) playMusicId(musicCategoryMaps["Forro e Sertanejo"][value]) end })
musicCategoryMaps["Trap"] = {}
musicCategoryOptions["Trap"] = {}
table.insert(musicCategoryOptions["Trap"], "Fumadouro Freestyle (Igorivooz)")
musicCategoryMaps["Trap"]["Fumadouro Freestyle (Igorivooz)"] = "138361625716987"
table.insert(musicCategoryOptions["Trap"], "BROCASITO - FUCK12FUCK17 (IgorIvooz)")
musicCategoryMaps["Trap"]["BROCASITO - FUCK12FUCK17 (IgorIvooz)"] = "73198805524530"
table.insert(musicCategoryOptions["Trap"], "nn sei")
musicCategoryMaps["Trap"]["nn sei"] = "107542190375511"
table.insert(musicCategoryOptions["Trap"], "two")
musicCategoryMaps["Trap"]["two"] = "111097146869502"
table.insert(musicCategoryOptions["Trap"], "medo de morrer em fita errada")
musicCategoryMaps["Trap"]["medo de morrer em fita errada"] = "79536863156529"
table.insert(musicCategoryOptions["Trap"], "savage")
musicCategoryMaps["Trap"]["savage"] = "82468394109989"
table.insert(musicCategoryOptions["Trap"], "oi")
musicCategoryMaps["Trap"]["oi"] = "121237528060775"
table.insert(musicCategoryOptions["Trap"], "brank")
musicCategoryMaps["Trap"]["brank"] = "125693967623045"
table.insert(musicCategoryOptions["Trap"], "lilze")
musicCategoryMaps["Trap"]["lilze"] = "140472521093719"
table.insert(musicCategoryOptions["Trap"], "shot")
musicCategoryMaps["Trap"]["shot"] = "113854156533841"
table.insert(musicCategoryOptions["Trap"], "myxp")
musicCategoryMaps["Trap"]["myxp"] = "120892610283928"
table.insert(musicCategoryOptions["Trap"], "Role de Gang Ft. Flacko/parte do flacko (IgorIvooz)")
musicCategoryMaps["Trap"]["Role de Gang Ft. Flacko/parte do flacko (IgorIvooz)"] = "136492273841253"
table.insert(musicCategoryOptions["Trap"], "Borges - PROIBIDÃO 2020 (IgorIvooz)")
musicCategoryMaps["Trap"]["Borges - PROIBIDÃO 2020 (IgorIvooz)"] = "119825256314153"
table.insert(musicCategoryOptions["Trap"], "Yung nobre - Chicago (IgorIvooz)")
musicCategoryMaps["Trap"]["Yung nobre - Chicago (IgorIvooz)"] = "72565881952543"
table.insert(musicCategoryOptions["Trap"], "Thoney - Kunk de 50 (IgorIvooz)")
musicCategoryMaps["Trap"]["Thoney - Kunk de 50 (IgorIvooz)"] = "129787180541266"
table.insert(musicCategoryOptions["Trap"], "FLACKO - BACKSTAGE (IgorIvooz)")
musicCategoryMaps["Trap"]["FLACKO - BACKSTAGE (IgorIvooz)"] = "133348867136414"
table.insert(musicCategoryOptions["Trap"], "Fire2000 (igorIvooz)")
musicCategoryMaps["Trap"]["Fire2000 (igorIvooz)"] = "92403543810906"
table.insert(musicCategoryOptions["Trap"], "balão gang (IgorIvooz)")
musicCategoryMaps["Trap"]["balão gang (IgorIvooz)"] = "112485922236528"
table.insert(musicCategoryOptions["Trap"], "Borges - Iphone Branco (IgorIvooz)")
musicCategoryMaps["Trap"]["Borges - Iphone Branco (IgorIvooz)"] = "103288558732219"
table.insert(musicCategoryOptions["Trap"], "Yung Nobre - R-Baby & R15 (IgorIvooz)")
musicCategoryMaps["Trap"]["Yung Nobre - R-Baby & R15 (IgorIvooz)"] = "111956898780672"
table.insert(musicCategoryOptions["Trap"], "Borges - range rover (IgorIvooz)")
musicCategoryMaps["Trap"]["Borges - range rover (IgorIvooz)"] = "140290669622809"
table.insert(musicCategoryOptions["Trap"], "Yung Nobre - Rip Fredo Santana (IgorIvooz)")
musicCategoryMaps["Trap"]["Yung Nobre - Rip Fredo Santana (IgorIvooz)"] = "82533576915716"
table.insert(musicCategoryOptions["Trap"], "Brocasito - Pimp Talk (IgorIvooz)")
musicCategoryMaps["Trap"]["Brocasito - Pimp Talk (IgorIvooz)"] = "133029122379275"
table.insert(musicCategoryOptions["Trap"], "boate azul (IgorIvooz)")
musicCategoryMaps["Trap"]["boate azul (IgorIvooz)"] = "106412079335663"
table.insert(musicCategoryOptions["Trap"], "Matuê - Cogulândia")
musicCategoryMaps["Trap"]["Matuê - Cogulândia"] = "113043854379729"
tabs.Music:AddDropdown({ Name = "Trap", Options = musicCategoryOptions["Trap"], Default = "Option 1", Callback = function(value) playMusicId(musicCategoryMaps["Trap"][value]) end })
musicCategoryMaps["Musicas e Memes Aleatorio"] = {}
musicCategoryOptions["Musicas e Memes Aleatorio"] = {}
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "desca dai seu corno")
musicCategoryMaps["Musicas e Memes Aleatorio"]["desca dai seu corno"] = "119738878921996"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "GTA ESTOURADO")
musicCategoryMaps["Musicas e Memes Aleatorio"]["GTA ESTOURADO"] = "109337680029292"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "ANXIETY (Amapiano Re-fix)")
musicCategoryMaps["Musicas e Memes Aleatorio"]["ANXIETY (Amapiano Re-fix)"] = "101483901475189"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Meu corpo, minhas regras")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Meu corpo, minhas regras"] = "127587901595282"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Megalovania but its only the melodies")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Megalovania but its only the melodies"] = "104500091160463"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "androphono strikes back")
musicCategoryMaps["Musicas e Memes Aleatorio"]["androphono strikes back"] = "78312089943968"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Bamm Bamm")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Bamm Bamm"] = "128730685516895"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "longe de mais")
musicCategoryMaps["Musicas e Memes Aleatorio"]["longe de mais"] = "124478512057763"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Garoto de Copacabana")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Garoto de Copacabana"] = "135648634110254"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "CELL!")
musicCategoryMaps["Musicas e Memes Aleatorio"]["CELL!"] = "117634275895085"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Boa vibe em Ubatuba")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Boa vibe em Ubatuba"] = "139059061493558"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "SLIP AWAY")
musicCategoryMaps["Musicas e Memes Aleatorio"]["SLIP AWAY"] = "126152928520174"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Alone in Motion")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Alone in Motion"] = "122379348696948"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Fade Away")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Fade Away"] = "81002139735874"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Wounds & Wishes")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Wounds & Wishes"] = "109347979566607"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Ascensão do Monarca")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Ascensão do Monarca"] = "101864243033211"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "carro do ovo")
musicCategoryMaps["Musicas e Memes Aleatorio"]["carro do ovo"] = "3148329638"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "ingles bus (fling ou kill bus)")
musicCategoryMaps["Musicas e Memes Aleatorio"]["ingles bus (fling ou kill bus)"] = "123268013026823"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "MIKU MIKU HATSUNE")
musicCategoryMaps["Musicas e Memes Aleatorio"]["MIKU MIKU HATSUNE"] = "112783541496955"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "Escalando a Seleção Brasileira para a Copa")
musicCategoryMaps["Musicas e Memes Aleatorio"]["Escalando a Seleção Brasileira para a Copa"] = "116546457407236"
table.insert(musicCategoryOptions["Musicas e Memes Aleatorio"], "id")
musicCategoryMaps["Musicas e Memes Aleatorio"]["id"] = "138361625716987"
tabs.Music:AddDropdown({ Name = "Musicas e Memes Aleatorio", Options = musicCategoryOptions["Musicas e Memes Aleatorio"], Default = "Option 1", Callback = function(value) playMusicId(musicCategoryMaps["Musicas e Memes Aleatorio"][value]) end })
musicCategoryMaps["Funk"] = {}
musicCategoryOptions["Funk"] = {}
table.insert(musicCategoryOptions["Funk"], "( nike )")
musicCategoryMaps["Funk"]["( nike )"] = "107416893652681"
table.insert(musicCategoryOptions["Funk"], "Terranova")
musicCategoryMaps["Funk"]["Terranova"] = "82746224492420"
table.insert(musicCategoryOptions["Funk"], "Jantar em Familia")
musicCategoryMaps["Funk"]["Jantar em Familia"] = "103043727188319"
table.insert(musicCategoryOptions["Funk"], "Uniao Flasco")
musicCategoryMaps["Funk"]["Uniao Flasco"] = "81628621752701"
table.insert(musicCategoryOptions["Funk"], "Ritmo de Quebrada")
musicCategoryMaps["Funk"]["Ritmo de Quebrada"] = "98405762839405"
table.insert(musicCategoryOptions["Funk"], "Fluxo da Tropa")
musicCategoryMaps["Funk"]["Fluxo da Tropa"] = "134059682734950"
table.insert(musicCategoryOptions["Funk"], "A Braba do Mago")
musicCategoryMaps["Funk"]["A Braba do Mago"] = "144567406839075"
table.insert(musicCategoryOptions["Funk"], "EU QUERO SER IGUAL O LÉO DA 17")
musicCategoryMaps["Funk"]["EU QUERO SER IGUAL O LÉO DA 17"] = "76728189899641"
table.insert(musicCategoryOptions["Funk"], "(Seu ex, ta nervoso de mais)")
musicCategoryMaps["Funk"]["(Seu ex, ta nervoso de mais)"] = "92999059792601"
table.insert(musicCategoryOptions["Funk"], "DJ KOALA6 - BOLINHA VERDE x BASE 9 x SUPIDO new jazz x funk")
musicCategoryMaps["Funk"]["DJ KOALA6 - BOLINHA VERDE x BASE 9 x SUPIDO new jazz x funk"] = "89980339864001"
table.insert(musicCategoryOptions["Funk"], "Quero saber a cor da sua c4lc1nh4")
musicCategoryMaps["Funk"]["Quero saber a cor da sua c4lc1nh4"] = "91138103156778"
table.insert(musicCategoryOptions["Funk"], "soca na danada")
musicCategoryMaps["Funk"]["soca na danada"] = "100337717591420"
table.insert(musicCategoryOptions["Funk"], "Tijolos XL 4")
musicCategoryMaps["Funk"]["Tijolos XL 4"] = "103715298147699"
table.insert(musicCategoryOptions["Funk"], "Os Menor são marolento")
musicCategoryMaps["Funk"]["Os Menor são marolento"] = "126719632721905"
table.insert(musicCategoryOptions["Funk"], "C WALK INTERLÚDIO X TAMBOR ERECA X AQUI NA CDD")
musicCategoryMaps["Funk"]["C WALK INTERLÚDIO X TAMBOR ERECA X AQUI NA CDD"] = "72451271928975"
table.insert(musicCategoryOptions["Funk"], "Mandela do Mago")
musicCategoryMaps["Funk"]["Mandela do Mago"] = "78159483726589"
table.insert(musicCategoryOptions["Funk"], "FININHO CLASSE A")
musicCategoryMaps["Funk"]["FININHO CLASSE A"] = "107481584214750"
table.insert(musicCategoryOptions["Funk"], "vai mamar o bonde")
musicCategoryMaps["Funk"]["vai mamar o bonde"] = "137888824649807"
table.insert(musicCategoryOptions["Funk"], "Insonia - Hungria")
musicCategoryMaps["Funk"]["Insonia - Hungria"] = "113039342592508"
table.insert(musicCategoryOptions["Funk"], "vermelho a Ferrari")
musicCategoryMaps["Funk"]["vermelho a Ferrari"] = "88094479399489"
table.insert(musicCategoryOptions["Funk"], "S")
musicCategoryMaps["Funk"]["S"] = "120513109445361"
table.insert(musicCategoryOptions["Funk"], "montagem verticional")
musicCategoryMaps["Funk"]["montagem verticional"] = "91374876039851"
table.insert(musicCategoryOptions["Funk"], "PIQUEZIN DO CARROSSEL")
musicCategoryMaps["Funk"]["PIQUEZIN DO CARROSSEL"] = "135638854748531"
table.insert(musicCategoryOptions["Funk"], "OLHA O")
musicCategoryMaps["Funk"]["OLHA O"] = "83097306124709"
table.insert(musicCategoryOptions["Funk"], "AUTOMOTIVO DE VERDADE")
musicCategoryMaps["Funk"]["AUTOMOTIVO DE VERDADE"] = "107362827741451"
table.insert(musicCategoryOptions["Funk"], "LIGOU NA MADRUGA")
musicCategoryMaps["Funk"]["LIGOU NA MADRUGA"] = "118906056296419"
table.insert(musicCategoryOptions["Funk"], "ONDA SUBAQUATICA 8 MONO")
musicCategoryMaps["Funk"]["ONDA SUBAQUATICA 8 MONO"] = "75422081790794"
table.insert(musicCategoryOptions["Funk"], "MC DAVI E DJ JOAO PEREIRA - HOJE EU ACORDEI COM O PÉ DIREITO")
musicCategoryMaps["Funk"]["MC DAVI E DJ JOAO PEREIRA - HOJE EU ACORDEI COM O PÉ DIREITO"] = "127870629973068"
table.insert(musicCategoryOptions["Funk"], "DJ KOALA6 - HOPE X HOJE É DIA DE FLA FLU")
musicCategoryMaps["Funk"]["DJ KOALA6 - HOPE X HOJE É DIA DE FLA FLU"] = "71395826563893"
table.insert(musicCategoryOptions["Funk"], "discord")
musicCategoryMaps["Funk"]["discord"] = "106285676892349"
table.insert(musicCategoryOptions["Funk"], "e os 01 vida")
musicCategoryMaps["Funk"]["e os 01 vida"] = "102365459820704"
table.insert(musicCategoryOptions["Funk"], "Gemidao sirene")
musicCategoryMaps["Funk"]["Gemidao sirene"] = "140228596635258"
table.insert(musicCategoryOptions["Funk"], "Bafora No Plugg")
musicCategoryMaps["Funk"]["Bafora No Plugg"] = "122367698779698"
table.insert(musicCategoryOptions["Funk"], "ANALONG FUNK")
musicCategoryMaps["Funk"]["ANALONG FUNK"] = "112214814544629"
table.insert(musicCategoryOptions["Funk"], "Ritmo do Mago")
musicCategoryMaps["Funk"]["Ritmo do Mago"] = "93704875691060"
table.insert(musicCategoryOptions["Funk"], "Eu vim na Captura")
musicCategoryMaps["Funk"]["Eu vim na Captura"] = "110126354319981"
table.insert(musicCategoryOptions["Funk"], "que que sharke")
musicCategoryMaps["Funk"]["que que sharke"] = "129546408528391"
table.insert(musicCategoryOptions["Funk"], "ENCOSTA A BUCTA NO AK")
musicCategoryMaps["Funk"]["ENCOSTA A BUCTA NO AK"] = "101222653992044"
table.insert(musicCategoryOptions["Funk"], "Maestros do Mandelão")
musicCategoryMaps["Funk"]["Maestros do Mandelão"] = "86162096510351"
table.insert(musicCategoryOptions["Funk"], "loucura que ela fez com migo")
musicCategoryMaps["Funk"]["loucura que ela fez com migo"] = "138830667342178"
table.insert(musicCategoryOptions["Funk"], "TUDO NA BOCA DA SUZY")
musicCategoryMaps["Funk"]["TUDO NA BOCA DA SUZY"] = "128417229744862"
table.insert(musicCategoryOptions["Funk"], "arabe funk")
musicCategoryMaps["Funk"]["arabe funk"] = "93451391025129"
table.insert(musicCategoryOptions["Funk"], "Pockt Renk")
musicCategoryMaps["Funk"]["Pockt Renk"] = "94600803570382"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "73987797951706"
table.insert(musicCategoryOptions["Funk"], "só mandelão original")
musicCategoryMaps["Funk"]["só mandelão original"] = "73174331998784"
table.insert(musicCategoryOptions["Funk"], "Multiplicou|")
musicCategoryMaps["Funk"]["Multiplicou|"] = "135750430892149"
table.insert(musicCategoryOptions["Funk"], "funk ritmada")
musicCategoryMaps["Funk"]["funk ritmada"] = "99857365723549"
table.insert(musicCategoryOptions["Funk"], "i can't handle change funk")
musicCategoryMaps["Funk"]["i can't handle change funk"] = "88743961684849"
table.insert(musicCategoryOptions["Funk"], "Supremo|")
musicCategoryMaps["Funk"]["Supremo|"] = "123295964560127"
table.insert(musicCategoryOptions["Funk"], "Quem mandou tu terminar?")
musicCategoryMaps["Funk"]["Quem mandou tu terminar?"] = "95013108971632"
table.insert(musicCategoryOptions["Funk"], "CANINHA SAFADO")
musicCategoryMaps["Funk"]["CANINHA SAFADO"] = "123509716049820"
table.insert(musicCategoryOptions["Funk"], "VEM")
musicCategoryMaps["Funk"]["VEM"] = "120892610283928"
table.insert(musicCategoryOptions["Funk"], "VEM SENTANDO")
musicCategoryMaps["Funk"]["VEM SENTANDO"] = "88342296270082"
table.insert(musicCategoryOptions["Funk"], "COM A TDK TU NAO VAI QUERER OUTRA VIDA")
musicCategoryMaps["Funk"]["COM A TDK TU NAO VAI QUERER OUTRA VIDA"] = "125109367810614"
table.insert(musicCategoryOptions["Funk"], "japa nk eu ja sei oq fazer")
musicCategoryMaps["Funk"]["japa nk eu ja sei oq fazer"] = "94090546957206"
table.insert(musicCategoryOptions["Funk"], "piranha vai passar mal")
musicCategoryMaps["Funk"]["piranha vai passar mal"] = "129902784040741"
table.insert(musicCategoryOptions["Funk"], "(Set - Do nada ela brota)")
musicCategoryMaps["Funk"]["(Set - Do nada ela brota)"] = "130806788012841"
table.insert(musicCategoryOptions["Funk"], "(menor do Pecece)")
musicCategoryMaps["Funk"]["(menor do Pecece)"] = "125516171040480"
table.insert(musicCategoryOptions["Funk"], "MTG CV")
musicCategoryMaps["Funk"]["MTG CV"] = "99971795276771"
table.insert(musicCategoryOptions["Funk"], "ESCUTA MEU SOM E SE CONCENTRA")
musicCategoryMaps["Funk"]["ESCUTA MEU SOM E SE CONCENTRA"] = "107027481244497"
table.insert(musicCategoryOptions["Funk"], "eu não sou gay")
musicCategoryMaps["Funk"]["eu não sou gay"] = "82816587043443"
table.insert(musicCategoryOptions["Funk"], "Yuzak e muito sagaz")
musicCategoryMaps["Funk"]["Yuzak e muito sagaz"] = "121833154300922"
table.insert(musicCategoryOptions["Funk"], "Na Casa de Praia")
musicCategoryMaps["Funk"]["Na Casa de Praia"] = "91134045725365"
table.insert(musicCategoryOptions["Funk"], "Passa a ba nele")
musicCategoryMaps["Funk"]["Passa a ba nele"] = "135084089965365"
table.insert(musicCategoryOptions["Funk"], "DEVAGARINHO")
musicCategoryMaps["Funk"]["DEVAGARINHO"] = "126682676484892"
table.insert(musicCategoryOptions["Funk"], "Batida do Tal Do Tbt")
musicCategoryMaps["Funk"]["Batida do Tal Do Tbt"] = "91007045451630"
table.insert(musicCategoryOptions["Funk"], "DJ KOALA6 - GRAVITY FALLS x QUEM MANDA É NÓS COMÉDIA")
musicCategoryMaps["Funk"]["DJ KOALA6 - GRAVITY FALLS x QUEM MANDA É NÓS COMÉDIA"] = "72398498657608"
table.insert(musicCategoryOptions["Funk"], "eu vou cuspir")
musicCategoryMaps["Funk"]["eu vou cuspir"] = "133208997220334"
table.insert(musicCategoryOptions["Funk"], "Baila na Quebrada")
musicCategoryMaps["Funk"]["Baila na Quebrada"] = "145068394058674"
table.insert(musicCategoryOptions["Funk"], "Mandelão Pesado")
musicCategoryMaps["Funk"]["Mandelão Pesado"] = "120495867493025"
table.insert(musicCategoryOptions["Funk"], "Mandela SP")
musicCategoryMaps["Funk"]["Mandela SP"] = "137970023957031"
table.insert(musicCategoryOptions["Funk"], "Piranha Piranha")
musicCategoryMaps["Funk"]["Piranha Piranha"] = "123238370098753"
table.insert(musicCategoryOptions["Funk"], "FALA QUE A TROPA E CV")
musicCategoryMaps["Funk"]["FALA QUE A TROPA E CV"] = "97244783527670"
table.insert(musicCategoryOptions["Funk"], "(Montagem passa alcool em gel)")
musicCategoryMaps["Funk"]["(Montagem passa alcool em gel)"] = "74660644507056"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM ELA SÓ TEM 15 ANOS  DJ MS")
musicCategoryMaps["Funk"]["MONTAGEM ELA SÓ TEM 15 ANOS  DJ MS"] = "72511079192065"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM - SET DO MC MN")
musicCategoryMaps["Funk"]["MONTAGEM - SET DO MC MN"] = "78631447496051"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "127060465281063"
table.insert(musicCategoryOptions["Funk"], "Tropa do Mago")
musicCategoryMaps["Funk"]["Tropa do Mago"] = "115049385764023"
table.insert(musicCategoryOptions["Funk"], "HOJE EU BROTEI NO BAILE DO SÃO JORGE")
musicCategoryMaps["Funk"]["HOJE EU BROTEI NO BAILE DO SÃO JORGE"] = "122650858043559"
table.insert(musicCategoryOptions["Funk"], "(Black Lança x Balinha pra essa garota)")
musicCategoryMaps["Funk"]["(Black Lança x Balinha pra essa garota)"] = "107230480488085"
table.insert(musicCategoryOptions["Funk"], "(Caveirão)")
musicCategoryMaps["Funk"]["(Caveirão)"] = "80004227292865"
table.insert(musicCategoryOptions["Funk"], "chairy")
musicCategoryMaps["Funk"]["chairy"] = "130071638363509"
table.insert(musicCategoryOptions["Funk"], "envolvidão (15 sgds de intro)")
musicCategoryMaps["Funk"]["envolvidão (15 sgds de intro)"] = "127775034804421"
table.insert(musicCategoryOptions["Funk"], "pena que acabou a gente")
musicCategoryMaps["Funk"]["pena que acabou a gente"] = "105322893381167"
table.insert(musicCategoryOptions["Funk"], "Eu de cabelo pretin")
musicCategoryMaps["Funk"]["Eu de cabelo pretin"] = "126125120004125"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM 2025")
musicCategoryMaps["Funk"]["MONTAGEM 2025"] = "138274205313969"
table.insert(musicCategoryOptions["Funk"], "DJ KOALA x GLOKK40SPAZ - I CHOSEE VIOLENCE/VEM PRO ABATE MEU AMOR x VAI MARIA FUZIL")
musicCategoryMaps["Funk"]["DJ KOALA x GLOKK40SPAZ - I CHOSEE VIOLENCE/VEM PRO ABATE MEU AMOR x VAI MARIA FUZIL"] = "104767744632555"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "106231505841465"
table.insert(musicCategoryOptions["Funk"], "Exe funk")
musicCategoryMaps["Funk"]["Exe funk"] = "131415306381990"
table.insert(musicCategoryOptions["Funk"], "meca")
musicCategoryMaps["Funk"]["meca"] = "108226178439659"
table.insert(musicCategoryOptions["Funk"], "BERIMBAU DA QUARENTENA 2 / ROCKET POCKET")
musicCategoryMaps["Funk"]["BERIMBAU DA QUARENTENA 2 / ROCKET POCKET"] = "139896225225059"
table.insert(musicCategoryOptions["Funk"], "RAIL GRIND ESTOURADOOO")
musicCategoryMaps["Funk"]["RAIL GRIND ESTOURADOOO"] = "135958179501280"
table.insert(musicCategoryOptions["Funk"], "COCOTA DO HELIPA - VEM PRO HELIPA VIRGEM")
musicCategoryMaps["Funk"]["COCOTA DO HELIPA - VEM PRO HELIPA VIRGEM"] = "130758596227702"
table.insert(musicCategoryOptions["Funk"], "e tudo aquilo que você trouxe")
musicCategoryMaps["Funk"]["e tudo aquilo que você trouxe"] = "82805460494325"
table.insert(musicCategoryOptions["Funk"], "Virtual Love")
musicCategoryMaps["Funk"]["Virtual Love"] = "95504533309589"
table.insert(musicCategoryOptions["Funk"], "SÓ CACETADA - MC's MENOR DO DOZE, 7 BELO SILVA - DJ's RUGAL ORIGINAL, TIO JOTA, SATI MARCONEX -")
musicCategoryMaps["Funk"]["SÓ CACETADA - MC's MENOR DO DOZE, 7 BELO SILVA - DJ's RUGAL ORIGINAL, TIO JOTA, SATI MARCONEX -"] = "82707909239312"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM ROMANO MANDELADO")
musicCategoryMaps["Funk"]["MONTAGEM ROMANO MANDELADO"] = "128562419041521"
table.insert(musicCategoryOptions["Funk"], "Sombria Vuk")
musicCategoryMaps["Funk"]["Sombria Vuk"] = "102839153047873"
table.insert(musicCategoryOptions["Funk"], "Carnavel - mc mamãe")
musicCategoryMaps["Funk"]["Carnavel - mc mamãe"] = "96934467275534"
table.insert(musicCategoryOptions["Funk"], "eu vou lamber")
musicCategoryMaps["Funk"]["eu vou lamber"] = "112757588991967"
table.insert(musicCategoryOptions["Funk"], "Derruba Subverso")
musicCategoryMaps["Funk"]["Derruba Subverso"] = "96940825546870"
table.insert(musicCategoryOptions["Funk"], "Palhaço do Mal 2 DJ DZ")
musicCategoryMaps["Funk"]["Palhaço do Mal 2 DJ DZ"] = "128464153860602"
table.insert(musicCategoryOptions["Funk"], "nao conheco")
musicCategoryMaps["Funk"]["nao conheco"] = "17422113153"
table.insert(musicCategoryOptions["Funk"], "CAVEIRAO HOPI HARI DJ ERY")
musicCategoryMaps["Funk"]["CAVEIRAO HOPI HARI DJ ERY"] = "128171341263904"
table.insert(musicCategoryOptions["Funk"], "CAVEIRÃO POCANDO")
musicCategoryMaps["Funk"]["CAVEIRÃO POCANDO"] = "102569146309499"
table.insert(musicCategoryOptions["Funk"], "Mandelão do Mago")
musicCategoryMaps["Funk"]["Mandelão do Mago"] = "142058694038576"
table.insert(musicCategoryOptions["Funk"], "Tremo mexicana DJ GP da ZL")
musicCategoryMaps["Funk"]["Tremo mexicana DJ GP da ZL"] = "110317978973938"
table.insert(musicCategoryOptions["Funk"], "FUNK RJ")
musicCategoryMaps["Funk"]["FUNK RJ"] = "108207460983034"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM MÁGICA 2 - DJ PEW ORIGINAL -")
musicCategoryMaps["Funk"]["MONTAGEM MÁGICA 2 - DJ PEW ORIGINAL -"] = "81733205826673"
table.insert(musicCategoryOptions["Funk"], "Cena do Perigo")
musicCategoryMaps["Funk"]["Cena do Perigo"] = "123049586749305"
table.insert(musicCategoryOptions["Funk"], "era minha ex com saudade da minha pir0c")
musicCategoryMaps["Funk"]["era minha ex com saudade da minha pir0c"] = "106980333280045"
table.insert(musicCategoryOptions["Funk"], "o sossego acabou")
musicCategoryMaps["Funk"]["o sossego acabou"] = "125354466627612"
table.insert(musicCategoryOptions["Funk"], "(Automotivo do Xeque Mate)")
musicCategoryMaps["Funk"]["(Automotivo do Xeque Mate)"] = "129902784040741"
table.insert(musicCategoryOptions["Funk"], "LALALALA")
musicCategoryMaps["Funk"]["LALALALA"] = "107314654399868"
table.insert(musicCategoryOptions["Funk"], "Job para  ladrão")
musicCategoryMaps["Funk"]["Job para  ladrão"] = "140020606400200"
table.insert(musicCategoryOptions["Funk"], "MTG FAZ A POSIÇAO DO CANGURU LEVANTA PERNINHA | DJ Betim do ATL -")
musicCategoryMaps["Funk"]["MTG FAZ A POSIÇAO DO CANGURU LEVANTA PERNINHA | DJ Betim do ATL -"] = "136735312788100"
table.insert(musicCategoryOptions["Funk"], "saldade da minha ex")
musicCategoryMaps["Funk"]["saldade da minha ex"] = "112164486056611"
table.insert(musicCategoryOptions["Funk"], "Set RJ")
musicCategoryMaps["Funk"]["Set RJ"] = "131963051073038"
table.insert(musicCategoryOptions["Funk"], "sla")
musicCategoryMaps["Funk"]["sla"] = "134763052215450"
table.insert(musicCategoryOptions["Funk"], "amiguinhos que tá de pt")
musicCategoryMaps["Funk"]["amiguinhos que tá de pt"] = "101427115159319"
table.insert(musicCategoryOptions["Funk"], "Mega quebra bailé, faixa 5")
musicCategoryMaps["Funk"]["Mega quebra bailé, faixa 5"] = "138911072832689"
table.insert(musicCategoryOptions["Funk"], "VERSÃO - SENTA TUA GOSTOSA")
musicCategoryMaps["Funk"]["VERSÃO - SENTA TUA GOSTOSA"] = "110176270788146"
table.insert(musicCategoryOptions["Funk"], "RAVE EMBRAZANTE")
musicCategoryMaps["Funk"]["RAVE EMBRAZANTE"] = "118671795412334"
table.insert(musicCategoryOptions["Funk"], "EU TO DE GLOCK NA CINTURA e FUZIL NA BANDOLERA")
musicCategoryMaps["Funk"]["EU TO DE GLOCK NA CINTURA e FUZIL NA BANDOLERA"] = "94878081234467"
table.insert(musicCategoryOptions["Funk"], "MTG EXPLODE")
musicCategoryMaps["Funk"]["MTG EXPLODE"] = "81384105684889"
table.insert(musicCategoryOptions["Funk"], "Melodia Serena")
musicCategoryMaps["Funk"]["Melodia Serena"] = "97011217688307"
table.insert(musicCategoryOptions["Funk"], "Roca nos amigo da boca")
musicCategoryMaps["Funk"]["Roca nos amigo da boca"] = "78247020542222"
table.insert(musicCategoryOptions["Funk"], "RITMADA SAYONARA")
musicCategoryMaps["Funk"]["RITMADA SAYONARA"] = "140655042547224"
table.insert(musicCategoryOptions["Funk"], "haha (NGI)")
musicCategoryMaps["Funk"]["haha (NGI)"] = "122114766584918"
table.insert(musicCategoryOptions["Funk"], "V7")
musicCategoryMaps["Funk"]["V7"] = "80348640826643"
table.insert(musicCategoryOptions["Funk"], "Uniao Flasco Original")
musicCategoryMaps["Funk"]["Uniao Flasco Original"] = "125594000795206"
table.insert(musicCategoryOptions["Funk"], "JOGA NO PAI")
musicCategoryMaps["Funk"]["JOGA NO PAI"] = "128011871344522"
table.insert(musicCategoryOptions["Funk"], "VOU TE CONTAR UM SEGREDO")
musicCategoryMaps["Funk"]["VOU TE CONTAR UM SEGREDO"] = "104951257397037"
table.insert(musicCategoryOptions["Funk"], "aqui!")
musicCategoryMaps["Funk"]["aqui!"] = "94596157966965"
table.insert(musicCategoryOptions["Funk"], "MC KELVINHO - MENINOS DO TORRO 2")
musicCategoryMaps["Funk"]["MC KELVINHO - MENINOS DO TORRO 2"] = "75531002354210"
table.insert(musicCategoryOptions["Funk"], "casa do seu zé")
musicCategoryMaps["Funk"]["casa do seu zé"] = "82889452939550"
table.insert(musicCategoryOptions["Funk"], "amiguinha best")
musicCategoryMaps["Funk"]["amiguinha best"] = "138021904914351"
table.insert(musicCategoryOptions["Funk"], "Passa Esfrega")
musicCategoryMaps["Funk"]["Passa Esfrega"] = "130991649454424"
table.insert(musicCategoryOptions["Funk"], "Baila no Mago")
musicCategoryMaps["Funk"]["Baila no Mago"] = "123049586749302"
table.insert(musicCategoryOptions["Funk"], "A BALINHA DO AMOR - (by: Gubbyxp7/bielxp7)")
musicCategoryMaps["Funk"]["A BALINHA DO AMOR - (by: Gubbyxp7/bielxp7)"] = "87047691839817"
table.insert(musicCategoryOptions["Funk"], "Pontinho dos fluxos")
musicCategoryMaps["Funk"]["Pontinho dos fluxos"] = "115908160799460"
table.insert(musicCategoryOptions["Funk"], "MC DALESTE - BONDE DOS MENOR")
musicCategoryMaps["Funk"]["MC DALESTE - BONDE DOS MENOR"] = "123248059613193"
table.insert(musicCategoryOptions["Funk"], "Tropa do Mandelão")
musicCategoryMaps["Funk"]["Tropa do Mandelão"] = "87394058276495"
table.insert(musicCategoryOptions["Funk"], "SEQUÊNCIA DA CATUCADA")
musicCategoryMaps["Funk"]["SEQUÊNCIA DA CATUCADA"] = "100258273816054"
table.insert(musicCategoryOptions["Funk"], "Senta no bugalu")
musicCategoryMaps["Funk"]["Senta no bugalu"] = "112504619203183"
table.insert(musicCategoryOptions["Funk"], "CLYXAL X NYT")
musicCategoryMaps["Funk"]["CLYXAL X NYT"] = "100258273816054"
table.insert(musicCategoryOptions["Funk"], "FAMOSO FAIXA BRANCA")
musicCategoryMaps["Funk"]["FAMOSO FAIXA BRANCA"] = "73548536674899"
table.insert(musicCategoryOptions["Funk"], "piui tictac")
musicCategoryMaps["Funk"]["piui tictac"] = "139239312760455"
table.insert(musicCategoryOptions["Funk"], "frequencia infernal")
musicCategoryMaps["Funk"]["frequencia infernal"] = "89198490801341"
table.insert(musicCategoryOptions["Funk"], "24")
musicCategoryMaps["Funk"]["24"] = "104805334951010"
table.insert(musicCategoryOptions["Funk"], "ASSOMBRA MATRIX 9")
musicCategoryMaps["Funk"]["ASSOMBRA MATRIX 9"] = "130149486547895"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM JUNÇÃO VENENOSA")
musicCategoryMaps["Funk"]["MONTAGEM JUNÇÃO VENENOSA"] = "74760409585507"
table.insert(musicCategoryOptions["Funk"], "Não Trate a Natalia mal")
musicCategoryMaps["Funk"]["Não Trate a Natalia mal"] = "76860168288557"
table.insert(musicCategoryOptions["Funk"], "tô com o piru desgovernado")
musicCategoryMaps["Funk"]["tô com o piru desgovernado"] = "115837046053738"
table.insert(musicCategoryOptions["Funk"], "i like trains")
musicCategoryMaps["Funk"]["i like trains"] = "94410505324605"
table.insert(musicCategoryOptions["Funk"], "(BYD ZAGO)")
musicCategoryMaps["Funk"]["(BYD ZAGO)"] = "104013424327800"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM - FAZ MACETE 2")
musicCategoryMaps["Funk"]["MONTAGEM - FAZ MACETE 2"] = "97063553131882"
table.insert(musicCategoryOptions["Funk"], "Seu Romeu")
musicCategoryMaps["Funk"]["Seu Romeu"] = "70791355308103"
table.insert(musicCategoryOptions["Funk"], "NAO MANDA TOMA")
musicCategoryMaps["Funk"]["NAO MANDA TOMA"] = "137188221417776"
table.insert(musicCategoryOptions["Funk"], "ngc daddy love and chopa x pluggnb x 130bpm")
musicCategoryMaps["Funk"]["ngc daddy love and chopa x pluggnb x 130bpm"] = "96223086135288"
table.insert(musicCategoryOptions["Funk"], "SENTA PRO GU SPC E KIKA PRO K.K")
musicCategoryMaps["Funk"]["SENTA PRO GU SPC E KIKA PRO K.K"] = "126496448781522"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "81414633363701"
table.insert(musicCategoryOptions["Funk"], "FUNK NARUTO")
musicCategoryMaps["Funk"]["FUNK NARUTO"] = "89473100926016"
table.insert(musicCategoryOptions["Funk"], "no seu olho")
musicCategoryMaps["Funk"]["no seu olho"] = "112416262448027"
table.insert(musicCategoryOptions["Funk"], "rainha")
musicCategoryMaps["Funk"]["rainha"] = "116224648054652"
table.insert(musicCategoryOptions["Funk"], "VAI SENTANDO DEVAGAR - DJ Souza Original -")
musicCategoryMaps["Funk"]["VAI SENTANDO DEVAGAR - DJ Souza Original -"] = "125681143524900"
table.insert(musicCategoryOptions["Funk"], "anarrana - tapete magico")
musicCategoryMaps["Funk"]["anarrana - tapete magico"] = "122488679897031"
table.insert(musicCategoryOptions["Funk"], "pre treino")
musicCategoryMaps["Funk"]["pre treino"] = "136869502216760"
table.insert(musicCategoryOptions["Funk"], "MTG XEREQUINHA DO TREM, VOU PRENDER A MINHA CABECINHA | DJ Betim do ATL -  (By Draax")
musicCategoryMaps["Funk"]["MTG XEREQUINHA DO TREM, VOU PRENDER A MINHA CABECINHA | DJ Betim do ATL -  (By Draax"] = "137074620376144"
table.insert(musicCategoryOptions["Funk"], "Dz7")
musicCategoryMaps["Funk"]["Dz7"] = "91976386006545"
table.insert(musicCategoryOptions["Funk"], "bonde do alan")
musicCategoryMaps["Funk"]["bonde do alan"] = "106489677491984"
table.insert(musicCategoryOptions["Funk"], "só uma surra de leve")
musicCategoryMaps["Funk"]["só uma surra de leve"] = "122259510323980"
table.insert(musicCategoryOptions["Funk"], "Id brazino atualizado")
musicCategoryMaps["Funk"]["Id brazino atualizado"] = "76261718144090"
table.insert(musicCategoryOptions["Funk"], "Ritmo da 011")
musicCategoryMaps["Funk"]["Ritmo da 011"] = "110204841162999"
table.insert(musicCategoryOptions["Funk"], "ajoelhas")
musicCategoryMaps["Funk"]["ajoelhas"] = "127052251825619"
table.insert(musicCategoryOptions["Funk"], "SENTA E RBL")
musicCategoryMaps["Funk"]["SENTA E RBL"] = "107513285979080"
table.insert(musicCategoryOptions["Funk"], "Viagem Sonora")
musicCategoryMaps["Funk"]["Viagem Sonora"] = "79349174602261"
table.insert(musicCategoryOptions["Funk"], "difícil de esquecer essa botada em você")
musicCategoryMaps["Funk"]["difícil de esquecer essa botada em você"] = "74442563897758"
table.insert(musicCategoryOptions["Funk"], "(Mandelao da Dz7 Blakes)")
musicCategoryMaps["Funk"]["(Mandelao da Dz7 Blakes)"] = "72047516958410"
table.insert(musicCategoryOptions["Funk"], "mc ig 3 dias")
musicCategoryMaps["Funk"]["mc ig 3 dias"] = "110821596297428"
table.insert(musicCategoryOptions["Funk"], "(Moço perigoso)")
musicCategoryMaps["Funk"]["(Moço perigoso)"] = "74561078455943"
table.insert(musicCategoryOptions["Funk"], "(Sobe balão, desce princesa)")
musicCategoryMaps["Funk"]["(Sobe balão, desce princesa)"] = "110023885558332"
table.insert(musicCategoryOptions["Funk"], "to fazendo academia")
musicCategoryMaps["Funk"]["to fazendo academia"] = "109190195951695"
table.insert(musicCategoryOptions["Funk"], "aplico o chá")
musicCategoryMaps["Funk"]["aplico o chá"] = "125706696726990"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM - NÃO TEM SEGREDO")
musicCategoryMaps["Funk"]["MONTAGEM - NÃO TEM SEGREDO"] = "76182545182727"
table.insert(musicCategoryOptions["Funk"], "Estratégia do Mago")
musicCategoryMaps["Funk"]["Estratégia do Mago"] = "101741584984252"
table.insert(musicCategoryOptions["Funk"], "ritmada")
musicCategoryMaps["Funk"]["ritmada"] = "74867410898061"
table.insert(musicCategoryOptions["Funk"], "(Soka com a envolvencia)")
musicCategoryMaps["Funk"]["(Soka com a envolvencia)"] = "91135107912129"
table.insert(musicCategoryOptions["Funk"], "Cena do Mago")
musicCategoryMaps["Funk"]["Cena do Mago"] = "138405967283401"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM VAPO VAPO DJ MANIN 2020 ( FAISCA X GUBBYXP7 X 1CH23 )")
musicCategoryMaps["Funk"]["MONTAGEM VAPO VAPO DJ MANIN 2020 ( FAISCA X GUBBYXP7 X 1CH23 )"] = "125618702364556"
table.insert(musicCategoryOptions["Funk"], "VOU TE COMER E TE ABANDONAR")
musicCategoryMaps["Funk"]["VOU TE COMER E TE ABANDONAR"] = "110483047851014"
table.insert(musicCategoryOptions["Funk"], "MAESTROS DO MANDELAO")
musicCategoryMaps["Funk"]["MAESTROS DO MANDELAO"] = "86162096510351"
table.insert(musicCategoryOptions["Funk"], "Tentar")
musicCategoryMaps["Funk"]["Tentar"] = "131267110896054"
table.insert(musicCategoryOptions["Funk"], "mc poze saudades de vc irmão")
musicCategoryMaps["Funk"]["mc poze saudades de vc irmão"] = "126572558378318"
table.insert(musicCategoryOptions["Funk"], "Montagem - O Mago")
musicCategoryMaps["Funk"]["Montagem - O Mago"] = "93850654162047"
table.insert(musicCategoryOptions["Funk"], "vai rebola pro pai")
musicCategoryMaps["Funk"]["vai rebola pro pai"] = "120075559226752"
table.insert(musicCategoryOptions["Funk"], "NA RELIQUIA DO DRAGON BAL")
musicCategoryMaps["Funk"]["NA RELIQUIA DO DRAGON BAL"] = "120482277956217"
table.insert(musicCategoryOptions["Funk"], "Mtg anos 2000 dj arana")
musicCategoryMaps["Funk"]["Mtg anos 2000 dj arana"] = "73111349649862"
table.insert(musicCategoryOptions["Funk"], "So CAVU")
musicCategoryMaps["Funk"]["So CAVU"] = "114255201746886"
table.insert(musicCategoryOptions["Funk"], "Melodia Virtual")
musicCategoryMaps["Funk"]["Melodia Virtual"] = "139147474886402"
table.insert(musicCategoryOptions["Funk"], "AniquiL Funk")
musicCategoryMaps["Funk"]["AniquiL Funk"] = "101119121510308"
table.insert(musicCategoryOptions["Funk"], "BRAZIL GANG FUNK")
musicCategoryMaps["Funk"]["BRAZIL GANG FUNK"] = "121206077121829"
table.insert(musicCategoryOptions["Funk"], "PAREDAO MORCEGAO")
musicCategoryMaps["Funk"]["PAREDAO MORCEGAO"] = "138120757806690"
table.insert(musicCategoryOptions["Funk"], "UIUAH")
musicCategoryMaps["Funk"]["UIUAH"] = "82894376737849"
table.insert(musicCategoryOptions["Funk"], "ELA FAZ STORYZIN 3.0 - NEW")
musicCategoryMaps["Funk"]["ELA FAZ STORYZIN 3.0 - NEW"] = "113854156533841"
table.insert(musicCategoryOptions["Funk"], "da Dz7 essa")
musicCategoryMaps["Funk"]["da Dz7 essa"] = "121010278897629"
table.insert(musicCategoryOptions["Funk"], "Sequencia de toma toma")
musicCategoryMaps["Funk"]["Sequencia de toma toma"] = "110472284585387"
table.insert(musicCategoryOptions["Funk"], "Balinha proibida")
musicCategoryMaps["Funk"]["Balinha proibida"] = "128512104863934"
table.insert(musicCategoryOptions["Funk"], "Sequencia da machucação DJ Blakes")
musicCategoryMaps["Funk"]["Sequencia da machucação DJ Blakes"] = "115660500409059"
table.insert(musicCategoryOptions["Funk"], "SOLDADO GUERREIRO")
musicCategoryMaps["Funk"]["SOLDADO GUERREIRO"] = "71590664026646"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM - INTERGALACTICA")
musicCategoryMaps["Funk"]["MONTAGEM - INTERGALACTICA"] = "120182857206973"
table.insert(musicCategoryOptions["Funk"], "Mega Trepa Trepa DJ Wizard")
musicCategoryMaps["Funk"]["Mega Trepa Trepa DJ Wizard"] = "127449416726113"
table.insert(musicCategoryOptions["Funk"], "Tijolos XL 3")
musicCategoryMaps["Funk"]["Tijolos XL 3"] = "84193648374486"
table.insert(musicCategoryOptions["Funk"], "Rlk do 2t")
musicCategoryMaps["Funk"]["Rlk do 2t"] = "122126177666117"
table.insert(musicCategoryOptions["Funk"], "(Montagem  Macetação)")
musicCategoryMaps["Funk"]["(Montagem  Macetação)"] = "110276209348037"
table.insert(musicCategoryOptions["Funk"], "(Sentada nervosa)")
musicCategoryMaps["Funk"]["(Sentada nervosa)"] = "100461622411736"
table.insert(musicCategoryOptions["Funk"], "Reboca sua xrc/ Seu pedreiro")
musicCategoryMaps["Funk"]["Reboca sua xrc/ Seu pedreiro"] = "116272171755349"
table.insert(musicCategoryOptions["Funk"], "comeno uma prkinha")
musicCategoryMaps["Funk"]["comeno uma prkinha"] = "94214367115154"
table.insert(musicCategoryOptions["Funk"], "Fall Into The Sky")
musicCategoryMaps["Funk"]["Fall Into The Sky"] = "139748606209287"
table.insert(musicCategoryOptions["Funk"], "o trem bala")
musicCategoryMaps["Funk"]["o trem bala"] = "83400946888030"
table.insert(musicCategoryOptions["Funk"], "meta ritmo")
musicCategoryMaps["Funk"]["meta ritmo"] = "110091098283354"
table.insert(musicCategoryOptions["Funk"], "(Novo rit do verão)")
musicCategoryMaps["Funk"]["(Novo rit do verão)"] = "98146817497066"
table.insert(musicCategoryOptions["Funk"], "MC ROGÊ - TOMA TOMA TÁ")
musicCategoryMaps["Funk"]["MC ROGÊ - TOMA TOMA TÁ"] = "132877691651436"
table.insert(musicCategoryOptions["Funk"], "Amor Hospitalar")
musicCategoryMaps["Funk"]["Amor Hospitalar"] = "96259351729049"
table.insert(musicCategoryOptions["Funk"], "Tu vai ficar de 4")
musicCategoryMaps["Funk"]["Tu vai ficar de 4"] = "97124592340288"
table.insert(musicCategoryOptions["Funk"], "apaga a luz e começa a")
musicCategoryMaps["Funk"]["apaga a luz e começa a"] = "88526654938622"
table.insert(musicCategoryOptions["Funk"], "Bruxaria Carnificina")
musicCategoryMaps["Funk"]["Bruxaria Carnificina"] = "133252379616732"
table.insert(musicCategoryOptions["Funk"], "ESTOURADAO KKKK")
musicCategoryMaps["Funk"]["ESTOURADAO KKKK"] = "86839065790068"
table.insert(musicCategoryOptions["Funk"], "vai me mmnds vai")
musicCategoryMaps["Funk"]["vai me mmnds vai"] = "101519980567219"
table.insert(musicCategoryOptions["Funk"], "Montagem do Paquistão")
musicCategoryMaps["Funk"]["Montagem do Paquistão"] = "99812493978684"
table.insert(musicCategoryOptions["Funk"], "vai voar no tapete magico")
musicCategoryMaps["Funk"]["vai voar no tapete magico"] = "4105580961743293"
table.insert(musicCategoryOptions["Funk"], "Bota o Fluxo")
musicCategoryMaps["Funk"]["Bota o Fluxo"] = "112049586739405"
table.insert(musicCategoryOptions["Funk"], "Berimbau Amostrado")
musicCategoryMaps["Funk"]["Berimbau Amostrado"] = "77712236704085"
table.insert(musicCategoryOptions["Funk"], "Meia Noite|")
musicCategoryMaps["Funk"]["Meia Noite|"] = "86617433885915"
table.insert(musicCategoryOptions["Funk"], "Montagem Malvada)")
musicCategoryMaps["Funk"]["Montagem Malvada)"] = "93517492369858"
table.insert(musicCategoryOptions["Funk"], "(Tropa do Urso)")
musicCategoryMaps["Funk"]["(Tropa do Urso)"] = "134834195289705"
table.insert(musicCategoryOptions["Funk"], "MICO ME DA UM LANÇA x BOA NOITE MEU CONSAGRADO KKKKKKK")
musicCategoryMaps["Funk"]["MICO ME DA UM LANÇA x BOA NOITE MEU CONSAGRADO KKKKKKK"] = "78352220341424"
table.insert(musicCategoryOptions["Funk"], "funkphonk fumando verde")
musicCategoryMaps["Funk"]["funkphonk fumando verde"] = "112143944982807"
table.insert(musicCategoryOptions["Funk"], "vem me f#")
musicCategoryMaps["Funk"]["vem me f#"] = "136574160308808"
table.insert(musicCategoryOptions["Funk"], "MC PW - Gps / Endereço da favela")
musicCategoryMaps["Funk"]["MC PW - Gps / Endereço da favela"] = "82117652303865"
table.insert(musicCategoryOptions["Funk"], "quem não bafora nao transa")
musicCategoryMaps["Funk"]["quem não bafora nao transa"] = "125154299082694"
table.insert(musicCategoryOptions["Funk"], "Ajoelha")
musicCategoryMaps["Funk"]["Ajoelha"] = "127052251825619"
table.insert(musicCategoryOptions["Funk"], "(Essa prr de idiotex)")
musicCategoryMaps["Funk"]["(Essa prr de idiotex)"] = "87718475791945"
table.insert(musicCategoryOptions["Funk"], "Joga a bct na ponta da Glock")
musicCategoryMaps["Funk"]["Joga a bct na ponta da Glock"] = "104226699513043"
table.insert(musicCategoryOptions["Funk"], "X")
musicCategoryMaps["Funk"]["X"] = "99392361796344"
table.insert(musicCategoryOptions["Funk"], "DPS DO BAILE")
musicCategoryMaps["Funk"]["DPS DO BAILE"] = "125312858660888"
table.insert(musicCategoryOptions["Funk"], "união flasco")
musicCategoryMaps["Funk"]["união flasco"] = "107991235917983"
table.insert(musicCategoryOptions["Funk"], "Mega dos beats")
musicCategoryMaps["Funk"]["Mega dos beats"] = "112164486056611"
table.insert(musicCategoryOptions["Funk"], "BROTEI NO BAILE DA MATINHA, VAI ROLAR UMA FUGIDINHA TOMA VAI NOVINHA")
musicCategoryMaps["Funk"]["BROTEI NO BAILE DA MATINHA, VAI ROLAR UMA FUGIDINHA TOMA VAI NOVINHA"] = "139877575020614"
table.insert(musicCategoryOptions["Funk"], "id estourada")
musicCategoryMaps["Funk"]["id estourada"] = "121660289883020"
table.insert(musicCategoryOptions["Funk"], "Balança o guarda chuva")
musicCategoryMaps["Funk"]["Balança o guarda chuva"] = "126988068303069"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "80512054525157"
table.insert(musicCategoryOptions["Funk"], "O palhação vai te pegar")
musicCategoryMaps["Funk"]["O palhação vai te pegar"] = "82865274986116"
table.insert(musicCategoryOptions["Funk"], "pipokinha")
musicCategoryMaps["Funk"]["pipokinha"] = "70725650826656"
table.insert(musicCategoryOptions["Funk"], "Bruxaria do Draax")
musicCategoryMaps["Funk"]["Bruxaria do Draax"] = "99509840423912"
table.insert(musicCategoryOptions["Funk"], "QUEM NÃO BAFORA NÃO TRANSA | DJ Patrick Muniz & JC no Beat -")
musicCategoryMaps["Funk"]["QUEM NÃO BAFORA NÃO TRANSA | DJ Patrick Muniz & JC no Beat -"] = "125154299082694"
table.insert(musicCategoryOptions["Funk"], "(Montagem Mega Agudo)")
musicCategoryMaps["Funk"]["(Montagem Mega Agudo)"] = "75741840147445"
table.insert(musicCategoryOptions["Funk"], "Bruxaria Trono")
musicCategoryMaps["Funk"]["Bruxaria Trono"] = "72411825283910"
table.insert(musicCategoryOptions["Funk"], "REBOLA")
musicCategoryMaps["Funk"]["REBOLA"] = "121046655523341"
table.insert(musicCategoryOptions["Funk"], "K9")
musicCategoryMaps["Funk"]["K9"] = "79518570188204"
table.insert(musicCategoryOptions["Funk"], "MC DAVI - 5 METAS")
musicCategoryMaps["Funk"]["MC DAVI - 5 METAS"] = "138014625328561"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM MINI GAME DAS INDIAS")
musicCategoryMaps["Funk"]["MONTAGEM MINI GAME DAS INDIAS"] = "131441995313231"
table.insert(musicCategoryOptions["Funk"], "hoje eu acordei")
musicCategoryMaps["Funk"]["hoje eu acordei"] = "127870629973068"
table.insert(musicCategoryOptions["Funk"], "Viver bem")
musicCategoryMaps["Funk"]["Viver bem"] = "82805460494325"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM GUITARRINHA MONOPLASMA")
musicCategoryMaps["Funk"]["MONTAGEM GUITARRINHA MONOPLASMA"] = "90570459800891"
table.insert(musicCategoryOptions["Funk"], "vai rebola pro pai/estourado")
musicCategoryMaps["Funk"]["vai rebola pro pai/estourado"] = "108808025565103"
table.insert(musicCategoryOptions["Funk"], "sla")
musicCategoryMaps["Funk"]["sla"] = "92524227941055"
table.insert(musicCategoryOptions["Funk"], "olha a explosão")
musicCategoryMaps["Funk"]["olha a explosão"] = "121075115415245"
table.insert(musicCategoryOptions["Funk"], "LIU KANG FUNK")
musicCategoryMaps["Funk"]["LIU KANG FUNK"] = "128352122850913"
table.insert(musicCategoryOptions["Funk"], "CAPPUCCINO ASSASSINO (SPEDUP)")
musicCategoryMaps["Funk"]["CAPPUCCINO ASSASSINO (SPEDUP)"] = "132733033157915"
table.insert(musicCategoryOptions["Funk"], "EU JA TO NA ONDA")
musicCategoryMaps["Funk"]["EU JA TO NA ONDA"] = "93483751210667"
table.insert(musicCategoryOptions["Funk"], "dom dom dom")
musicCategoryMaps["Funk"]["dom dom dom"] = "71010430843983"
table.insert(musicCategoryOptions["Funk"], "VAI MACHUCANDO A XT")
musicCategoryMaps["Funk"]["VAI MACHUCANDO A XT"] = "77741294709660"
table.insert(musicCategoryOptions["Funk"], "SOU TEU Fa (ORUAM)")
musicCategoryMaps["Funk"]["SOU TEU Fa (ORUAM)"] = "85342086082111"
table.insert(musicCategoryOptions["Funk"], "Vai de quatro novinha se joga no Plugg")
musicCategoryMaps["Funk"]["Vai de quatro novinha se joga no Plugg"] = "81102632991320"
table.insert(musicCategoryOptions["Funk"], "(Montagem na onda)")
musicCategoryMaps["Funk"]["(Montagem na onda)"] = "80488815553151"
table.insert(musicCategoryOptions["Funk"], "BERIMBAU KK")
musicCategoryMaps["Funk"]["BERIMBAU KK"] = "77712236704085"
table.insert(musicCategoryOptions["Funk"], "157")
musicCategoryMaps["Funk"]["157"] = "122488203955460"
table.insert(musicCategoryOptions["Funk"], "vem me fudendo")
musicCategoryMaps["Funk"]["vem me fudendo"] = "136574160308808"
table.insert(musicCategoryOptions["Funk"], "Assombra matrix 9")
musicCategoryMaps["Funk"]["Assombra matrix 9"] = "130149486547895"
table.insert(musicCategoryOptions["Funk"], "Pai|")
musicCategoryMaps["Funk"]["Pai|"] = "108808025565103"
table.insert(musicCategoryOptions["Funk"], "Assobio Turbulento")
musicCategoryMaps["Funk"]["Assobio Turbulento"] = "88975584625558"
table.insert(musicCategoryOptions["Funk"], "YOU SEE X TA LIBERADO O LANÇA")
musicCategoryMaps["Funk"]["YOU SEE X TA LIBERADO O LANÇA"] = "113315459485897"
table.insert(musicCategoryOptions["Funk"], "eu tô apaixonado")
musicCategoryMaps["Funk"]["eu tô apaixonado"] = "89460438416730"
table.insert(musicCategoryOptions["Funk"], "street fighter funk")
musicCategoryMaps["Funk"]["street fighter funk"] = "71193421005563"
table.insert(musicCategoryOptions["Funk"], "NA ONDA DO VAPO VAPO")
musicCategoryMaps["Funk"]["NA ONDA DO VAPO VAPO"] = "135903820233276"
table.insert(musicCategoryOptions["Funk"], "157 cafajeste")
musicCategoryMaps["Funk"]["157 cafajeste"] = "100162235063839"
table.insert(musicCategoryOptions["Funk"], "Montagem Malvada")
musicCategoryMaps["Funk"]["Montagem Malvada"] = "93517492369858"
table.insert(musicCategoryOptions["Funk"], "AUTOMOTIVO DOS BIGODE")
musicCategoryMaps["Funk"]["AUTOMOTIVO DOS BIGODE"] = "118419001003031"
table.insert(musicCategoryOptions["Funk"], "Espacial DJ Mandrake")
musicCategoryMaps["Funk"]["Espacial DJ Mandrake"] = "103866589172379"
table.insert(musicCategoryOptions["Funk"], "CVRL PODE ENTRAR ATE BLINDADO")
musicCategoryMaps["Funk"]["CVRL PODE ENTRAR ATE BLINDADO"] = "124244582950595"
table.insert(musicCategoryOptions["Funk"], "Faixa estronda")
musicCategoryMaps["Funk"]["Faixa estronda"] = "121187736532042"
table.insert(musicCategoryOptions["Funk"], "Beco")
musicCategoryMaps["Funk"]["Beco"] = "73607045201707"
table.insert(musicCategoryOptions["Funk"], "VAI DAR UMA SENTADA")
musicCategoryMaps["Funk"]["VAI DAR UMA SENTADA"] = "94384686700395"
table.insert(musicCategoryOptions["Funk"], "FUNK SAD")
musicCategoryMaps["Funk"]["FUNK SAD"] = "107703036365295"
table.insert(musicCategoryOptions["Funk"], "BALINHA")
musicCategoryMaps["Funk"]["BALINHA"] = "112406825739796"
table.insert(musicCategoryOptions["Funk"], "SIMETRICAMENTE")
musicCategoryMaps["Funk"]["SIMETRICAMENTE"] = "76981625332079"
table.insert(musicCategoryOptions["Funk"], "SO PARASITA")
musicCategoryMaps["Funk"]["SO PARASITA"] = "130629170421888"
table.insert(musicCategoryOptions["Funk"], "QUEM TA PASSANDO EH O TREM BALA X TROPA DO MARTIN & GINA")
musicCategoryMaps["Funk"]["QUEM TA PASSANDO EH O TREM BALA X TROPA DO MARTIN & GINA"] = "137828639403630"
table.insert(musicCategoryOptions["Funk"], "Fluxo do Mago")
musicCategoryMaps["Funk"]["Fluxo do Mago"] = "97840582736495"
table.insert(musicCategoryOptions["Funk"], "Pantanal|")
musicCategoryMaps["Funk"]["Pantanal|"] = "94880156546772"
table.insert(musicCategoryOptions["Funk"], "tenta roubar meu kit")
musicCategoryMaps["Funk"]["tenta roubar meu kit"] = "138677350979763"
table.insert(musicCategoryOptions["Funk"], "RADINHO")
musicCategoryMaps["Funk"]["RADINHO"] = "139693447546059"
table.insert(musicCategoryOptions["Funk"], "Pura bruxaria")
musicCategoryMaps["Funk"]["Pura bruxaria"] = "135772975027358"
table.insert(musicCategoryOptions["Funk"], "Quando ver o bonde")
musicCategoryMaps["Funk"]["Quando ver o bonde"] = "132706975762383"
table.insert(musicCategoryOptions["Funk"], "VIRA MORTAL (mais ids tropa vou trazer todos devolta)")
musicCategoryMaps["Funk"]["VIRA MORTAL (mais ids tropa vou trazer todos devolta)"] = "85464353244509"
table.insert(musicCategoryOptions["Funk"], "Automotivo VAI BALANÇA O GUARDA CHUVA")
musicCategoryMaps["Funk"]["Automotivo VAI BALANÇA O GUARDA CHUVA"] = "92208065564467"
table.insert(musicCategoryOptions["Funk"], "(Medley Galatico mandrake)")
musicCategoryMaps["Funk"]["(Medley Galatico mandrake)"] = "81928219576467"
table.insert(musicCategoryOptions["Funk"], "Montagem Xique da O11")
musicCategoryMaps["Funk"]["Montagem Xique da O11"] = "112524148245451"
table.insert(musicCategoryOptions["Funk"], "(Ajoelha DJ Chipoka)")
musicCategoryMaps["Funk"]["(Ajoelha DJ Chipoka)"] = "127052251825619"
table.insert(musicCategoryOptions["Funk"], "antares")
musicCategoryMaps["Funk"]["antares"] = "122938948937941"
table.insert(musicCategoryOptions["Funk"], "não para nao baby")
musicCategoryMaps["Funk"]["não para nao baby"] = "132790002708106"
table.insert(musicCategoryOptions["Funk"], "batida Brega Violino (Beat Brega Funk)")
musicCategoryMaps["Funk"]["batida Brega Violino (Beat Brega Funk)"] = "99399643204701"
table.insert(musicCategoryOptions["Funk"], "C0RP$3 P4RTY FUNK")
musicCategoryMaps["Funk"]["C0RP$3 P4RTY FUNK"] = "140709876805704"
table.insert(musicCategoryOptions["Funk"], "veracruz - mc kevin")
musicCategoryMaps["Funk"]["veracruz - mc kevin"] = "75852595649911"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM DA SIRENE")
musicCategoryMaps["Funk"]["MONTAGEM DA SIRENE"] = "87655745800335"
table.insert(musicCategoryOptions["Funk"], "MC DAVI, DJ R4, MC YAGO, MC JOAO, MC MM - NO BECO ALI MESMO")
musicCategoryMaps["Funk"]["MC DAVI, DJ R4, MC YAGO, MC JOAO, MC MM - NO BECO ALI MESMO"] = "73607045201707"
table.insert(musicCategoryOptions["Funk"], "so no c#zin")
musicCategoryMaps["Funk"]["so no c#zin"] = "111901654887475"
table.insert(musicCategoryOptions["Funk"], "(kn beat)")
musicCategoryMaps["Funk"]["(kn beat)"] = "130304783327966"
table.insert(musicCategoryOptions["Funk"], "SET MEGAFUNK DE QUALIDADE | DJ Mendes - SC -")
musicCategoryMaps["Funk"]["SET MEGAFUNK DE QUALIDADE | DJ Mendes - SC -"] = "130309888987007"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "116257708415048"
table.insert(musicCategoryOptions["Funk"], "OS CRIA TÁ DE RADINHO | MC GL -")
musicCategoryMaps["Funk"]["OS CRIA TÁ DE RADINHO | MC GL -"] = "139282344442965"
table.insert(musicCategoryOptions["Funk"], "pantanal")
musicCategoryMaps["Funk"]["pantanal"] = "94880156546772"
table.insert(musicCategoryOptions["Funk"], "Fogo na inveja")
musicCategoryMaps["Funk"]["Fogo na inveja"] = "80454057741879"
table.insert(musicCategoryOptions["Funk"], "pros menor que vende drg e porta pt")
musicCategoryMaps["Funk"]["pros menor que vende drg e porta pt"] = "90252250244704"
table.insert(musicCategoryOptions["Funk"], "cafajeste")
musicCategoryMaps["Funk"]["cafajeste"] = "100162235063839"
table.insert(musicCategoryOptions["Funk"], "Solteirão eu to suave Metralha dos bailes")
musicCategoryMaps["Funk"]["Solteirão eu to suave Metralha dos bailes"] = "75633080501124"
table.insert(musicCategoryOptions["Funk"], "SE PREPARA (Z3UXSS)")
musicCategoryMaps["Funk"]["SE PREPARA (Z3UXSS)"] = "77428616866753"
table.insert(musicCategoryOptions["Funk"], "se joga funk")
musicCategoryMaps["Funk"]["se joga funk"] = "81102632991320"
table.insert(musicCategoryOptions["Funk"], "(Eu aplico o chá)")
musicCategoryMaps["Funk"]["(Eu aplico o chá)"] = "86866545861125"
table.insert(musicCategoryOptions["Funk"], "PESADELO ARABE - SOCA XRC DELA - PUMBA LA PUMBA")
musicCategoryMaps["Funk"]["PESADELO ARABE - SOCA XRC DELA - PUMBA LA PUMBA"] = "82016192638562"
table.insert(musicCategoryOptions["Funk"], "I Don't wanna do this anymore")
musicCategoryMaps["Funk"]["I Don't wanna do this anymore"] = "119554282991865"
table.insert(musicCategoryOptions["Funk"], "Dança do Canguru (Pke Gaz1nh)")
musicCategoryMaps["Funk"]["Dança do Canguru (Pke Gaz1nh)"] = "86876136192157"
table.insert(musicCategoryOptions["Funk"], "crazy-lol")
musicCategoryMaps["Funk"]["crazy-lol"] = "106958630419629"
table.insert(musicCategoryOptions["Funk"], "X")
musicCategoryMaps["Funk"]["X"] = "125784363463466"
table.insert(musicCategoryOptions["Funk"], "Brotei Funk")
musicCategoryMaps["Funk"]["Brotei Funk"] = "139877575020614"
table.insert(musicCategoryOptions["Funk"], "RITMO BALANÇA UMBRELLA DJ Menor 7")
musicCategoryMaps["Funk"]["RITMO BALANÇA UMBRELLA DJ Menor 7"] = "97039031206276"
table.insert(musicCategoryOptions["Funk"], "(MTG Apocaliptica do Bolsonaro)")
musicCategoryMaps["Funk"]["(MTG Apocaliptica do Bolsonaro)"] = "94729386479038"
table.insert(musicCategoryOptions["Funk"], "(MTG pra ficar legal)")
musicCategoryMaps["Funk"]["(MTG pra ficar legal)"] = "90279100823725"
table.insert(musicCategoryOptions["Funk"], "(Bruxaria derruba noia)")
musicCategoryMaps["Funk"]["(Bruxaria derruba noia)"] = "108990536280174"
table.insert(musicCategoryOptions["Funk"], "Ritmo do Perigo")
musicCategoryMaps["Funk"]["Ritmo do Perigo"] = "134059678234905"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM ARABIANA (Pke Gaz1nh)")
musicCategoryMaps["Funk"]["MONTAGEM ARABIANA (Pke Gaz1nh)"] = "78076624091098"
table.insert(musicCategoryOptions["Funk"], "Mega Automotivo DJ Du")
musicCategoryMaps["Funk"]["Mega Automotivo DJ Du"] = "123211214479861"
table.insert(musicCategoryOptions["Funk"], "montagem ex")
musicCategoryMaps["Funk"]["montagem ex"] = "83287654397479"
table.insert(musicCategoryOptions["Funk"], "PUt cara")
musicCategoryMaps["Funk"]["PUt cara"] = "92162451393338"
table.insert(musicCategoryOptions["Funk"], "Meu Hd Chei De Cp")
musicCategoryMaps["Funk"]["Meu Hd Chei De Cp"] = "118351471702293"
table.insert(musicCategoryOptions["Funk"], "senta pra bandido")
musicCategoryMaps["Funk"]["senta pra bandido"] = "74497576726788"
table.insert(musicCategoryOptions["Funk"], "é o lugar")
musicCategoryMaps["Funk"]["é o lugar"] = "135161051909666"
table.insert(musicCategoryOptions["Funk"], "se tive preferencia bota o anel no meu p@u")
musicCategoryMaps["Funk"]["se tive preferencia bota o anel no meu p@u"] = "101252559371424"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM - STREET FIGHTER")
musicCategoryMaps["Funk"]["MONTAGEM - STREET FIGHTER"] = "71193421005563"
table.insert(musicCategoryOptions["Funk"], "Automotivo Aguçado")
musicCategoryMaps["Funk"]["Automotivo Aguçado"] = "108514034335295"
table.insert(musicCategoryOptions["Funk"], "Ritmo Pixelado")
musicCategoryMaps["Funk"]["Ritmo Pixelado"] = "93928823862203"
table.insert(musicCategoryOptions["Funk"], "(123 testando Negresko)")
musicCategoryMaps["Funk"]["(123 testando Negresko)"] = "72792600222689"
table.insert(musicCategoryOptions["Funk"], "fuga na viatura")
musicCategoryMaps["Funk"]["fuga na viatura"] = "131891110268352"
table.insert(musicCategoryOptions["Funk"], "Maldita de Ex")
musicCategoryMaps["Funk"]["Maldita de Ex"] = "139081830944037"
table.insert(musicCategoryOptions["Funk"], "quem gosta de bucetão")
musicCategoryMaps["Funk"]["quem gosta de bucetão"] = "84434631780133"
table.insert(musicCategoryOptions["Funk"], "SENTA")
musicCategoryMaps["Funk"]["SENTA"] = "124085422276732"
table.insert(musicCategoryOptions["Funk"], "CVRL")
musicCategoryMaps["Funk"]["CVRL"] = "124244582950595"
table.insert(musicCategoryOptions["Funk"], "BIG RUSH")
musicCategoryMaps["Funk"]["BIG RUSH"] = "123247961603489"
table.insert(musicCategoryOptions["Funk"], "Beat do Latre")
musicCategoryMaps["Funk"]["Beat do Latre"] = "94165015928539"
table.insert(musicCategoryOptions["Funk"], "Ritmo do Fluxo")
musicCategoryMaps["Funk"]["Ritmo do Fluxo"] = "87394058276495"
table.insert(musicCategoryOptions["Funk"], "ar condicionado")
musicCategoryMaps["Funk"]["ar condicionado"] = "131013862565986"
table.insert(musicCategoryOptions["Funk"], "Diario de um cafajeste")
musicCategoryMaps["Funk"]["Diario de um cafajeste"] = "125191649461874"
table.insert(musicCategoryOptions["Funk"], "MONTAGEM DO FUTURO")
musicCategoryMaps["Funk"]["MONTAGEM DO FUTURO"] = "82493734590818"
table.insert(musicCategoryOptions["Funk"], "TECLADO LINDINHO 2009")
musicCategoryMaps["Funk"]["TECLADO LINDINHO 2009"] = "140552102781618"
table.insert(musicCategoryOptions["Funk"], "poze tropa")
musicCategoryMaps["Funk"]["poze tropa"] = "76260463454427"
table.insert(musicCategoryOptions["Funk"], "Ela vem de perna aberta")
musicCategoryMaps["Funk"]["Ela vem de perna aberta"] = "108672579124479"
table.insert(musicCategoryOptions["Funk"], "Cena de Favela")
musicCategoryMaps["Funk"]["Cena de Favela"] = "145068394058674"
table.insert(musicCategoryOptions["Funk"], "ID")
musicCategoryMaps["Funk"]["ID"] = "110440975935834"
table.insert(musicCategoryOptions["Funk"], "Ela Ta Chapada")
musicCategoryMaps["Funk"]["Ela Ta Chapada"] = "99333448689558"
table.insert(musicCategoryOptions["Funk"], "BRUXARIA INFERNAL")
musicCategoryMaps["Funk"]["BRUXARIA INFERNAL"] = "109151251394874"
table.insert(musicCategoryOptions["Funk"], "No Daily")
musicCategoryMaps["Funk"]["No Daily"] = "137149487552633"
table.insert(musicCategoryOptions["Funk"], "NAT FUNK")
musicCategoryMaps["Funk"]["NAT FUNK"] = "107416893652681"
table.insert(musicCategoryOptions["Funk"], "colecionador")
musicCategoryMaps["Funk"]["colecionador"] = "125415203699674"
table.insert(musicCategoryOptions["Funk"], "BEAT DO PICA PAU")
musicCategoryMaps["Funk"]["BEAT DO PICA PAU"] = "118398889706388"
table.insert(musicCategoryOptions["Funk"], "(Agudo magico 2 DJ Auralio)")
musicCategoryMaps["Funk"]["(Agudo magico 2 DJ Auralio)"] = "105296412172773"
table.insert(musicCategoryOptions["Funk"], "Sacanagem|")
musicCategoryMaps["Funk"]["Sacanagem|"] = "124054822886984"
table.insert(musicCategoryOptions["Funk"], "Montagem das comunidades")
musicCategoryMaps["Funk"]["Montagem das comunidades"] = "121073524660757"
table.insert(musicCategoryOptions["Funk"], "TUIM DAS RELIKIAS")
musicCategoryMaps["Funk"]["TUIM DAS RELIKIAS"] = "106182904518834"
table.insert(musicCategoryOptions["Funk"], "larguei tudo pra ficar com tigo")
musicCategoryMaps["Funk"]["larguei tudo pra ficar com tigo"] = "130401348697721"
table.insert(musicCategoryOptions["Funk"], "quem n bafora n trnz")
musicCategoryMaps["Funk"]["quem n bafora n trnz"] = "105021704860122"
table.insert(musicCategoryOptions["Funk"], "Manda o papo (NGI)")
musicCategoryMaps["Funk"]["Manda o papo (NGI)"] = "132642647937688"
table.insert(musicCategoryOptions["Funk"], "Montagem Turbolic")
musicCategoryMaps["Funk"]["Montagem Turbolic"] = "105119398541153"
table.insert(musicCategoryOptions["Funk"], "Rae do Baile do Pombal")
musicCategoryMaps["Funk"]["Rae do Baile do Pombal"] = "98120357366524"
table.insert(musicCategoryOptions["Funk"], "se envolveu")
musicCategoryMaps["Funk"]["se envolveu"] = "131641189029925"
table.insert(musicCategoryOptions["Funk"], "(berimbau ultradimensional)")
musicCategoryMaps["Funk"]["(berimbau ultradimensional)"] = "89909853236568"
table.insert(musicCategoryOptions["Funk"], "OS 244")
musicCategoryMaps["Funk"]["OS 244"] = "88671860575007"
table.insert(musicCategoryOptions["Funk"], "(Nao sei o nome dessa)")
musicCategoryMaps["Funk"]["(Nao sei o nome dessa)"] = "82263761934975"
table.insert(musicCategoryOptions["Funk"], "eu gosto de tu fy")
musicCategoryMaps["Funk"]["eu gosto de tu fy"] = "73937969824874"
table.insert(musicCategoryOptions["Funk"], "gin de 10")
musicCategoryMaps["Funk"]["gin de 10"] = "140191183373449"
table.insert(musicCategoryOptions["Funk"], "MEGA FUNK - ESPECIAL DROGA NA CASA DA VÓ | DJ Mendes  SC -")
musicCategoryMaps["Funk"]["MEGA FUNK - ESPECIAL DROGA NA CASA DA VÓ | DJ Mendes  SC -"] = "101530003424070"
table.insert(musicCategoryOptions["Funk"], "(Joga essa BCT pros menor do PCC)")
musicCategoryMaps["Funk"]["(Joga essa BCT pros menor do PCC)"] = "131935226569147"
table.insert(musicCategoryOptions["Funk"], "Perigosa (Repost)")
musicCategoryMaps["Funk"]["Perigosa (Repost)"] = "99316998084000"
table.insert(musicCategoryOptions["Funk"], "Cocota Nesgreco")
musicCategoryMaps["Funk"]["Cocota Nesgreco"] = "130758596227702"
table.insert(musicCategoryOptions["Funk"], "(No Movimento Chombix)")
musicCategoryMaps["Funk"]["(No Movimento Chombix)"] = "117324277183945"
table.insert(musicCategoryOptions["Funk"], "Retorno Pras Pa - ESTOURADO")
musicCategoryMaps["Funk"]["Retorno Pras Pa - ESTOURADO"] = "107384370678918"
table.insert(musicCategoryOptions["Funk"], "(Na raba toma tapão)")
musicCategoryMaps["Funk"]["(Na raba toma tapão)"] = "128589691105865"
table.insert(musicCategoryOptions["Funk"], "No bailão")
musicCategoryMaps["Funk"]["No bailão"] = "117704589011831"
table.insert(musicCategoryOptions["Funk"], "IN0X x Edited Audio 24")
musicCategoryMaps["Funk"]["IN0X x Edited Audio 24"] = "82284832948222"
tabs.Music:AddDropdown({ Name = "Funk", Options = musicCategoryOptions["Funk"], Default = "Option 1", Callback = function(value) playMusicId(musicCategoryMaps["Funk"][value]) end })
musicCategoryMaps["Phonk"] = {}
musicCategoryOptions["Phonk"] = {}
table.insert(musicCategoryOptions["Phonk"], "wyles")
musicCategoryMaps["Phonk"]["wyles"] = "85385155970460"
table.insert(musicCategoryOptions["Phonk"], "Vai Que E No Vapor!")
musicCategoryMaps["Phonk"]["Vai Que E No Vapor!"] = "94845998956451"
table.insert(musicCategoryOptions["Phonk"], "phonk kawai")
musicCategoryMaps["Phonk"]["phonk kawai"] = "91502410121438"
table.insert(musicCategoryOptions["Phonk"], "querendo da a bucet@")
musicCategoryMaps["Phonk"]["querendo da a bucet@"] = "72720721570850"
table.insert(musicCategoryOptions["Phonk"], "vem no pocpoc")
musicCategoryMaps["Phonk"]["vem no pocpoc"] = "102333419023382"
table.insert(musicCategoryOptions["Phonk"], "tatiu wim")
musicCategoryMaps["Phonk"]["tatiu wim"] = "122871512353520"
table.insert(musicCategoryOptions["Phonk"], "novinha sapeca")
musicCategoryMaps["Phonk"]["novinha sapeca"] = "111668097052966"
table.insert(musicCategoryOptions["Phonk"], "novinha representa")
musicCategoryMaps["Phonk"]["novinha representa"] = "93786060174790"
table.insert(musicCategoryOptions["Phonk"], "phonk1")
musicCategoryMaps["Phonk"]["phonk1"] = "77501611905348"
table.insert(musicCategoryOptions["Phonk"], "phonk2")
musicCategoryMaps["Phonk"]["phonk2"] = "126887144190812"
table.insert(musicCategoryOptions["Phonk"], "phonk sarra")
musicCategoryMaps["Phonk"]["phonk sarra"] = "132436320685732"
table.insert(musicCategoryOptions["Phonk"], "phonk3")
musicCategoryMaps["Phonk"]["phonk3"] = "90323407842935"
table.insert(musicCategoryOptions["Phonk"], "novinha dançapanpa")
musicCategoryMaps["Phonk"]["novinha dançapanpa"] = "132245626038510"
table.insert(musicCategoryOptions["Phonk"], "phonk sexoagreçivo")
musicCategoryMaps["Phonk"]["phonk sexoagreçivo"] = "111995323199676"
table.insert(musicCategoryOptions["Phonk"], "phonk4")
musicCategoryMaps["Phonk"]["phonk4"] = "115016589376700"
table.insert(musicCategoryOptions["Phonk"], "phonk5")
musicCategoryMaps["Phonk"]["phonk5"] = "118740708757685"
table.insert(musicCategoryOptions["Phonk"], "phonk6")
musicCategoryMaps["Phonk"]["phonk6"] = "139435437308948"
table.insert(musicCategoryOptions["Phonk"], "phonk chapaquente")
musicCategoryMaps["Phonk"]["phonk chapaquente"] = "109189438638906"
table.insert(musicCategoryOptions["Phonk"], "phonk rajada")
musicCategoryMaps["Phonk"]["phonk rajada"] = "105126065014034"
table.insert(musicCategoryOptions["Phonk"], "rede globo")
musicCategoryMaps["Phonk"]["rede globo"] = "138487820505005"
table.insert(musicCategoryOptions["Phonk"], "phonk indiano")
musicCategoryMaps["Phonk"]["phonk indiano"] = "87968531262747"
table.insert(musicCategoryOptions["Phonk"], "vapo do vapo")
musicCategoryMaps["Phonk"]["vapo do vapo"] = "106317184644394"
table.insert(musicCategoryOptions["Phonk"], "tutatatutata")
musicCategoryMaps["Phonk"]["tutatatutata"] = "112068892721408"
table.insert(musicCategoryOptions["Phonk"], "phonk slower")
musicCategoryMaps["Phonk"]["phonk slower"] = "122852029094656"
table.insert(musicCategoryOptions["Phonk"], "phonk9")
musicCategoryMaps["Phonk"]["phonk9"] = "91760524161503"
table.insert(musicCategoryOptions["Phonk"], "phonk10")
musicCategoryMaps["Phonk"]["phonk10"] = "73140398421340"
table.insert(musicCategoryOptions["Phonk"], "phonk11")
musicCategoryMaps["Phonk"]["phonk11"] = "137962454483542"
table.insert(musicCategoryOptions["Phonk"], "phonk12")
musicCategoryMaps["Phonk"]["phonk12"] = "84733736048142"
table.insert(musicCategoryOptions["Phonk"], "phonk13")
musicCategoryMaps["Phonk"]["phonk13"] = "106322173003761"
table.insert(musicCategoryOptions["Phonk"], "phonk14")
musicCategoryMaps["Phonk"]["phonk14"] = "94604796823780"
table.insert(musicCategoryOptions["Phonk"], "phonk15")
musicCategoryMaps["Phonk"]["phonk15"] = "118063577904953"
table.insert(musicCategoryOptions["Phonk"], "phonk16")
musicCategoryMaps["Phonk"]["phonk16"] = "115567432786512"
table.insert(musicCategoryOptions["Phonk"], "phonk toq")
musicCategoryMaps["Phonk"]["phonk toq"] = "71304501822029"
table.insert(musicCategoryOptions["Phonk"], "phonk hey")
musicCategoryMaps["Phonk"]["phonk hey"] = "132218979961283"
table.insert(musicCategoryOptions["Phonk"], "phonk17")
musicCategoryMaps["Phonk"]["phonk17"] = "102708912256857"
table.insert(musicCategoryOptions["Phonk"], "phonk18")
musicCategoryMaps["Phonk"]["phonk18"] = "140642559093189"
table.insert(musicCategoryOptions["Phonk"], "phonk neve")
musicCategoryMaps["Phonk"]["phonk neve"] = "13530439660"
table.insert(musicCategoryOptions["Phonk"], "phonk19")
musicCategoryMaps["Phonk"]["phonk19"] = "87863924786534"
table.insert(musicCategoryOptions["Phonk"], "phonk20")
musicCategoryMaps["Phonk"]["phonk20"] = "133135085604736"
table.insert(musicCategoryOptions["Phonk"], "phonk lento")
musicCategoryMaps["Phonk"]["phonk lento"] = "97258811783169"
table.insert(musicCategoryOptions["Phonk"], "phonk21")
musicCategoryMaps["Phonk"]["phonk21"] = "92308400487695"
table.insert(musicCategoryOptions["Phonk"], "tipo wym")
musicCategoryMaps["Phonk"]["tipo wym"] = "88064647826500"
table.insert(musicCategoryOptions["Phonk"], "estouradassa1")
musicCategoryMaps["Phonk"]["estouradassa1"] = "92175624643620"
table.insert(musicCategoryOptions["Phonk"], "estouradassa2")
musicCategoryMaps["Phonk"]["estouradassa2"] = "108099943758978"
table.insert(musicCategoryOptions["Phonk"], "trem")
musicCategoryMaps["Phonk"]["trem"] = "114608169341947"
table.insert(musicCategoryOptions["Phonk"], "eoropa")
musicCategoryMaps["Phonk"]["eoropa"] = "111346133543699"
table.insert(musicCategoryOptions["Phonk"], "atimosphekika")
musicCategoryMaps["Phonk"]["atimosphekika"] = "77857496821844"
table.insert(musicCategoryOptions["Phonk"], "phonk ALL THE TIME")
musicCategoryMaps["Phonk"]["phonk ALL THE TIME"] = "123809083385992"
table.insert(musicCategoryOptions["Phonk"], "Automotivo Blondie (Pke Gaz1nh)")
musicCategoryMaps["Phonk"]["Automotivo Blondie (Pke Gaz1nh)"] = "74564219749776"
table.insert(musicCategoryOptions["Phonk"], "สวัสดีคนไทย v2")
musicCategoryMaps["Phonk"]["สวัสดีคนไทย v2"] = "118225359190317"
table.insert(musicCategoryOptions["Phonk"], "MTG TU VAI SENTAR (Pke Gaz1nh)")
musicCategoryMaps["Phonk"]["MTG TU VAI SENTAR (Pke Gaz1nh)"] = "115317874112657"
table.insert(musicCategoryOptions["Phonk"], "Catuquanvan")
musicCategoryMaps["Phonk"]["Catuquanvan"] = "88038595663211"
table.insert(musicCategoryOptions["Phonk"], "F-D-1 (slowed)")
musicCategoryMaps["Phonk"]["F-D-1 (slowed)"] = "124958445624871"
table.insert(musicCategoryOptions["Phonk"], "Sucessagem")
musicCategoryMaps["Phonk"]["Sucessagem"] = "88551699463723"
table.insert(musicCategoryOptions["Phonk"], "ILOVE phonksla")
musicCategoryMaps["Phonk"]["ILOVE phonksla"] = "82148953715595"
table.insert(musicCategoryOptions["Phonk"], "SPEED SLIDE")
musicCategoryMaps["Phonk"]["SPEED SLIDE"] = "118959437310311"
table.insert(musicCategoryOptions["Phonk"], "TOMA FUNK PHONK")
musicCategoryMaps["Phonk"]["TOMA FUNK PHONK"] = "126291069838831"
table.insert(musicCategoryOptions["Phonk"], "PASSO BEM SOLTO X NEW JAZZ")
musicCategoryMaps["Phonk"]["PASSO BEM SOLTO X NEW JAZZ"] = "122706595087279"
table.insert(musicCategoryOptions["Phonk"], "MONTAGEM BIONICA DIAMANTE")
musicCategoryMaps["Phonk"]["MONTAGEM BIONICA DIAMANTE"] = "122338822665007"
table.insert(musicCategoryOptions["Phonk"], "BALA SELVAGEM!")
musicCategoryMaps["Phonk"]["BALA SELVAGEM!"] = "96180057167470"
table.insert(musicCategoryOptions["Phonk"], "COMO TU")
musicCategoryMaps["Phonk"]["COMO TU"] = "86928685812280"
table.insert(musicCategoryOptions["Phonk"], "MONTAGEM SOLAR TROPICANO (SPEED UP)")
musicCategoryMaps["Phonk"]["MONTAGEM SOLAR TROPICANO (SPEED UP)"] = "116461681407294"
table.insert(musicCategoryOptions["Phonk"], "MONTAGEM SOLAR TROPICANO (SLOWED)")
musicCategoryMaps["Phonk"]["MONTAGEM SOLAR TROPICANO (SLOWED)"] = "109308273341422"
table.insert(musicCategoryOptions["Phonk"], "YO DE TI")
musicCategoryMaps["Phonk"]["YO DE TI"] = "125181345407169"
table.insert(musicCategoryOptions["Phonk"], "Beauty, (Phonk), Super sped up")
musicCategoryMaps["Phonk"]["Beauty, (Phonk), Super sped up"] = "71123357599630"
table.insert(musicCategoryOptions["Phonk"], "BRAZIL DO FUNK")
musicCategoryMaps["Phonk"]["BRAZIL DO FUNK"] = "133498554139200"
table.insert(musicCategoryOptions["Phonk"], "FUNK DO RAVE 1.0")
musicCategoryMaps["Phonk"]["FUNK DO RAVE 1.0"] = "137135395010424"
table.insert(musicCategoryOptions["Phonk"], " Portao Funk")
musicCategoryMaps["Phonk"][" Portao Funk"] = "70900514961735"
table.insert(musicCategoryOptions["Phonk"], " FUTABA")
musicCategoryMaps["Phonk"][" FUTABA"] = "91834632690710"
table.insert(musicCategoryOptions["Phonk"], " Melódica Explosão De Melodia")
musicCategoryMaps["Phonk"][" Melódica Explosão De Melodia"] = "98371771055411"
table.insert(musicCategoryOptions["Phonk"], " HIPNOTIZA")
musicCategoryMaps["Phonk"][" HIPNOTIZA"] = "117668905142866"
table.insert(musicCategoryOptions["Phonk"], "CRISTAL NOTURNO")
musicCategoryMaps["Phonk"]["CRISTAL NOTURNO"] = "103695219371872"
table.insert(musicCategoryOptions["Phonk"], " SKY HIGH")
musicCategoryMaps["Phonk"][" SKY HIGH"] = "123517126955383"
table.insert(musicCategoryOptions["Phonk"], "GOTH FUNK")
musicCategoryMaps["Phonk"]["GOTH FUNK"] = "97662362226511"
table.insert(musicCategoryOptions["Phonk"], "SUBURBANA")
musicCategoryMaps["Phonk"]["SUBURBANA"] = "139825057894568"
table.insert(musicCategoryOptions["Phonk"], "STORYMODECOOL")
musicCategoryMaps["Phonk"]["STORYMODECOOL"] = "87115976125426"
table.insert(musicCategoryOptions["Phonk"], "KOBALT")
musicCategoryMaps["Phonk"]["KOBALT"] = "79381341943021"
table.insert(musicCategoryOptions["Phonk"], " andante bacterial")
musicCategoryMaps["Phonk"][" andante bacterial"] = "105882833374061"
table.insert(musicCategoryOptions["Phonk"], "ANGEL Speed Up")
musicCategoryMaps["Phonk"]["ANGEL Speed Up"] = "139593870988593"
table.insert(musicCategoryOptions["Phonk"], "MALDITA")
musicCategoryMaps["Phonk"]["MALDITA"] = "133814632960968"
table.insert(musicCategoryOptions["Phonk"], "HIPNOTIZA")
musicCategoryMaps["Phonk"]["HIPNOTIZA"] = "132015050363205"
table.insert(musicCategoryOptions["Phonk"], "MIDZUKI speed up")
musicCategoryMaps["Phonk"]["MIDZUKI speed up"] = "129151948619922"
table.insert(musicCategoryOptions["Phonk"], "CRISTAL")
musicCategoryMaps["Phonk"]["CRISTAL"] = "103445348511856"
tabs.Music:AddDropdown({ Name = "Phonk", Options = musicCategoryOptions["Phonk"], Default = "Option 1", Callback = function(value) playMusicId(musicCategoryMaps["Phonk"][value]) end })
tabs.Troll_PLayers:AddSection({ Name = "abaixo tem a continuação da aba" })
tabs.Rgbs:AddSection({ Name = "RGB para usar em você" })
tabs.Rgbs:AddSection({ Name = "Name and Bio" })
tabs.Rgbs:AddSection({ Name = "others" })
tabs.Rgbs:AddSection({ Name = "Character" })
tabs.Vehicles_and_House:AddSection({ Name = "all car functions" })
tabs.Vehicles_and_House:AddSection({ Name = "Vehicle - Rgb" })
tabs.Vehicles_and_House:AddSection({ Name = "Your House" })
tabs.Vehicles_and_House:AddSection({ Name = "Hack3d Housetext" })
tabs.Vehicles_and_House:AddSection({ Name = "Other Houses" })
tabs.Vehicles_and_House:AddSection({ Name = "Loop Scripts" })
tabs.Fun:AddSection({ Name = "Fun Players" })
tabs.Fun:AddSection({ Name = "Head Sit" })
tabs.Fun:AddSection({ Name = "Players" })
tabs.Avatar:AddSection({ Name = "Avatar" })
tabs.Avatar:AddSection({ Name = "Copy Avatar" })
tabs.Sound_All:AddSection({ Name = "memes" })
tabs.Troll_PLayers:AddSection({ Name = "Options Players" })
tabs.Music:AddParagraph({ "Musica Nao foi? nos informe no discord.", "", Name = "Musica Nao foi? nos informe no discord.", Description = "" })
tabs.Troll_PLayers:AddSection({ Name = "Troll" })
tabs.Troll_PLayers:AddSection({ Name = "All Players" })
tabs.Vehicles_and_House:AddSection({ Name = "Speed Car Functions" })
tabs.Troll_PLayers:AddSection({ Name = "Methods" })
tabs.Troll_PLayers:AddSection({ Name = "Novos Métodos" })
tabs.Troll_PLayers:AddSection({ Name = "Fling Boat" })
tabs.Troll_PLayers:AddSection({ Name = "Click Kill" })
tabs.Troll_PLayers:AddSection({ Name = "All methods" })
tabs.Scripts:AddSection({ Name = "All Scripts" })
tabs.Protections:AddToggle({ Name = "Anti Canoe Fling", Default = false, Callback = antiCanoe })
tabs.Protections:AddToggle({ Name = "Anti Jet Fling", Default = false, Callback = antiJet })
tabs.Protections:AddToggle({ Name = "Anti Helicopter Fling", Default = false, Callback = antiHelicopter })
tabs.Protections:AddToggle({ Name = "Anti Ball Fling", Default = false, Callback = antiBall })
tabs.Protections:AddToggle({ Name = "Anti Sit", Default = false, Callback = antiSit })
tabs.Troll_PLayers:AddToggle({ Name = "Gravity Orbit", Default = false, Callback = gravityOrbitLoop })
tabs.Fun:AddButton({ Name = "Kill", Callback = killSelected })
tabs.Fun:AddButton({ Name = "Bring", Callback = bringSelected })
tabs.Fun:AddButton({ Name = "Go To", Callback = goToSelected })
tabs.Fun:AddToggle({ Name = "View", Default = false, Callback = viewSelectedLoop })
tabs.Rgbs:AddSlider({ Name = "Velocidade RGB", Description = "Aumenta a velocidade do efeito RGB", Min = 1, Max = 10, Increase = 1, Default = 2, Callback = function(value) rgbSpeed = tonumber(value) or rgbSpeed end })
tabs.Rgbs:AddToggle({ Name = "Nome + Bio RGB", Default = false, Callback = rgbNameBioLoop })
tabs.Rgbs:AddToggle({ Name = "Name RGB", Description = "Make the Name colorful", Default = false, Callback = rgbNameLoop })
tabs.Rgbs:AddToggle({ Name = "Bio RGB", Description = "Make the Bio colorful", Default = false, Callback = rgbBioLoop })
tabs.Rgbs:AddToggle({ Name = "RGB Bicicleta", Description = "RGB na bicicleta", Default = false, Callback = callback_7896 })
tabs.Rgbs:AddToggle({ Name = "Rádio RGB", Default = false, Callback = radioRgbLoop })
tabs.Rgbs:AddToggle({ Name = "RGB Character", Description = "Make your character RGB", Default = false, Callback = rgbCharacterLoop })
tabs.Fun:AddToggle({ Name = "Black Hole Fling player", Default = false, Callback = blackHoleFlingPlayerLoop })
tabs.Vehicles_and_House:AddToggle({ Name = "Matar todos os carros do server", Description = "Teleporta os carros vazios para o void sequencialmente", Default = false, Callback = killAllCarsLoop })
tabs.Vehicles_and_House:AddButton({ Name = "Trazer Todos os Carros", Description = "Teleporta todos os carros do servidor para sua posição", Callback = bringAllCars })
tabs.Vehicles_and_House:AddToggle({ Name = "Vehicle - Rgb", Default = false, Callback = vehicleRgbLoop })
tabs.Vehicles_and_House:AddToggle({ Name = "House - Rgb", Default = false, Callback = houseRgbLoop })
tabs.Vehicles_and_House:AddToggle({ Name = "Housetext - Rgb", Default = false, Callback = houseTextRgbLoop })
tabs.Vehicles_and_House:AddToggle({ Name = "Apply Hack3d Housetext", Default = false, Callback = hackedHouseTextLoop })
tabs.Vehicles_and_House:AddButton({ Name = "Remover Ban de Todas as Casas", Description = "Tenta remover o ban de todas as casas ", Callback = removeHouseBans })
tabs.Vehicles_and_House:AddToggle({ Name = "Loop Garage", Default = false, Callback = garageLoop })
local playerDropdown_27 = tabs.Fun:AddDropdown({ Name = "Select a Player", Options = getPlayerNames(), Default = "", Callback = function(value) selectedPlayerName = value end })
table.insert(playerDropdownHandles, playerDropdown_27)
tabs.Fun:AddToggle({ Name = "Head Sit", Default = false, Callback = headSitLoop })
tabs.Fun:AddButton({ Name = "Update Player List", Callback = refreshPlayerDropdowns })
tabs.Fun:AddButton({ Name = "Placa troca all", Callback = applySignText })
tabs.Fun:AddToggle({ Name = "Noclip", Default = false, Callback = noclipLoop })
tabs.Fun:AddButton({ Name = "Invisible FE", Callback = function() loadExternal("https://pastebin.com/raw/3Rnd9rHf") end })
local playerDropdown_33 = tabs.Avatar:AddDropdown({ Name = "Select Player", Options = getPlayerNames(), Default = "", Callback = function(value) selectedAvatarName = value end })
table.insert(playerDropdownHandles, playerDropdown_33)
tabs.Avatar:AddButton({ Name = "Copy Avatar", Callback = copyAvatar })
tabs.Sound_All:AddButton({ Name = "Tocar Som Global", Description = "Toca o áudio para todos os jogadores", Callback = playGlobalSound })
tabs.Sound_All:AddToggle({ Name = "Loop Global", Description = "Repetir som globalmente", Default = false, Callback = loopGlobalSound })
local playerDropdown_37 = tabs.Troll_PLayers:AddDropdown({ Name = "Select Player", Options = getPlayerNames(), Default = "", Callback = function(value) selectedPlayerName = value end })
table.insert(playerDropdownHandles, playerDropdown_37)
tabs.Troll_PLayers:AddToggle({ Name = "Fling Couch Method one", Default = false, Callback = couchMethodOneLoop })
tabs.Troll_PLayers:AddToggle({ Name = "Loop TP To Player", Default = false, Callback = loopTpSelected })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Couch Loop", Default = false, Callback = couchLoop })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Couch Rápido", Default = false, Callback = couchFastLoop })
tabs.Troll_PLayers:AddButton({ Name = "Fling Portas", Callback = flingDoors })
tabs.Troll_PLayers:AddButton({ Name = "Fling Ball Car", Callback = flingBallCar })
tabs.Troll_PLayers:AddButton({ Name = "Fling Canoa", Callback = function() flingCanoePlayer(selectedPlayer()) end })
tabs.Troll_PLayers:AddButton({ Name = "Car Bring", Callback = carBring })
tabs.Troll_PLayers:AddButton({ Name = "Car Kill", Callback = carKill })
tabs.Troll_PLayers:AddButton({ Name = "Fling Boat", Callback = flingBoat })
tabs.Troll_PLayers:AddButton({ Name = "Fling Boat V2", Callback = flingBoatV2 })
tabs.Troll_PLayers:AddToggle({ Name = "Glitch Couch All Players", Default = false, Callback = glitchCouchAllPlayers })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Couch super Rápido Todos Jogadores", Default = false, Callback = couchSuperFastAllPlayers })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Canoa All Players", Default = false, Callback = canoeAllPlayers })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Boat All Players", Default = false, Callback = boatAllPlayers })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Boat V2 All", Default = false, Callback = boatV2AllPlayers })
tabs.Troll_PLayers:AddToggle({ Name = "Fatal Fling (Best)", Default = false, Callback = fatalFlingLoop })
tabs.Music:AddButton({ Name = "Stop", Description = "ALL music", Callback = stopSounds })
tabs.Troll_PLayers:AddDropdown({ Name = "Method", Options = { "Ball", "Couch", "Boat", "PoliceBoat", "Bus", "TowTruck" }, Default = "", Callback = function(value) selectedMethod = value end })
local playerDropdown_57 = tabs.Troll_PLayers:AddDropdown({ Name = "Target", Options = getPlayerNames(), Default = "", Callback = function(value) selectedPlayerName = value end })
table.insert(playerDropdownHandles, playerDropdown_57)
tabs.Troll_PLayers:AddButton({ Name = "Atualizar Lista", Callback = refreshPlayerDropdowns })
tabs.Sound_All:AddDropdown({ Name = "Memes Sons Globais", Description = "Escolha um som para tocar globalmente", Options = soundNames, Default = "", Callback = function(value) selectedSoundId = soundByName[value] end })
tabs.Sound_All:AddButton({ Name = "Tocar Som Selecionado", Description = "Toca o som globalmente", Callback = playSelectedSound })
tabs.Sound_All:AddToggle({ Name = "Loop Som Global", Description = "Repete o som selecionado globalmente", Default = false, Callback = loopSelectedSound })
tabs.Troll_PLayers:AddButton({ Name = "Refresh Player List", Callback = refreshPlayerDropdowns })
tabs.Troll_PLayers:AddButton({ Name = "Teleport to Player", Callback = teleportSelected })
tabs.Troll_PLayers:AddToggle({ Name = "Spectate Player", Default = false, Callback = spectateSelectedLoop })
tabs.Troll_PLayers:AddDropdown({ Name = "Select Kill Method", Options = { "Ball", "Couch", "Couch V2", "Boat", "PoliceBoat", "Bus", "TowTruck" }, Default = "", Callback = function(value) selectedKillMethod = value end })
tabs.Troll_PLayers:AddButton({ Name = "Kill Player", Callback = function() dispatchFling(selectedPlayer(), selectedKillMethod) end })
tabs.Troll_PLayers:AddButton({ Name = "House Ban Kill", Callback = houseBanKillSelected })
tabs.Troll_PLayers:AddToggle({ Name = "Auto Fling", Default = false, Callback = autoFlingVelocityLoop })
tabs.Troll_PLayers:AddButton({ Name = "Fling Ball", Callback = function() flingBallPlayer(selectedPlayer()) end })
tabs.Vehicles_and_House:AddButton({ Name = "Apply Speed", Callback = applySpeed })
tabs.Vehicles_and_House:AddButton({ Name = "Apply Turbo", Callback = applyTurbo })
tabs.Troll_PLayers:AddToggle({ Name = "Auto Fling", Default = false, Callback = autoFlingVehicleLoop })
tabs.Troll_PLayers:AddToggle({ Name = "Fling Couch Method two", Default = false, Callback = couchMethodTwoLoop })
tabs.Troll_PLayers:AddButton({ Name = "Glitch Couch", Callback = glitchCouchSelected })
tabs.Troll_PLayers:AddButton({ Name = "Fling - Boat", Callback = startFlingBoat })
tabs.Troll_PLayers:AddButton({ Name = "Turn off Fling - Boat", Callback = stopFlingBoat })
tabs.Troll_PLayers:AddButton({ Name = "Click Fling Doors", Callback = clickFlingDoors })
tabs.Troll_PLayers:AddButton({ Name = "Click Kill Couch", Callback = function() loadExternal("https://raw.githubusercontent.com/nxvap/cdn/db/src/ckcouch") end })
tabs.Troll_PLayers:AddButton({ Name = "Click Fling Couch", Callback = function() loadExternal("https://raw.githubusercontent.com/nxvap/cdn/db/src/cfcouch") end })
tabs.Troll_PLayers:AddButton({ Name = "Click Fling Ball", Callback = clickFlingBall })
tabs.Troll_PLayers:AddButton({ Name = "Kill All Bus", Callback = killAllBus })
tabs.Troll_PLayers:AddButton({ Name = "House Ban Kill All", Callback = houseBanKillAll })
tabs.Troll_PLayers:AddButton({ Name = "Fling Boat All", Callback = flingBoatAll })
tabs.Troll_PLayers:AddButton({ Name = "Auto Fling All", Callback = autoFlingAll })
tabs.Troll_PLayers:AddButton({ Name = "Fling Ball All", Callback = flingBallAll })
tabs.Scripts:AddButton({ Name = "Enable Shaders (Irreversible)", Callback = function() loadExternal("https://api.rubis.app/v2/scrap/GkhMtEaOCVNAt8EL/raw") end })
tabs.Scripts:AddButton({ Name = "Rejoin Server", Callback = rejoinServer })
tabs.Scripts:AddButton({ Name = "KitK4t Emotes", Callback = function() loadExternal("https://api.rubis.app/v2/scrap/qehrlb7Oh8oLOgu3/raw") end })
tabs.Scripts:AddButton({ Name = "Gazes Emotes", Callback = function() loadExternal("https://raw.githubusercontent.com/Gazer-Ha/Gaze-stuff/refs/heads/main/Gaze%20emote") end })
tabs.Scripts:AddButton({ Name = "Jerk r15 and r6", Callback = function() loadExternal("https://pastebin.com/raw/FWwdST5Y") end })
tabs.Scripts:AddButton({ Name = "Slayer Fly", Callback = function() loadExternal("https://api.rubis.app/v2/scrap/DF5ohwz7Y23VPawx/raw") end })
tabs.Scripts:AddButton({ Name = "Drone do Lyra", Callback = function() loadExternal("https://raw.githubusercontent.com/BRENOPOOF/drone/refs/heads/main/Main.txt") end })

refreshPlayerDropdowns()

