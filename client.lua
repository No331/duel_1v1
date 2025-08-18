
local isMenuOpen = false
local inDuel = false
local currentInstanceId = nil
local originalCoords = nil
local currentArena = nil
local selectedWeapon = nil
local currentRounds = {
    currentRound = 0,
    maxRounds = 5,
    showRoundCounter = false
}
local isWaitingForRespawn = false

-- Point d'interaction
local interactionPoint = vector3(256.3, -776.82, 30.88)

-- Coordonnées des arènes avec zones limitées (50m de rayon)
local arenas = {
    aeroport = {
        center = vector3(-1037.0, -2737.0, 20.0),
        radius = 50.0,
        name = "AEROPORT",
        spawns = {
            vector3(-1050.0, -2750.0, 20.0),
            vector3(-1024.0, -2724.0, 20.0)
        }
    },
    ["dans l'eau"] = {
        center = vector3(-1308.0, 6636.0, 5.0),
        radius = 50.0,
        name = "DANS L'EAU",
        spawns = {
            vector3(-1320.0, 6650.0, 5.0),
            vector3(-1296.0, 6622.0, 5.0)
        }
    },
    foret = {
        center = vector3(-1617.0, 4445.0, 3.0),
        radius = 50.0,
        name = "FORET",
        spawns = {
            vector3(-1630.0, 4460.0, 3.0),
            vector3(-1604.0, 4430.0, 3.0)
        }
    },
    hippie = {
        center = vector3(2450.0, 3757.0, 41.0),
        radius = 50.0,
        name = "HIPPIE",
        spawns = {
            vector3(2435.0, 3770.0, 41.0),
            vector3(2465.0, 3744.0, 41.0)
        }
    }
}

-- Thread principal pour le marker
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - interactionPoint)
        
        -- Afficher le marker si pas en duel et proche
        if not inDuel and distance < 100.0 then
            DrawMarker(1, interactionPoint.x, interactionPoint.y, interactionPoint.z - 1.0, 
                      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                      3.0, 3.0, 1.0, 
                      0, 150, 255, 200, 
                      false, true, 2, false, nil, nil, false)
        end
        
        -- Interaction proche
        if not inDuel and distance < 3.0 then
            -- Affichage permanent du message E
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de duel")
            EndTextCommandDisplayHelp(0, false, false, -1)
            
            if IsControlJustPressed(1, 38) and not isMenuOpen then
                openDuelMenu()
            end
        end
        
        Citizen.Wait(0)
    end
end)

-- Thread pour vérifier les limites de zone en duel
Citizen.CreateThread(function()
    while true do
        if inDuel and currentArena then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local arena = arenas[currentArena]
            
            if arena then
                local distance = #(playerCoords - arena.center)
                
                -- Dessiner le cercle de limite en rouge permanent et visible
                DrawMarker(1, arena.center.x, arena.center.y, arena.center.z - 1.0,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 1.0,
                          255, 0, 0, 100,
                          false, true, 2, false, nil, nil, false)
                
                -- Dessiner aussi un cercle au sol pour bien voir la limite
                DrawMarker(25, arena.center.x, arena.center.y, arena.center.z,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 2.0,
                          255, 0, 0, 80,
                          false, true, 2, false, nil, nil, false)
                
                -- Si le joueur dépasse la limite
                if distance > arena.radius then
                    SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
                    
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"[DUEL]", "Vous avez dépassé la zone de combat ! Retour au centre."}
                    })
                end
                
                -- Afficher le message pour quitter (permanent)
                if not isWaitingForRespawn then
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour quitter le duel")
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
                
                -- Afficher le compteur de manches en bas à droite
                if currentRounds.showRoundCounter then
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextScale(0.8, 0.8)
                    SetTextColour(255, 255, 255, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextRightJustify(true)
                    SetTextWrap(0.0, 0.95)
                    SetTextEntry("STRING")
                    
                    local scoreText = "MANCHE " .. currentRounds.currentRound .. "/" .. currentRounds.maxRounds
                    
                    AddTextComponentString(scoreText)
                    DrawText(0.95, 0.85)
                end
            end
        end
        
        Citizen.Wait(0)
    end
end)

