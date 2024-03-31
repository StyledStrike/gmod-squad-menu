SquadMenu = {
    THEME_COLOR = Color( 34, 52, 142 ),

    -- Max. length of a squad name
    MAX_NAME_LENGTH = 30,

    -- Size limit for JSON data
    MAX_JSON_SIZE = 49152, -- 48 kibibytes

    -- Used on net.WriteUInt for the command ID
    COMMAND_SIZE = 3,

    -- Command IDs (Max. ID when COMMAND_SIZE = 3 is 7)
    BROADCAST_EVENT = 0,
    SQUAD_LIST = 1,
    SETUP_SQUAD = 2,
    JOIN_SQUAD = 3,
    LEAVE_SQUAD = 4,
    ACCEPT_REQUESTS = 5,
    REQUESTS_LIST = 6,
    KICK = 7,

    -- Reasons given when a member is removed from a squad
    LEAVE_REASON_DELETED = 0,
    LEAVE_REASON_LEFT = 1,
    LEAVE_REASON_KICKED = 2
}

CreateConVar(
    "squad_max_members",
    "10",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Limits how many members a single squad can have.",
    0, 100
)

CreateConVar(
    "squad_name_render_distance",
    "2000",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Sets the render distance of squad members' names.",
    100, 10000
)

function SquadMenu.PrintF( str, ... )
    MsgC( SquadMenu.THEME_COLOR, "[Squad Menu] ", Color( 255, 255, 255 ), string.format( str, ... ), "\n" )
end

function SquadMenu.TableToJSON( t )
    return util.TableToJSON( t, false )
end

function SquadMenu.JSONToTable( s )
    if type( s ) ~= "string" or s == "" then
        return {}
    end

    return util.JSONToTable( s ) or {}
end

function SquadMenu.GetMemberLimit()
    local cvarLimit = GetConVar( "squad_max_members" )
    return cvarLimit and cvarLimit:GetInt() or 10
end

function SquadMenu.GetNameRenderDistance()
    local cvarDistance = GetConVar( "squad_name_render_distance" )
    return cvarDistance and cvarDistance:GetInt() or 1000
end

function SquadMenu.AllPlayersBySteamID()
    local all = player.GetHumans()
    local byId = {}

    for _, p in ipairs( all ) do
        byId[p:SteamID()] = p
    end

    return byId
end

function SquadMenu.StartCommand( id )
    net.Start( "squad_menu.command", false )
    net.WriteUInt( id, SquadMenu.COMMAND_SIZE )
end

function SquadMenu.BroadcastEvent( name, data )
    data.eventName = name

    SquadMenu.StartCommand( SquadMenu.BROADCAST_EVENT )
    net.WriteString( SquadMenu.TableToJSON( data ) )
    net.Broadcast()
end

function SquadMenu.WriteTable( t )
    local data = util.Compress( SquadMenu.TableToJSON( t ) )
    local bytes = #data

    if bytes > SquadMenu.MAX_JSON_SIZE then
        SquadMenu.PrintF( "Tried to write JSON that was too big! (%d/%d)", bytes, SquadMenu.MAX_JSON_SIZE )
        return
    end

    net.WriteUInt( bytes, 16 )
    net.WriteData( data )
end

function SquadMenu.ReadTable()
    local bytes = net.ReadUInt( 16 )

    if bytes > SquadMenu.MAX_JSON_SIZE then
        SquadMenu.PrintF( "Tried to read JSON that was too big! (%d/%d)", bytes, SquadMenu.MAX_JSON_SIZE )
        return {}
    end

    local data = net.ReadData( bytes )
    return SquadMenu.JSONToTable( util.Decompress( data ) )
end

if SERVER then
    util.AddNetworkString( "squad_menu.command" )

    -- Shared files
    include( "squad_menu/sh_player.lua" )
    AddCSLuaFile( "squad_menu/sh_player.lua" )

    -- Server files
    include( "squad_menu/server/squad.lua" )
    include( "squad_menu/server/network.lua" )

    -- Client files
    AddCSLuaFile( "squad_menu/client/theme.lua" )
    AddCSLuaFile( "squad_menu/client/main.lua" )
    AddCSLuaFile( "squad_menu/client/menu.lua" )
    AddCSLuaFile( "squad_menu/client/hud.lua" )
end

if CLIENT then
    function SquadMenu.GetLanguageText( id )
        return language.GetPhrase( "squad_menu." .. id )
    end

    function SquadMenu.ChatPrint( ... )
        chat.AddText( SquadMenu.THEME_COLOR, "[" .. SquadMenu.GetLanguageText( "title" )  .. "] ", Color( 255, 255, 255 ), ... )
    end

    -- Shared files
    include( "squad_menu/sh_player.lua" )

    -- Client files
    include( "squad_menu/client/theme.lua" )
    include( "squad_menu/client/main.lua" )
    include( "squad_menu/client/menu.lua" )
    include( "squad_menu/client/hud.lua" )
end
