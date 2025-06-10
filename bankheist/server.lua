local QBCore = exports['qb-core']:GetCoreObject()

--------------------------
-- CONFIGURATION (Server-side only needs logic, not shell/prop details)
--------------------------
local MeetLocations = {
    { coords = vector3(1200.0, -3110.0, 5.0), heading = 90.0, model = "s_m_m_security_01" },
    { coords = vector3(1130.0, -3190.0, 5.0), heading = 180.0, model = "s_m_m_security_01" },
    { coords = vector3(1250.0, -3160.0, 5.0), heading = 270.0, model = "s_m_m_security_01" }
}

local TruckSpawn = {
    coords = vector4(1108.0, -3196.0, -39.9, 90.0),
    model = "stockade",
    guardModel = "s_m_m_security_01",
    guardWeapon = "weapon_smg",
    numGuards = 3,
    patrolRoute = {
        vector3(1130.0, -3180.0, -40.1),
        vector3(1145.0, -3200.0, -40.1),
        vector3(1120.0, -3210.0, -40.1),
        vector3(1100.0, -3185.0, -40.1)
    }
}

local MeetCooldown = 15 * 60 -- 15 minutes
local TruckCooldown = 45 * 60 -- 45 minutes
local lastMeet = 0
local lastTruck = 0

--------------------------
-- START MEET EVENT
--------------------------
RegisterNetEvent("qb-banktruck:server:startMeet", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if os.time() - lastMeet < MeetCooldown then
        TriggerClientEvent("QBCore:Notify", src, "The job broker is busy, try again later.", "error")
        return
    end

    lastMeet = os.time()
    local choice = math.random(1, #MeetLocations)
    local data = MeetLocations[choice]
    TriggerClientEvent("qb-banktruck:client:meetLocation", src, data.coords, data.heading, data.model)
end)

--------------------------
-- BUY TRUCK INFO
--------------------------
RegisterNetEvent("qb-banktruck:server:buyTruckInfo", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cost = 2000

    if os.time() - lastTruck < TruckCooldown then
        TriggerClientEvent("QBCore:Notify", src, "No trucks available right now, come back later.", "error")
        return
    end

    if Player.Functions.RemoveMoney('cash', cost, "banktruck-info") then
        lastTruck = os.time()
        local loc = TruckSpawn.coords
        TriggerClientEvent("qb-banktruck:client:spawnTruck", -1, loc, TruckSpawn.model, TruckSpawn.guardModel, TruckSpawn.guardWeapon, TruckSpawn.numGuards, TruckSpawn.patrolRoute)
        TriggerClientEvent("QBCore:Notify", src, "Truck location purchased! Good luck.", "success", 6000)
    else
        TriggerClientEvent("QBCore:Notify", src, "You don't have enough cash.", "error")
    end
end)

--------------------------
-- GIVE LOOT ITEMS
--------------------------
RegisterNetEvent("banktruck:loot:giveItem", function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    Player.Functions.AddItem(item, amount, false, false, false)
    TriggerClientEvent("QBCore:Notify", src, ("Received %sx %s"):format(amount, item), "success", 3500)
end)

RegisterNetEvent("banktruck:loot:giveMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    Player.Functions.AddMoney('cash', amount, "banktruck-loot")
    TriggerClientEvent("QBCore:Notify", src, ("Received $%s cash"):format(amount), "success", 3500)
end)