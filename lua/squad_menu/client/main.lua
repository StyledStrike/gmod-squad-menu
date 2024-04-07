concommand.Add(
    "squad_menu",
    function() SquadMenu:OpenSquadMenu() end,
    nil,
    "Opens the squad menu."
)

if engine.ActiveGamemode() == "sandbox" then
    list.Set(
        "DesktopWindows",
        "SquadMenuDesktopIcon",
        {
            title = SquadMenu.GetLanguageText( "title" ),
            icon = "materials/icon128/squad_menu.png",
            init = function() SquadMenu:OpenSquadMenu() end
        }
    )
end

----------

local L = SquadMenu.GetLanguageText

function SquadMenu:SetMembers( newMembers, printMessages )
    local members = self.mySquad.members
    local membersById = self.mySquad.membersById

    local keep = {}

    -- Add new members that we do not have on our end
    for _, member in ipairs( newMembers ) do
        local id = member.id

        keep[id] = true

        if not membersById[id] then
            membersById[id] = member
            members[#members + 1] = member

            self:AddMemberToHUD( member )

            if printMessages then
                self.ChatPrint( string.format( L"member_joined", member.name ) )
            end
        end
    end

    -- Remove members that we have on our end but do not exist in newMembers
    -- Backwards loop because we use table.remove
    for i = #members, 1, -1 do
        local member = members[i]
        local id = member.id

        if not keep[id] then
            membersById[id] = nil
            table.remove( members, i )

            self:RemoveMemberFromHUD( member )

            if printMessages then
                self.ChatPrint( string.format( L"member_left", member.name ) )
            end
        end
    end

    -- Remove join requests from players in newMembers
    local requests = self.mySquad.requests

    -- Backwards loop because we use table.remove
    for i = #requests, 1, -1 do
        local member = requests[i]
        local id = member.id

        if keep[id] then
            table.remove( requests, i )
        end
    end
end

function SquadMenu:SetupSquad( data )
    local squad = self.mySquad or { id = -1 }

    self.mySquad = squad

    local isUpdate = data.id == squad.id

    squad.id = data.id
    squad.name = data.name
    squad.icon = data.icon

    squad.leaderId = data.leaderId
    squad.leaderName = data.leaderName

    squad.enableRings = data.enableRings
    squad.friendlyFire = data.friendlyFire
    squad.isPublic = data.isPublic

    squad.color = Color( data.r, data.g, data.b )

    if not isUpdate then
        squad.requests = {}
        squad.members = {}
        squad.membersById = {}

        self.ChatPrint( L"squad_welcome", squad.color, " " .. squad.name )
        self.ChatPrint( L"chat_tip", " " .. table.concat( self.CHAT_PREFIXES, ", " ) )

        sound.Play( "buttons/combine_button3.wav", Vector(), 0, 120, 0.75 )
    end

    self:FullUpdateSquadMenu()
    self:UpdateMembersHUD()
    self:SetMembers( data.members, isUpdate )
end

function SquadMenu:OnLeaveSquad( reason )
    local reasonText = {
        [self.LEAVE_REASON_DELETED] = "deleted_squad",
        [self.LEAVE_REASON_KICKED] = "kicked_from_squad"
    }

    if self.mySquad then
        self.ChatPrint( L( reasonText[reason] or "left_squad" ) )

        sound.Play( "buttons/combine_button2.wav", Vector(), 0, 120, 0.75 )
    end

    self.mySquad = nil

    self:RemoveMembersHUD()
    self:FullUpdateSquadMenu( true )
end

----------

local commands = {}

commands[SquadMenu.BROADCAST_EVENT] = function()
    local data = SquadMenu.JSONToTable( net.ReadString() )
    local event = data.eventName

    SquadMenu.PrintF( "Event received: %s", event )

    if event == "open_menu" then
        SquadMenu:OpenSquadMenu()

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
        -- Update the squad list (if it's open)
        SquadMenu:RequestSquadListUpdate()

    elseif event == "members_chat" then
        local squad = SquadMenu.mySquad
        if not squad then return end

        local white = Color( 255, 255, 255 )

        chat.AddText( white, "[", squad.color, squad.name, white, "] ",
            squad.color, data.senderName, white, ": ", data.text )
    end
end

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

    -- Compare the new request IDs against what we already got
    local requestIds = SquadMenu.ReadTable()
    local newCount = 0

    for _, member in ipairs( requestIds ) do
        if not alreadyRequested[member.id] then
            -- This is a new request for us
            requests[#requests + 1] = member
            newCount = newCount + 1

            SquadMenu.ChatPrint( string.format( L"request_message", member.name ) )
        end
    end

    if newCount > 0 then
        sound.Play( "buttons/combine_button1.wav", Vector(), 0, 120, 0.8 )
    end

    SquadMenu:UpdateRequestsPanel()
end

net.Receive( "squad_menu.command", function()
    local cmd = net.ReadUInt( SquadMenu.COMMAND_SIZE )

    if not commands[cmd] then
        SquadMenu.PrintF( "Received a unknown network command! (%d)", cmd )
        return
    end

    commands[cmd]( ply, ent )
end )
