local PID = SquadMenu.GetPlayerId
local L = SquadMenu.GetLanguageText
local ApplyTheme = SquadMenu.Theme.Apply

local function CreateStatusHeader( parent, text )
    local panel = vgui.Create( "DPanel", parent )
    panel:Dock( FILL )

    ApplyTheme( panel )

    local labelStatus = vgui.Create( "DLabel", panel )
    labelStatus:SetText( L( text ) )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:SizeToContents()
    labelStatus:Dock( FILL )

    ApplyTheme( labelStatus )
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

local function CreatePropertyLabel( text, parent )
    local label = vgui.Create( "DLabel", parent )
    label:Dock( TOP )
    label:DockMargin( 0, 0, 0, 2 )
    label:SetText( L( text ) )
    label:SetTall( 26 )

    ApplyTheme( label )

    return label
end

function SquadMenu:CloseFrame()
    if IsValid( self.frame ) then
        self.frame:Close()
    end
end

function SquadMenu:OpenFrame()
    if IsValid( self.frame ) then
        self:CloseFrame()
        return
    end

    local frame = vgui.Create( "Squad_TabbedFrame" )
    frame:Center()
    frame:MakePopup()

    frame.OnClose = function()
        self.frame = nil
    end

    self.frame = frame

    local panels = {}
    frame._panels = panels

    -- Squad state
    panels.squadState = vgui.Create( "DPanel", frame )
    panels.squadState:SetTall( 32 )
    panels.squadState:Dock( BOTTOM )
    panels.squadState:DockMargin( 4, 4, 0, 0 )
    panels.squadState:DockPadding( 4, 4, 4, 4 )

    ApplyTheme( panels.squadState )

    -- Tabs
    panels.squadList = frame:AddTab( "icon16/text_list_bullets.png", L"tab.squad_list" )
    panels.squadProperties = frame:AddTab( "icon16/flag_blue.png", L"tab.squad_properties" )
    panels.squadMembers = frame:AddTab( "icon16/group.png", L"tab.squad_members" )
    panels.joinRequests = frame:AddTab( "icon16/user_add.png", L"tab.join_requests" )
    panels.settings = frame:AddTab( "icon16/cog.png", L"tab.settings" )

    self:RequestSquadListUpdate()
    self:UpdateSquadStatePanel()
    self:UpdateRequestsPanel()
    self:UpdateSquadMembersPanel()
    self:UpdateSquadPropertiesPanel()

    local squad = self.mySquad

    if squad then
        if #squad.members < 2 then
            frame:SetActiveTabByIndex( 4 ) -- join requests
        else
            frame:SetActiveTabByIndex( 3 ) -- squad members
        end
    end

    -- Settings
    local panelHeader = vgui.Create( "DPanel", panels.settings )
    panelHeader:SetTall( 30 )
    panelHeader:Dock( TOP )

    ApplyTheme( panelHeader )

    local labelStatus = vgui.Create( "DLabel", panelHeader )
    labelStatus:SetText( L"tab.settings" )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:Dock( FILL )

    ApplyTheme( labelStatus )

    local scroll = vgui.Create( "DScrollPanel", panels.settings )
    scroll:Dock( FILL )
    scroll:DockMargin( 0, 4, 0, 0 )
    scroll.pnlCanvas:DockPadding( 40, 8, 40, 8 )

    ApplyTheme( scroll )

    local sliderNameDist = vgui.Create( "DNumSlider", scroll )
    sliderNameDist:SetText( L"settings.name_draw_distance" )
    sliderNameDist:SetMin( 500 )
    sliderNameDist:SetMax( 50000 )
    sliderNameDist:SetDecimals( 0 )
    sliderNameDist:SetValue( self.Config.nameDistance )
    sliderNameDist:Dock( TOP )
    sliderNameDist:DockMargin( 0, 0, 0, 8 )

    ApplyTheme( sliderNameDist )

    sliderNameDist.OnValueChanged = function( _, value )
        self.Config.nameDistance = self.ValidateNumber( value, 2000, 500, 50000 )
        self.Config:Save()
    end

    local sliderHaloDist = vgui.Create( "DNumSlider", scroll )
    sliderHaloDist:SetText( L"settings.halo_draw_distance" )
    sliderHaloDist:SetMin( 500 )
    sliderHaloDist:SetMax( 50000 )
    sliderHaloDist:SetDecimals( 0 )
    sliderHaloDist:SetValue( self.Config.haloDistance )
    sliderHaloDist:Dock( TOP )
    sliderHaloDist:DockMargin( 0, 0, 0, 8 )

    ApplyTheme( sliderHaloDist )

    sliderHaloDist.OnValueChanged = function( _, value )
        self.Config.haloDistance = self.ValidateNumber( value, 8000, 500, 50000 )
        self.Config:Save()
    end

    local panelPing = vgui.Create( "DPanel", scroll )
    panelPing:SetPaintBackground( false )
    panelPing:SetTall( 30 )
    panelPing:Dock( TOP )
    panelPing:DockMargin( 0, 0, 0, 8 )

    local labelPing = vgui.Create( "DLabel", panelPing )
    labelPing:SetText( L( "settings.ping_key" ) )
    labelPing:SizeToContents()
    labelPing:Dock( LEFT )

    ApplyTheme( labelPing )

    local binderPing = vgui.Create( "DBinder", panelPing )
    binderPing:SetValue( self.Config.pingKey )
    binderPing:Dock( FILL )
    binderPing:DockMargin( 20, 0, 0, 0 )

    ApplyTheme( binderPing )

    binderPing.OnChange = function( _, key )
        self.Config.pingKey = key
        self.Config:Save()
    end

    CreateToggleButton( scroll, "settings.show_members", self.Config.showMembers, function( checked )
        self.Config.showMembers = checked
        self.Config:Save()
    end )

    CreateToggleButton( scroll, "settings.show_rings", self.Config.showRings, function( checked )
        self.Config.showRings = checked
        self.Config:Save()
    end )

    CreateToggleButton( scroll, "settings.show_halos", self.Config.showHalos, function( checked )
        self.Config.showHalos = checked
        self.Config:Save()
    end )

    CreateToggleButton( scroll, "settings.enable_sounds", self.Config.enableSounds, function( checked )
        self.Config.enableSounds = checked
        self.Config:Save()
    end )
