local L = SquadMenu.GetLanguageText
local ApplyTheme = SquadMenu.Theme.Apply

function SquadMenu:GetFrameChild( id )
    if IsValid( self.squadMenuFrame ) then
        return self.squadMenuFrame[id]
    end
end

function SquadMenu:CloseSquadMenu()
    if IsValid( self.squadMenuFrame ) then
        self.squadMenuFrame:Close()
    end
end

function SquadMenu:OpenSquadMenu()
    if IsValid( self.squadMenuFrame ) then
        self:CloseSquadMenu()
        return
    end

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( L"title" )
    frame:SetIcon( "icon128/squad_menu.png" )
    frame:SetPos( 0, 0 )
    frame:SetSize( 600, 400 )
    frame:SetSizable( true )
    frame:SetDraggable( true )
    frame:SetDeleteOnClose( true )
    frame:SetScreenLock( true )
    frame:SetMinWidth( 600 )
    frame:SetMinHeight( 400 )
    frame:Center()
    frame:MakePopup()

    ApplyTheme( frame )

    frame.OnClose = function()
        self.squadMenuFrame = nil
    end

    self.squadMenuFrame = frame

    -- Squad state panel
    local statePanel = vgui.Create( "DPanel", frame )
    statePanel:SetTall( 36 )
    statePanel:Dock( BOTTOM )
    statePanel:DockPadding( 4, 4, 4, 4 )

    ApplyTheme( statePanel )

    frame.statePanel = statePanel
    self:UpdateSquadStatePanel()

    -- Squad list panel
    local listPanel = vgui.Create( "DScrollPanel", frame )
    listPanel:Dock( FILL )
    listPanel:DockMargin( 0, 0, 0, 2 )
    listPanel.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    ApplyTheme( listPanel )

    frame.listPanel = listPanel
    self:RequestSquadListUpdate()

    -- Squad join requests panel
    self:UpdateRequestsPanel()
end

function SquadMenu:UpdateSquadStatePanel()
    local statePanel = self:GetFrameChild( "statePanel" )
    if not statePanel then return end

    statePanel:Clear()

    local squad = self.mySquad

    local panelBanner = vgui.Create( "DPanel", statePanel )
    panelBanner:SetTall( 40 )
    panelBanner:Dock( FILL )
    panelBanner:DockPadding( 4, 4, 4, 4 )

    local squadColor = squad and squad.color or Color( 0, 0, 0 )

    panelBanner.Paint = function( _, w, h )
        surface.SetDrawColor( 20, 20, 20 )
        surface.DrawRect( 0, 0, w, h )

        surface.SetDrawColor( squadColor:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )
    end

    local imageIcon = vgui.Create( "DImage", panelBanner )
    imageIcon:Dock( LEFT )
    imageIcon:SetWide( 22 )
    imageIcon:SetImage( squad and squad.icon or "vgui/avatar_default" )

    local labelName = vgui.Create( "DLabel", panelBanner )
    labelName:Dock( FILL )
    labelName:DockMargin( 8, 0, 0, 0 )
    labelName:SetText( squad and squad.name or L"not_in_a_squad" )

    ApplyTheme( labelName )

    local isLocalPlayerLeader = squad and squad.leaderId == LocalPlayer():SteamID()

    if isLocalPlayerLeader then
        local buttonKick = vgui.Create( "DButton", statePanel )
        buttonKick:SetText( L"kick" )
        buttonKick:SizeToContents()
        buttonKick:SetWide( buttonKick:GetWide() + 8 )
        buttonKick:Dock( RIGHT )
        buttonKick:DockMargin( 4, 0, 0, 0 )

        ApplyTheme( buttonKick )

        buttonKick.DoClick = function()
            self:CloseSquadMenu()
            self:OpenMembersEditor()
        end

        local buttonEdit = vgui.Create( "DButton", statePanel )
        buttonEdit:SetText( L"edit_squad" )
        buttonEdit:SizeToContents()
        buttonEdit:SetWide( buttonEdit:GetWide() + 8 )
        buttonEdit:Dock( RIGHT )
        buttonEdit:DockMargin( 4, 0, 0, 0 )

        ApplyTheme( buttonEdit )

        buttonEdit.DoClick = function()
            self:CloseSquadMenu()
            self:OpenSquadEditor( self.mySquad )
        end
    end

    local buttonAction = vgui.Create( "DButton", statePanel )
    buttonAction:SetText( L( squad and "leave_squad" or "create_squad" ) )
    buttonAction:SizeToContents()
    buttonAction:SetWide( buttonAction:GetWide() + 8 )
    buttonAction:Dock( RIGHT )
    buttonAction:DockMargin( 4, 0, 0, 0 )

    ApplyTheme( buttonAction )

    local function Leave()
        self:CloseSquadMenu()

        SquadMenu.StartCommand( SquadMenu.LEAVE_SQUAD )
        net.SendToServer()
    end

    buttonAction.DoClick = function()
        if not squad then
            self:CloseSquadMenu()
            self:OpenSquadEditor()

            return
        end

        if isLocalPlayerLeader then
            Derma_Query( L"leave_leader", L"leave_squad", L"yes", function()
                Leave()
            end, L"no" )
        else
            Leave()
        end
    end
