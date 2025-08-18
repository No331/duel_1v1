
-- Système d'instances
local instances = {}
local nextInstanceId = 1

-- Configuration du système de manches
local MAX_ROUNDS = 5 -- Maximum 5 manches
local ROUNDS_TO_WIN = 3 -- Premier à 3 manches gagne

-- Fonction pour créer une nouvelle instance
function createInstance(playerId, arenaType, weapon)
    local instanceId = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    
    instances[instanceId] = {
        id = instanceId,
        creator = playerId,
        arena = arenaType,
        weapon = weapon,
        players = {playerId},
        maxPlayers = 2,
        status = "waiting", -- waiting, full, active
        created = os.time(),
        rounds = {
            player1Score = 0,
            player2Score = 0,
            currentRound = 0,
            maxRounds = 5,
            roundsToWin = ROUNDS_TO_WIN
        }
    }
    
    return instanceId
end

-- Fonction pour supprimer une instance
function deleteInstance(instanceId)
    if instances[instanceId] then
        local instance = instances[instanceId]
        instances[instanceId] = nil
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

-- Fonction pour obtenir les arènes disponibles (en attente de joueurs)
function getAvailableArenas()
    local available = {}
    for instanceId, instance in pairs(instances) do
        if instance.status == "waiting" and #instance.players < instance.maxPlayers then
            local creatorName = GetPlayerName(instance.creator) or ("Joueur " .. instance.creator)
            table.insert(available, {
                id = instanceId,
                creator = instance.creator,
                creatorName = creatorName,
                arena = instance.arena,
                weapon = instance.weapon,
                players = #instance.players,
                maxPlayers = instance.maxPlayers
            })
        end
    end
    return available
end

-- Fonction pour ajouter un joueur à une instance
function addPlayerToInstance(instanceId, playerId)
    local instance = instances[instanceId]
    if not instance then
        return false, "Instance non trouvée"
    end
    
    if #instance.players >= instance.maxPlayers then
        return false, "Instance pleine"
    end
    
    -- Vérifier que le joueur n'est pas déjà dans l'instance
    for _, pid in ipairs(instance.players) do
        if pid == playerId then
            return false, "Joueur déjà dans l'instance"
        end
    end
    
    table.insert(instance.players, playerId)
    
    -- Si l'instance est maintenant pleine, changer le statut
    if #instance.players >= instance.maxPlayers then
        instance.status = "full"
    end
    
    return true, "Joueur ajouté avec succès"
end

-- Fonction pour gérer la mort d'un joueur
function handlePlayerDeath(instanceId, deadPlayerId, killerPlayerId)
    
    local instance = instances[instanceId]
    if not instance then return end
    
    -- Vérifier qu'on a bien 2 joueurs
    if #instance.players < 2 then return end
    
    -- Vérifier qu'on a un tueur valide et différent du mort
    if not killerPlayerId or killerPlayerId == deadPlayerId or killerPlayerId == 0 then return end
    
    -- Déterminer qui est le joueur 1 et qui est le joueur 2
    local player1Id = instance.players[1]
    local player2Id = instance.players[2]
    
    -- Vérifier que le tueur est bien un des 2 joueurs du duel
    if killerPlayerId ~= player1Id and killerPlayerId ~= player2Id then return end
    
    -- Incrémenter le round
    instance.rounds.currentRound = instance.rounds.currentRound + 1
    
    -- Incrémenter le score du tueur selon son index dans la liste
    if killerPlayerId == player1Id then
        instance.rounds.player1Score = instance.rounds.player1Score + 1
    elseif killerPlayerId == player2Id then
        instance.rounds.player2Score = instance.rounds.player2Score + 1
    end
    
    -- Vérifier si quelqu'un a gagné
    local winner = nil
    local winnerName = ""
    local loserName = ""
    local duelFinished = false
    
    -- Vérifier si quelqu'un a gagné (3 manches) OU si on a atteint 5 manches
    if instance.rounds.player1Score >= ROUNDS_TO_WIN then
        winner = instance.players[1]
        winnerName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
        loserName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
        duelFinished = true
    elseif instance.rounds.player2Score >= ROUNDS_TO_WIN then
        winner = instance.players[2]
        winnerName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
        loserName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
        duelFinished = true
    elseif instance.rounds.currentRound >= MAX_ROUNDS then
        -- Si on a fait 5 manches, celui avec le plus de points gagne
        if instance.rounds.player1Score > instance.rounds.player2Score then
            winner = instance.players[1]
            winnerName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
            loserName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
        elseif instance.rounds.player2Score > instance.rounds.player1Score then
            winner = instance.players[2]
            winnerName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
            loserName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
        else
            -- Égalité - pas de gagnant
            winner = nil
            winnerName = "Égalité"
        end
        duelFinished = true
    end
    
    -- Envoyer les scores aux joueurs
    for _, playerId in ipairs(instance.players) do
        TriggerClientEvent('duel:roundResult', playerId, {
            player1Score = instance.rounds.player1Score,
            player2Score = instance.rounds.player2Score,
            currentRound = instance.rounds.currentRound,
            maxRounds = MAX_ROUNDS,
            winner = winner,
            winnerName = winnerName,
            loserName = loserName,
            killerPlayerId = killerPlayerId,
            deadPlayerId = deadPlayerId,
            duelFinished = duelFinished,
            player1Id = player1Id,
            player2Id = player2Id
        })
    end
    
    -- Si quelqu'un a gagné, terminer le duel
    if duelFinished then
        -- Attendre 3 secondes puis supprimer l'instance
        Citizen.SetTimeout(3000, function()
            deleteInstance(instanceId)
        end)
    end