end

function SquadMenu:GetPanel( id )
    if IsValid( self.frame ) then
        return self.frame._panels[id]
    end
end

function SquadMenu:UpdateSquadStatePanel()
    local statePanel = self:GetPanel( "squadState" )
    if not statePanel then return end

    statePanel:Clear()

    local squad = self.mySquad
    local squadColor = squad and squad.color or Color( 0, 0, 0 )

    statePanel.Paint = function( _, w, h )
        surface.SetDrawColor( 20, 20, 20 )
        surface.DrawRect( 0, 0, w, h )

        surface.SetDrawColor( squadColor:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )
    end

    local imageIcon = vgui.Create( "DImage", statePanel )
    imageIcon:Dock( LEFT )
    imageIcon:SetWide( 24 )
    imageIcon:SetImage( squad and squad.icon or "vgui/avatar_default" )

    local labelName = vgui.Create( "DLabel", statePanel )
    labelName:Dock( FILL )
    labelName:DockMargin( 8, 0, 0, 0 )
    labelName:SetText( squad and squad.name or L"not_in_a_squad" )

    ApplyTheme( labelName )

    if not squad then return end

    local buttonLeave = vgui.Create( "DButton", statePanel )
    buttonLeave:SetText( L"leave_squad" )
    buttonLeave:Dock( RIGHT )
    buttonLeave:DockMargin( 4, 0, 0, 0 )

    ApplyTheme( buttonLeave )

    buttonLeave.DoClick = function()
        SquadMenu.LeaveMySquad( buttonLeave )
    end
end

