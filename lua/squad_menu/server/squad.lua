local IsValid = IsValid
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

        self.StartEvent( "squad_deleted", { id = id } )
        net.Broadcast()
    end
end

--- Check for and remove player from join requests on all squads
function SquadMenu:CleanupRequests( steamId, dontSync )
    for _, squad in pairs( self.squads ) do
        if squad.requests[steamId] then
            squad.requests[steamId] = nil

            if not dontSync then
                squad:SyncRequests()
            end
        end
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

    self.StartEvent( "squad_created", { id = id } )
    net.Broadcast()

    return self.squads[id]
end

--- Get a table containing details of this squad.
function Squad:GetBasicInfo()
    local members = {}
    local count = 0

    -- Take the chance to cleanup invalid members, if/when this somehow happens
    for i = #self.members, 1, -1 do
        local member = self.members[i]

        if IsValid( member ) then
            count = count + 1
            members[count] = { id = member:SteamID(), name = member:Nick() }
        else
            table.remove( self.members, i )
        end
    end

    return {
        id = self.id,
        members = members,

        leaderId = self.leader:SteamID(),
        leaderName = self.leader:Nick(),

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

local ValidateString = SquadMenu.ValidateString
local ValidateNumber = SquadMenu.ValidateNumber

--- Set the details of this squad using a table.
function Squad:SetBasicInfo( info )
    self.name = ValidateString( info.name, "Unnamed", SquadMenu.MAX_NAME_LENGTH )
    self.icon = ValidateString( info.icon, "icon16/flag_blue.png", 256 )

    self.enableRings = info.enableRings == true
    self.friendlyFire = info.friendlyFire == true
    self.isPublic = info.isPublic == true

    self.r = ValidateNumber( info.r, 255, 0, 255 )
    self.g = ValidateNumber( info.g, 255, 0, 255 )
    self.b = ValidateNumber( info.b, 255, 0, 255 )

    blockDamage[self.id] = Either( self.friendlyFire, nil, true )
end

--- Send details and a list of members to all squad members.
function Squad:SyncWithMembers()
    if #self.members == 0 then return end

    local data = self:GetBasicInfo()

    SquadMenu.StartCommand( SquadMenu.SETUP_SQUAD )
    SquadMenu.WriteTable( data )
    net.Send( self.members )
end

--- Send the requests list to the squad leader.
function Squad:SyncRequests()
    SquadMenu.StartCommand( SquadMenu.REQUESTS_LIST )
    SquadMenu.WriteTable( self.requests )
    net.Send( self.leader )
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

    -- We don't send the requests list to the squad leaders (2nd "true" parameter)
    -- because "player_joined_squad" will already tell them to remove
    -- this player from their own copies of the join requests list.
    SquadMenu:CleanupRequests( id, true )

    SquadMenu.StartEvent( "player_joined_squad", {
        squadId = self.id,
        playerId = id
    } )
    net.Broadcast()
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
        net.WriteUInt( reasonId, 3 )
        net.Send( ply )
    end

    self:SyncWithMembers()
end

--- Add a player to the list of players that
--- requested to join and notify the squad leader.
function Squad:RequestToJoin( ply )
    if self.isPublic then
        self:AddMember( ply )
        return
    end

    local id = ply:SteamID()

    if self.requests[id] then return end

    self.requests[id] = ply:Nick()
    self:SyncRequests()
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
            self:AddMember( players[id], true ) -- add but don't sync yet
        end
    end

    if count > 0 then
        self:SyncWithMembers() -- sync now
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
        net.WriteUInt( SquadMenu.LEAVE_REASON_DELETED, 3 )
        net.Send( recipients )
    end

    self.members = nil
    self.requests = nil

    SquadMenu:DeleteSquad( self.id )
end