-- Thread pour gérer la touche E pour quitter le duel
Citizen.CreateThread(function()
    while true do
        if inDuel and not isWaitingForRespawn then
            if IsControlJustPressed(1, 38) then
                quitDuel()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Thread pour gérer la mort et le respawn automatique
Citizen.CreateThread(function()
    while true do
        if inDuel then
            local playerPed = PlayerPedId()
            
            -- Détecter la mort (santé <= 0 ou IsPedDeadOrDying)
            if (IsPedDeadOrDying(playerPed, true) or GetEntityHealth(playerPed) <= 100) and not isWaitingForRespawn then
                isWaitingForRespawn = true
                
                -- Trouver qui a tué le joueur
                local killer = GetPedSourceOfDeath(playerPed)
                local killerPlayerId = nil
                
                if killer ~= 0 and killer ~= playerPed then
                    -- Chercher le joueur correspondant au killer
                    for i = 0, 255 do
                        if NetworkIsPlayerActive(i) then
                            local otherPed = GetPlayerPed(i)
                            if otherPed == killer then
                                killerPlayerId = i
                                break
                            end
                        end
                    end
                end
                
                -- Signaler la mort au serveur
                TriggerServerEvent('duel:playerDied', killerPlayerId)
                
                -- Attendre 2-3 secondes (temps de ragdoll)
                Citizen.SetTimeout(2500, function()
                    if inDuel then
                        respawnPlayer()
                    end
                end)
            end
        end
        
        Citizen.Wait(100)
    end
end)

-- Fonction pour respawn le joueur
function respawnPlayer()
    if not inDuel or not currentArena then return end
    
    local arena = arenas[currentArena]
    if not arena then return end
    
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    
    -- Choisir un spawn aléatoire
    local spawnIndex = math.random(1, #arena.spawns)
    local spawnPos = arena.spawns[spawnIndex]
    
    -- Forcer la résurrection
    NetworkResurrectLocalPlayer(spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    
    -- Attendre que le joueur soit respawné
    Citizen.Wait(100)
    
    local newPed = PlayerPedId()
    SetEntityCoords(newPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
    
    -- Ne pas appliquer de variations de ped pour éviter les erreurs
    -- Le joueur garde son apparence par défaut
    
    -- Heal complet + kevlar max
    SetEntityHealth(newPed, 200)
    SetPedArmour(newPed, 100)
    ClearPedBloodDamage(newPed)
    
    -- Redonner l'arme avec les bonnes munitions
    local weapons = {
        pistol = "WEAPON_PISTOL",
        combat_pistol = "WEAPON_COMBATPISTOL",
        heavy_pistol = "WEAPON_HEAVYPISTOL",
        vintage_pistol = "WEAPON_VINTAGEPISTOL"
    }
    
    RemoveAllPedWeapons(newPed, true)
    local weaponHash = GetHashKey(weapons[selectedWeapon] or weapons.pistol)
    GiveWeaponToPed(newPed, weaponHash, 250, false, true)
    SetCurrentPedWeapon(newPed, weaponHash, true)
    
    isWaitingForRespawn = false
end

-- Fonction pour ouvrir le menu
function openDuelMenu()
    local playerPed = PlayerPedId()
    originalCoords = GetEntityCoords(playerPed)
    
    isMenuOpen = true
    SetNuiFocus(true, true)
    
    TriggerServerEvent('duel:getAvailableArenas')
    
    SendNUIMessage({
        type = "openMenu"
    })
end

-- Fonction pour fermer le menu
function closeDuelMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Fonction pour quitter le duel
function quitDuel()
    
    -- Enlever le kevlar
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 0)
    
    enablePlayerPermissions()
    
    TriggerServerEvent('duel:quitArena')
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté l'arène et êtes retourné au point de départ."}
    })
end

-- Fonction pour désactiver les permissions du joueur
function disablePlayerPermissions()
    
    Citizen.CreateThread(function()
        while inDuel do
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 288, true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 166, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 74, true)
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 244, true)
            
            Citizen.Wait(0)
        end
    end)
end

-- Fonction pour réactiver les permissions du joueur
function enablePlayerPermissions()
end

-- Callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    closeDuelMenu()
    cb('ok')
end)

RegisterNUICallback('createArena', function(data, cb)
    
    if not data.weapon or not data.map then
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    closeDuelMenu()
    
    TriggerServerEvent('duel:createArena', data.weapon, data.map)
    
    cb('ok')
end)

RegisterNUICallback('joinSpecificArena', function(data, cb)
    
    if not data.arenaId or not data.weapon then
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    closeDuelMenu()
    
    TriggerServerEvent('duel:joinSpecificArena', data.arenaId, data.weapon)
    
    cb('ok')
end)

