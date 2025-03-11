local PID = SquadMenu.GetPlayerId
local L = SquadMenu.GetLanguageText
local ScaleSize = StyledTheme.ScaleSize

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

    local frame = vgui.Create( "Styled_TabbedFrame" )
    frame:SetTitle( L"title" )
    frame:Center()
    frame:MakePopup()

    frame.OnClose = function()
        self.frame = nil
    end

    local h = ScaleSize( 550 )
    frame:SetTall( h )
    frame:SetMinHeight( h )

    self.frame = frame

    local panels = {}
    frame._panels = panels

    -- Squad state
    local separation = ScaleSize( 4 )

    panels.squadState = vgui.Create( "DPanel", frame )
    panels.squadState:SetTall( ScaleSize( 40 ) )
    panels.squadState:Dock( BOTTOM )
    panels.squadState:DockMargin( separation, separation, 0, 0 )
    panels.squadState:DockPadding( separation, separation, separation, separation )

    -- Tabs
    panels.squadList = frame:AddTab( "styledstrike/icons/bullet_list.png", L"tab.squad_list" )
    panels.squadProperties = frame:AddTab( "styledstrike/icons/flag_two_tone.png", L"tab.squad_properties", "DPanel" )
    panels.squadMembers = frame:AddTab( "styledstrike/icons/users.png", L"tab.squad_members", "DPanel" )
    panels.joinRequests = frame:AddTab( "styledstrike/icons/user_add.png", L"tab.join_requests", "DPanel" )
    panels.settings = frame:AddTab( "styledstrike/icons/cog.png", L"tab.settings" )

    self:RequestSquadListUpdate()
    self:UpdateSquadStatePanel()
    self:UpdateRequestsPanel()
    self:UpdateSquadMembersPanel()
    self:UpdateSquadPropertiesPanel()

    local squad = self.mySquad

    if squad then
        if #squad.members < 2 then
            frame:SetActiveTabByIndex( 4 ) -- Join requests
        else
            frame:SetActiveTabByIndex( 3 ) -- Squad members
        end
    end

    -- Settings
    StyledTheme.CreateFormHeader( panels.settings, L"tab.settings", 0 )

    StyledTheme.CreateFormSlider( panels.settings, L"settings.name_draw_distance", self.Config.nameDistance, 500, 50000, 0, function( value )
        self.Config.nameDistance = self.ValidateNumber( value, 2000, 500, 50000 )
        self.Config:Save()
    end )

    StyledTheme.CreateFormSlider( panels.settings, L"settings.halo_draw_distance", self.Config.haloDistance, 500, 50000, 0, function( value )
        self.Config.haloDistance = self.ValidateNumber( value, 8000, 500, 50000 )
        self.Config:Save()
    end )

    local binderPing = StyledTheme.CreateFormBinder( panels.settings, L"settings.ping_key", self.Config.pingKey )

    binderPing.OnChange = function( _, key )
        self.Config.pingKey = key
        self.Config:Save()
    end

    StyledTheme.CreateFormToggle( panels.settings, L"settings.show_members", self.Config.showMembers, function( checked )
        self.Config.showMembers = checked
        self.Config:Save()
    end )

    StyledTheme.CreateFormToggle( panels.settings, L"settings.show_rings", self.Config.showRings, function( checked )
        self.Config.showRings = checked
        self.Config:Save()
    end )

    StyledTheme.CreateFormToggle( panels.settings, L"settings.show_halos", self.Config.showHalos, function( checked )
        self.Config.showHalos = checked
        self.Config:Save()
    end )

    StyledTheme.CreateFormToggle( panels.settings, L"settings.enable_sounds", self.Config.enableSounds, function( checked )
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
    imageIcon:SetWide( ScaleSize( 32 ) )
    imageIcon:SetImage( squad and squad.icon or "vgui/avatar_default" )

    local labelName = vgui.Create( "DLabel", statePanel )
    labelName:Dock( FILL )
    labelName:DockMargin( ScaleSize( 8 ), 0, 0, 0 )
    labelName:SetText( squad and squad.name or L"not_in_a_squad" )

    StyledTheme.Apply( labelName )

    if not squad then return end

    local buttonLeave = vgui.Create( "DButton", statePanel )
    buttonLeave:SetText( L"leave_squad" )
    buttonLeave:SetWide( ScaleSize( 180 ) )
    buttonLeave:Dock( RIGHT )

    StyledTheme.Apply( buttonLeave )

    buttonLeave.DoClick = function()
        SquadMenu.LeaveMySquad( buttonLeave )
    end
end

function SquadMenu:RequestSquadListUpdate( immediate )
    timer.Remove( "SquadMenu.RequestListUpdate" )

    local listPanel = self:GetPanel( "squadList" )
    if not listPanel then return end

    listPanel:Clear()

    StyledTheme.CreateFormHeader( listPanel, L"fetching_data", 0 )

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
        StyledTheme.CreateFormHeader( listPanel, L"no_available_squads", 0 )
        return
    end

    StyledTheme.CreateFormHeader( listPanel, L"tab.squad_list", 0 )

    local separation = ScaleSize( 6 )

    for _, squad in ipairs( squads ) do
        local line = vgui.Create( "Squad_ListRow", listPanel )
        line:SetSquad( squad )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, separation )
    end
