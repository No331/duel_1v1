print("^2[DUEL] Client script chargé^7")

local isMenuOpen = false
local inDuel = false
local currentInstanceId = nil
local originalCoords = nil
local currentArena = nil
local selectedWeapon = nil

-- Point d'interaction
local interactionPoint = vector3(256.3, -776.82, 30.88)

-- Coordonnées des arènes avec zones limitées (50m de rayon)
local arenas = {
    aeroport = {
        center = vector3(-1037.0, -2737.0, 20.0),
        radius = 50.0,
        name = "AEROPORT"
    },
    ["dans l'eau"] = {
        center = vector3(-1308.0, 6636.0, 5.0),
        radius = 50.0,
        name = "DANS L'EAU"
    },
    foret = {
        center = vector3(-1617.0, 4445.0, 3.0),
        radius = 50.0,
        name = "FORET"
    },
    hippie = {
        center = vector3(2450.0, 3757.0, 41.0),
        radius = 50.0,
        name = "HIPPIE"
    }
}

-- Thread principal pour le marker
Citizen.CreateThread(function()
    print("^2[DUEL] Thread marker démarré^7")
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
            SetTextComponentFormat("STRING")
            AddTextComponentString("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de duel")
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            
            if IsControlJustPressed(1, 38) and not isMenuOpen then
                print("^3[DUEL] Touche E pressée^7")
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
                
                -- Dessiner le cercle de limite
                DrawMarker(1, arena.center.x, arena.center.y, arena.center.z - 1.0,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 1.0,
                          255, 0, 0, 50,
                          false, true, 2, false, nil, nil, false)
                
                -- Si le joueur dépasse la limite
                if distance > arena.radius then
                    print("^1[DUEL] Joueur hors limite, téléportation au centre^7")
                    SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
                    
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"[DUEL]", "Vous avez dépassé la zone de combat ! Retour au centre."}
                    })
                end
                
                -- Afficher le message pour quitter (permanent)
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour quitter le duel")
                EndTextCommandDisplayHelp(0, false, false, -1)
            end
        end
        
        Citizen.Wait(500)
    end
end)

-- Thread pour gérer la touche E pour quitter le duel
Citizen.CreateThread(function()
    while true do
        if inDuel then
            if IsControlJustPressed(1, 38) then
                print("^3[DUEL] Touche E pressée pour quitter le duel^7")
                quitDuel()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Thread pour gérer la mort et le respawn automatique
Citizen.CreateThread(function()
    local wasAlive = true
    
    while true do
        if inDuel then
            local playerPed = PlayerPedId()
            local isAlive = not IsEntityDead(playerPed)
            
            -- Détecter le changement d'état (vivant -> mort)
            if wasAlive and not isAlive then
                print("^1[DUEL] Joueur mort détecté, respawn immédiat^7")
                
                -- Respawn immédiat
                if currentArena then
                    local arena = arenas[currentArena]
                    
                    if arena then
                        -- Position de respawn aléatoire dans l'arène
                        local spawnX = arena.center.x + math.random(-15, 15)
                        local spawnY = arena.center.y + math.random(-15, 15)
                        local spawnZ = arena.center.z
                        
                        -- Forcer la résurrection
                        NetworkResurrectLocalPlayer(spawnX, spawnY, spawnZ, 0.0, true, false)
                        
                        -- Attendre que le joueur soit respawné
                        Citizen.Wait(100)
                        
                        local newPed = PlayerPedId()
                        SetEntityCoords(newPed, spawnX, spawnY, spawnZ, false, false, false, true)
                        SetEntityHealth(newPed, 200)
                        SetPedArmour(newPed, 0)
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
                        
                        print("^2[DUEL] Joueur respawné immédiatement dans l'arène^7")
                        
                        TriggerEvent('chat:addMessage', {
                            color = {255, 165, 0},
                            multiline = true,
                            args = {"[DUEL]", "Respawn dans l'arène !"}
                        })
                    end
                end
            end
            
            wasAlive = isAlive
        end
        
        Citizen.Wait(100)
    end
end)

-- Fonction pour ouvrir le menu
function openDuelMenu()
    print("^3[DUEL] Ouverture du menu^7")
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
    print("^3[DUEL] Fermeture du menu^7")
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Fonction pour quitter le duel
function quitDuel()
    print("^3[DUEL] Quitter le duel^7")
    
    enablePlayerPermissions()
    
    TriggerServerEvent('duel:quitArena')
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    
    local playerPed = PlayerPedId()
    
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
    print("^1[DUEL] Désactivation des permissions^7")
    
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
    print("^2[DUEL] Réactivation des permissions^7")
end

-- Callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    print("^2[DUEL] Callback closeMenu reçu^7")
    closeDuelMenu()
    cb('ok')
end)