end

-- ENREGISTREMENT DES EVENTS

-- Event pour signaler une mort
AddEventHandler('duel:playerDied', function(killerPlayerId)
    local source = source
    local deadPlayerName = GetPlayerName(source) or "Joueur " .. source
    local killerPlayerName = GetPlayerName(killerPlayerId) or "Joueur " .. killerPlayerId
    
    -- Trouver l'instance du joueur mort
    local instanceId, instance = getPlayerInstance(source)
    if instanceId and instance then
        handlePlayerDeath(instanceId, source, killerPlayerId)
    end
end)

RegisterNetEvent('duel:playerDied')

-- Commande de test pour vérifier la communication client-serveur
RegisterCommand('testduel', function(source, args, rawCommand)
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DUEL]", "Communication serveur OK !"}
        })
    end
end, false)

-- Event pour rejoindre une arène (créer une instance)
AddEventHandler('duel:createArena', function(weapon, map)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    -- Vérifier que les paramètres sont valides
    if not weapon or not map then return end
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        -- Supprimer l'ancienne instance et en créer une nouvelle
        deleteInstance(currentInstanceId)
    end
    
    -- Créer une nouvelle instance en attente
    local instanceId = createInstance(source, map, weapon)
    
    -- Confirmer au client
    TriggerClientEvent('duel:instanceCreated', source, instanceId, weapon, map)
    
    -- Notifier tous les clients de la mise à jour des arènes disponibles
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
end)

RegisterNetEvent('duel:createArena')

-- Event pour rejoindre une arène existante
AddEventHandler('duel:joinArena', function(weapon)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then return end
    
    -- Trouver une arène disponible avec la même arme
    local targetInstanceId = nil
    for instanceId, instance in pairs(instances) do
        if instance.status == "waiting" and instance.weapon == weapon and #instance.players < instance.maxPlayers then
            targetInstanceId = instanceId
            break
        end
    end
    
    if not targetInstanceId then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Aucune arène disponible avec cette arme. Créez votre propre arène !"}
        })
        return
    end
    
    -- Ajouter le joueur à l'instance
    local success, message = addPlayerToInstance(targetInstanceId, source)
    if not success then return end
    
    local instance = instances[targetInstanceId]
    
    -- Téléporter le joueur vers l'arène
    TriggerClientEvent('duel:instanceCreated', source, targetInstanceId, weapon, instance.arena)
    
    -- Notifier le créateur qu'un adversaire a rejoint
    local creatorName = GetPlayerName(instance.creator) or "Joueur " .. instance.creator
    TriggerClientEvent('duel:opponentJoined', instance.creator, playerName)
    TriggerClientEvent('duel:opponentJoined', source, creatorName)
    
    -- Mettre à jour la liste des arènes disponibles pour tous
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
end)

RegisterNetEvent('duel:joinArena')

-- Event pour rejoindre une arène spécifique
AddEventHandler('duel:joinSpecificArena', function(arenaId, weapon)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then return end
    
    -- Vérifier que l'arène existe
    local targetInstance = instances[arenaId]
    if not targetInstance then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Cette arène n'existe plus !"}
        })
        return
    end
    
    -- Vérifier que l'arène est disponible
    if targetInstance.status ~= "waiting" or #targetInstance.players >= targetInstance.maxPlayers then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Cette arène n'est plus disponible !"}
        })
        return
    end
    
    -- Vérifier que l'arme correspond
    if targetInstance.weapon ~= weapon then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Arme incompatible avec cette arène !"}
        })
        return
    end
    
    -- Ajouter le joueur à l'instance
    local success, message = addPlayerToInstance(arenaId, source)
    if not success then return end
    
    -- Téléporter le joueur vers l'arène
    TriggerClientEvent('duel:instanceCreated', source, arenaId, weapon, targetInstance.arena)
    
    -- Notifier le créateur qu'un adversaire a rejoint
    local creatorName = GetPlayerName(targetInstance.creator) or "Joueur " .. targetInstance.creator
    TriggerClientEvent('duel:opponentJoined', targetInstance.creator, playerName)
    TriggerClientEvent('duel:opponentJoined', source, creatorName)
    
    -- Mettre à jour la liste des arènes disponibles pour tous
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
end)

RegisterNetEvent('duel:joinSpecificArena')

-- Event pour obtenir les arènes disponibles
AddEventHandler('duel:getAvailableArenas', function()
    local source = source
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', source, availableArenas)
end)

RegisterNetEvent('duel:getAvailableArenas')

-- Event pour quitter une arène (supprimer l'instance)
AddEventHandler('duel:quitArena', function()
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    -- Trouver et supprimer l'instance du joueur
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
        TriggerClientEvent('duel:instanceDeleted', source)
    end
end)

RegisterNetEvent('duel:quitArena')

-- Nettoyer les instances quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur inconnu"
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
    end
end)

-- Commande admin pour voir les instances actives
RegisterCommand('duel_instances', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, "command.duel_instances") then
        local count = 0
        for instanceId, instance in pairs(instances) do
            count = count + 1
            local creatorName = GetPlayerName(instance.creator) or "Joueur déconnecté"
            local timeElapsed = os.time() - instance.created
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
            -- Informer le joueur que son instance a été supprimée
            local instance = instances[instanceId]
            if instance and instance.creator then
                TriggerClientEvent('duel:instanceDeleted', instance.creator)
            end
            deleteInstance(instanceId)
        end
    end
end)