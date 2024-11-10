function SquadMenu.GetLanguageText( id )
    return language.GetPhrase( "squad_menu." .. id ):Trim()
end

function SquadMenu:PlayUISound( path )
    if self.Config.enableSounds then
        sound.Play( path, Vector(), 0, 120, 0.75 )
    end
end

local L = SquadMenu.GetLanguageText

function SquadMenu.GlobalMessage( ... )
    chat.AddText( SquadMenu.THEME_COLOR, "[" .. L( "title" )  .. "] ", Color( 255, 255, 255 ), ... )
end

function SquadMenu.SquadMessage( ... )
    local squad = SquadMenu.mySquad
    if not squad then return end

    local contents = { color_white, "[", squad.color, squad.name, color_white, "] ", ... }

    if CustomChat then
        CustomChat:AddMessage( contents, "squad" )
    else
        chat.AddText( unpack( contents ) )
    end
end

function SquadMenu.LeaveMySquad( buttonToBlank, leaveNow )
    local squad = SquadMenu.mySquad
    if not squad then return end

    if not leaveNow and squad.leaderId == SquadMenu.GetPlayerId( LocalPlayer() ) then
        Derma_Query( L"leave_leader", L"leave_squad", L"yes", function()
            SquadMenu.LeaveMySquad( buttonToBlank, true )
        end, L"no" )

        return
    end

    if IsValid( buttonToBlank ) then
        buttonToBlank:SetEnabled( false )
        buttonToBlank:SetText( "..." )
    end

    SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
    net.SendToServer()
end

--- If GMinimap is installed, update squad members' blips.
function SquadMenu:UpdatePlayerBlips( icon, color )
    if not self.mySquad then return end

    local me = LocalPlayer()
    local byId = self.AllPlayersById()

    for _, member in ipairs( self.mySquad.members ) do
        local ply = byId[member.id]

        if ply and ply ~= me then
            ply:SetBlipIcon( icon )
            ply:SetBlipColor( color )
        end
    end
end