end

function SquadMenu:UpdateRequestsPanel()
    local requestsPanel = self:GetPanel( "joinRequests" )
    if not requestsPanel then return end

    requestsPanel:Clear()

    local padding = StyledTheme.dimensions.scrollPadding
    requestsPanel:DockPadding( padding, 0, padding, padding )
    requestsPanel:SetPaintBackground( true )
    requestsPanel:SetBackgroundColor( StyledTheme.colors.scrollBackground )

    self.frame:SetTabNotificationCountByIndex( 4, 0 ) -- Join requests tab

    local squad = self.mySquad

    if not squad then
        StyledTheme.CreateFormHeader( requestsPanel, L"not_in_a_squad", 0 )
        return
    end

    if squad.leaderId ~= PID( LocalPlayer() ) then
        StyledTheme.CreateFormHeader( requestsPanel, L"not_squad_leader", 0 )
        return
    end

    local memberLimit = self.GetMemberLimit() - #squad.members

    if memberLimit < 1 then
        StyledTheme.CreateFormHeader( requestsPanel, L"member_limit_reached", 0 )
        return
    end

    local requestsHeaderLabel = StyledTheme.CreateFormHeader( requestsPanel, L"requests_list", 0 ):GetChildren()[1]

    local function UpdateMemberCount( current )
        requestsHeaderLabel:SetText( L( "slots" ) .. ": " .. current .. "/" .. self.GetMemberLimit() )
    end

    UpdateMemberCount( #squad.members )

    if squad.isPublic then
        StyledTheme.CreateFormHeader( requestsPanel, L"no_requests_needed", 0 )
        return
    end

    if #squad.requests == 0 then
        StyledTheme.CreateFormHeader( requestsPanel, L"no_requests_yet", 0 )
        return
    end

    self.frame:SetTabNotificationCountByIndex( 4, #squad.requests ) -- Join requests tab

    local scrollRequests = vgui.Create( "DScrollPanel", requestsPanel )
    scrollRequests:Dock( FILL )
    scrollRequests:SetPaintBackground( false )

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
        buttonAccept:Dock( BOTTOM )
        buttonAccept.DoClick = OnClickAccept
        buttonAccept._themeHighlight = true

        StyledTheme.Apply( buttonAccept )
    end

    UpdateAcceptedCount( 0 )

    local function OnClickRow( row )
        local id = row._id
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

        row.isChecked = acceptedPlayers[id] ~= nil
        UpdateAcceptedCount( count )
    end

    local rowHeight = ScaleSize( 48 )
    local rowPadding = ScaleSize( 6 )
    local nameColor = Color( 255, 255, 255 )

    local function OnPaintRow( row, w, h )
        row._OriginalPaint( row, w, h )
        draw.SimpleText( row._name, "StyledTheme_Small", rowHeight + rowPadding, h * 0.5, nameColor, 0, 1 )
    end

    local byId = SquadMenu.AllPlayersById()
    local dimensions = StyledTheme.dimensions

    for _, member in ipairs( squad.requests ) do
        local row = vgui.Create( "DButton", scrollRequests )
        row:SetText( "" )
        row:Dock( TOP )
        row:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )
        row:DockPadding( rowPadding, rowPadding, rowPadding, rowPadding )

        StyledTheme.Apply( row )

        row._id = member.id
        row._name = member.name
        row.isToggle = true
        row.isChecked = false
        row.DoClick = OnClickRow
        row:SetTall( rowHeight )

        row._OriginalPaint = row.Paint
        row.Paint = OnPaintRow

        local avatar = vgui.Create( "AvatarImage", row )
        avatar:Dock( LEFT )
        avatar:SetWide( rowHeight - rowPadding * 2 )

        if byId[member.id] then
            avatar:SetPlayer( byId[member.id], 64 )
        end
    end
end

function SquadMenu:UpdateSquadMembersPanel()
    local membersPanel = self:GetPanel( "squadMembers" )
    if not membersPanel then return end

    membersPanel:Clear()

    local padding = StyledTheme.dimensions.scrollPadding
    membersPanel:DockPadding( padding, 0, padding, padding )
    membersPanel:SetPaintBackground( true )
    membersPanel:SetBackgroundColor( StyledTheme.colors.scrollBackground )

    local squad = self.mySquad

    if not squad then
        StyledTheme.CreateFormHeader( membersPanel, L"not_in_a_squad", 0 )
        return
    end

    local memberCount = #squad.members

    StyledTheme.CreateFormHeader( membersPanel, L( "slots" ) .. ": " .. memberCount .. "/" .. self.GetMemberLimit(), 0 )

    if memberCount < 2 then
        StyledTheme.CreateFormHeader( membersPanel, L"no_members", 0 )
        return
    end

    local localId = PID( LocalPlayer() )
    local isLocalPlayerLeader = squad.leaderId == localId

    local membersScroll = vgui.Create( "DScrollPanel", membersPanel )
    membersScroll:Dock( FILL )
    membersScroll:DockMargin( 0, padding, 0, padding )

    local OnClickKick = function( s )
        s:SetEnabled( false )
        s:SetText( "..." )

        self.StartCommand( self.KICK )
        net.WriteString( s._id )
        net.SendToServer()
    end

    local rowHeight = ScaleSize( 48 )
    local rowPadding = ScaleSize( 6 )

    local colors = StyledTheme.colors
    local DrawRect = StyledTheme.DrawRect

    local function OnPaintRow( row, w, h )
        DrawRect( 0, 0, w, h, colors.buttonBorder )
        DrawRect( 1, 1, w - 2, h - 2, colors.panelBackground )

        draw.SimpleText( row._name, "StyledTheme_Small", rowHeight + rowPadding, h * 0.5, colors.labelText, 0, 1 )
    end

    local byId = SquadMenu.AllPlayersById()
    local dimensions = StyledTheme.dimensions

    for _, member in ipairs( squad.members ) do
        local row = vgui.Create( "Panel", membersScroll )
        row:Dock( TOP )
        row:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )
        row:DockPadding( rowPadding, rowPadding, rowPadding, rowPadding )

        row._name = member.name
        row.Paint = OnPaintRow
        row:SetTall( rowHeight )

        local avatar = vgui.Create( "AvatarImage", row )
        avatar:Dock( LEFT )
        avatar:SetWide( rowHeight - rowPadding * 2 )

        if byId[member.id] then
            avatar:SetPlayer( byId[member.id], 64 )
        end

        if isLocalPlayerLeader and member.id ~= localId then
            local kick = vgui.Create( "DButton", row )
            kick:SetText( L"kick" )
            kick:SetWide( ScaleSize( 100 ) )
            kick:Dock( RIGHT )

            kick._id = member.id
            kick.DoClick = OnClickKick

            StyledTheme.Apply( kick )
        end
    end