RegisterNUICallback('createArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK CREATEARENA ==========^7")
    print("^3[DUEL] Données reçues: weapon=" .. tostring(data.weapon) .. ", map=" .. tostring(data.map) .. "^7")
    
    if not data.weapon or not data.map then
        print("^1[DUEL] Données manquantes^7")
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour créer l'arène^7")
    TriggerServerEvent('duel:createArena', data.weapon, data.map)
    
    cb('ok')
end)

RegisterNUICallback('joinSpecificArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK JOIN SPECIFIC ARENA ==========^7")
    print("^3[DUEL] Données reçues: arenaId=" .. tostring(data.arenaId) .. ", weapon=" .. tostring(data.weapon) .. "^7")
    
    if not data.arenaId or not data.weapon then
        print("^1[DUEL] Données manquantes^7")
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour rejoindre l'arène spécifique^7")
    TriggerServerEvent('duel:joinSpecificArena', data.arenaId, data.weapon)
    
    cb('ok')
end)

-- Échapper pour fermer le menu
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            if IsControlJustPressed(1, 322) then
                print("^3[DUEL] ESC pressé^7")
                closeDuelMenu()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Event reçu quand une instance est créée
RegisterNetEvent('duel:instanceCreated')
AddEventHandler('duel:instanceCreated', function(instanceId, weapon, map)
    print("^2[DUEL] Instance " .. tostring(instanceId) .. " créée pour arène '" .. tostring(map) .. "'^7")
    
    inDuel = true
    currentInstanceId = instanceId
    currentArena = map
    
    disablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    local arena = arenas[map]
    
    if arena then
        SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
        
        print("^2[DUEL] Téléportation vers " .. arena.name .. " (" .. arena.center.x .. ", " .. arena.center.y .. ", " .. arena.center.z .. ")^7")
        
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
        print("^1[DUEL] Arène '" .. tostring(map) .. "' non trouvée dans la liste des arènes^7")
        print("^1[DUEL] Arènes disponibles: aeroport, dans l'eau, foret, hippie^7")
    end
end)

-- Event reçu quand une instance est supprimée
RegisterNetEvent('duel:instanceDeleted')
AddEventHandler('duel:instanceDeleted', function()
    print("^1[DUEL] Instance supprimée^7")
    
    enablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté votre instance privée et êtes retourné au point de départ."}
    })
end)

-- Event reçu pour mettre à jour la liste des arènes disponibles
RegisterNetEvent('duel:updateAvailableArenas')
AddEventHandler('duel:updateAvailableArenas', function(arenas)
    print("^3[DUEL] Mise à jour des arènes disponibles: " .. #arenas .. " arène(s)^7")
    
    SendNUIMessage({
        type = "updateArenas",
        arenas = arenas
    })
end)

-- Event reçu quand un adversaire rejoint
RegisterNetEvent('duel:opponentJoined')
AddEventHandler('duel:opponentJoined', function(opponentName)
    print("^2[DUEL] Adversaire rejoint: " .. tostring(opponentName) .. "^7")
    
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

print("^2[DUEL] Client script complètement initialisé^7")