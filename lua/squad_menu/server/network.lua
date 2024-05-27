util.AddNetworkString( "squad_menu.command" )

function SquadMenu.StartEvent( event, data )
    data = data or {}
    data.event = event

    SquadMenu.StartCommand( SquadMenu.BROADCAST_EVENT )
    SquadMenu.WriteTable( data )
end

local commands = {}
local PID = SquadMenu.GetPlayerId

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
    local plyId = PID( ply )
    local data = SquadMenu.ReadTable()

    if type( data.name ) == "string" then
        local shouldAllow, name = hook.Run( "ShouldAllowSquadName", data.name, ply )

        if shouldAllow == false then
            data.name = name or "?"
        end
    end

    -- Update existing squad if this ply is the leader.
    if squadId ~= -1 then
        local squad = SquadMenu:GetSquad( squadId )
        if not squad then return end
        if squad.leaderId ~= plyId then return end

        squad:SetBasicInfo( data )
        squad:SyncWithMembers()

        SquadMenu.PrintF( "Edited squad #%d for %s", squadId, ply:SteamID() )

        SquadMenu.StartEvent( "squad_created", { id = squadId } )
        net.Broadcast()

        return
    end

    local squad = SquadMenu:CreateSquad()
    squad:SetBasicInfo( data )
    squad:SetLeader( ply )
    squad:AddMember( ply )

    SquadMenu.StartEvent( "squad_created", {
        id = squadId,
        name = squad.name,
        leaderName = squad.leaderName,
        r = squad.r,
        g = squad.g,
        b = squad.b
    } )
    net.Broadcast()
end

commands[SquadMenu.JOIN_SQUAD] = function( ply )
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
    local ids = SquadMenu.ReadTable()

    if squad and squad.leaderId == PID( ply ) then
        squad:AcceptRequests( ids )
    end
end

commands[SquadMenu.KICK] = function( ply )
    local squadId = ply:GetSquadID()
    if squadId == -1 then return end

    local plyId = PID( ply )
    local squad = SquadMenu:GetSquad( squadId )

    if squad and squad.leaderId == plyId then
        local targetId = net.ReadString()
        if targetId == plyId then return end

        local byId = SquadMenu.AllPlayersById()
        if not byId[targetId] then return end

        squad:RemoveMember( byId[targetId], SquadMenu.LEAVE_REASON_KICKED )
    end
end

-- Safeguard against spam
local cooldowns = {
    [SquadMenu.SQUAD_LIST] = { interval = 0.5, players = {} },
    [SquadMenu.SETUP_SQUAD] = { interval = 1, players = {} },
    [SquadMenu.JOIN_SQUAD] = { interval = 0.1, players = {} },
    [SquadMenu.LEAVE_SQUAD] = { interval = 1, players = {} },
    [SquadMenu.ACCEPT_REQUESTS] = { interval = 0.2, players = {} },
    [SquadMenu.KICK] = { interval = 0.1, players = {} }
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

hook.Add( "PlayerDisconnected", "SquadMenu.NetCleanup", function( ply )
    local id = ply:SteamID()

    for _, c in pairs( cooldowns ) do
        c.players[id] = nil
    end
end )
