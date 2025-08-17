print("^2[DUEL] Server script chargé^7")

-- Système d'instances
local instances = {}
local nextInstanceId = 1

-- Fonction pour créer une nouvelle instance
function createInstance(playerId, arenaType)
    local instanceId = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    
    instances[instanceId] = {
        id = instanceId,
        owner = playerId,
        arena = arenaType,
        players = {playerId},
        created = os.time()
    }
    
    print("^3[DUEL] Instance " .. instanceId .. " créée pour le joueur " .. playerId .. " (arène: " .. arenaType .. ")^7")
    return instanceId
end

-- Fonction pour supprimer une instance
function deleteInstance(instanceId)
    if instances[instanceId] then
        local instance = instances[instanceId]
        print("^1[DUEL] Instance " .. instanceId .. " supprimée (propriétaire: " .. instance.owner .. ", arène: " .. instance.arena .. ")^7")
        instances[instanceId] = nil
    else
        print("^1[DUEL] Tentative de suppression d'une instance inexistante: " .. instanceId .. "^7")
    end
end

-- Fonction pour obtenir l'instance d'un joueur
function getPlayerInstance(playerId)
    for instanceId, instance in pairs(instances) do
        for _, pid in ipairs(instance.players) do
            if pid == playerId then
                return instanceId, instance
            end
        end
    end
    return nil, nil
end

-- Commande de test pour vérifier la communication client-serveur
print("^2[DUEL] Enregistrement de la commande testduel^7")
RegisterCommand('testduel', function(source, args, rawCommand)
    local playerName = GetPlayerName(source) or "Joueur " .. source
    print("^2[DUEL] Commande testduel reçue de " .. playerName .. " (ID: " .. source .. ")^7")
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DUEL]", "Communication serveur OK !"}
        })
    end
end, false)

-- Event pour rejoindre une arène (créer une instance)
print("^2[DUEL] Enregistrement de l'event duel:joinArena^7")
RegisterNetEvent('duel:joinArena')
AddEventHandler('duel:joinArena', function(weapon, map)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^2[DUEL] ========== EVENT JOINARENA SERVEUR ==========^7")
    print("^2[DUEL] Joueur: " .. playerName .. " (ID: " .. source .. ")^7")
    print("^2[DUEL] Paramètres reçus:^7")
    print("^2[DUEL]   weapon = " .. tostring(weapon) .. " (type: " .. type(weapon) .. ")^7")
    print("^2[DUEL]   map = " .. tostring(map) .. " (type: " .. type(map) .. ")^7")
    
    -- Vérifier que les paramètres sont valides
    if not weapon or not map then
        print("^1[DUEL] Paramètres invalides - weapon: " .. tostring(weapon) .. ", map: " .. tostring(map) .. "^7")
        return
    end
    
    print("^2[DUEL] Paramètres valides, vérification instance existante^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur " .. source .. " déjà dans l'instance " .. currentInstanceId .. "^7")
        -- Supprimer l'ancienne instance et en créer une nouvelle
        deleteInstance(currentInstanceId)
    else
        print("^2[DUEL] Aucune instance existante pour le joueur^7")
    end
    
    print("^2[DUEL] Création de la nouvelle instance^7")
    -- Créer une nouvelle instance privée
    local instanceId = createInstance(source, map)
    
    print("^2[DUEL] Instance " .. instanceId .. " créée avec succès pour " .. playerName .. "^7")
    print("^2[DUEL] Envoi de l'event duel:instanceCreated au client^7")
    
    -- Confirmer au client
    TriggerClientEvent('duel:instanceCreated', source, instanceId, weapon, map)
    
    print("^2[DUEL] ========== FIN EVENT JOINARENA ==========^7")
end)
print("^2[DUEL] Event duel:joinArena enregistré avec succès^7")

-- Event pour quitter une arène (supprimer l'instance)
RegisterNetEvent('duel:quitArena')
AddEventHandler('duel:quitArena', function()
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^3[DUEL] " .. playerName .. " (ID: " .. source .. ") quitte son arène^7")
    
    -- Trouver et supprimer l'instance du joueur
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        print("^3[DUEL] Suppression de l'instance " .. instanceId .. " pour le joueur " .. source .. "^7")
        deleteInstance(instanceId)
        TriggerClientEvent('duel:instanceDeleted', source)
    else
        print("^1[DUEL] Aucune instance trouvée pour le joueur " .. source .. "^7")
    end
end)

-- Nettoyer les instances quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur inconnu"
    
    print("^1[DUEL] " .. playerName .. " s'est déconnecté, nettoyage de son instance^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        print("^1[DUEL] Suppression de l'instance " .. instanceId .. " suite à déconnexion de " .. playerName .. "^7")
        deleteInstance(instanceId)
    else
        print("^3[DUEL] Aucune instance à nettoyer pour " .. playerName .. "^7")
    end
end)

-- Commande admin pour voir les instances actives
RegisterCommand('duel_instances', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, "command.duel_instances") then
        print("^2[DUEL] Instances actives:^7")
        local count = 0
        for instanceId, instance in pairs(instances) do
            count = count + 1
            local playerName = GetPlayerName(instance.owner) or "Joueur déconnecté"
            local timeElapsed = os.time() - instance.created
            print("^3  Instance " .. instanceId .. ": " .. playerName .. " (" .. instance.owner .. ") - Arène: " .. instance.arena .. "^7")
            print("^3    Créée il y a " .. timeElapsed .. " secondes^7")
        end
        if count == 0 then
            print("^1  Aucune instance active^7")
        end
        
        if source ~= 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"[DUEL]", count .. " instance(s) active(s). Voir console F8 pour détails."}
            })
        end
    end
end, false)

-- Nettoyage automatique des instances anciennes (toutes les 2 heures)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(7200000) -- 2 heures
        
        local currentTime = os.time()
        local toDelete = {}
        
        for instanceId, instance in pairs(instances) do
            -- Supprimer les instances de plus de 2 heures
            if currentTime - instance.created > 7200 then
                table.insert(toDelete, instanceId)
            end
        end
        
        for _, instanceId in ipairs(toDelete) do
            print("^1[DUEL] Instance " .. instanceId .. " supprimée automatiquement (trop ancienne - plus de 2h)^7")
            -- Informer le joueur que son instance a été supprimée
            local instance = instances[instanceId]
            if instance and instance.owner then
                TriggerClientEvent('duel:instanceDeleted', instance.owner)
            end
            deleteInstance(instanceId)
        end
    end
end)

print("^2[DUEL] Server script complètement initialisé^7")