--- Set the current members of the local player's squad.
--- Updates the HUD and shows join/leave messages (if `printMessages` is `true`).
---
--- `newMembers` is an array where items are also arrays
--- with a number (player id) and a string (player name).
function SquadMenu:SetMembers( newMembers, printMessages )
    local members = self.mySquad.members
    local membersById = self.mySquad.membersById
    local keep = {}

    -- Add new members that we do not have on our end
    for _, m in ipairs( newMembers ) do
        local id = m[1]
        local member = { id = id, name = m[2] }

        keep[id] = true

        if not membersById[id] then
            membersById[id] = member
            members[#members + 1] = member

            self:AddMemberToHUD( member )

            if printMessages then
                self.SquadMessage( string.format( L"member_joined", member.name ) )
            end
        end
    end

    local byId = self.AllPlayersById()

    -- Remove members that we have locally but do not exist on `newMembers`.
    -- Backwards loop because we use `table.remove`
    for i = #members, 1, -1 do
        local member = members[i]
        local id = member.id

        if not keep[id] then
            membersById[id] = nil
            table.remove( members, i )

            self:RemoveMemberFromHUD( member )

            if printMessages then
                self.SquadMessage( string.format( L"member_left", member.name ) )
            end

            local ply = byId[id]

            if IsValid( ply ) and GMinimap then
                ply:SetBlipIcon( nil )
                ply:SetBlipColor( nil )
            end
        end
    end
end

--- Set the local player's squad.
--- `data` is a table that comes from `squad:GetBasicInfo`.
function SquadMenu:SetupSquad( data )
    local squad = self.mySquad or { id = -1 }
    local isUpdate = data.id == squad.id

    self.mySquad = squad

    squad.id = data.id
    squad.name = data.name
    squad.icon = data.icon

    squad.leaderId = data.leaderId
    squad.leaderName = data.leaderName or ""

    squad.enableRings = data.enableRings
    squad.friendlyFire = data.friendlyFire
    squad.isPublic = data.isPublic

    squad.color = Color( data.r, data.g, data.b )

    if CustomChat and squad.name then
        CustomChat:CreateCustomChannel( "squad", squad.name, squad.icon )
    end

    if not isUpdate then
        squad.requests = {}
        squad.members = {}
        squad.membersById = {}

        self:PlayUISound( "buttons/combine_button3.wav" )
        self.SquadMessage( L"squad_welcome", squad.color, " " .. squad.name )
        self.SquadMessage( L"chat_tip", " " .. table.concat( self.CHAT_PREFIXES, ", " ) )
    end

    self:UpdateMembersHUD()
    self:SetMembers( data.members, isUpdate )

    if IsValid( self.frame ) then
        self:RequestSquadListUpdate()
        self:UpdateSquadStatePanel()
        self:UpdateRequestsPanel()
        self:UpdateSquadMembersPanel()
        self:UpdateSquadPropertiesPanel()

        self.frame:SetActiveTabByIndex( 3 ) -- squad members
    end

    if GMinimap then
        self:UpdatePlayerBlips( "gminimap/blips/npc_default.png", squad.color )

        hook.Add( "CanSeePlayerBlip", "ShowSquadBlips", function( ply )
            if ply:GetSquadID() == squad.id then return true, 50000 end
        end )
    end
end

function SquadMenu:OnLeaveSquad( reason )
    if GMinimap then
        self:UpdatePlayerBlips( nil, nil )
        hook.Remove( "CanSeePlayerBlip", "ShowSquadBlips" )
    end

    local reasonText = {
        [self.LEAVE_REASON_DELETED] = "deleted_squad",
        [self.LEAVE_REASON_KICKED] = "kicked_from_squad"
    }

    if self.mySquad then
        self.GlobalMessage( L( reasonText[reason] or "left_squad" ) )
        self:PlayUISound( "buttons/combine_button2.wav" )
    end

    self.mySquad = nil
    self:RemoveMembersHUD()

    if IsValid( self.frame ) then
        self:RequestSquadListUpdate()
        self:UpdateSquadStatePanel()
        self:UpdateRequestsPanel()
        self:UpdateSquadMembersPanel()
        self:UpdateSquadPropertiesPanel()

        if self.frame.lastTabIndex ~= 5 then -- not in settings
            self.frame:SetActiveTabByIndex( 1 ) -- squad list
        end
    end

    if CustomChat then
        CustomChat:RemoveCustomChannel( "squad" )
    end
end

----------

local commands = {}

commands[SquadMenu.SQUAD_LIST] = function()
    SquadMenu:UpdateSquadList( SquadMenu.ReadTable() )
end

commands[SquadMenu.SETUP_SQUAD] = function()
    local data = SquadMenu.ReadTable()
    SquadMenu:SetupSquad( data )
end

commands[SquadMenu.LEAVE_SQUAD] = function()
    local reason = net.ReadUInt( 3 )
    SquadMenu:OnLeaveSquad( reason )
end

commands[SquadMenu.REQUESTS_LIST] = function()
    local squad = SquadMenu.mySquad
    if not squad then return end

    local requests = squad.requests

    -- Remember which players have requested before
    local alreadyRequested = {}

    for _, member in ipairs( requests ) do
        alreadyRequested[member.id] = true
    end

    -- Compare the new requests against what we already got
    local requestsById = SquadMenu.ReadTable()
    local newCount = 0

    for id, name in pairs( requestsById ) do
        if not alreadyRequested[id] then
            -- This is a new request for us
            requests[#requests + 1] = { id = id, name = name }
            newCount = newCount + 1

            SquadMenu.SquadMessage( string.format( L"request_message", name ) )
        end
    end

    if newCount > 0 then
        SquadMenu:PlayUISound( "buttons/combine_button1.wav" )
    end

    -- Remove requests we already got if they aren't on the new requests list
    for i = #requests, 1, -1 do
        local member = requests[i]

        if not requestsById[member.id] then
            table.remove( requests, i )
        end
    end

    SquadMenu:UpdateRequestsPanel()
end

commands[SquadMenu.PING] = function()
    local pos = net.ReadVector()
    local label = net.ReadString()
    local id = net.ReadString()

    local ping = SquadMenu.pings[id]

    if not ping then
        ping = {}
    end

    ping.pos = pos
    ping.label = label
    ping.start = RealTime()
    ping.lifetime = 5

    SquadMenu.pings[id] = ping

    if not SquadMenu.Config.enableSounds then return end

    local eyePos = EyePos()
    local soundDir = pos - eyePos
    soundDir:Normalize()

    sound.Play( "friends/friend_join.wav", eyePos + soundDir * 500, 100, 120, 1 )
end

commands[SquadMenu.BROADCAST_EVENT] = function()
    local data = SquadMenu.ReadTable()
    local event = data.event

    SquadMenu.PrintF( "Event received: %s", event )

    if event == "open_menu" then
        SquadMenu:OpenFrame()

    elseif event == "squad_position_changed" then
        if SquadMenu.membersPanel then
            SquadMenu.membersPanel:InvalidateLayout()
        end

    elseif event == "player_joined_squad" then
        local squad = SquadMenu.mySquad
        if not squad then return end

        -- Remove this player from my requests list
        local requests = squad.requests

        for i, member in ipairs( requests ) do
            if data.playerId == member.id then
                table.remove( requests, i )
                break
            end
        end

        SquadMenu:UpdateRequestsPanel()

    elseif event == "squad_created" or event == "squad_deleted" then
        SquadMenu:RequestSquadListUpdate()

        if event == "squad_created" and data.name and SquadMenu.GetShowCreationMessage() then
            local color = Color( data.r, data.g, data.b )
            SquadMenu.GlobalMessage( string.format( L"squad_created", data.leaderName ), color, " " .. data.name )
        end

    elseif event == "members_chat" then
        local squad = SquadMenu.mySquad
        if not squad then return end

        SquadMenu.SquadMessage( squad.color, data.senderName, color_white, ": ", data.text )
    end
end

net.Receive( "squad_menu.command", function()
    local cmd = net.ReadUInt( SquadMenu.COMMAND_SIZE )

    if not commands[cmd] then
        SquadMenu.PrintF( "Received a unknown network command! (%d)", cmd )
        return
    end

    commands[cmd]( ply, ent )
end )

concommand.Add(
    "squad_menu",
    function() SquadMenu:OpenFrame() end,
    nil,
    "Opens the squad menu."
)

if engine.ActiveGamemode() == "sandbox" then
    list.Set(
        "DesktopWindows",
        "SquadMenuDesktopIcon",
        {
            title = SquadMenu.GetLanguageText( "title" ),
            icon = "materials/squad_menu/squad_menu.png",
            init = function() SquadMenu:OpenFrame() end
        }
    )
end

hook.Add( "InitPostEntity", "SquadMenu.CreateFont", function()
    surface.CreateFont( "SquadMenuInfo", {
        font = "Roboto-Condensed",
        extended = true,
        size = math.floor( ScrH() * 0.016 ),
        weight = 600,
        blursize = 0,
        scanlines = 0,
        antialias = true,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = false,
        additive = false,
        outline = false
    } )
end )