end

local function SetListStatus( text )
    local parent = SquadMenu.squadMenuFrame.listPanel

    local labelStatus = vgui.Create( "DLabel", parent )
    labelStatus:SetText( L( text ) )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:SizeToContents()
    labelStatus:Dock( TOP )
    labelStatus:DockMargin( 0, 8, 0, 0 )

    ApplyTheme( labelStatus )
end

function SquadMenu:RequestSquadListUpdate()
    local listPanel = self:GetFrameChild( "listPanel" )
    if not listPanel then return end

    listPanel:Clear()

    if LocalPlayer():GetSquadID() ~= -1 then
        SetListStatus( "leave_first" )
        return
    end

    SetListStatus( "fetching_data" )

    SquadMenu.StartCommand( SquadMenu.SQUAD_LIST )
    net.SendToServer()
end

function SquadMenu:UpdateSquadList( squads )
    local listPanel = self:GetFrameChild( "listPanel" )
    if not listPanel then return end

    listPanel:Clear()

    if #squads == 0 then
        SetListStatus( "no_available_squads" )
        return
    end

    if LocalPlayer():GetSquadID() ~= -1 then
        SetListStatus( "leave_first" )
        return
    end

    local bgColor = Color( 0, 0, 0 )
    local nameColor = Color( 255, 255, 255 )

    local PaintLine = function( s, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, bgColor )
        draw.SimpleText( s._name, "Trebuchet18", 48, h * 0.5, nameColor, 0, 1 )

        surface.SetDrawColor( s._color:Unpack() )
        surface.DrawRect( 0, 0, 4, h )
    end

    local UpdateButton = function( button, text, enabled )
        button:SetEnabled( enabled )
        button:SetText( L( text ) )
        button:SizeToContents()
        button:SetWide( button:GetWide() + 8 )
    end

    local OnClickJoin = function( s )
        UpdateButton( s, "waiting_response", false )

        SquadMenu.StartCommand( SquadMenu.JOIN_SQUAD )
        net.WriteUInt( s._id, 16 )
        net.SendToServer()
    end

    local players = SquadMenu.AllPlayersBySteamID()
    local maxMembers = SquadMenu.GetMemberLimit()

    for _, squad in ipairs( squads ) do
        local p = vgui.Create( "DPanel", listPanel )
        p:SetTall( 48 )
        p:Dock( TOP )
        p:DockMargin( 0, 0, 0, 2 )

        p.Paint = PaintLine
        p._id = squad.id
        p._name = squad.name
        p._leaderName = players[squad.leaderId]:Nick()
        p._color = Color( squad.r, squad.g, squad.b )

        local icon = vgui.Create( "DImage", p )
        icon:Dock( LEFT )
        icon:DockMargin( 12, 12, 12, 12 )
        icon:SetWide( 24 )
        icon:SetImage( squad.icon )

        local buttonJoin = vgui.Create( "DButton", p )
        buttonJoin:Dock( RIGHT )
        buttonJoin:DockMargin( 0, 4, 4, 4 )

        ApplyTheme( buttonJoin )

        if squad.memberCount < maxMembers then
            buttonJoin._id = squad.id
            buttonJoin.DoClick = OnClickJoin

            UpdateButton( buttonJoin, squad.isPublic and "join" or "request_to_join", true )
        else
            UpdateButton( buttonJoin, "full_squad", false )
        end

        local labelCount = vgui.Create( "DLabel", p )
        labelCount:SetText( squad.memberCount .. "/" .. maxMembers )
        labelCount:SizeToContents()
        labelCount:Dock( RIGHT )
        labelCount:DockMargin( 0, 0, 10, 0 )

        local iconCount = vgui.Create( "DImage", p )
        iconCount:Dock( RIGHT )
        iconCount:DockMargin( 16, 16, 4, 16 )
        iconCount:SetWide( 16 )
        iconCount:SetImage( "icon16/user.png" )
    end
