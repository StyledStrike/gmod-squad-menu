resource.AddWorkshop( "3207278246" )

SquadMenu.blockDamage = SquadMenu.blockDamage or {}
SquadMenu.squads = SquadMenu.squads or {}
SquadMenu.lastSquadId = SquadMenu.lastSquadId or 0

--- Find a squad by it's ID.
function SquadMenu:GetSquad( id )
    return self.squads[id]
end

--- Find and remove a squad by it's ID.
function SquadMenu:DeleteSquad( id )
    local squad = self.squads[id]

    if squad then
        squad:Delete()
    end
end

--- Remove a player id from join requests on all squads.
function SquadMenu:CleanupRequests( id, dontSync )
    for _, squad in pairs( self.squads ) do
        if squad.requestsById[id] then
            squad.requestsById[id] = nil

            if not dontSync then
                squad:SyncRequests()
            end
        end
    end
end

-- Updates the player name everywhere it appears.
function SquadMenu:UpdatePlayerName( ply )
    if not IsValid( ply ) then return end

    local id = self.GetPlayerId( ply )
    local name = ply:Nick()

    for _, squad in pairs( self.squads ) do
        -- Update leader name
        if squad.leaderId == id then
            squad.leaderName = name
        end

        -- Update join request
        if squad.requestsById[id] then
            squad.requestsById[id] = name
            squad:SyncRequests()
        end

        -- Update member name
        if squad.membersById[id] then
            squad.membersById[id] = name
            squad:SyncWithMembers()
        end
    end
end

--- Create a new squad.
function SquadMenu:CreateSquad()
    local id = self.lastSquadId + 1
    self.lastSquadId = id

    self.squads[id] = setmetatable( {
        id = id,
        name = "",
        icon = "",

        enableRings = false,
        friendlyFire = false,
        isPublic = false,

        r = 255,
        g = 255,
        b = 255,

        -- Members key-value table. Do not modify directly,
        -- instead use squad:AddMember/squad:RemoveMember.
        --
        -- Each key is a player id from SquadMenu.GetPlayerId,
        -- and each value is the player name.
        membersById = {},

        -- Join Requests key-value table.
        --
        -- Each key is a player id from SquadMenu.GetPlayerId,
        -- and each value is the player name.
        requestsById = {}
    }, self.Squad )

    self.PrintF( "Created squad #%d", id )

    return self.squads[id]
end

-- Callbacks on FCVAR_REPLICATED cvars don't work clientside so we need this
cvars.AddChangeCallback( "squad_members_position", function()
    SquadMenu.StartEvent( "squad_position_changed" )
    net.Broadcast()
end, "changed_squad_members_position" )

--- Update player names on change
gameevent.Listen( "player_changename" )
hook.Add( "player_changename", "SquadMenu.UpdatePlayerName", function( data )
    SquadMenu:UpdatePlayerName( Player( data.userid ) )
end )

--- Update player names on first spawn
hook.Add( "PlayerInitialSpawn", "SquadMenu.UpdatePlayerName", function( ply )
    SquadMenu:UpdatePlayerName( ply )
end )

-- On disconnect, remove join requests and this player from their squad, if they have one
hook.Add( "PlayerDisconnected", "SquadMenu.PlayerCleanup", function( ply )
    SquadMenu:CleanupRequests( PID( ply ) )

    local squad = SquadMenu:GetSquad( ply:GetSquadID() )

    if squad then
        squad:RemoveMember( ply )
    end
end )

--- Block damage between squad members
local blockDamage = SquadMenu.blockDamage

hook.Add( "PlayerShouldTakeDamage", "SquadMenu.BlockFriendlyFire", function( ply, attacker )
    if not attacker.GetSquadID then return end

    local id = ply:GetSquadID()

    if id ~= -1 and ply ~= attacker and blockDamage[id] and id == attacker:GetSquadID() then
        return false
    end
end )

--- Chat commands and squad-only chat messages
local prefixes = {}

for _, prefix in ipairs( SquadMenu.CHAT_PREFIXES ) do
    prefixes[prefix] = true
end

hook.Add( "PlayerSay", "SquadMenu.RemovePrefix", function( sender, text )
    -- Check for commands to open the menu
    if text[1] == "!" then
        text = string.lower( string.Trim( text ) )

        if text == "!squad" or text == "!party" then
            SquadMenu.StartEvent( "open_menu" )
            net.Send( sender )

            return ""
        end
    end

    -- Check if this is supposed to be a members-only message
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

    local members = SquadMenu:GetSquad( id ):GetActiveMembers()

    SquadMenu.StartEvent( "members_chat", {
        senderName = sender:Nick(),
        text = text
    } )
    net.Send( members )

    return ""
end, HOOK_HIGH )
