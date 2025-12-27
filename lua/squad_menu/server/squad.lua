local IsValid = IsValid
local PID = SquadMenu.GetPlayerId
local FindByPID = SquadMenu.FindPlayerById

local Squad = SquadMenu.Squad or {}
SquadMenu.Squad = Squad
Squad.__index = Squad

--- Set the leader of this squad. `ply` can either be
--- a player entity, a ID string that came from `SquadMenu.GetPlayerId`,
--- or `nil` if you want to unset the current squad leader.
function Squad:SetLeader( ply, name )
    if type( ply ) == "string" then
        self.leaderId = ply -- this is a player ID
        self.leaderName = name or "?"

    elseif IsValid( ply ) then
        self.leaderId = PID( ply )
        self.leaderName = ply:Nick()

    else
        self.leaderId = nil
        self.leaderName = nil

        SquadMenu.PrintF( "Removed leader from squad #%d", self.id )
        return
    end

    SquadMenu.PrintF( "New leader for squad #%d: %s <%s>", self.id, self.leaderName, self.leaderId )
end

--- Get a table containing a list of active squad members.
--- Returns an array of player entities that are currently on the server.
function Squad:GetActiveMembers()
    local members, count = {}, 0
    local byId = SquadMenu.AllPlayersById()

    for id, _ in pairs( self.membersById ) do
        if byId[id] then
            count = count + 1
            members[count] = byId[id]
        end
    end

    return members, count
end

--- Get a ready-to-be-stringified table containing details from this squad.
function Squad:GetBasicInfo()
    local info = {
        id = self.id,
        name = self.name,
        icon = self.icon,
        members = {},

        enableRings = self.enableRings,
        friendlyFire = self.friendlyFire,
        isPublic = self.isPublic,

        r = self.r,
        g = self.g,
        b = self.b
    }

    if self.leaderId then
        info.leaderId = self.leaderId
        info.leaderName = self.leaderName
    end

    local count = 0

    for id, name in pairs( self.membersById ) do
        count = count + 1
        info.members[count] = { id, name }
    end

    return info
end

local ValidateString = SquadMenu.ValidateString
local ValidateNumber = SquadMenu.ValidateNumber

--- Set the details of this squad using a table.
function Squad:SetBasicInfo( info )
    if SquadMenu.GetForceFriendlyFire() then
        info.friendlyFire = true
    end

    self.name = ValidateString( info.name, "Unnamed", SquadMenu.MAX_NAME_LENGTH )
    self.icon = ValidateString( info.icon, "icon16/flag_blue.png", 256 )

    self.enableRings = info.enableRings == true
    self.friendlyFire = info.friendlyFire == true
    self.isPublic = info.isPublic == true

    self.r = ValidateNumber( info.r, 255, 0, 255 )
    self.g = ValidateNumber( info.g, 255, 0, 255 )
    self.b = ValidateNumber( info.b, 255, 0, 255 )

    SquadMenu.blockDamage[self.id] = Either( self.friendlyFire, nil, true )
end

--- Send details and a list of members to all squad members.
--- You should never set `immediate` to `true` unless you know what you're doing.
function Squad:SyncWithMembers( immediate )
    if not immediate then
        -- avoid spamming the networking system
        timer.Remove( "SquadMenu.Sync" .. self.id )
        timer.Create( "SquadMenu.Sync" .. self.id, 0.5, 1, function()
            self:SyncWithMembers( true )
        end )

        return
    end

    local members, count = self:GetActiveMembers()
    if count == 0 then return end

    local data = self:GetBasicInfo()

    SquadMenu.StartCommand( SquadMenu.SETUP_SQUAD )
    SquadMenu.WriteTable( data, SquadMenu.MAX_SV_TO_CL_JSON_SIZE )
    net.Send( members )
end

--- Send the requests list to the squad leader.
function Squad:SyncRequests()
    local leader = FindByPID( self.leaderId )
    if not IsValid( leader ) then return end

    SquadMenu.StartCommand( SquadMenu.REQUESTS_LIST )
    SquadMenu.WriteTable( self.requestsById, SquadMenu.MAX_SV_TO_CL_JSON_SIZE )
    net.Send( leader )
end

