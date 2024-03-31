local blockDamage = SquadMenu.blockDamage or {}

SquadMenu.squads = SquadMenu.squads or {}
SquadMenu.lastSquadId = SquadMenu.lastSquadId or 0
SquadMenu.blockDamage = blockDamage

hook.Add( "PlayerShouldTakeDamage", "SquadMenu.BlockFriendlyFire", function( ply, attacker )
    if not attacker.GetSquadID then return end
    local id = ply:GetSquadID()

    if id ~= -1 and ply ~= attacker and blockDamage[id] and id == attacker:GetSquadID() then
        return false
    end
end )

--- Find a squad by it's ID.
function SquadMenu:GetSquad( id )
    return self.squads[id]
end

--- Find and remove a squad by it's ID.
function SquadMenu:DeleteSquad( id )
    if self.squads[id] then
        self.squads[id] = nil
        self.blockDamage[id] = nil

        self.PrintF( "Deleted squad #%d", id )
        self.BroadcastEvent( "squad_deleted", {
            id = id
        } )
    end
end

local Squad = {}

Squad.__index = Squad

--- Register a new squad.
function SquadMenu:CreateSquad( leader )
    local id = self.lastSquadId + 1
    self.lastSquadId = id

    self.squads[id] = setmetatable( {
        id = id,
        leader = leader,

        name = "",
        icon = "",

        enableRings = false,
        friendlyFire = false,
        isPublic = false,

        r = 255,
        g = 255,
        b = 255,

        members = {},
        requests = {}
    }, Squad )

    self.PrintF( "Created squad #%d for %s", id, leader:SteamID() )
    self.BroadcastEvent( "squad_created", {
        id = id
    } )

    return self.squads[id]
end

--- Get a table containing details of this squad.
function Squad:GetBasicInfo()
    return {
        id = self.id,
        leaderId = self.leader:SteamID(),
        memberCount = #self.members,

        name = self.name,
        icon = self.icon,

        enableRings = self.enableRings,
        friendlyFire = self.friendlyFire,
        isPublic = self.isPublic,

        r = self.r,
        g = self.g,
        b = self.b
    }
end

local function ValidateString( s, default, maxLength )
    if type( s ) ~= "string" then
        return default
    end

    s = string.Trim( s )

    if s == "" then
        return default
    end

    if string.len( s ) > maxLength then
        s = string.Left( s, maxLength )
    end

    return s
end

local function ValidateNumber( n, min, max )
    return math.Clamp( tonumber( n ) or 0, min, max )
end

--- Set the details of this squad using a table.
function Squad:SetBasicInfo( info )
    self.name = ValidateString( info.name, "Unamed", SquadMenu.MAX_NAME_LENGTH )
    self.icon = ValidateString( info.icon, "games/16/garrysmod.png", 256 )

    self.enableRings = info.enableRings == true
    self.friendlyFire = info.friendlyFire == true
    self.isPublic = info.isPublic == true

    self.r = ValidateNumber( info.r, 0, 255 )
    self.g = ValidateNumber( info.g, 0, 255 )
    self.b = ValidateNumber( info.b, 0, 255 )

    blockDamage[self.id] = Either( self.friendlyFire, nil, true )
end

--- Send details and a list of members to all squad members.
--- Will convert player entities to SteamIDs.
function Squad:SyncWithMembers()
    if #self.members == 0 then return end

    local memberIds = {}

    for i, member in ipairs( self.members ) do
        memberIds[i] = member:SteamID()
    end

    local squad = self:GetBasicInfo()
    squad.memberIds = memberIds

    SquadMenu.StartCommand( SquadMenu.SETUP_SQUAD )
    SquadMenu.WriteTable( squad )
    net.Send( self.members )
end

--- Add a player as a new member.
function Squad:AddMember( ply, dontSync )
    if ply:GetSquadID() == self.id then return end

    local count = #self.members
    if count >= SquadMenu.GetMemberLimit() then return end

    ply:SetNWInt( "squad_menu.id", self.id )

    self.members[count + 1] = ply

    if not dontSync then
        self:SyncWithMembers()
    end

    local id = ply:SteamID()

    -- Check for and remove player from join requests on all squads
    for _, squad in pairs( SquadMenu.squads ) do
        squad.requests[id] = nil
    end

    SquadMenu.BroadcastEvent( "player_joined_squad", {
        squadId = self.id,
        playerId = id
    } )
end

--- Remove a player from this squad's members list.
function Squad:RemoveMember( ply, reasonId )
    local index = table.KeyFromValue( self.members, ply )
    if not index then return end

    if ply == self.leader then
        self:Disband()
        return
    end

    table.remove( self.members, index )
    ply:SetNWInt( "squad_menu.id", -1 )

    if reasonId ~= nil then
        SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
        net.WriteUInt( reasonId, 2 )
        net.Send( ply )
    end

    self:SyncWithMembers()
end

--- Add a player to the list of players that requested to join,
--- and notify the squad leader about this.
function Squad:RequestToJoin( ply )
    if self.isPublic then
        self:AddMember( ply )
        return
    end

    local id = ply:SteamID()

    if self.requests[id] then return end
    self.requests[id] = true

    local requestIds = table.GetKeys( self.requests )

    SquadMenu.StartCommand( SquadMenu.REQUESTS_LIST )
    SquadMenu.WriteTable( requestIds )
    net.Send( self.leader )
end

--- Accept all the join requests from a list of players' SteamIDs.
function Squad:AcceptRequests( ids )
    if not table.IsSequential( ids ) then return end

    local memberLimit = SquadMenu.GetMemberLimit() - #self.members
    local players = SquadMenu.AllPlayersBySteamID()
    local count = 0

    for _, id in ipairs( ids ) do
        if count < memberLimit and players[id] and self.requests[id] then
            count = count + 1

            self.requests[id] = nil
            self:AddMember( players[id], true )
        end
    end

    if count > 0 then
        self:SyncWithMembers()
    end
end

--- Remove all members from this squad and delete it.
function Squad:Disband()
    local count = 0
    local recipients = {}

    -- Remove all members from the squad
    for _, ply in ipairs( self.members ) do
        if IsValid( ply ) then
            ply:SetNWInt( "squad_menu.id", -1 )

            count = count + 1
            recipients[count] = ply
        end
    end

    if count > 0 then
        SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
        net.WriteUInt( SquadMenu.LEAVE_REASON_DELETED, 2 )
        net.Send( recipients )
    end

    self.members = nil
    self.requests = nil

    SquadMenu:DeleteSquad( self.id )
end