-- Échapper pour fermer le menu
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            if IsControlJustPressed(1, 322) then
                closeDuelMenu()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Event pour heal le joueur au début d'une nouvelle manche
RegisterNetEvent('duel:healPlayer')
AddEventHandler('duel:healPlayer', function()
    if inDuel then
        local playerPed = PlayerPedId()
        SetEntityHealth(playerPed, 200)
        SetPedArmour(playerPed, 100)
        
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 255},
            multiline = true,
            args = {"[DUEL]", "Nouvelle manche ! Santé et kevlar restaurés."}
        })
    end
end)

-- Event reçu quand une instance est créée
RegisterNetEvent('duel:instanceCreated')
AddEventHandler('duel:instanceCreated', function(instanceId, weapon, map)
    
    inDuel = true
    currentInstanceId = instanceId
    currentArena = map
    isWaitingForRespawn = false
    
    disablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    local arena = arenas[map]
    
    if arena then
        -- Spawn à une position spécifique selon l'ordre d'arrivée
        local spawnPos = arena.spawns[1] -- Premier spawn par défaut
        SetEntityCoords(playerPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
        
        -- Heal complet + kevlar max à l'entrée
        SetEntityHealth(playerPed, 200)
        SetPedArmour(playerPed, 100)
        
        local weapons = {
            pistol = "WEAPON_PISTOL",
            combat_pistol = "WEAPON_COMBATPISTOL",
            heavy_pistol = "WEAPON_HEAVYPISTOL",
            vintage_pistol = "WEAPON_VINTAGEPISTOL"
        }
        
        RemoveAllPedWeapons(playerPed, true)
        
        local weaponHash = GetHashKey(weapons[weapon] or weapons.pistol)
        GiveWeaponToPed(playerPed, weaponHash, 250, false, true)
        
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DUEL]", "Vous êtes dans l'arène " .. arena.name .. " ! En attente d'un adversaire..."}
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Erreur: Arène non trouvée"}
        })
    end
end)

-- Event reçu quand une instance est supprimée
RegisterNetEvent('duel:instanceDeleted')
AddEventHandler('duel:instanceDeleted', function()
    
    enablePlayerPermissions()
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    
    -- Enlever le kevlar à la sortie
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 0)
    
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté votre instance privée et êtes retourné au point de départ."}
    })
end)

-- Event reçu pour mettre à jour la liste des arènes disponibles
RegisterNetEvent('duel:updateAvailableArenas')
AddEventHandler('duel:updateAvailableArenas', function(arenas)
    
    SendNUIMessage({
        type = "updateArenas",
        arenas = arenas
    })
end)

-- Event reçu quand un adversaire rejoint
RegisterNetEvent('duel:opponentJoined')
AddEventHandler('duel:opponentJoined', function(opponentName)
    -- Activer l'affichage du compteur de manches
    currentRounds.showRoundCounter = true
    currentRounds.currentRound = 0
    currentRounds.maxRounds = 5
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", opponentName .. " a rejoint l'arène ! Le duel commence dans 3 secondes..."}
    })
    
    -- Compte à rebours avec affichage à l'écran
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        args = {"[DUEL]", "3..."}
    })
    
    -- Affichage grand écran pour le compte à rebours
    Citizen.CreateThread(function()
        -- 3
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 1000 do
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(3.0, 3.0)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString("3")
            DrawText(0.5, 0.4)
            Citizen.Wait(0)
        end
    end)
    
    Citizen.SetTimeout(1000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "2..."}
        })
        
        -- Affichage grand écran pour 2
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1000 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(3.0, 3.0)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("2")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
    
    Citizen.SetTimeout(2000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "1..."}
        })
        
        -- Affichage grand écran pour 1
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1000 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(3.0, 3.0)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("1")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
    
    Citizen.SetTimeout(3000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            args = {"[DUEL]", "GO !"}
        })
        
        -- Affichage grand écran pour GO
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1500 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(4.0, 4.0)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("GO !")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
end)

-- Event pour mettre à jour le compteur de manches
RegisterNetEvent('duel:updateRoundCounter')
AddEventHandler('duel:updateRoundCounter', function(currentRound, maxRounds)
    currentRounds.currentRound = currentRound
    currentRounds.maxRounds = maxRounds
    currentRounds.showRoundCounter = true
end)