function SquadMenu:RequestSquadListUpdate( immediate )
    timer.Remove( "SquadMenu.RequestListUpdate" )

    local listPanel = self:GetPanel( "squadList" )
    if not listPanel then return end

    listPanel:Clear()
    CreateStatusHeader( listPanel, "fetching_data" )

    if not immediate then
        -- Don't spam when this function gets called in quick succession
        timer.Create( "SquadMenu.RequestListUpdate", 1, 1, function()
            SquadMenu:RequestSquadListUpdate( true )
        end )

        return
    end

    self.StartCommand( self.SQUAD_LIST )
    net.SendToServer()
end

function SquadMenu:UpdateSquadList( squads )
    local listPanel = self:GetPanel( "squadList" )
    if not listPanel then return end

    listPanel:Clear()

    if #squads == 0 then
        CreateStatusHeader( listPanel, "no_available_squads" )
        return
    end

    local scrollPanel = vgui.Create( "DScrollPanel", listPanel )
    scrollPanel:Dock( FILL )
    scrollPanel.pnlCanvas:DockPadding( 0, 0, 4, 0 )

    for _, squad in ipairs( squads ) do
        local line = vgui.Create( "Squad_Line", scrollPanel )
        line:SetSquad( squad )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 4 )
    end
end

function SquadMenu:UpdateRequestsPanel()
    local requestsPanel = self:GetPanel( "joinRequests" )
    if not requestsPanel then return end

    requestsPanel:Clear()
    self.frame:SetTabNotificationCountByIndex( 4, 0 ) -- join requests tab

    local squad = self.mySquad

    if not squad then
        CreateStatusHeader( requestsPanel, "not_in_a_squad" )
        return
    end

    if squad.leaderId ~= PID( LocalPlayer() ) then
        CreateStatusHeader( requestsPanel, "not_squad_leader" )
        return
    end

    local memberLimit = self.GetMemberLimit() - #squad.members

    if memberLimit < 1 then
        CreateStatusHeader( requestsPanel, "member_limit_reached" )
        return
    end

    local panelHeader = vgui.Create( "DPanel", requestsPanel )
    panelHeader:SetTall( 30 )
    panelHeader:Dock( TOP )
    panelHeader:DockMargin( 0, 0, 0, 4 )

    ApplyTheme( panelHeader )

    local labelStatus = vgui.Create( "DLabel", panelHeader )
    labelStatus:SetText( L"requests_list" )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:Dock( FILL )

    ApplyTheme( labelStatus )

    local function UpdateMemberCount( current )
        labelStatus:SetText( L( "slots" ) .. ": " .. current .. "/" .. self.GetMemberLimit() )
    end

    UpdateMemberCount( #squad.members )

    if squad.isPublic then
        CreateStatusHeader( requestsPanel, "no_requests_needed" )
        return
    end

    if #squad.requests == 0 then
        CreateStatusHeader( requestsPanel, "no_requests_yet" )
        return
    end

    self.frame:SetTabNotificationCountByIndex( 4, #squad.requests ) -- join requests tab

    local buttonAccept
    local acceptedPlayers = {}

    local function OnClickAccept()
        local ids = table.GetKeys( acceptedPlayers )

        self.StartCommand( self.ACCEPT_REQUESTS )
        self.WriteTable( ids )
        net.SendToServer()
    end

    local function UpdateAcceptedCount( count )
        UpdateMemberCount( #squad.members + count )

        if buttonAccept then
            buttonAccept:Remove()
            buttonAccept = nil
        end

        if count == 0 then return end

        buttonAccept = vgui.Create( "DButton", requestsPanel )
        buttonAccept:SetText( L"accept" )
        buttonAccept:SetTall( 36 )
        buttonAccept:Dock( BOTTOM )
        buttonAccept:DockMargin( 4, 4, 4, 2 )
        buttonAccept.DoClick = OnClickAccept
        buttonAccept._themeHighlight = true

        ApplyTheme( buttonAccept )
    end

    UpdateAcceptedCount( 0 )

    local requestsScroll = vgui.Create( "DScrollPanel", requestsPanel )
    requestsScroll:Dock( FILL )
    requestsScroll.pnlCanvas:DockPadding( 10, 0, 10, 4 )

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
                Derma_Message( L"cannot_accept_more", L"title", L"ok" )
            end
        end

        UpdateAcceptedCount( count )
    end

    local byId = SquadMenu.AllPlayersById()

    for _, member in ipairs( squad.requests ) do
        local line = vgui.Create( "DPanel", requestsScroll )
        line:SetCursor( "hand" )
        line:SetTall( 28 )
        line:SetTall( 48 )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 2 )

        line._id = member.id
        line._name = member.name
        line.Paint = PaintLine
        line.OnMousePressed = ClickLine

        local avatar = vgui.Create( "AvatarImage", line )
        avatar:Dock( LEFT )
        avatar:DockMargin( 12, 12, 12, 12 )
        avatar:SetWide( 24 )

        if byId[member.id] then
            avatar:SetPlayer( byId[member.id], 64 )
        end
    end
end

function SquadMenu:UpdateSquadMembersPanel()
    local membersPanel = self:GetPanel( "squadMembers" )
    if not membersPanel then return end

    membersPanel:Clear()

    local squad = self.mySquad

    if not squad then
        CreateStatusHeader( membersPanel, "not_in_a_squad" )
        return
    end

    local memberCount = #squad.members

    local panelHeader = vgui.Create( "DPanel", membersPanel )
    panelHeader:SetTall( 30 )
    panelHeader:Dock( TOP )
    panelHeader:DockMargin( 0, 0, 0, 4 )

    ApplyTheme( panelHeader )

    local labelStatus = vgui.Create( "DLabel", panelHeader )
    labelStatus:SetText( L( "slots" ) .. ": " .. memberCount .. "/" .. self.GetMemberLimit() )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:Dock( FILL )

    ApplyTheme( labelStatus )

    if memberCount < 2 then
        CreateStatusHeader( membersPanel, "no_members" )
        return
    end

    local localId = PID( LocalPlayer() )
    local isLocalPlayerLeader = squad.leaderId == localId

    local membersScroll = vgui.Create( "DScrollPanel", membersPanel )
    membersScroll:Dock( FILL )
    membersScroll.pnlCanvas:DockPadding( 10, 0, 10, 4 )

    local OnClickKick = function( s )
        s:SetEnabled( false )
        s:SetText( "..." )

        self.StartCommand( self.KICK )
        net.WriteString( s._id )
        net.SendToServer()
    end

    local bgColor = Color( 0, 0, 0 )
    local nameColor = Color( 255, 255, 255 )

    local PaintLine = function( s, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, bgColor )
        draw.SimpleText( s._name, "Trebuchet18", 42, h * 0.5, nameColor, 0, 1 )
    end

    local byId = SquadMenu.AllPlayersById()

    for _, member in ipairs( squad.members ) do
        local line = vgui.Create( "DPanel", membersScroll )
        line:SetTall( 28 )
        line:SetTall( 48 )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 2 )
        line:DockPadding( 12, 12, 12, 12 )

        line._name = member.name
        line.Paint = PaintLine

        if isLocalPlayerLeader and member.id ~= localId then
            local kick = vgui.Create( "DButton", line )
            kick:SetText( L"kick" )
            kick:SizeToContents()
            kick:Dock( RIGHT )

            kick._id = member.id
            kick.DoClick = OnClickKick

            ApplyTheme( kick )
        end

        local avatar = vgui.Create( "AvatarImage", line )
        avatar:Dock( LEFT )
        avatar:SetWide( 24 )

        if byId[member.id] then
            avatar:SetPlayer( byId[member.id], 64 )
        end
    end
end

function SquadMenu:UpdateSquadPropertiesPanel()
    local propertiesPanel = self:GetPanel( "squadProperties" )
    if not propertiesPanel then return end

    propertiesPanel:Clear()

    local squad = self.mySquad

    if squad and squad.leaderId ~= PID( LocalPlayer() ) then
        CreateStatusHeader( propertiesPanel, "leave_first_create" )
        return
    end

    local panelHeader = vgui.Create( "DPanel", propertiesPanel )
    panelHeader:SetTall( 30 )
    panelHeader:Dock( TOP )

    ApplyTheme( panelHeader )

    local isNew = squad == nil
    local oldName = squad and squad.name or nil
    local oldColor = squad and squad.color or nil

    if not oldColor then
        local c = HSVToColor( math.random( 0, 360 ), 1, 1 )
        oldColor = Color( c.r, c.g, c.b ) -- reconstruct color to avoid a bug
    end

    squad = squad or {
        enableRings = true
    }

    local labelStatus = vgui.Create( "DLabel", panelHeader )
    labelStatus:SetText( L( isNew and "create_squad" or "edit_squad" ) )
    labelStatus:SetContentAlignment( 5 )
    labelStatus:Dock( FILL )

    ApplyTheme( labelStatus )

    local data = {
        name = squad.name or string.format( L"default_squad_name", LocalPlayer():Nick() ),
        icon = squad.icon or "icon16/flag_blue.png",

        enableRings = squad.enableRings == true,
        friendlyFire = squad.friendlyFire == true,
        isPublic = squad.isPublic == true,

        r = oldColor.r,
        g = oldColor.g,
        b = oldColor.b
    }

    local buttonCreate = vgui.Create( "DButton", propertiesPanel )
    buttonCreate:SetTall( 36 )
    buttonCreate:SetText( L( isNew and "create_squad" or "edit_squad" ) )
    buttonCreate:Dock( BOTTOM )
    buttonCreate:DockMargin( 0, 4, 0, 0 )
    buttonCreate._themeHighlight = true

    ApplyTheme( buttonCreate )

    buttonCreate.DoClick = function( s )
        s:SetEnabled( false )
        s:SetText( "..." )

        self.StartCommand( self.SETUP_SQUAD )
        self.WriteTable( data )
        net.SendToServer()
    end

    local leftPanel = vgui.Create( "DPanel", propertiesPanel )
    leftPanel:Dock( FILL )
    leftPanel:DockMargin( 0, 4, 0, 0 )
    leftPanel:DockPadding( 8, 8, 8, 8 )

    ApplyTheme( leftPanel )

    CreatePropertyLabel( "squad_name", leftPanel )

    local entryName = vgui.Create( "DTextEntry", leftPanel )
    entryName:SetTall( 30 )
    entryName:Dock( TOP )
    entryName:DockMargin( 0, 0, 0, 4 )
    entryName:SetMaximumCharCount( self.MAX_NAME_LENGTH )
    entryName:SetValue( data.name )

    entryName.OnChange = function()
        local value = entryName:GetValue()
        data.name = value:Trim() == "" and oldName or value
    end

    ApplyTheme( entryName )

    CreatePropertyLabel( "tab.squad_properties", leftPanel )

    local buttonIcon = vgui.Create( "DButton", leftPanel )
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

    CreateToggleButton( leftPanel, "squad_is_public", data.isPublic, function( checked )
        data.isPublic = checked
    end )

    CreateToggleButton( leftPanel, "squad_friendly_fire", data.friendlyFire, function( checked )
        data.friendlyFire = checked
    end )

    CreateToggleButton( leftPanel, "squad_rings", data.enableRings, function( checked )
        data.enableRings = checked
    end )

    local rightPanel = vgui.Create( "DPanel", propertiesPanel )
    rightPanel:SetWide( 250 )
    rightPanel:Dock( RIGHT )
    rightPanel:DockMargin( 0, 4, 0, 0 )
    rightPanel:DockPadding( 8, 8, 8, 8 )

    ApplyTheme( rightPanel )

    CreatePropertyLabel( "squad_color", rightPanel )

    local colorPicker = vgui.Create( "DColorMixer", rightPanel )
    colorPicker:SetTall( 200 )
    colorPicker:Dock( TOP )
    colorPicker:SetPalette( true )
    colorPicker:SetAlphaBar( false )
    colorPicker:SetWangs( true )
    colorPicker:SetColor( oldColor )

    colorPicker.ValueChanged = function( _, color )
        data.r = color.r
        data.g = color.g
        data.b = color.b
    end
end