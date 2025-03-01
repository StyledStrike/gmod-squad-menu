SquadMenu = SquadMenu or {}

if CLIENT then
    -- Settings file
    SquadMenu.DATA_FILE = "squad_menu.json"
end

-- Chat prefixes that allow messaging squad members only
SquadMenu.CHAT_PREFIXES = { "/s", "!s", "/p", "!pchat" }

-- Primary color used for the UI theme
SquadMenu.THEME_COLOR = Color( 34, 52, 142 )

-- Max. length of a squad name
SquadMenu.MAX_NAME_LENGTH = 30

-- Size limit for JSON data
SquadMenu.MAX_JSON_SIZE = 49152 -- 48 kibibytes

-- Used on net.WriteUInt for the command ID
SquadMenu.COMMAND_SIZE = 4

-- Command IDs (Max. ID when COMMAND_SIZE = 4 is 15)
SquadMenu.BROADCAST_EVENT = 0
SquadMenu.SQUAD_LIST = 1
SquadMenu.SETUP_SQUAD = 2
SquadMenu.JOIN_SQUAD = 3
SquadMenu.LEAVE_SQUAD = 4
SquadMenu.ACCEPT_REQUESTS = 5
SquadMenu.REQUESTS_LIST = 6
SquadMenu.KICK = 7
SquadMenu.PING = 8

-- Reasons given when a member is removed from a squad
SquadMenu.LEAVE_REASON_DELETED = 0
SquadMenu.LEAVE_REASON_LEFT = 1
SquadMenu.LEAVE_REASON_KICKED = 2

-- Server settings
local maxMembersCvar = CreateConVar(
    "squad_max_members",
    "10",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Limits how many members a single squad can have.",
    1, 100
)

local squadListPosCvar = CreateConVar(
    "squad_members_position",
    "6",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Sets the position of the squad members on the screen. Takes numbers betweek 1-9 and uses the same positions as a numpad.",
    1, 9
)

local broadcastCvar = CreateConVar(
    "squad_broadcast_creation_message",
    "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "When set to 1, Squad Menu will print when a new squad is created on the chat.",
    0, 1
)

local friendlyfireCvar = CreateConVar(
    "squad_force_friendly_fire",
    "0",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Makes so squads always have friendly fire enabled.",
    0, 1
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
    return maxMembersCvar:GetInt()
end

function SquadMenu.GetMembersPosition()
    return squadListPosCvar:GetInt()
end

function SquadMenu.GetShowCreationMessage()
    return broadcastCvar:GetInt() > 0
end

function SquadMenu.GetForceFriendlyFire()
    return friendlyfireCvar:GetInt() > 0
end

function SquadMenu.GetPlayerId( ply )
    if ply:IsBot() then
        return "BOT_" .. ply:AccountID()
    end

    return ply:SteamID()
end

local PID = SquadMenu.GetPlayerId

function SquadMenu.AllPlayersById()
    local all = player.GetAll()
    local byId = {}

    for _, ply in ipairs( all ) do
        byId[PID( ply )] = ply
    end

    return byId
end

function SquadMenu.FindPlayerById( id )
    local all = player.GetAll()

    for _, ply in ipairs( all ) do
        if id == PID( ply ) then return ply end
    end
end

function SquadMenu.ValidateNumber( n, default, min, max )
    return math.Clamp( tonumber( n ) or default, min, max )
end

function SquadMenu.ValidateString( s, default, maxLength )
    if type( s ) ~= "string" then
        return default
    end

    s = string.Trim( s )

    if s == "" then
        return default
    end

    if s:len() > maxLength then
        return string.Left( s, maxLength - 3 ) .. "..."
    end

    return s
end

function SquadMenu.StartCommand( id )
    net.Start( "squad_menu.command", false )
    net.WriteUInt( id, SquadMenu.COMMAND_SIZE )
end

function SquadMenu.WriteTable( t )
    local data = util.Compress( SquadMenu.TableToJSON( t ) )
    local bytes = #data

    net.WriteUInt( bytes, 16 )

    if bytes > SquadMenu.MAX_JSON_SIZE then
        SquadMenu.PrintF( "Tried to write JSON that was too big! (%d/%d)", bytes, SquadMenu.MAX_JSON_SIZE )
        return
    end

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
    -- Shared files
    include( "squad_menu/player.lua" )
    AddCSLuaFile( "squad_menu/player.lua" )

    -- Server files
    include( "squad_menu/server/main.lua" )
    include( "squad_menu/server/squad.lua" )
    include( "squad_menu/server/network.lua" )

    -- Client files
    AddCSLuaFile( "styledstrike/theme.lua" )

    AddCSLuaFile( "squad_menu/client/main.lua" )
    AddCSLuaFile( "squad_menu/client/config.lua" )
    AddCSLuaFile( "squad_menu/client/menu.lua" )
    AddCSLuaFile( "squad_menu/client/hud.lua" )

    AddCSLuaFile( "squad_menu/client/vgui/member_status.lua" )
    AddCSLuaFile( "squad_menu/client/vgui/squad_list_row.lua" )
end

if CLIENT then
    -- Shared files
    include( "squad_menu/player.lua" )

    -- Client files
    include( "styledstrike/theme.lua" )

    local fonts = StyledTheme.fonts

    fonts["SquadMenuInfo"] = {
        screenSize = 0.016,
        font = "Roboto-Condensed",
        extended = false,
        weight = 600,
        blursize = 0,
        scanlines = 0,
        antialias = true
    }

    include( "squad_menu/client/main.lua" )
    include( "squad_menu/client/config.lua" )
    include( "squad_menu/client/menu.lua" )
    include( "squad_menu/client/hud.lua" )

    include( "squad_menu/client/vgui/member_status.lua" )
    include( "squad_menu/client/vgui/squad_list_row.lua" )
end
