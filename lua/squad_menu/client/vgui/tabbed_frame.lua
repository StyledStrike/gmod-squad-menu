local L = SquadMenu.GetLanguageText
local colors = SquadMenu.Theme

local TabButton = {}

function TabButton:Init()
    self:SetCursor( "hand" )
    self.isSelected = false
    self.notificationCount = 0
    self.icon = vgui.Create( "DImage", self )
end

function TabButton:SetIcon( path )
    self.icon:SetImage( path )
end

function TabButton:PerformLayout( w, h )
    local size = math.max( w, h ) * 0.4

    self.icon:SetSize( size, size )
    self.icon:Center()
end

local COLOR_INDICATOR = Color( 200, 0, 0, 255 )

function TabButton:Paint( w, h )
    if self.isSelected then
        surface.SetDrawColor( colors.buttonPress:Unpack() )
        surface.DrawRect( 0, 0, w, h )
    end

    if self:IsHovered() then
        surface.SetDrawColor( colors.buttonHover:Unpack() )
        surface.DrawRect( 0, 0, w, h )
    end

    if self.notificationCount > 0 then
        local size = 14
        local x = w - size - 2
        local y = h - size - 2

        draw.RoundedBox( size * 0.5, x, y, size, size, COLOR_INDICATOR )
        draw.SimpleText( self.notificationCount, "TargetIDSmall", x + size * 0.5, y + size * 0.5, colors.buttonText, 1, 1 )
    end
end

function TabButton:OnMousePressed( keyCode )
    if keyCode == MOUSE_LEFT then
        self:GetParent():GetParent():SetActiveTab( self.tab )
    end
end

vgui.Register( "Squad_TabButton", TabButton, "DPanel" )

local PANEL = {}

function PANEL:Init()
    local w = math.max( ScrH() * 0.7, 600 )
    local h = math.max( ScrH() * 0.45, 400 )

    self:SetTitle( L"title" )
    self:SetIcon( "squad_menu/squad_menu.png" )
    self:SetPos( 0, 0 )
    self:SetSize( w, h )
    self:SetSizable( true )
    self:SetDraggable( true )
    self:SetDeleteOnClose( true )
    self:SetScreenLock( true )
    self:SetMinWidth( 600 )
    self:SetMinHeight( 400 )
    self:DockPadding( 4, 28, 4, 4 )

    self.btnClose:SetText( "X" )
    self.btnMaxim:Remove()
    self.btnMinim:Remove()

    SquadMenu.ApplyTheme( self.btnClose )
    SquadMenu.ApplyTheme( self, "DFrame" )

    self.tabList = vgui.Create( "DPanel", self )
    self.tabList:SetWide( 48 )
    self.tabList:Dock( LEFT )
    self.tabList:DockPadding( 2, 2, 2, 2 )
    self.tabList:SetBackgroundColor( Color( 0, 0, 0, 200 ) )

    self.tabContainer = vgui.Create( "DPanel", self )
    self.tabContainer:Dock( FILL )
    self.tabContainer:DockMargin( 4, 0, 0, 0 )
    self.tabContainer:DockPadding( 0, 0, 0, 0 )
    self.tabContainer:SetPaintBackground( false )

    self.tabs = {}
end

function PANEL:AddTab( icon, tooltip )
    local tab = {}

    tab.button = vgui.Create( "Squad_TabButton", self.tabList )
    tab.button:SetIcon( icon )
    tab.button:SetTall( 44 )
    tab.button:SetTooltip( tooltip )
    tab.button:Dock( TOP )
    tab.button:DockMargin( 0, 0, 0, 2 )
    tab.button.tab = tab

    tab.panel = vgui.Create( "DPanel", self.tabContainer )
    tab.panel:Dock( FILL )
    tab.panel:DockMargin( 0, 0, 0, 0 )
    tab.panel:DockPadding( 0, 0, 0, 0 )
    tab.panel:SetPaintBackground( false )
    tab.panel:SetVisible( false )

    self.tabs[#self.tabs + 1] = tab

    if #self.tabs == 1 then
        self:SetActiveTab( tab )
    end

    return tab.panel
end

function PANEL:SetActiveTab( tab )
    for i, t in ipairs( self.tabs ) do
        local isThisOne = t == tab

        t.button.isSelected = isThisOne
        t.panel:SetVisible( isThisOne )

        if isThisOne then
            self.lastTabIndex = i
        end
    end
end

function PANEL:SetActiveTabByIndex( index )
    if self.tabs[index] then
        self:SetActiveTab( self.tabs[index] )
    end
end

function PANEL:SetTabNotificationCountByIndex( index, count )
    if self.tabs[index] then
        self.tabs[index].button.notificationCount = count
    end
end

function PANEL:PerformLayout()
    local titlePush = 16

    self.imgIcon:SetPos( 4, 5 )
    self.imgIcon:SetSize( 16, 16 )

    self.btnClose:SetPos( self:GetWide() - 28 - 2, 2 )
    self.btnClose:SetSize( 28, 20 )

    self.lblTitle:SetPos( 8 + titlePush, 2 )
    self.lblTitle:SetSize( self:GetWide() - 25 - titlePush, 20 )
end

vgui.Register( "Squad_TabbedFrame", PANEL, "DFrame" )
