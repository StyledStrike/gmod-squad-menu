# Simple Squad menu

A basic squad/party creation addon for Garry's Mod.

### Features

* Create a private or public squad with a custom name, icon and color
* Players can view all available squads and join/request to join them
* Squad leaders can choose if your members can damage eachother (friendly fire)
* Squad members can see the health/armor of all members
* Squad members have indicators in the world so you can tell who is on your squad

### For developers

You can check a Player's squad by calling this function:

```lua
-- Available both on SERVER and CLIENT.
-- Will be -1 if this player is not in a squad.
local id = Player:GetSquadID()

-- You can use this function to get the squad instance.
local squad = SquadMenu:GetSquad( id )

--[[
    This allows you to access things like:

    squad.name      - string
    squad.icon      - string
    squad.leader    - Player

    squad.enableRings   - boolean
    squad.friendlyFire  - boolean
    squad.isPublic      - boolean

    squad.members - Player[]

    Please do not modify squad.members directly.
    Check out squad:AddMember and squad:RemoveMember if you need to. 
]]
```

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

# Contributing

Before you open a pull request, if it deals with Lua code, please read [this](https://github.com/StyledStrike/gmod-squad-menu/blob/main/.github/pull_request_template.md).