end

function SquadMenu:UpdateRequestsPanel()
    if not IsValid( self.squadMenuFrame ) then return end

    local requestsPanel = self.squadMenuFrame.requestsPanel

    if requestsPanel then
        requestsPanel:Remove()
    end

    local squad = self.mySquad
    if not squad then return end
    if squad.leaderId ~= LocalPlayer():SteamID() then return end

    requestsPanel = vgui.Create( "DPanel", self.squadMenuFrame )
    requestsPanel:SetTall( 290 )
    requestsPanel:Dock( BOTTOM )
    requestsPanel:DockMargin( 0, 0, 0, 2 )

    self.squadMenuFrame.requestsPanel = requestsPanel

    ApplyTheme( requestsPanel )

    local panelHeader = vgui.Create( "DPanel", requestsPanel )
    panelHeader:SetTall( 36 )
    panelHeader:DockPadding( 8, 4, 8, 4 )
    panelHeader:Dock( TOP )

    ApplyTheme( panelHeader )

    local labelRequests = vgui.Create( "DLabel", panelHeader )
    labelRequests:Dock( LEFT )

    ApplyTheme( labelRequests )

    local memberLimit = SquadMenu.GetMemberLimit() - squad.memberCount

    if memberLimit < 1 then
        labelRequests:SetText( L"member_limit_reached" )
        labelRequests:SizeToContents()
        return
    end

    local labelMemberCount = vgui.Create( "DLabel", panelHeader )
    labelMemberCount:Dock( RIGHT )

    ApplyTheme( labelMemberCount )

    local function UpdateMemberCount( current )
        labelMemberCount:SetText( L( "slots" ) .. ": " .. current .. "/" .. SquadMenu.GetMemberLimit() )
        labelMemberCount:SizeToContents()
    end

    UpdateMemberCount( squad.memberCount )

    if squad.isPublic then
        labelRequests:SetText( L"no_requests_needed" )
        labelRequests:SizeToContents()
        return
    end

    if not self.joinRequests or #self.joinRequests == 0 then
        labelRequests:SetText( L"no_requests_yet" )
        labelRequests:SizeToContents()
        return
    end

    labelRequests:SetText( L"requests_list" )
    labelRequests:SizeToContents()

    local buttonAccept
    local acceptedPlayers = {}

    local function OnClickAccept()
        local steamIds = table.GetKeys( acceptedPlayers )

        SquadMenu.StartCommand( SquadMenu.ACCEPT_REQUESTS )
        SquadMenu.WriteTable( steamIds )
        net.SendToServer()

        self:UpdateRequestsPanel()
    end

    local function UpdateAcceptedCount( count )
        UpdateMemberCount( squad.memberCount + count )

        if count == 0 then
            if buttonAccept then
                buttonAccept:Remove()
                buttonAccept = nil
            end

            return
        end

        buttonAccept = vgui.Create( "DButton", requestsPanel )
        buttonAccept:SetText( L"accept" )
        buttonAccept:SetTall( 36 )
        buttonAccept:Dock( BOTTOM )
        buttonAccept:DockMargin( 4, 4, 4, 4 )
        buttonAccept.DoClick = OnClickAccept

        ApplyTheme( buttonAccept )
    end

    UpdateAcceptedCount( 0 )

    local requestsScroll = vgui.Create( "DScrollPanel", requestsPanel )
    requestsScroll:Dock( FILL )
    requestsScroll.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    local bgColor = Color( 0, 0, 0 )
    local nameColor = Color( 255, 255, 255 )

    local PaintLine = function( s, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, bgColor )
        draw.SimpleText( s._name, "Trebuchet18", 48, h * 0.5, nameColor, 0, 1 )

        if acceptedPlayers[s._id] then
            surface.SetDrawColor( 0, 255, 0, 255 )
            surface.DrawOutlinedRect( 1, 1, w - 2, h - 2, 2 )
        end
    end

    local ClickLine = function( s )
        local id = s._id
        local count = #table.GetKeys( acceptedPlayers )

        if acceptedPlayers[id] then
            acceptedPlayers[id] = nil
            count = count - 1
        else
            if count < memberLimit then
                acceptedPlayers[id] = true
                count = count + 1
            else
                Derma_Message( L"member_limit", L"title", L"ok" )
            end
        end

        UpdateAcceptedCount( count )
    end

    local players = SquadMenu.AllPlayersBySteamID()

    for _, id in ipairs( self.joinRequests ) do
        local ply = players[id]

        if ply then
            local line = vgui.Create( "DPanel", requestsScroll )
            line:SetCursor( "hand" )
            line:SetTall( 28 )
            line:SetTall( 48 )
            line:Dock( TOP )
            line:DockMargin( 0, 0, 0, 2 )

            line._id = id
            line._name = ply:Nick()
            line.Paint = PaintLine
            line.OnMousePressed = ClickLine

            local avatar = vgui.Create( "AvatarImage", line )
            avatar:Dock( LEFT )
            avatar:DockMargin( 12, 12, 12, 12 )
            avatar:SetWide( 24 )
            avatar:SetPlayer( ply, 64 )
        end
    end
