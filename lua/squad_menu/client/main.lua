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

hook.Add( "OnPlayerChat", "SquadMenu.ChatCommand", function( ply, text )
    if ply ~= LocalPlayer() then return end
    if text[1] ~= "!" then return end

    text = string.lower( string.Trim( text ) )

    if text == "!squad" or text == "!party" then
        SquadMenu:OpenSquadMenu()
    end
end )

----------

local L = SquadMenu.GetLanguageText

function SquadMenu:SetCurrentMembers( memberIds, printMessages )
    local otherMembers = {}
    local players = SquadMenu.AllPlayersBySteamID()

    for _, id in ipairs( memberIds ) do
        if players[id] and players[id] ~= LocalPlayer() then
            otherMembers[#otherMembers + 1] = players[id]
        end
    end

    self.otherMembers = otherMembers
    self:UpdateHUDMembers( memberIds, printMessages )
end

function SquadMenu:OnJoinSquad( data )
    self.mySquad = {
        id = data.id,
        name = data.name,
        icon = data.icon,
        leaderId = data.leaderId,

        enableRings = data.enableRings,
        friendlyFire = data.friendlyFire,
        isPublic = data.isPublic,

        color = Color( data.r, data.g, data.b ),
        memberCount = #data.memberIds
    }

    self.joinRequests = {}
    self:CloseSquadMenu()

    self:CreateMembersHUD()
    self:SetCurrentMembers( data.memberIds )

    self.ChatPrint( L"squad_welcome", self.mySquad.color, " " .. data.name )
    self.ChatPrint( L"chat_tip", " " .. table.concat( self.CHAT_PREFIXES, ", " ) )
end

function SquadMenu:OnUpdateSquad( data )
    self.mySquad.name = data.name
    self.mySquad.icon = data.icon
    self.mySquad.leaderId = data.leaderId
    self.mySquad.memberCount = #data.memberIds

    self.mySquad.enableRings = data.enableRings
    self.mySquad.friendlyFire = data.friendlyFire
    self.mySquad.isPublic = data.isPublic

    self.mySquad.color = Color( data.r, data.g, data.b )

    local existingMembers = {}

    for _, id in ipairs( data.memberIds ) do
        existingMembers[id] = true
    end

    -- remove existing members from the join request list
    local requests = {}

    for _, id in ipairs( self.joinRequests ) do
        if not existingMembers[id] then
            requests[#requests + 1] = id
        end
    end

    self.joinRequests = requests

    self:UpdateSquadStatePanel()
    self:UpdateRequestsPanel()
    self:SetCurrentMembers( data.memberIds, true )
end

function SquadMenu:OnLeaveSquad( reason )
    local reasonText = {
        [self.LEAVE_REASON_DELETED] = "deleted_squad",
        [self.LEAVE_REASON_KICKED] = "kicked_from_squad"
    }

    if self.mySquad then
        self.ChatPrint( L( reasonText[reason] or "left_squad" ) )
    end

    self.mySquad = nil
    self.joinRequests = nil
    self.otherMembers = nil
    self:RemoveMembersHUD()
    self:CloseSquadMenu()
end

----------

local commands = {}

commands[SquadMenu.BROADCAST_EVENT] = function()
    local data = SquadMenu.JSONToTable( net.ReadString() )
    local event = data.eventName

    if event == "player_joined_squad" then
        if SquadMenu.currentSquadId == data.squadId then return end

        -- Remove this player from my requests list
        local joinRequests = SquadMenu.joinRequests
        if not joinRequests then return end

        for i, id in ipairs( joinRequests ) do
            if id == data.playerId then
                table.remove( joinRequests, i )
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

        local sender = player.GetBySteamID( data.senderId )
        if not IsValid( sender ) then return end

        local white = Color( 255, 255, 255 )

        chat.AddText( white, "[", squad.color, squad.name, white, "] ",
            squad.color, sender:Nick(), white, ": ", data.text )
    end
end

commands[SquadMenu.SQUAD_LIST] = function()
    SquadMenu:UpdateSquadList( SquadMenu.ReadTable() )
end

commands[SquadMenu.SETUP_SQUAD] = function()
    local data = SquadMenu.ReadTable()

    if SquadMenu.currentSquadId == data.id then
        SquadMenu:OnUpdateSquad( data )
    else
        SquadMenu:OnJoinSquad( data )
    end

    SquadMenu.currentSquadId = data.id
end

commands[SquadMenu.LEAVE_SQUAD] = function()
    local reason = net.ReadUInt( 2 )

    SquadMenu:OnLeaveSquad( reason )
    SquadMenu.currentSquadId = nil
end

commands[SquadMenu.REQUESTS_LIST] = function()
    local joinRequests = SquadMenu.joinRequests
    if not joinRequests then return end

    -- Turn the current sequential list of requester IDs into a key-value dictionary
    local existingIds = {}

    for _, id in ipairs( joinRequests ) do
        existingIds[id] = true
    end

    -- Compare the new request IDs against what we already got
    local requestIds = SquadMenu.ReadTable()
    local players = SquadMenu.AllPlayersBySteamID()

    for _, id in ipairs( requestIds ) do
        if not existingIds[id] and players[id] then
            -- This is a new player for us
            joinRequests[#joinRequests + 1] = id
            SquadMenu.ChatPrint( string.format( L"request_message", players[id]:Nick() ) )
        end
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
