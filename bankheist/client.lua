local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config

--------------------------
-- PHONEBOOTH THIRD EYE
--------------------------
Citizen.CreateThread(function()
    for _, model in ipairs(Config.PhoneBoothModels) do
        exports['qb-target']:AddTargetModel(model, {
            options = {
                {
                    event = "qb-banktruck:client:phoneBoothInteract",
                    icon = "fas fa-phone",
                    label = "Call for a job",
                }
            },
            distance = 2.0
        })
    end
end)

RegisterNetEvent("qb-banktruck:client:phoneBoothInteract", function()
    QBCore.Functions.Notify("You called for a job!", "success", 3500)
    TriggerServerEvent("qb-banktruck:server:startMeet")
end)

--------------------------
-- HEIST STATE & UTILITY
--------------------------
local meetNPC
local truck
local truckBlip
local guards = {}
local truckCoords, truckHeading
local doorsBlown = false
local insideShell = false
local shellObject
local truckDoorHealth = Config.TruckDoorHealth
local playerPrevPos, playerPrevHeading

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

--------------------------
-- MEET NPC FLOW
--------------------------
RegisterNetEvent("qb-banktruck:client:meetLocation", function(coords, heading, model)
    QBCore.Functions.Notify("Meet up at this location to get the info!", "primary", 7000)
    SetNewWaypoint(coords.x, coords.y)
    Citizen.CreateThread(function()
        while true do
            Wait(500)
            if #(GetEntityCoords(PlayerPedId()) - coords) < 30.0 and not meetNPC then
                TriggerEvent("qb-banktruck:client:spawnMeetNPC", coords, heading, model)
                break
            end
        end
    end)
end)