end

function SquadMenu:OpenMembersEditor()
    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( L"kick" )
    frame:SetIcon( "icon128/squad_menu.png" )
    frame:SetPos( 0, 0 )
    frame:SetSize( 300, 400 )
    frame:SetSizable( true )
    frame:SetDraggable( true )
    frame:SetDeleteOnClose( true )
    frame:SetScreenLock( true )
    frame:SetMinWidth( 300 )
    frame:SetMinHeight( 400 )
    frame:Center()
    frame:MakePopup()

    ApplyTheme( frame )

    local membersScroll = vgui.Create( "DScrollPanel", frame )
    membersScroll:Dock( FILL )
    membersScroll.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    if #self.otherMembers == 0 then
        local labelStatus = vgui.Create( "DLabel", membersScroll )
        labelStatus:SetText( L"no_members" )
        labelStatus:Dock( TOP )
        labelStatus:DockMargin( 0, 8, 0, 0 )
        labelStatus:SetContentAlignment( 5 )

        ApplyTheme( labelStatus )

        return
    end

    local bgColor = Color( 0, 0, 0 )
    local nameColor = Color( 255, 255, 255 )

    local PaintLine = function( s, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, bgColor )
        draw.SimpleText( s._name, "Trebuchet18", 42, h * 0.5, nameColor, 0, 1 )
    end

    local ClickLine = function( s )
        SquadMenu.StartCommand( SquadMenu.KICK )
        net.WriteString( s._id )
        net.SendToServer()

        s:Remove()
    end

    for _, ply in ipairs( self.otherMembers ) do
        if IsValid( ply ) then
            local line = vgui.Create( "DPanel", membersScroll )
            line:SetCursor( "hand" )
            line:SetTall( 28 )
            line:SetTall( 48 )
            line:Dock( TOP )
            line:DockMargin( 0, 0, 0, 2 )

            line._id = ply:SteamID()
            line._name = ply:Nick()
            line.Paint = PaintLine
            line.OnMousePressed = ClickLine

            local avatar = vgui.Create( "AvatarImage", line )
            avatar:Dock( LEFT )
            avatar:DockMargin( 12, 12, 12, 12 )
            avatar:SetWide( 24 )
            avatar:SetPlayer( ply, 64 )
        end
    end
end

local function CreateToggleButton( parent, label, isChecked, callback )
    local button = vgui.Create( "DButton", parent )
    button:SetTall( 30 )
    button:SetIcon( isChecked and "icon16/accept.png" or "icon16/cancel.png" )
    button:SetText( L( label ) )
    button:Dock( TOP )
    button:DockMargin( 0, 0, 0, 4 )
    button._isChecked = isChecked

    ApplyTheme( button )

    button.DoClick = function( s )
        s._isChecked = not s._isChecked
        button:SetIcon( s._isChecked and "icon16/accept.png" or "icon16/cancel.png" )
        callback( s._isChecked )
    end

    return button
end

