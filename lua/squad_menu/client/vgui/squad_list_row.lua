local L = SquadMenu.GetLanguageText
local ScaleSize = StyledTheme.ScaleSize

local UpdateButton = function( button, text, enabled )
    button:SetEnabled( enabled )
    button:SetText( L( text ) )
    button:SizeToContentsX( ScaleSize( 12 ) )
    button:GetParent():InvalidateLayout()
end

local PANEL = {}
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
    self.animHover = 0

    self.collapsedHeight = ScaleSize( 52 )
    self.padding = ScaleSize( 6 )
    self.iconSize = self.collapsedHeight - self.padding * 2

    self.icon = vgui.Create( "DImage", self )
    self.icon:SetSize( self.iconSize, self.iconSize )

    self.buttonJoin = vgui.Create( "DButton", self )

    StyledTheme.Apply( self.buttonJoin )
    self.buttonJoin:SetTall( self.collapsedHeight - self.padding * 2 )

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
    self.memberCount:SetTall( self.collapsedHeight - self.padding * 2 )
    self.memberCount:SetPaintBackground( false )

    self:SetTall( self.collapsedHeight )
end

function PANEL:PerformLayout( w )
    self.icon:SetPos( self.padding, self.padding )

    local joinWidth = self.buttonJoin:GetWide()

    self.buttonJoin:SetPos( w - joinWidth - self.padding, self.padding )
    self.memberCount:SetPos( w - joinWidth - self.memberCount:GetWide() - self.padding * 2, self.padding )
end

local colors = StyledTheme.colors
local DrawRect = StyledTheme.DrawRect

function PANEL:Paint( w, h )
    self.animHover = Lerp( FrameTime() * 10, self.animHover, self:IsHovered() and 1 or 0 )

    DrawRect( 0, 0, w, h, self.squad.color )
    DrawRect( 1, 1, w - 2, h - 2, COLOR_BLACK )
    DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )

    local x = self.iconSize + self.padding * 2
    local y = self.collapsedHeight * 0.5

    draw.SimpleText( self.squad.name, "StyledTheme_Small", x, y, colors.labelText, 0, 4 )
    draw.SimpleText( self.squad.leaderName or "<Server>", "StyledTheme_Tiny", x, y, colors.buttonTextDisabled, 0, 3 )
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

    local labelWide = labelCount:GetWide()

    local iconCount = vgui.Create( "DImage", self.memberCount )
    iconCount:SetImage( "styledstrike/icons/users.png" )
    iconCount:SetWide( self.collapsedHeight - self.padding * 4 )
    iconCount:Dock( LEFT )
    iconCount:DockMargin( 0, self.padding, 0, self.padding )

    self.memberCount:SetWide( labelWide + iconCount:GetWide() )
end

function PANEL:SetExpanded( expanded, scroll )
    self.isExpanded = expanded

    local height = self.collapsedHeight
    local memberHeight = ScaleSize( 32 )

    if expanded then
        height = height + self.padding + memberHeight * math.min( #self.squad.members, 5 )
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
    membersScroll:DockMargin( 0, self.collapsedHeight, 0, 0 )
    membersScroll.pnlCanvas:DockPadding( 0, 0, 0, 0 )

    self.membersScroll = membersScroll

    local byId = SquadMenu.AllPlayersById()
    local separation = ScaleSize( 2 )
    local padding = ScaleSize( 4 )

    for _, m in ipairs( self.squad.members ) do
        local id = m[1]

        local row = vgui.Create( "DPanel", membersScroll )
        row:SetBackgroundColor( colors.panelBackground )
        row:SetTall( memberHeight - separation )
        row:Dock( TOP )
        row:DockMargin( self.padding, 0, self.padding, separation )

        local name = vgui.Create( "DLabel", row )
        name:SetText( m[2] )
        name:Dock( FILL )

        local avatar = vgui.Create( "AvatarImage", row )
        avatar:SetWide( memberHeight - padding * 2 )
        avatar:Dock( LEFT )
        avatar:DockMargin( padding, padding, padding, padding )

        if byId[id] then
            avatar:SetPlayer( byId[id], 64 )
        end

        if id == self.squad.leaderId then
            row:SetZPos( -1 )

            local leaderIcon = vgui.Create( "DImage", row )
            leaderIcon:SetWide( memberHeight - padding * 2 )
            leaderIcon:SetImage( "icon16/award_star_gold_3.png" )
            leaderIcon:Dock( RIGHT )
            leaderIcon:DockMargin( 0, padding, padding, padding )
        end
    end
end

vgui.Register( "Squad_ListRow", PANEL, "DPanel" )
