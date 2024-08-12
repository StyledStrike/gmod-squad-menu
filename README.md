# Simple Squad menu

[![GLuaLint](https://github.com/StyledStrike/gmod-squad-menu/actions/workflows/glualint.yml/badge.svg)](https://github.com/FPtje/GLuaFixer)
[![Workshop Page](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-steam-workshop.jross.me%2F3207278246%2Fsubscriptions-text)](https://steamcommunity.com/sharedfiles/filedetails/?id=3207278246)

A basic squad/party creation addon for Garry's Mod.

## Features

* Create a private or public squad with a custom name, icon and color
* Players can view all available squads and join/request to join them
* Squad leaders can choose if your members can damage eachother (friendly fire)
* Squad members can see the health/armor of all members
* Squad members have indicators in the world so you can tell who is on your squad

## For developers

You can check a Player's squad by calling this function:

```lua
-- Available both on SERVER and CLIENT.
-- Will be -1 if this player is not in a squad.
local id = Player:GetSquadID()
```

**On the server only**, you can use this function to get a specific squad instance:

```lua
local squad = SquadMenu:GetSquad( id )

--[[
    This allows you to access things like:

    squad.name      - string
    squad.icon      - string
    squad.leader    - Player

    squad.enableRings   - boolean
    squad.friendlyFire  - boolean
    squad.isPublic      - boolean
]]

-- You can get the player entities that are part of the squad with:
local players = squad:GetActiveMembers()

-- "p" represents a player Entity or a string you can get from SquadMenu.GetPlayerId:
squad:AddMember( p )
squad:RemoveMember( p, reason ) -- reason is a number from SquadMenu.LEAVE_REASON_*
```

### Hook: `ShouldAllowSquadName`

You can also filter the squad name before it's assigned by using the `ShouldAllowSquadName` hook **on the server**.

```lua
hook.Add( "ShouldAllowSquadName", "BlockWordsExample", function( name, leader )
    -- When you only return false, the squad will be "Unamed".
    if string.find( name, "amogus" ) then
        return false
    end

    -- Optionally you can also return a second value for the name
    if string.find( name, "sus" ) then
        return false, string.Replace( name, "sus", "nope" )
    end
end )
```

### Hook: `SquadPlayerSay`

You can also override/filter squad-only messages by using the `SquadPlayerSay` hook **on the server**.

```lua
hook.Add( "SquadPlayerSay", "BlockMessagesExample", function( sender, text )
    -- When you return false, the message will not be sent.
    if string.find( text, "amogus" ) then
        return false
    end

    -- You can return a string to override the message.
    if string.find( text, "sus" ) then
        return string.Replace( text, "sus", "nope" )
    end
end )
```

### Hooks: `SquadMenu_OnJoinedSquad` and `SquadMenu_OnLeftSquad`

You can use these hooks to detect when a player has joined/left a squad **on the server**.

```lua
hook.Add( "SquadMenu_OnJoinedSquad", "JoinedSquadExample", function( squadId, ply, plySteamID )
    -- Get the squad instance's name
    local squadName = SquadMenu:GetSquad( squadId ).name

    -- Get the player name, if the player is not valid then just use their SteamID
    local playerName = IsValid( ply ) and ply:Nick() or plySteamID

    -- Print a message on everyone's chat
    for _, p in ipairs( player.GetAll() ) do
        p:ChatPrint( playerName .. " joined the squad: " .. squadName )
    end
end )

hook.Add( "SquadMenu_OnLeftSquad", "LeftSquadExample", function( squadId, ply, plySteamID )
    -- Get the squad instance's name
    local squadName = SquadMenu:GetSquad( squadId ).name

    -- Get the player name, if the player is not valid then just use their SteamID
    local playerName = IsValid( ply ) and ply:Nick() or plySteamID

    -- Print a message on everyone's chat
    for _, p in ipairs( player.GetAll() ) do
        p:ChatPrint( playerName .. " left the squad: " .. squadName )
    end
end )
```

# Contributing

Before you open a pull request, if it deals with Lua code, please read [this](https://github.com/StyledStrike/gmod-squad-menu/blob/main/.github/pull_request_template.md).
