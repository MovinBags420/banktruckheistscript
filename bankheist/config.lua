Config = {}

Config.PhoneBoothModels = {
    "prop_phonebox_01a",
    "prop_phonebox_02",
    "prop_phonebox_03",
    "prop_phonebox_04"
}

Config.MeetNPCs = {
    {
        coords = vector3(542.75, -1579.04, 29.28),
        heading = 50.84,
        model = "s_m_y_dealer_01"
    },
    {
        coords = vector3(-256.51, -1939.02, 29.95),
        heading = 132.81,
        model = "s_m_y_dealer_01"
    }
}

Config.TruckSpawns = {
    vector4(-2958.72, 493.05, 15.31, 89.11),
    vector4(784.52, -3103.21, 5.8, 341.01),
    vector4(-73.31, -615.45, 36.19, 341.58),
    vector4(1952.38, 3736.85, 32.34, 220.29),
    vector4(-132.03, 6466.75, 31.38, 136.79)
}

Config.BankTruckModel = "stockade"
Config.GuardModel = "s_m_y_swat_01"
Config.GuardWeapon = "WEAPON_CARBINERIFLE"
Config.NumGuards = 2
Config.TruckBlipTime = 60
Config.TruckLifeTime = 300
Config.InfoCost = 2000
Config.TruckDoorHealth = 400

Config.HeistCooldown = 1200
Config.HeistMaxTime = 1200

Config.ShellModel = "k4mb1_heist_van" -- Replace with your shell model if different
Config.ShellSpawn = vector3(1090.63, -3191.52, -116.16)
Config.ShellHeading = 359.06
Config.ShellExit = vector3(1090.63, -3191.52, -115.96)

Config.LootTable = {
    { type = "money", min = 5000, max = 15000 },
    { type = "item", item = "goldbar", min = 1, max = 3 },
    { type = "item", item = "rolex", min = 2, max = 6 }
}

Config.PatrolRoutes = {
    {
        vector3(-2958.72, 493.05, 15.31),
        vector3(-2733.59, 229.14, 16.63),
        vector3(-2325.96, 360.31, 174.6),
        vector3(-2228.45, -367.12, 13.32),
    },
    {
        vector3(784.52, -3103.21, 5.8),
        vector3(1181.54, -3193.81, 5.89),
        vector3(1320.12, -2551.13, 46.57),
        vector3(811.02, -2313.81, 29.51),
    },
    {
        vector3(143.13, -1062.75, 29.19),
        vector3(-73.33, -1102.14, 25.76),
        vector3(-265.69, -1164.31, 23.13),
        vector3(-532.45, -1247.12, 18.43),
    },
    {
        vector3(1952.38, 3736.85, 32.34),
        vector3(1738.54, 3707.81, 34.13),
        vector3(1720.12, 3291.13, 41.66),
        vector3(2000.02, 3191.81, 45.51),
    },
    {
        vector3(-132.03, 6466.75, 31.38),
        vector3(-245.33, 6192.14, 31.49),
        vector3(-452.69, 6144.31, 30.62),
        vector3(-246.45, 6087.12, 31.45),
    }
}