local L = SquadMenu.GetLanguageText
local colors = SquadMenu.Theme

local UpdateButton = function( button, text, enabled )
    button:SetEnabled( enabled )
    button:SetText( L( text ) )
    button:SizeToContentsX( 10 )
    button:GetParent():InvalidateLayout()
end

local PANEL = {}
local DEFAULT_HEIGHT = 48
local COLOR_BLACK = Color( 0, 0, 0, 255 )

function PANEL:Init()
    self.squad = {
        id = 0,
        name = "-",
        leaderName = "-",
        color = COLOR_BLACK
    }

    self:SetCursor( "hand" )
    self:SetExpanded( false )

    self.icon = vgui.Create( "DImage", self )
    self.icon:SetSize( 24, 24 )

    self.buttonJoin = vgui.Create( "DButton", self )
    self.buttonJoin:SetTall( 32 )

    self.buttonJoin.DoClick = function()
        if self.leaveOnClick then
            SquadMenu.LeaveMySquad( self.buttonJoin )
        else
            UpdateButton( self.buttonJoin, "waiting_response", false )

            SquadMenu.StartCommand( SquadMenu.JOIN_SQUAD )
            net.WriteUInt( self.squad.id, 16 )
            net.SendToServer()
        end
    end

    self.memberCount = vgui.Create( "DPanel", self )
    self.memberCount:SetTall( 32 )
    self.memberCount:SetPaintBackground( false )
    self.memberCount:DockPadding( 4, 0, 4, 0 )

    SquadMenu.ApplyTheme( self.buttonJoin )
end

function PANEL:PerformLayout( w )
    local joinWidth = self.buttonJoin:GetWide()

    self.icon:SetPos( 12, 12 )
    self.buttonJoin:SetPos( w - joinWidth - 4, 8 )
    self.memberCount:SetPos( w - joinWidth - self.memberCount:GetWide() - 8, 8 )
end

function PANEL:Paint( w, h )
    draw.RoundedBox( 4, 0, 0, w, h, COLOR_BLACK )

    if self:IsHovered() then
        draw.RoundedBox( 4, 0, 0, w, DEFAULT_HEIGHT, colors.buttonBackground )
    end

    surface.SetDrawColor( self.squad.color:Unpack() )
    surface.DrawRect( 0, 0, 4, h )

    draw.SimpleText( self.squad.name, "Trebuchet18", 48, 4 + DEFAULT_HEIGHT * 0.5, colors.buttonText, 0, 4 )
    draw.SimpleText( self.squad.leaderName or "<Server>", "DefaultSmall", 48, 1 + DEFAULT_HEIGHT * 0.5, colors.buttonTextDisabled, 0, 3 )
end

function PANEL:OnMousePressed( keyCode )
    if keyCode == MOUSE_LEFT then
        self:SetExpanded( not self.isExpanded, true )
    end
end

--- Set the squad data.
--- `squad` is a table that comes from `squad:GetBasicInfo`.
function PANEL:SetSquad( squad )
    squad.color = Color( squad.r, squad.g, squad.b )

    self.squad = squad
    self.icon:SetImage( squad.icon )

    local maxMembers = SquadMenu.GetMemberLimit()
    local count = #squad.members

    self.leaveOnClick = squad.id == ( SquadMenu.mySquad and SquadMenu.mySquad.id or -1 )

    if self.leaveOnClick then
        UpdateButton( self.buttonJoin, "leave_squad", true )
    elseif count < maxMembers then
        UpdateButton( self.buttonJoin, squad.isPublic and "join" or "request_to_join", true )
    else
        UpdateButton( self.buttonJoin, "full_squad", false )
    end

    self.memberCount:Clear()

    local labelCount = vgui.Create( "DLabel", self.memberCount )
    labelCount:SetText( count .. "/" .. maxMembers )
    labelCount:SizeToContents()
    labelCount:Dock( FILL )

    local left, _, right = self.memberCount:GetDockPadding()
    local labelWide = labelCount:GetWide() + left + right + 4

    local iconCount = vgui.Create( "DImage", self.memberCount )
    iconCount:Dock( LEFT )
    iconCount:DockMargin( 0, 8, 4, 8 )
    iconCount:SetWide( 16 )
    iconCount:SetImage( "icon16/user.png" )

    self.memberCount:SetWide( labelWide + iconCount:GetWide() )
end

function PANEL:SetExpanded( expanded, scroll )
    self.isExpanded = expanded

    local height = DEFAULT_HEIGHT
    local memberHeight = 30

    if expanded then
        height = height + 4 + memberHeight * math.min( #self.squad.members, 5 )
    end

    self:SetTall( height )
    self:InvalidateLayout()

    if expanded and scroll then
        self:GetParent():GetParent():ScrollToChild( self )
    end

    if self.membersScroll then
        self.membersScroll:Remove()
        self.membersScroll = nil
    end

    if not expanded then return end

    local membersScroll = vgui.Create( "DScrollPanel", self )
    membersScroll:Dock( FILL )
    membersScroll:DockMargin( 0, DEFAULT_HEIGHT, 0, 0 )
    membersScroll.pnlCanvas:DockPadding( 6, 2, 2, 2 )

    self.membersScroll = membersScroll

    local byId = SquadMenu.AllPlayersById()

    for _, m in ipairs( self.squad.members ) do
        local id = m[1]

        local line = vgui.Create( "DPanel", membersScroll )
        line:SetBackgroundColor( colors.panelBackground )
        line:SetTall( memberHeight - 2 )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 2 )

        local name = vgui.Create( "DLabel", line )
        name:SetText( m[2] )
        name:Dock( FILL )

        local avatar = vgui.Create( "AvatarImage", line )
        avatar:SetWide( 20 )
        avatar:Dock( LEFT )
        avatar:DockMargin( 4, 4, 4, 4 )

        if byId[id] then
            avatar:SetPlayer( byId[id], 64 )
        end

        if id == self.squad.leaderId then
            line:SetZPos( -1 )

            local leaderIcon = vgui.Create( "DImage", line )
            leaderIcon:SetWide( 16 )
            leaderIcon:SetImage( "icon16/award_star_gold_3.png" )
            leaderIcon:Dock( RIGHT )
            leaderIcon:DockMargin( 0, 6, 4, 6 )
        end
    end
end

vgui.Register( "Squad_Line", PANEL, "DPanel" )
