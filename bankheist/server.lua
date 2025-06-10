local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config

local lastMeet = 0
local lastTruck = 0

RegisterNetEvent("qb-banktruck:server:startMeet", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if os.time() - lastMeet < Config.HeistCooldown then
        TriggerClientEvent("QBCore:Notify", src, "The job broker is busy, try again later.", "error")
        return
    end

    lastMeet = os.time()
    local choice = math.random(1, #Config.MeetNPCs)
    local data = Config.MeetNPCs[choice]
    TriggerClientEvent("qb-banktruck:client:meetLocation", src, data.coords, data.heading, data.model)
end)

RegisterNetEvent("qb-banktruck:server:buyTruckInfo", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if os.time() - lastTruck < Config.HeistCooldown then
        TriggerClientEvent("QBCore:Notify", src, "No trucks available right now, come back later.", "error")
        return
    end

    if Player.Functions.RemoveMoney('cash', Config.InfoCost, "banktruck-info") then
        lastTruck = os.time()
        local spawnIdx = math.random(1, #Config.TruckSpawns)
        local loc = Config.TruckSpawns[spawnIdx]
        local patrolRoute = Config.PatrolRoutes[spawnIdx]
        TriggerClientEvent("qb-banktruck:client:spawnTruck", -1, loc, Config.BankTruckModel, Config.GuardModel, Config.GuardWeapon, Config.NumGuards, patrolRoute)
        TriggerClientEvent("QBCore:Notify", src, "Truck location purchased! Good luck.", "success", 6000)
    else
        TriggerClientEvent("QBCore:Notify", src, "You don't have enough cash.", "error")
    end
end)

RegisterNetEvent("banktruck:loot:giveItems", function(boxName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Find the lootbox config entry by name
    local boxConfig
    for _, box in ipairs(Config.LootBoxes) do
        if box.name == boxName then
            boxConfig = box
            break
        end
    end

    if not boxConfig or not boxConfig.rewards then
        TriggerClientEvent("QBCore:Notify", src, "No reward found for this lootbox.", "error")
        return
    end

    for _, reward in ipairs(boxConfig.rewards) do
        local min, max = reward.amount[1], reward.amount[2]
        local amount = math.random(min, max)
        Player.Functions.AddItem(reward.item, amount)
        TriggerClientEvent("QBCore:Notify", src, ("Received %sx %s"):format(amount, reward.item), "success", 3500)
    end
end)