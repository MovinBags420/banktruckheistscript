local QBCore = exports['qb-core']:GetCoreObject()

--------------------------
-- CONFIGURATION
--------------------------
local PhoneBoothModels = {
    "prop_phonebox_01",
    "prop_phonebox_02",
    "prop_phonebox_03",
    "prop_phonebox_04"
}

-- Shell configuration
local Config = {}
Config.ShellModel = "k4mb1_heist_van" -- DO NOT CHANGE UNLESS REQUESTED
Config.ShellSpawn = vector3(1088.7, -3196.6, -114.0)
Config.ShellExit = vector3(1088.7, -3196.6, -113.8)
Config.ShellHeading = 270.0

--------------------------
-- STATE FOR EXIT POSITION
--------------------------
local playerPrevPos = nil
local playerPrevHeading = nil

--------------------------
-- PHONEBOOTH THIRD EYE
--------------------------
Citizen.CreateThread(function()
    for _, model in ipairs(PhoneBoothModels) do
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
-- HEIST STATE
--------------------------
local meetNPC
local truck
local truckBlip
local guards = {}
local truckCoords, truckHeading
local doorsBlown, insideShell = false, false
local shellObject
local patrolRoute = {
    vector3(1130.0, -3180.0, -40.1),
    vector3(1145.0, -3200.0, -40.1),
    vector3(1120.0, -3210.0, -40.1),
    vector3(1100.0, -3185.0, -40.1)
}
local truckDoorHealth = 60

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
                label = "Buy Truck Location ($2000)"
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
RegisterNetEvent("qb-banktruck:client:spawnTruck", function(loc, truckModel, guardModel, guardWeapon, numGuards, route)
    -- Blip
    if truckBlip then RemoveBlip(truckBlip) end
    truckBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(truckBlip, 477)
    SetBlipColour(truckBlip, 5)
    SetBlipScale(truckBlip, 1.2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Bank Truck")
    EndTextCommandSetBlipName(truckBlip)
    QBCore.Functions.Notify("A bank truck has been spotted! Check your map!", "primary", 8000)

    -- Truck
    RequestModel(truckModel)
    while not HasModelLoaded(truckModel) do Wait(10) end
    truck = CreateVehicle(truckModel, loc.x, loc.y, loc.z, loc.w, true, true)
    SetEntityAsMissionEntity(truck, true, true)
    SetVehicleDoorsLocked(truck, 2)
    SetVehicleNumberPlateText(truck, "BANK"..math.random(100,999))
    truckCoords = vector3(loc.x, loc.y, loc.z)
    truckHeading = loc.w

    -- Guards
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
            local dest = route[idx]
            TaskVehicleDriveToCoord(guards[1], truck, dest.x, dest.y, dest.z, 25.0, 0, GetEntityModel(truck), 786603, 1.0, true)
            repeat
                Wait(1000)
                if #(GetEntityCoords(truck) - dest) < 10.0 then break end
            until doorsBlown
            idx = idx + 1
            if idx > #route then idx = 1 end
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
-- SHELL LOGIC
--------------------------
RegisterNetEvent("qb-banktruck:client:enterShell", function()
    -- Save previous position for safe exit
    playerPrevPos = GetEntityCoords(PlayerPedId())
    playerPrevHeading = GetEntityHeading(PlayerPedId())
    insideShell = true
    DoScreenFadeOut(500)
    Wait(700)
    RequestModel(Config.ShellModel)
    while not HasModelLoaded(Config.ShellModel) do Wait(10) end
    shellObject = CreateObject(GetHashKey(Config.ShellModel), Config.ShellSpawn, false, false, false)
    SetEntityHeading(shellObject, Config.ShellHeading)
    SetEntityAsMissionEntity(shellObject, true, true)
    FreezeEntityPosition(shellObject, true)
    SetEntityCoords(PlayerPedId(), Config.ShellExit)
    SetEntityHeading(PlayerPedId(), Config.ShellHeading)
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
        if #(GetEntityCoords(ply) - Config.ShellExit) < 2.0 then
            DrawText3D(Config.ShellExit.x, Config.ShellExit.y, Config.ShellExit.z+1.0, "[E] Exit")
            if IsControlJustReleased(0, 38) then
                DoScreenFadeOut(500)
                Wait(700)
                if playerPrevPos then
                    SetEntityCoords(ply, playerPrevPos.x, playerPrevPos.y, playerPrevPos.z)
                    SetEntityHeading(ply, playerPrevHeading or 0.0)
                else
                    SetEntityCoords(ply, 1088.7, -3196.6, 30.0) -- fallback to street
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
-- LOOT BOXES (qb-target BoxZone + drill/loot logic, only third eye)
--------------------------
local drilledBoxes = {}
local banktruckDrillZones = {}

local DrillLootSpots = {
    -- Top row
    {
        coords = vector3(1086.54, -3196.01, -112.34),
        name = "banktruck_lootbox_1",
        loot = { item = "goldbar", min = 1, max = 2 }
    },
    {
        coords = vector3(1087.33, -3195.99, -112.34),
        name = "banktruck_lootbox_2",
        loot = { item = "rolex", min = 2, max = 4 }
    },
    {
        coords = vector3(1087.48, -3197.48, -112.34),
        name = "banktruck_lootbox_3",
        loot = { item = "diamond", min = 1, max = 2 }
    },
    {
        coords = vector3(1086.7, -3197.45, -112.34),
        name = "banktruck_lootbox_4",
        loot = { item = "markedbills", min = 3, max = 7 }
    },
    -- Bottom row (.17 lower in Z)
    {
        coords = vector3(1086.54, -3196.01, -112.51),
        name = "banktruck_lootbox_5",
        loot = { item = "goldbar", min = 1, max = 2 }
    },
    {
        coords = vector3(1087.33, -3195.99, -112.51),
        name = "banktruck_lootbox_6",
        loot = { item = "rolex", min = 2, max = 4 }
    },
    {
        coords = vector3(1087.48, -3197.48, -112.51),
        name = "banktruck_lootbox_7",
        loot = { item = "diamond", min = 1, max = 2 }
    },
    {
        coords = vector3(1086.7, -3197.45, -112.51),
        name = "banktruck_lootbox_8",
        loot = { item = "markedbills", min = 3, max = 7 }
    },
}

function setupBankTruckDrillLootZones()
    for _, box in ipairs(DrillLootSpots) do
        drilledBoxes[box.name] = drilledBoxes[box.name] or false
        if not banktruckDrillZones[box.name] then
            banktruckDrillZones[box.name] = exports['qb-target']:AddBoxZone(box.name, box.coords, 0.2, 0.2, {
                name = box.name,
                heading = 0,
                debugPoly = false,
                minZ = box.coords.z - 0.5,
                maxZ = box.coords.z + 0.5,
            }, {
                options = {
                    {
                        label = "Drill Safety Box",
                        icon = "fas fa-drill",
                        action = function()
                            local ply = PlayerPedId()
                            if not drilledBoxes[box.name] then
                                -- Spawn drill prop and attach to hand (flipped 180 degrees)
                                local drillModel = "hei_prop_heist_drill"
                                RequestModel(drillModel)
                                while not HasModelLoaded(drillModel) do Wait(10) end
                                local drillObj = CreateObject(GetHashKey(drillModel), GetEntityCoords(ply), true, true, true)
                                -- Attach to right hand and flip 180 degrees (Z + 180)
                                AttachEntityToEntity(drillObj, ply, GetPedBoneIndex(ply, 57005), 0.13, 0.03, -0.02, 90.0, 90.0, 0.0, true, true, false, true, 1, true)

                                -- Play drill sound (use xSound or native PlaySoundFromEntity)
                                TriggerEvent("qb-banktruck:client:playDrillSound", drillObj)

                                QBCore.Functions.Progressbar("drill_loot_box", "Drilling open the box...", 7500, false, true, {
                                    disableMovement = true,
                                    disableCarMovement = true,
                                    disableMouse = false,
                                    disableCombat = true,
                                }, {
                                    animDict = "anim@heists@fleeca_bank@drilling",
                                    anim = "drill_straight_idle",
                                    flags = 49,
                                }, {}, {}, function()
                                    drilledBoxes[box.name] = true
                                    local amt = math.random(box.loot.min, box.loot.max)
                                    TriggerServerEvent("banktruck:loot:giveItem", box.loot.item, amt)
                                    QBCore.Functions.Notify("You found "..amt.."x "..box.loot.item.."!", "success", 3000)
                                    ClearPedTasks(ply)
                                    -- Remove drill prop
                                    DeleteEntity(drillObj)
                                    -- Stop drill sound
                                    TriggerEvent("qb-banktruck:client:stopDrillSound")
                                end, function()
                                    QBCore.Functions.Notify("You stopped drilling.", "error", 2000)
                                    ClearPedTasks(ply)
                                    -- Remove drill prop
                                    DeleteEntity(drillObj)
                                    -- Stop drill sound
                                    TriggerEvent("qb-banktruck:client:stopDrillSound")
                                end)
                            else
                                QBCore.Functions.Notify("This box is already looted.", "error", 2000)
                            end
                        end,
                        canInteract = function()
                            return insideShell and not drilledBoxes[box.name]
                        end,
                        distance = 1.5
                    }
                },
                distance = 1.5,
            })
        end
    end
end

-- Drill sound logic using xSound (recommended) or natives
local drillSoundId = nil

RegisterNetEvent("qb-banktruck:client:playDrillSound", function(entity)
    -- Use xSound if available
    if exports['xsound'] then
        local pos = GetEntityCoords(entity)
        exports['xsound']:PlayUrlPos("banktruck_drill", "sounds/drill.ogg", 0.4, pos)
        exports['xsound']:Distance("banktruck_drill", 2.0)
    else
        -- Fallback: Use PlaySoundFromEntity (must add drill.ogg as audio in GTA or use a default sound)
        drillSoundId = GetSoundId()
        PlaySoundFromEntity(drillSoundId, "DRILL", entity, 0, 0, 0)
    end
end)

RegisterNetEvent("qb-banktruck:client:stopDrillSound", function()
    if exports['xsound'] then
        if exports['xsound'].destroy then
            exports['xsound']:destroy("banktruck_drill")
        elseif exports['xsound'].Destroy then
            exports['xsound']:Destroy("banktruck_drill")
        end
    end
end)

function CleanupBankTruckDrillLootZones()
    for _, box in ipairs(DrillLootSpots) do
        exports['qb-target']:RemoveZone(box.name)
        drilledBoxes[box.name] = nil
        banktruckDrillZones[box.name] = nil
    end
end

--------------------------
-- UTILITY
--------------------------
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
-- CLEANUP ON RESOURCE STOP
--------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if meetNPC and DoesEntityExist(meetNPC) then DeleteEntity(meetNPC) end
        if truck and DoesEntityExist(truck) then DeleteEntity(truck) end
        for _, ped in ipairs(guards) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
        if shellObject and DoesEntityExist(shellObject) then DeleteEntity(shellObject) end
        CleanupBankTruckDrillLootZones()
        if truckBlip then RemoveBlip(truckBlip) end
        TriggerEvent("qb-banktruck:client:stopDrillSound")
    end
end)