RegisterNetEvent("qb-banktruck:client:spawnMeetNPC", function(coords, heading, model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    meetNPC = CreatePed(4, model, coords.x, coords.y, coords.z, heading, false, true)
    SetEntityAsMissionEntity(meetNPC, true, true)
    SetBlockingOfNonTemporaryEvents(meetNPC, true)
    SetEntityInvincible(meetNPC, true)
    FreezeEntityPosition(meetNPC, true)
    exports['qb-target']:AddTargetEntity(meetNPC, {
        options = {
            {
                event = "qb-banktruck:client:buyInfo",
                icon = "fas fa-money-bill",
                label = "Buy Truck Location ($" .. Config.InfoCost .. ")"
            }
        },
        distance = 2.0
    })
end)

RegisterNetEvent("qb-banktruck:client:buyInfo", function()
    TriggerServerEvent("qb-banktruck:server:buyTruckInfo")
    if meetNPC and DoesEntityExist(meetNPC) then
        DeleteEntity(meetNPC)
        meetNPC = nil
    end
end)

--------------------------
-- TRUCK SPAWN & PATROL
--------------------------
RegisterNetEvent("qb-banktruck:client:spawnTruck", function(loc, truckModel, guardModel, guardWeapon, numGuards, patrolRoute)
    if truckBlip then RemoveBlip(truckBlip) end
    truckBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(truckBlip, 477)
    SetBlipColour(truckBlip, 5)
    SetBlipScale(truckBlip, 1.2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Bank Truck")
    EndTextCommandSetBlipName(truckBlip)
    QBCore.Functions.Notify("A bank truck has been spotted! Check your map!", "primary", 8000)

    RequestModel(truckModel)
    while not HasModelLoaded(truckModel) do Wait(10) end
    truck = CreateVehicle(truckModel, loc.x, loc.y, loc.z, loc.w, true, true)
    SetEntityAsMissionEntity(truck, true, true)
    SetVehicleDoorsLocked(truck, 2)
    SetVehicleNumberPlateText(truck, "BANK"..math.random(100,999))
    truckCoords = vector3(loc.x, loc.y, loc.z)
    truckHeading = loc.w

    RequestModel(guardModel)
    while not HasModelLoaded(guardModel) do Wait(10) end
    guards = {}
    for seat = -1, numGuards-2 do
        local ped = CreatePedInsideVehicle(truck, 4, guardModel, seat, true, false)
        GiveWeaponToPed(ped, GetHashKey(guardWeapon), 100, false, true)
        SetPedKeepTask(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCombatAttributes(ped, 46, true)
        table.insert(guards, ped)
    end

    doorsBlown = false
    Citizen.CreateThread(function()
        local idx = 1
        while truck and DoesEntityExist(truck) and not doorsBlown do
            local dest = patrolRoute[idx]
            TaskVehicleDriveToCoord(guards[1], truck, dest.x, dest.y, dest.z, 25.0, 0, GetEntityModel(truck), 786603, 1.0, true)
            repeat
                Wait(1000)
                if #(GetEntityCoords(truck) - dest) < 10.0 then break end
            until doorsBlown
            idx = idx + 1
            if idx > #patrolRoute then idx = 1 end
        end
    end)
    Citizen.CreateThread(TruckInteractionThread)
    Citizen.CreateThread(GuardExitAttackThread)
end)

function TruckInteractionThread()
    while truck and DoesEntityExist(truck) do
        Wait(0)
        local ply = PlayerPedId()
        local backPos = GetOffsetFromEntityInWorldCoords(truck, 0.0, -4.0, 0.0)
        if not doorsBlown then
            if IsPedShooting(ply) and #(GetEntityCoords(ply) - backPos) < 5.0 then
                truckDoorHealth = truckDoorHealth - 20
                if truckDoorHealth <= 0 then
                    doorsBlown = true
                    SetVehicleDoorBroken(truck, 2, true)
                    SetVehicleDoorBroken(truck, 3, true)
                    QBCore.Functions.Notify("Doors destroyed! Press E to enter.", "success", 4000)
                end
                Wait(500)
            end
        elseif not insideShell then
            if #(GetEntityCoords(ply) - backPos) < 2.0 then
                DrawText3D(backPos.x, backPos.y, backPos.z + 1.0, "[E] Enter the truck")
                if IsControlJustReleased(0, 38) then
                    TriggerEvent("qb-banktruck:client:enterShell")
                    break
                end
            end
        end
    end
end

function GuardExitAttackThread()
    while truck and DoesEntityExist(truck) do
        Wait(1000)
        if doorsBlown then
            for _, ped in ipairs(guards) do
                if DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
                    TaskLeaveVehicle(ped, truck, 256)
                    Wait(1000)
                    TaskCombatPed(ped, PlayerPedId(), 0, 16)
                end
            end
            break
        end
    end
end

--------------------------
-- SHELL LOGIC (SPAWN SHELL OBJECT)
--------------------------
RegisterNetEvent("qb-banktruck:client:enterShell", function()
    playerPrevPos = GetEntityCoords(PlayerPedId())
    playerPrevHeading = GetEntityHeading(PlayerPedId())
    insideShell = true
    DoScreenFadeOut(500)
    Wait(700)
    local model = Config.ShellModel or "k4mb1_heist_van"
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local shellSpawn = vector3(1091.19, -3195.17, 51.86)
    shellObject = CreateObject(GetHashKey(model), shellSpawn, false, false, false)
    SetEntityHeading(shellObject, 0.0)
    SetEntityAsMissionEntity(shellObject, true, true)
    FreezeEntityPosition(shellObject, true)
    SetEntityCoords(PlayerPedId(), 1091.19, -3195.17, 52.26)
    SetEntityHeading(PlayerPedId(), 0.0)
    Wait(400)
    DoScreenFadeIn(500)
    QBCore.Functions.Notify("You are inside the vault! Use your third eye to interact with lootboxes.", "primary", 5000)
    setupBankTruckDrillLootZones()
    Citizen.CreateThread(ShellMenuThread)
end)

function ShellMenuThread()
    while insideShell do
        Wait(0)
        local ply = PlayerPedId()
        if #(GetEntityCoords(ply) - vector3(1091.19, -3195.17, 52.26)) < 2.5 then
            DrawText3D(1091.19, -3195.17, 52.6, "[E] Exit")
            if IsControlJustReleased(0, 38) then
                DoScreenFadeOut(500)
                Wait(700)
                if playerPrevPos then
                    SetEntityCoords(ply, playerPrevPos.x, playerPrevPos.y, playerPrevPos.z)
                    SetEntityHeading(ply, playerPrevHeading or 0.0)
                else
                    SetEntityCoords(ply, 1088.7, -3196.6, 30.0)
                end
                if shellObject and DoesEntityExist(shellObject) then DeleteEntity(shellObject) end
                shellObject = nil
                insideShell = false
                CleanupBankTruckDrillLootZones()
                Wait(400)
                DoScreenFadeIn(500)
                QBCore.Functions.Notify("You exited the truck.", "primary", 3000)
                break
            end
        end
    end
end

--------------------------
-- LOOTBOXES WITH CONFIGURABLE REWARD LOGIC
--------------------------
local drilledBoxes = {}
local banktruckDrillZones = {}

function setupBankTruckDrillLootZones()
    CleanupBankTruckDrillLootZones()
    for _, box in ipairs(Config.LootBoxes) do
        drilledBoxes[box.name] = drilledBoxes[box.name] or false
        if not banktruckDrillZones[box.name] then
            banktruckDrillZones[box.name] = exports['qb-target']:AddBoxZone(box.name, box.coords, 0.35, 0.35, {
                name = box.name,
                heading = 0,
                debugPoly = false,
                minZ = box.coords.z - 0.25,
                maxZ = box.coords.z + 0.25,
            }, {
                options = {
                    {
                        label = "Lockpick Lootbox",
                        icon = "fas fa-lock",
                        action = function()
                            if drilledBoxes[box.name] then
                                QBCore.Functions.Notify("Already looted.", "error")
                                return
                            end
                            local ped = PlayerPedId()
                            -- Only play animation once before progressbar/minigame
                            RequestAnimDict("amb@prop_human_bum_bin@base")
                            while not HasAnimDictLoaded("amb@prop_human_bum_bin@base") do Wait(10) end
                            TaskPlayAnim(ped, "amb@prop_human_bum_bin@base", "base", 8.0, -8.0, 5000, 1, 0, false, false, false)
                            QBCore.Functions.Progressbar("lockpicking_lootbox", "Lockpicking...", 5000, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function()
                                ClearPedTasks(ped)
                                TriggerEvent("qb-lock:client:openLockpick", function(success)
                                    if success then
                                        drilledBoxes[box.name] = true
                                        QBCore.Functions.Notify("Success! Looting...", "success")
                                        -- Debug print for loot event
                                        print("[Banktruck:loot:giveItems] Triggering for box:", box.name)
                                        -- Only send box name, NOT reward table!
                                        TriggerServerEvent("banktruck:loot:giveItems", box.name)
                                    else
                                        QBCore.Functions.Notify("You failed the lockpick.", "error")
                                    end
                                end, true)
                            end, function()
                                ClearPedTasks(ped)
                                QBCore.Functions.Notify("You stopped lockpicking.", "error")
                            end)
                        end,
                        canInteract = function()
                            return not drilledBoxes[box.name]
                        end,
                        distance = 1.5
                    }
                },
                distance = 2.0,
            })
        end
    end
end

function CleanupBankTruckDrillLootZones()
    for _, box in ipairs(Config.LootBoxes) do
        if banktruckDrillZones[box.name] then
            exports['qb-target']:RemoveZone(box.name)
            banktruckDrillZones[box.name] = nil
        end
        drilledBoxes[box.name] = nil
    end
end

--------------------------
-- RESOURCE CLEANUP
--------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if meetNPC and DoesEntityExist(meetNPC) then DeleteEntity(meetNPC) end
        if truck and DoesEntityExist(truck) then DeleteEntity(truck) end
        for _, ped in ipairs(guards) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
        if shellObject and DoesEntityExist(shellObject) then DeleteEntity(shellObject) end
        CleanupBankTruckDrillLootZones()
        if truckBlip then RemoveBlip(truckBlip) end
    end
end)