end

function SquadMenu:UpdateSquadPropertiesPanel()
    local propertiesPanel = self:GetPanel( "squadProperties" )
    if not propertiesPanel then return end

    propertiesPanel:Clear()

    local padding = StyledTheme.dimensions.scrollPadding
    propertiesPanel:DockPadding( padding, 0, padding, padding )
    propertiesPanel:SetPaintBackground( true )
    propertiesPanel:SetBackgroundColor( StyledTheme.colors.scrollBackground )

    local squad = self.mySquad

    if squad and squad.leaderId ~= PID( LocalPlayer() ) then
        StyledTheme.CreateFormHeader( propertiesPanel, L"leave_first_create", 0 )
        return
    end

    local isNew = squad == nil
    local oldName = squad and squad.name or nil
    local oldColor = squad and squad.color or nil

    if not oldColor then
        local c = HSVToColor( math.random( 0, 360 ), 1, 1 )
        oldColor = Color( c.r, c.g, c.b ) -- Reconstruct color instance to avoid a bug
    end

    squad = squad or {
        enableRings = true
    }

    StyledTheme.CreateFormHeader( propertiesPanel, L( isNew and "create_squad" or "edit_squad" ), 0 )

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
    buttonCreate:DockMargin( 0, ScaleSize( 8 ), 0, 0 )

    StyledTheme.Apply( buttonCreate )

    buttonCreate.DoClick = function( s )
        s:SetEnabled( false )
        s:SetText( "..." )

        self.StartCommand( self.SETUP_SQUAD )
        self.WriteTable( data )
        net.SendToServer()
    end

    local leftPanel = vgui.Create( "DPanel", propertiesPanel )
    leftPanel:Dock( FILL )

    StyledTheme.Apply( leftPanel )
    StyledTheme.CreateFormHeader( leftPanel, L"squad_name", 0, 0 )

    local separator = ScaleSize( 6 )
    local rowHeight = StyledTheme.dimensions.buttonHeight

    local entryName = vgui.Create( "DTextEntry", leftPanel )
    entryName:SetTall( rowHeight )
    entryName:Dock( TOP )
    entryName:DockMargin( separator, separator, separator, separator )
    entryName:SetMaximumCharCount( self.MAX_NAME_LENGTH )
    entryName:SetValue( data.name )

    entryName.OnChange = function()
        local value = entryName:GetValue()
        data.name = value:Trim() == "" and oldName or value
    end

    StyledTheme.Apply( entryName )
    StyledTheme.CreateFormHeader( leftPanel, L"tab.squad_properties", 0, 0 )

    local buttonIcon = vgui.Create( "DButton", leftPanel )
    buttonIcon:SetTall( rowHeight )
    buttonIcon:SetIcon( data.icon )
    buttonIcon:SetText( L"choose_icon" )
    buttonIcon:Dock( TOP )
    buttonIcon:DockMargin( separator, separator, separator, 0 )

    StyledTheme.Apply( buttonIcon )

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

    StyledTheme.CreateFormToggle( leftPanel, L"squad_is_public", data.isPublic, function( checked )
        data.isPublic = checked
    end ):DockMargin( separator, separator, separator, 0 )

    local ffButton = StyledTheme.CreateFormToggle( leftPanel, L"squad_friendly_fire", data.friendlyFire, function( checked )
        data.friendlyFire = checked
    end )

    ffButton:DockMargin( separator, separator, separator, 0 )

    if SquadMenu.GetForceFriendlyFire() then
        ffButton:SetEnabled( false )
        ffButton:SetIcon( "icon16/accept.png" )
        ffButton:SetText( L"squad_force_friendly_fire" )
    end

    StyledTheme.CreateFormToggle( leftPanel, L"squad_rings", data.enableRings, function( checked )
        data.enableRings = checked
    end ):DockMargin( separator, separator, separator, 0 )

    local rightPanel = vgui.Create( "DPanel", propertiesPanel )
    rightPanel:SetWide( ScaleSize( 260 ) )
    rightPanel:Dock( RIGHT )
    rightPanel:DockMargin( separator, 0, 0, 0 )

    StyledTheme.Apply( rightPanel )
    StyledTheme.CreateFormHeader( rightPanel, L"squad_color", 0, 0 )

    local colorPicker = vgui.Create( "DColorMixer", rightPanel )
    colorPicker:Dock( FILL )
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