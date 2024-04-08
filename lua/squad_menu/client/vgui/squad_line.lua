local L = SquadMenu.GetLanguageText
local colors = SquadMenu.Theme.colors

local UpdateButton = function( button, text, enabled )
    button:SetEnabled( enabled )
    button:SetText( L( text ) )
    button:SizeToContentsX( 10 )
    button:GetParent():InvalidateLayout()
end

local PANEL = {}

function PANEL:Init()
    self.squad = {
        id = 0,
        name = "-",
        leaderName = "-",
        color = colors.black
    }

    self:SetCursor( "hand" )
    self:SetExpanded( false )

    self.icon = vgui.Create( "DImage", self )
    self.icon:SetSize( 24, 24 )

    self.buttonJoin = vgui.Create( "DButton", self )
    self.buttonJoin:SetTall( 32 )

    self.buttonJoin.DoClick = function()
        UpdateButton( self.buttonJoin, "waiting_response", false )

        SquadMenu.StartCommand( SquadMenu.JOIN_SQUAD )
        net.WriteUInt( self.squad.id, 16 )
        net.SendToServer()
    end

    self.memberCount = vgui.Create( "DPanel", self )
    self.memberCount:SetTall( 32 )
    self.memberCount:DockPadding( 4, 0, 4, 0 )

    SquadMenu.Theme.Apply( self.buttonJoin )
    SquadMenu.Theme.Apply( self.memberCount )
end

function PANEL:PerformLayout( w )
    local joinWidth = self.buttonJoin:GetWide()

    self.icon:SetPos( 12, 12 )
    self.buttonJoin:SetPos( w - joinWidth - 4, 8 )
    self.memberCount:SetPos( w - joinWidth - self.memberCount:GetWide() - 8, 8 )
end

function PANEL:Paint( w, h )
    draw.RoundedBox( 4, 0, 0, w, h, colors.black )

    surface.SetDrawColor( self.squad.color:Unpack() )
    surface.DrawRect( 0, 0, 4, h )

    draw.SimpleText( self.squad.name, "Trebuchet18", 48, 26, colors.buttonText, 0, 4 )
    draw.SimpleText( self.squad.leaderName, "DefaultSmall", 48, 26, colors.buttonTextDisabled, 0, 3 )
end

function PANEL:OnMousePressed( keyCode )
    if keyCode == MOUSE_LEFT then
        self:SetExpanded( not self.isExpanded, true )
    end
end

function PANEL:SetSquad( squad )
    squad.color = Color( squad.r, squad.g, squad.b )

    self.squad = squad
    self.icon:SetImage( squad.icon )

    local maxMembers = SquadMenu.GetMemberLimit()
    local memberCount = #squad.members

    if memberCount < maxMembers then
        UpdateButton( self.buttonJoin, squad.isPublic and "join" or "request_to_join", true )
    else
        UpdateButton( self.buttonJoin, "full_squad", false )
    end

    self.memberCount:Clear()

    local labelCount = vgui.Create( "DLabel", self.memberCount )
    labelCount:SetText( memberCount .. "/" .. maxMembers )
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

    self:SetTall( expanded and 198 or 48 )
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
    membersScroll:DockMargin( 6, 48, 4, 4 )
    membersScroll.pnlCanvas:DockPadding( 2, 2, 2, 2 )

    self.membersScroll = membersScroll

    local players = SquadMenu.AllPlayersBySteamID()

    for _, member in ipairs( self.squad.members ) do
        local line = vgui.Create( "DPanel", membersScroll )
        line:SetBackgroundColor( colors.panelBackground )
        line:SetTall( 28 )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 2 )

        local name = vgui.Create( "DLabel", line )
        name:SetText( member.name )
        name:Dock( FILL )

        local avatar = vgui.Create( "AvatarImage", line )
        avatar:SetWide( 20 )
        avatar:Dock( LEFT )
        avatar:DockMargin( 4, 4, 4, 4 )

        if players[member.id] then
            avatar:SetPlayer( players[member.id], 64 )
        end
    end
end

vgui.Register( "Squad_Line", PANEL, "DPanel" )
