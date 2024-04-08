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
            icon = "materials/icon128/squad_menu.png",
            init = function() SquadMenu:OpenFrame() end
        }
    )
end

----------

local Config = SquadMenu.Config or {}

SquadMenu.Config = Config

function Config:Reset()
    self.showMembers = true
    self.showRings = true
    self.showHalos = false
    self.enableSounds = true
    self.drawDistance = 2000
end

function Config:Load()
    self:Reset()

    local data = file.Read( SquadMenu.DATA_FILE, "DATA" )
    if not data then return end

    data = SquadMenu.JSONToTable( data )

    self.showMembers = data.showMembers == true
    self.showRings = data.showRings == true
    self.showHalos = data.showHalos == true
    self.enableSounds = data.enableSounds == true

    self.drawDistance = SquadMenu.ValidateNumber( data.drawDistance, 2000, 500, 50000 )
end

function Config:Save( immediate )
    if not immediate then
        -- avoid spamming the file system
        timer.Remove( "SquadMenu.SaveConfigDelay" )
        timer.Create( "SquadMenu.SaveConfigDelay", 0.5, 1, function()
            self:Save( true )
        end )

        return
    end

    local path = SquadMenu.DATA_FILE

    local data = SquadMenu.TableToJSON( {
        showMembers = self.showMembers,
        showRings = self.showRings,
        showHalos = self.showHalos,
        enableSounds = self.enableSounds
    } )

    SquadMenu.PrintF( "%s: writing %s", path, string.NiceSize( string.len( data ) ) )
    file.Write( path, data )

    if SquadMenu.mySquad then
        SquadMenu:UpdateMembersHUD()
    end
end

Config:Load()

----------

local L = SquadMenu.GetLanguageText

function SquadMenu:PlayUISound( path )
    if self.Config.enableSounds then
        sound.Play( path, Vector(), 0, 120, 0.75 )
    end
end

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
        self:PlayUISound( "buttons/combine_button3.wav" )
    end

    self:UpdateMembersHUD()
    self:SetMembers( data.members, isUpdate )

    if IsValid( self.frame ) then
        self:UpdateSquadList()
        self:UpdateSquadStatePanel()
        self:UpdateRequestsPanel()
        self:UpdateSquadMembersPanel()
        self:UpdateSquadPropertiesPanel()

        self.frame:SetActiveTabByIndex( 3 ) -- squad members
    end
end

function SquadMenu:OnLeaveSquad( reason )
    local reasonText = {
        [self.LEAVE_REASON_DELETED] = "deleted_squad",
        [self.LEAVE_REASON_KICKED] = "kicked_from_squad"
    }

    if self.mySquad then
        self.ChatPrint( L( reasonText[reason] or "left_squad" ) )
        self:PlayUISound( "buttons/combine_button2.wav" )
    end

    self.mySquad = nil
    self:RemoveMembersHUD()

    if IsValid( self.frame ) then
        self:UpdateSquadStatePanel()
        self:UpdateRequestsPanel()
        self:UpdateSquadMembersPanel()
        self:UpdateSquadPropertiesPanel()

        if self.frame.lastTabIndex ~= 5 then -- not in settings
            self.frame:SetActiveTabByIndex( 1 ) -- squad list
        end

        -- prevent calling list update twice when the leader leaves
        if reason ~= self.LEAVE_REASON_DELETED then
            self:RequestSquadListUpdate()
        end
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
        SquadMenu:PlayUISound( "buttons/combine_button1.wav" )
    end

    SquadMenu:UpdateRequestsPanel()
end

commands[SquadMenu.BROADCAST_EVENT] = function()
    local data = SquadMenu.JSONToTable( net.ReadString() )
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

    elseif event == "members_chat" then
        local squad = SquadMenu.mySquad
        if not squad then return end

        local white = Color( 255, 255, 255 )

        chat.AddText( white, "[", squad.color, squad.name, white, "] ",
            squad.color, data.senderName, white, ": ", data.text )
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