--- Turns `p` into a id and player entity depending on what `p` is.
local function ParsePlayerArg( p )
    if type( p ) == "string" then
        return p, FindByPID( p )
    end

    return PID( p ), p
end

--- Add a player as a new member.
--- `p` can be a player id from `SquadMenu.GetPlayerId` or a player entity.
--- `ignoreLimit` can be a boolean to ignore the member limit check, useful for external addons.
function Squad:AddMember( p, ignoreLimit )
    local id, ply = ParsePlayerArg( p )
    if self.membersById[id] then return end

    local count = table.Count( self.membersById )
    if not ignoreLimit and count >= SquadMenu.GetMemberLimit() then return end

    local name = id

    if IsValid( ply ) then
        local oldSquad = SquadMenu:GetSquad( ply:GetSquadID() )

        if oldSquad then
            oldSquad:RemoveMember( ply, SquadMenu.LEAVE_REASON_LEFT )
        end

        ply:SetNWInt( "squad_menu.id", self.id )
        name = ply:Nick()
    end

    self.membersById[id] = name
    self:SyncWithMembers()

    -- We don't send the requests list to the squad leaders (2nd "true" parameter)
    -- because "player_joined_squad" will already tell them to remove
    -- this player from their own copies of the join requests list.
    SquadMenu:CleanupRequests( id, true )

    SquadMenu.StartEvent( "player_joined_squad", {
        squadId = self.id,
        playerId = id
    } )
    net.Broadcast()

    hook.Run( "SquadMenu_OnJoinedSquad", self.id, ply, id )
end

--- Remove a player from this squad's members list.
--- `ply` can be a player id from `SquadMenu.GetPlayerId` or a player entity.
--- `reasonId` can be `nil` or one of the values from `SquadMenu.LEAVE_REASON_*`.
function Squad:RemoveMember( p, reasonId )
    local id, ply = ParsePlayerArg( p )
    if not self.membersById[id] then return end

    if id == self.leaderId then
        local members, count = self:GetActiveMembers()

        if count > 1 then
            -- Pick a new leader
            for _, plyEnt in ipairs( members ) do
                if plyEnt ~= ply then
                    self:SetLeader( plyEnt )
                    break
                end
            end
        else
            -- Delete the squad if there are no members left
            pcall( hook.Run, "SquadMenu_OnLeftSquad", self.id, ply, id )
            self:Delete()

            return
        end
    end

    self.membersById[id] = nil
    self:SyncWithMembers()

    if not IsValid( ply ) then return end

    ply:SetNWInt( "squad_menu.id", -1 )

    if reasonId ~= nil then
        SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
        net.WriteUInt( reasonId, 3 )
        net.Send( ply )
    end

    hook.Run( "SquadMenu_OnLeftSquad", self.id, ply, id )
end

--- Add a player to the list of players that
--- requested to join and notify the squad leader.
function Squad:RequestToJoin( ply )
    if self.isPublic then
        self:AddMember( ply )
        return
    end

    local plyId = PID( ply )
    if self.requestsById[plyId] then return end

    self.requestsById[plyId] = ply:Nick()
    self:SyncRequests()
end

--- Accept all the join requests from a list of player IDs.
function Squad:AcceptRequests( ids )
    if not table.IsSequential( ids ) then return end

    local limit = SquadMenu.GetMemberLimit()
    local count = table.Count( self.membersById )

    for _, id in ipairs( ids ) do
        if count >= limit then
            break

        elseif self.requestsById[id] then
            count = count + 1

            self.requestsById[id] = nil
            self:AddMember( id )
        end
    end
end

--- Remove all members from this squad and delete it.
function Squad:Delete()
    timer.Remove( "SquadMenu.Sync" .. self.id )

    local members, count = self:GetActiveMembers()

    if count > 0 then
        for _, ply in ipairs( members ) do
            ply:SetNWInt( "squad_menu.id", -1 )
        end

        SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
        net.WriteUInt( SquadMenu.LEAVE_REASON_DELETED, 3 )
        net.Send( members )
    end

    self.membersById = nil
    self.requestsById = nil

    local id = self.id

    SquadMenu.squads[id] = nil
    SquadMenu.blockDamage[id] = nil

    SquadMenu.PrintF( "Deleted squad #%d", id )

    SquadMenu.StartEvent( "squad_deleted", { id = id } )
    net.Broadcast()
end
