--- Squad Menu library. Contains functions for getting more information about squads
-- @name squad
-- @class library
-- @libtbl squad_library
SF.RegisterLibrary( "squad" )

return function( instance )

local CheckType = instance.CheckType
local player_methods = instance.Types.Player.Methods
local ply_meta, punwrap = instance.Types.Player, instance.Types.Player.Unwrap

local function GetPlayer( this )
    local ent = punwrap( this )

    if ent:IsValid() then
        return ent
    end

    SF.Throw( "Player is not valid.", 3 )
end

--- Returns true is this player is part of a squad.
-- @shared
-- @return boolean
function player_methods:isSquadMember()
    CheckType( self, ply_meta )

    local ply = GetPlayer( self )
    return ply:GetSquadID() ~= -1
end

--- Get the ID of the squad this player is part of.
-- @shared
-- @return number Squad ID. -1 if this player is not in one.
function player_methods:getSquadID()
    CheckType( self, ply_meta )

    local ply = GetPlayer( self )
    return ply:GetSquadID()
end

if SERVER then
    local CheckLuaType = SF.CheckLuaType
    local WrapColor = instance.Types.Color.Wrap
    local WrapPlayer = instance.Types.Player.Wrap
    local squad_library = instance.Libraries.squad

    --- Returns true if the given ID points to a valid squad.
    -- @server
    -- @param number id The squad ID
    -- @return boolean
    function squad_library.exists( id )
        CheckLuaType( id, TYPE_NUMBER )
        return SquadMenu:GetSquad( id ) ~= nil
    end

    --- Returns a table with all available squads. Each item contains these keys:
    --- - number id
    --- - string name
    --- - string icon
    --- - Player leader
    --- - Color color
    --- - boolean isPublic
    --- - boolean friendlyFire
    -- @server
    -- @return table
    function squad_library.getAll()
        local all, i = {}, 0

        for id, squad in pairs( SquadMenu.squads ) do
            i = i + 1
            all[i] = {
                id = id,
                name = squad.name,
                icon = squad.icon,
                leader = WrapPlayer( squad.leader ),
                color = WrapColor( Color( squad.r, squad.g, squad.b ) ),

                isPublic = squad.isPublic,
                friendlyFire = squad.friendlyFire
            }
        end

        return all
    end

    --- Finds a squad by it's ID and returns the name. Returns nil if the squad does not exist.
    -- @server
    -- @param number id The squad ID
    -- @return string?
    function squad_library.getName( id )
        CheckLuaType( id, TYPE_NUMBER )

        local squad = SquadMenu:GetSquad( id )
        return squad and squad.name or nil
    end

    --- Finds a squad by it's ID and returns the color. Returns nil if the squad does not exist.
    -- @server
    -- @param number id The squad ID
    -- @return Color?
    function squad_library.getColor( id )
        CheckLuaType( id, TYPE_NUMBER )

        local squad = SquadMenu:GetSquad( id )
        return squad and WrapColor( Color( squad.r, squad.g, squad.b ) ) or nil
    end

    --- Returns the number of members in a squad. Returns nil if the squad does not exist.
    -- @server
    -- @param number id The squad ID
    -- @return number?
    function squad_library.getMemberCount( id )
        CheckLuaType( id, TYPE_NUMBER )

        local squad = SquadMenu:GetSquad( id )
        return squad and #squad.members or nil
    end

    --- Returns an table of players in the squad. Returns nil if the squad does not exist.
    -- @server
    -- @param number id The squad ID
    -- @return table?
    function squad_library.getMembers( id )
        CheckLuaType( id, TYPE_NUMBER )

        local squad = SquadMenu:GetSquad( id )
        if not squad then return end

        local members = {}

        for _, ply in ipairs( squad.members ) do
            if IsValid( ply ) then
                members[#members + 1] = WrapPlayer( ply )
            end
        end

        return members
    end
end

end
