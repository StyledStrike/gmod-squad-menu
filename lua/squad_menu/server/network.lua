local commands = {}

commands[SquadMenu.SQUAD_LIST] = function( ply )
    local data = {}

    for _, squad in pairs( SquadMenu.squads ) do
        data[#data + 1] = squad:GetBasicInfo()
    end

    SquadMenu.StartCommand( SquadMenu.SQUAD_LIST )
    SquadMenu.WriteTable( data )
    net.Send( ply )
end

commands[SquadMenu.SETUP_SQUAD] = function( ply )
    local squadId = ply:GetSquadID()
    local data = SquadMenu.ReadTable()

    if type( data.name ) == "string" then
        local shouldAllow, name = hook.Run( "ShouldAllowSquadName", data.name, ply )

        if shouldAllow == false then
            data.name = name or ""
        end
    end

    -- Update existing squad, if this ply is the leader.
    if squadId ~= -1 then
        local squad = SquadMenu:GetSquad( squadId )
        if not squad then return end
        if squad.leader ~= ply then return end

        squad:SetBasicInfo( data )
        squad:SyncWithMembers()

        SquadMenu.PrintF( "Edited squad #%d for %s", squadId, ply:SteamID() )

        SquadMenu.BroadcastEvent( "squad_created", {
            id = squadId
        } )

        return
    end

    local squad = SquadMenu:CreateSquad( ply )
    squad:SetBasicInfo( data )
    squad:AddMember( ply )
end

commands[SquadMenu.JOIN_SQUAD] = function( ply )
    if ply:GetSquadID() ~= -1 then return end

    local squadId = net.ReadUInt( 16 )
    local squad = SquadMenu:GetSquad( squadId )

    if squad then
        squad:RequestToJoin( ply )
    end
end

commands[SquadMenu.LEAVE_SQUAD] = function( ply )
    local squadId = ply:GetSquadID()
    if squadId == -1 then return end

    local squad = SquadMenu:GetSquad( squadId )

    if squad then
        squad:RemoveMember( ply, SquadMenu.LEAVE_REASON_LEFT )
    end
end

commands[SquadMenu.ACCEPT_REQUESTS] = function( ply )
    local squadId = ply:GetSquadID()
    if squadId == -1 then return end

    local squad = SquadMenu:GetSquad( squadId )
    local steamIds = SquadMenu.ReadTable()

    if squad then
        squad:AcceptRequests( steamIds )
    end
end

commands[SquadMenu.KICK] = function( ply )
    local squadId = ply:GetSquadID()
    if squadId == -1 then return end

    local squad = SquadMenu:GetSquad( squadId )

    if squad and squad.leader == ply then
        local targetId = net.ReadString()
        local players = SquadMenu.AllPlayersBySteamID()
        if not players[targetId] then return end

        squad:RemoveMember( players[targetId], SquadMenu.LEAVE_REASON_KICKED )
    end
end

-- Safeguard against spam
local cooldowns = {
    [SquadMenu.SQUAD_LIST] = { interval = 0.5, players = {} },
    [SquadMenu.SETUP_SQUAD] = { interval = 1, players = {} },
    [SquadMenu.JOIN_SQUAD] = { interval = 1, players = {} },
    [SquadMenu.LEAVE_SQUAD] = { interval = 1, players = {} },
    [SquadMenu.ACCEPT_REQUESTS] = { interval = 0.2, players = {} },
    [SquadMenu.KICK] = { interval = 0.2, players = {} }
}

net.Receive( "squad_menu.command", function( _, ply )
    local id = ply:SteamID()
    local cmd = net.ReadUInt( SquadMenu.COMMAND_SIZE )

    if not commands[cmd] then
        SquadMenu.PrintF( "%s <%s> sent a unknown network command! (%d)", ply:Nick(), id, cmd )
        return
    end

    local t = RealTime()
    local players = cooldowns[cmd].players

    if players[id] and players[id] > t then
        SquadMenu.PrintF( "%s <%s> sent network commands too fast!", ply:Nick(), id )
        return
    end

    players[id] = t + cooldowns[cmd].interval
    commands[cmd]( ply )
end )

hook.Add( "PlayerDisconnected", "SquadMenu.PlayerCleanup", function( ply )
    local id = ply:SteamID()

    for _, c in pairs( cooldowns ) do
        c.players[id] = nil
    end

    -- Check for and remove player from join requests on all squads
    for _, squad in pairs( SquadMenu.squads ) do
        squad.requests[id] = nil
    end

    -- Remove player from their squad, if they have one
    local squadId = ply:GetSquadID()
    if squadId == -1 then return end

    local squad = SquadMenu:GetSquad( squadId )
    squad:RemoveMember( ply )
end )

local prefixes = {}

for _, prefix in ipairs( SquadMenu.CHAT_PREFIXES ) do
    prefixes[prefix] = true
end

hook.Add( "PlayerSay", "SquadMenu.RemovePrefix", function( sender, text )
    local parts = string.Explode( " ", text, false )
    if not parts[1] or not prefixes[parts[1]] then return end

    local id = sender:GetSquadID()

    if id == -1 then
        sender:ChatPrint( "You're not in a squad." )
        return ""
    end

    table.remove( parts, 1 )

    text = table.concat( parts, " " )

    if text:len() == 0 then
        sender:ChatPrint( "Please type a message to send to your squad members." )
        return ""
    end

    local members = SquadMenu:GetSquad( id ).members

    local data = {
        eventName = "members_chat",
        senderId = sender:SteamID(),
        text = text
    }

    SquadMenu.StartCommand( SquadMenu.BROADCAST_EVENT )
    net.WriteString( SquadMenu.TableToJSON( data ) )
    net.Send( members )

    return ""
end, HOOK_HIGH )