function SquadMenu:OpenSquadEditor( squad )
    local isNew = squad == nil

    squad = squad or { enableRings = true }

    local oldColor = squad.color or Color( 0, 0, 255 )

    local data = {
        name = squad.name or string.format( L"default_squad_name", LocalPlayer():Nick() ),
        icon = squad.icon or "games/16/garrysmod.png",

        enableRings = squad.enableRings == true,
        friendlyFire = squad.friendlyFire == true,
        isPublic = squad.isPublic == true,

        r = oldColor.r or 0,
        g = oldColor.g or 0,
        b = oldColor.b or 255
    }

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( L"create_squad" )
    frame:SetIcon( "icon128/squad_menu.png" )
    frame:SetPos( 0, 0 )
    frame:SetSize( 300, 500 )
    frame:SetSizable( true )
    frame:SetDraggable( true )
    frame:SetDeleteOnClose( true )
    frame:SetScreenLock( true )
    frame:SetMinWidth( 300 )
    frame:SetMinHeight( 500 )
    frame:Center()
    frame:MakePopup()

    ApplyTheme( frame )

    local buttonCreate = vgui.Create( "DButton", frame )
    buttonCreate:SetTall( 36 )
    buttonCreate:SetText( L( isNew and "create_squad" or "edit_squad" ) )
    buttonCreate:Dock( BOTTOM )
    buttonCreate:DockMargin( 0, 4, 0, 0 )

    ApplyTheme( buttonCreate )

    buttonCreate.DoClick = function()
        SquadMenu.StartCommand( SquadMenu.SETUP_SQUAD )
        SquadMenu.WriteTable( data )
        net.SendToServer()

        frame:Close()
    end

    local panelProperties = vgui.Create( "DScrollPanel", frame )
    panelProperties:Dock( FILL )
    panelProperties.pnlCanvas:DockPadding( 8, 4, 8, 4 )

    ApplyTheme( panelProperties )

    local function CreatePropertyLabel( text )
        local label = vgui.Create( "DLabel", panelProperties )
        label:Dock( TOP )
        label:DockMargin( 0, 0, 0, 2 )
        label:SetText( L( text ) )
        label:SetTall( 26 )

        ApplyTheme( label )

        return label
    end

    CreatePropertyLabel( "squad_name" )

    local entryName = vgui.Create( "DTextEntry", panelProperties )
    entryName:SetTall( 30 )
    entryName:Dock( TOP )
    entryName:DockMargin( 0, 0, 0, 4 )
    entryName:SetMaximumCharCount( SquadMenu.MAX_NAME_LENGTH )
    entryName:SetValue( data.name )

    entryName.OnChange = function()
        data.name = entryName:GetValue()
    end

    ApplyTheme( entryName )

    CreatePropertyLabel( "squad_options" )

    local buttonIcon = vgui.Create( "DButton", panelProperties )
    buttonIcon:SetTall( 30 )
    buttonIcon:SetIcon( data.icon )
    buttonIcon:SetText( L"choose_icon" )
    buttonIcon:Dock( TOP )
    buttonIcon:DockMargin( 0, 0, 0, 4 )

    ApplyTheme( buttonIcon )

    buttonIcon.DoClick = function()
        local iconBrowser = vgui.Create( "DIconBrowser" )
        iconBrowser:SetSize( 300, 200 )

        local m = DermaMenu()
        m:AddPanel( iconBrowser )
        m:SetPaintBackground( false )
        m:Open( gui.MouseX() + 8, gui.MouseY() + 10 )

        iconBrowser.OnChange = function( s )
            local iconPath = s:GetSelectedIcon()

            buttonIcon:SetIcon( iconPath )
            data.icon = iconPath

            CloseDermaMenus()
        end
    end

    CreateToggleButton( panelProperties, "squad_is_public", data.isPublic, function( checked )
        data.isPublic = checked
    end )

    CreateToggleButton( panelProperties, "squad_friendly_fire", data.friendlyFire, function( checked )
        data.friendlyFire = checked
    end )

    CreateToggleButton( panelProperties, "squad_rings", data.enableRings, function( checked )
        data.enableRings = checked
    end )

    CreatePropertyLabel( "squad_color" )

    local colorPicker = vgui.Create( "DColorMixer", panelProperties )
    colorPicker:SetTall( 200 )
    colorPicker:Dock( TOP )
    colorPicker:SetPalette( true )
    colorPicker:SetAlphaBar( false )
    colorPicker:SetWangs( true )
    colorPicker:SetColor( Color( data.r, data.g, data.b ) )

    colorPicker.ValueChanged = function( _, color )
        data.r = color.r
        data.g = color.g
        data.b = color.b
    end
end
