E2Lib.RegisterExtension( "squad_menu", true, "Add player functions related to the Squad Menu" )

local function ValidatePlayer( self, ent )
    if not IsValid( ent ) then self:throw( "Invalid entity!", 0 ) end
    if not ent:IsPlayer() then self:throw( "Not a player entity!", 0 ) end
end

__e2setcost( 5 )

e2function number entity:isSquadMember()
    ValidatePlayer( self, this )
    return this:GetSquadID() == -1 and 0 or 1
end

e2function number entity:getSquadID()
    ValidatePlayer( self, this )
    return this:GetSquadID()
end

e2function number doesSquadExist( number id )
    return SquadMenu:GetSquad( id ) == nil and 0 or 1
end

e2function string getSquadName( number id )
    local squad = SquadMenu:GetSquad( id )
    return squad and squad.name or ""
end

e2function vector getSquadColor( number id )
    local squad = SquadMenu:GetSquad( id )
    return squad and Vector( squad.r, squad.g, squad.b ) or Vector()
end

e2function number getSquadMemberCount( number id )
    local squad = SquadMenu:GetSquad( id )
    return squad and #squad.members or 0
end

e2function array getSquadMembers( number id )
    local squad = SquadMenu:GetSquad( id )
    if not squad then return {} end

    local members = {}

    for _, ply in ipairs( squad.members ) do
        if IsValid( ply ) then
            members[#members + 1] = ply
        end
    end

    return members
end

e2function array getAllSquadIDs()
    local all, i = {}, 0

    for id, _ in pairs( SquadMenu.squads ) do
        i = i + 1
        all[i] = id
    end

    return all
end
