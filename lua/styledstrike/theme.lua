--[[
    StyledStrike's VGUI theme utilities

    A collection of functions to create common
    UI panels and to apply a custom theme to them.
]]

StyledTheme = StyledTheme or {}

--[[
    Setup color constants
]]
do
    StyledTheme.colors = StyledTheme.colors or {}

    local colors = StyledTheme.colors or {}

    colors.accent = Color( 56, 113, 179 )
    colors.panelBackground = Color( 46, 46, 46, 240 )
    colors.panelDisabledBackground = Color( 90, 90, 90, 255 )
    colors.scrollBackground = Color( 0, 0, 0, 200 )

    colors.labelText = Color( 255, 255, 255, 255 )
    colors.labelTextDisabled = Color( 180, 180, 180, 255 )

    colors.buttonHover = Color( 150, 150, 150, 50 )
    colors.buttonPress = colors.accent
    colors.buttonBorder = Color( 32, 32, 32, 255 )
    colors.buttonText = Color( 255, 255, 255, 255 )
    colors.buttonTextDisabled = Color( 180, 180, 180, 255 )

    colors.entryBackground = Color( 20, 20, 20, 255 )
    colors.entryBorder = Color( 80, 80, 80, 255 )
    colors.entryHighlight = colors.accent
    colors.entryPlaceholder = Color( 150, 150, 150, 255 )
    colors.entryText = Color( 255, 255, 255, 255 )
end

--[[
    Setup fonts
]]
do
    StyledTheme.BASE_FONT_NAME = "Roboto"
    StyledTheme.fonts = StyledTheme.fonts or {}

    local fonts = StyledTheme.fonts

    fonts["StyledTheme_Small"] = {
        font = StyledTheme.BASE_FONT_NAME,
        screenSize = 0.018,
        weight = 500,
        blursize = 0,
        scanlines = 0,
        extended = false,
        antialias = true
    }

    fonts["StyledTheme_Tiny"] = {
        font = StyledTheme.BASE_FONT_NAME,
        screenSize = 0.013,
        weight = 500,
        blursize = 0,
        scanlines = 0,
        extended = false,
        antialias = true
    }
end

hook.Add( "StyledTheme_OnResolutionChange", "StyledTheme.UpdateFonts", function( _, screenH )
    for name, data in pairs( StyledTheme.fonts ) do
        data.size = math.floor( screenH * data.screenSize )
        surface.CreateFont( name, data )
    end
end )

--[[
    Setup dimensions
]]
StyledTheme.dimensions = StyledTheme.dimensions or {}

hook.Add( "StyledTheme_OnResolutionChange", "StyledTheme.UpdateDimensions", function()
    local dimensions = StyledTheme.dimensions
    local ScaleSize = StyledTheme.ScaleSize

    dimensions.framePadding = ScaleSize( 10 )
    dimensions.frameButtonSize = ScaleSize( 36 )

    dimensions.buttonHeight = ScaleSize( 40 )
    dimensions.headerHeight = ScaleSize( 32 )

    dimensions.scrollBarWidth = ScaleSize( 16 )
    dimensions.scrollPadding = ScaleSize( 8 )

    dimensions.formPadding = ScaleSize( 20 )
    dimensions.formSeparator = ScaleSize( 6 )
    dimensions.formLabelWidth = ScaleSize( 300 )

    dimensions.menuPadding = ScaleSize( 6 )
    dimensions.indicatorSize = ScaleSize( 20 )
end )

--[[
    Watch for changes in screen resolution
]]
do
    local Floor = math.floor
    local screenW, screenH = 0, 0

    --- Scales the given size (in pixels) from a 1080p resolution to 
    --- the resolution currently being used by the game.
    function StyledTheme.ScaleSize( size )
        return Floor( ( size / 1080 ) * screenH )
    end

    hook.Add( "Initialize", "StyledTheme.CreateFonts", function()
        screenW, screenH = ScrW(), ScrH()
        hook.Run( "StyledTheme_OnResolutionChange", screenW, screenH )
    end )

    -- Detect resolution changes
    local ScrW, ScrH = ScrW, ScrH

    timer.Create( "StyledTheme.CheckResolution", 3, 0, function()
        if ScrW() ~= screenW or ScrH() ~= screenH then
            screenW, screenH = ScrW(), ScrH()
            hook.Run( "StyledTheme_OnResolutionChange", screenW, screenH )
        end
    end )
end

--[[
    Misc. utility functions
]]
do
    --- Gets a localized language string, with the first character being in uppercase.
    function StyledTheme.GetUpperLanguagePhrase( text )
        text = language.GetPhrase( text )
        return text:sub( 1, 1 ):upper() .. text:sub( 2 )
    end

    local SetDrawColor = surface.SetDrawColor
    local DrawRect = surface.DrawRect

    --- Draw box, using the specified background color.
    --- It allows overriding the alpha while keeping the supplied color table intact.
    function StyledTheme.DrawRect( x, y, w, h, color, alpha )
        alpha = alpha or 1

        SetDrawColor( color.r, color.g, color.b, color.a * alpha )
        DrawRect( x, y, w, h )
    end

    local SetMaterial = surface.SetMaterial
    local MAT_BLUR = Material( "pp/blurscreen" )

    --- Blur the background of a panel.
    function StyledTheme.BlurPanel( panel, alpha, density )
        SetDrawColor( 255, 255, 255, alpha or panel:GetAlpha() )
        SetMaterial( MAT_BLUR )

        MAT_BLUR:SetFloat( "$blur", density or 4 )
        MAT_BLUR:Recompute()

        render.UpdateScreenEffectTexture()

        local x, y = panel:LocalToScreen( 0, 0 )
        surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
    end

    local cache = {}

    -- Get a material given a path to a material or .png file.
    function StyledTheme.GetMaterial( path )
        if cache[path] then
            return cache[path]
        end

        cache[path] = Material( path, "smooth ignorez" )

        return cache[path]
    end

    local GetMaterial = StyledTheme.GetMaterial
    local DrawTexturedRect = surface.DrawTexturedRect
    local COLOR_WHITE = Color( 255, 255, 255, 255 )

    --- Draw a icon, using the specified image file path and color.
    --- It allows overriding the alpha while keeping the supplied color table intact.
    function StyledTheme.DrawIcon( path, x, y, w, h, alpha, color )
        color = color or COLOR_WHITE
        alpha = alpha or 1

        SetMaterial( GetMaterial( path ) )
        SetDrawColor( color.r, color.g, color.b, 255 * alpha )
        DrawTexturedRect( x, y, w, h )
    end
end

--[[
    Utility function to apply the theme to existing VGUI panels
]]
do
    local ClassFunctions = {}

    function StyledTheme.Apply( panel, classOverride )
        local funcs = ClassFunctions[classOverride or panel.ClassName]
        if not funcs then return end

        if funcs.Prepare then
            funcs.Prepare( panel )
        end

        if funcs.Paint then
            panel.Paint = funcs.Paint
        end

        if funcs.UpdateColours then
            panel.UpdateColours = funcs.UpdateColours
        end

        if funcs.Close then
            panel.Close = funcs.Close
        end
    end

    local colors = StyledTheme.colors
    local dimensions = StyledTheme.dimensions
    local DrawRect = StyledTheme.DrawRect

    ClassFunctions["DLabel"] = {
        Prepare = function( self )
            self:SetColor( colors.labelText )
            self:SetFont( "StyledTheme_Small" )
        end
    }

    ClassFunctions["DPanel"] = {
        Paint = function( self, w, h )
            DrawRect( 0, 0, w, h, self:GetBackgroundColor() or colors.panelBackground )
        end
    }

    local function CustomMenuAdd( self, class )
        local pnl = self:OriginalAdd( class )

        if class == "DButton" then
            StyledTheme.Apply( pnl )

            timer.Simple( 0, function()
                if not IsValid( pnl ) then return end

                pnl:SetPaintBackground( true )
                pnl:SizeToContentsX( StyledTheme.ScaleSize( 20 ) )
                pnl:DockMargin( 0, 0, dimensions.menuPadding, 0 )
            end )
        end

        return pnl
    end

    ClassFunctions["DMenuBar"] = {
        Prepare = function( self )
            self:SetTall( dimensions.buttonHeight )
            self:DockMargin( 0, 0, 0, 0 )
            self:DockPadding( dimensions.menuPadding, dimensions.menuPadding, dimensions.menuPadding, dimensions.menuPadding )

            self.OriginalAdd = self.Add
            self.Add = CustomMenuAdd
        end,
        Paint = function( self, w, h )
            DrawRect( 0, 0, w, h, self:GetBackgroundColor() or colors.accent )
        end
    }

    local Lerp = Lerp
    local FrameTime = FrameTime

    ClassFunctions["DButton"] = {
        Prepare = function( self )
            self:SetFont( "StyledTheme_Small" )
            self:SetTall( dimensions.buttonHeight )
            self.animHover = 0
            self.animPress = 0
        end,

        Paint = function( self, w, h )
            local dt = FrameTime() * 10
            local enabled = self:IsEnabled()

            self.animHover = Lerp( dt, self.animHover, ( enabled and self.Hovered ) and 1 or 0 )
            self.animPress = Lerp( dt, self.animPress, ( enabled and ( self:IsDown() or self.m_bSelected ) ) and 1 or 0 )

            DrawRect( 0, 0, w, h, ( self.isToggle and self.isChecked ) and colors.buttonPress or colors.buttonBorder )
            DrawRect( 1, 1, w - 2, h - 2, enabled and colors.panelBackground or colors.panelDisabledBackground )
            DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )
            DrawRect( 1, 1, w - 2, h - 2, colors.buttonPress, self.animPress )
        end,

        UpdateColours = function( self )
            if self:IsEnabled() then
                self:SetTextStyleColor( colors.buttonText )
            else
                self:SetTextStyleColor( colors.buttonTextDisabled )
            end
        end
    }

    ClassFunctions["DBinder"] = ClassFunctions["DButton"]

    ClassFunctions["DTextEntry"] = {
        Prepare = function( self )
            self:SetFont( "StyledTheme_Small" )
            self:SetTall( dimensions.buttonHeight )
            self:SetDrawBorder( false )
            self:SetPaintBackground( false )

            self:SetTextColor( colors.entryText )
            self:SetCursorColor( colors.entryText )
            self:SetHighlightColor( colors.entryHighlight )
            self:SetPlaceholderColor( colors.entryPlaceholder )
        end,

        Paint = function( self, w, h )
            local enabled = self:IsEnabled()

            DrawRect( 0, 0, w, h, ( self:IsEditing() and enabled ) and colors.entryHighlight or colors.entryBorder )
            DrawRect( 1, 1, w - 2, h - 2, enabled and colors.entryBackground or colors.panelDisabledBackground )

            derma.SkinHook( "Paint", "TextEntry", self, w, h )
        end
    }

    ClassFunctions["DComboBox"] = {
        Prepare = function( self )
            self:SetFont( "StyledTheme_Small" )
            self:SetTall( dimensions.buttonHeight )
            self:SetTextColor( colors.entryText )
            self.animHover = 0
        end,

        Paint = function( self, w, h )
            local dt = FrameTime() * 10
            local enabled = self:IsEnabled()

            self.animHover = Lerp( dt, self.animHover, ( enabled and self.Hovered ) and 1 or 0 )

            DrawRect( 0, 0, w, h, ( self:IsMenuOpen() and enabled ) and colors.entryHighlight or colors.buttonBorder )
            DrawRect( 1, 1, w - 2, h - 2, enabled and colors.panelBackground or colors.panelDisabledBackground )
            DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )
        end
    }

    ClassFunctions["DNumSlider"] = {
        Prepare = function( self )
            StyledTheme.Apply( self.TextArea )
            StyledTheme.Apply( self.Label )
        end
    }

    ClassFunctions["DScrollPanel"] = {
        Prepare = function( self )
            StyledTheme.Apply( self.VBar )

            local padding = dimensions.scrollPadding
            self.pnlCanvas:DockPadding( padding, padding, padding, padding )
            self:SetPaintBackground( true )
        end,

        Paint = function( self, w, h )
            if self:GetPaintBackground() then
                DrawRect( 0, 0, w, h, colors.scrollBackground )
            end
        end
    }

    local Clamp = math.Clamp

    local function AddScroll( self, delta )
        local oldScroll = self.animTargetScroll or self:GetScroll()
        local newScroll = Clamp( oldScroll + delta * 40, 0, self.CanvasSize )

        if oldScroll == newScroll then
            return false
        end

        self:Stop()
        self.animTargetScroll = newScroll

        local anim = self:NewAnimation( 0.4, 0, 0.25, function( _, pnl )
            pnl.animTargetScroll = nil
        end )

        anim.StartPos = oldScroll
        anim.TargetPos = newScroll

        anim.Think = function( a, pnl, fraction )
            pnl:SetScroll( Lerp( fraction, a.StartPos, a.TargetPos ) )
        end

        return true
    end

    local function DrawGrip( self, w, h )
        local dt = FrameTime() * 10

        self.animHover = Lerp( dt, self.animHover, self.Hovered and 1 or 0 )
        self.animPress = Lerp( dt, self.animPress, self.Depressed and 1 or 0 )

        DrawRect( 0, 0, w, h, colors.buttonBorder )
        DrawRect( 1, 1, w - 2, h - 2, colors.panelBackground )
        DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )
        DrawRect( 1, 1, w - 2, h - 2, colors.buttonPress, self.animPress )
    end

    ClassFunctions["DVScrollBar"] = {
        Prepare = function( self )
            self:SetWide( dimensions.scrollBarWidth )
            self:SetHideButtons( true )
            self.AddScroll = AddScroll

            self.btnGrip.animHover = 0
            self.btnGrip.animPress = 0
            self.btnGrip.Paint = DrawGrip
        end,

        Paint = function( _, w, h )
            DrawRect( 0, 0, w, h, colors.scrollBackground )
        end
    }

    local function FrameSlideAnim( anim, panel, fraction )
        if not anim.StartPos then
            anim.StartPos = Vector( panel.x, panel.y + anim.StartOffset, 0 )
            anim.TargetPos = Vector( panel.x, panel.y + anim.EndOffset, 0 )
        end

        local pos = LerpVector( fraction, anim.StartPos, anim.TargetPos )
        panel:SetPos( pos.x, pos.y )
        panel:SetAlpha( 255 * Lerp( fraction, anim.StartAlpha, anim.EndAlpha ) )
    end

    local function FramePerformLayout( self, w )
        local padding = dimensions.framePadding
        local buttonSize = dimensions.frameButtonSize

        self.btnClose:SetSize( buttonSize, buttonSize )
        self.btnClose:SetPos( w - self.btnClose:GetWide() - padding, padding )

        local iconMargin = 0

        if IsValid( self.imgIcon ) then
            local iconSize = buttonSize * 0.6

            self.imgIcon:SetPos( padding, padding + ( buttonSize * 0.5 ) - ( iconSize * 0.5 ) )
            self.imgIcon:SetSize( iconSize, iconSize )

            iconMargin = iconSize + padding * 0.5
        end

        self.lblTitle:SetPos( padding + iconMargin, padding )
        self.lblTitle:SetSize( w - ( padding * 2 ) - iconMargin, buttonSize )
    end

    ClassFunctions["DFrame"] = {
        Prepare = function( self )
            self._OriginalClose = self.Close
            self.PerformLayout = FramePerformLayout

            StyledTheme.Apply( self.btnClose )
            StyledTheme.Apply( self.lblTitle )

            local padding = dimensions.framePadding
            local buttonSize = dimensions.frameButtonSize

            self:DockPadding( padding, buttonSize + padding * 2, padding, padding )
            self.btnClose:SetText( "X" )

            if IsValid( self.btnMaxim ) then
                self.btnMaxim:Remove()
            end

            if IsValid( self.btnMinim ) then
                self.btnMinim:Remove()
            end

            local anim = self:NewAnimation( 0.4, 0, 0.25 )
            anim.StartOffset = -80
            anim.EndOffset = 0
            anim.StartAlpha = 0
            anim.EndAlpha = 1
            anim.Think = FrameSlideAnim
        end,

        Close = function( self )
            self:SetMouseInputEnabled( false )
            self:SetKeyboardInputEnabled( false )

            if self.OnStartClosing then
                self.OnStartClosing()
            end

            local anim = self:NewAnimation( 0.2, 0, 0.5, function()
                self:_OriginalClose()
            end )

            anim.StartOffset = 0
            anim.EndOffset = -80
            anim.StartAlpha = 1
            anim.EndAlpha = 0
            anim.Think = FrameSlideAnim
        end,

        Paint = function( self, w, h )
            if self.m_bBackgroundBlur then
                Derma_DrawBackgroundBlur( self, self.m_fCreateTime )
            else
                StyledTheme.BlurPanel( self )
            end

            DrawRect( 0, 0, w, h, colors.panelBackground, self:GetAlpha() / 255 )
        end
    }
end

--[[
    Utility functions to create frequently used panels.
]]
do
    local colors = StyledTheme.colors
    local dimensions = StyledTheme.dimensions

    function StyledTheme.CreateFormHeader( parent, text, mtop, mbottom )
        mtop = mtop or dimensions.formSeparator
        mbottom = mbottom or dimensions.formSeparator

        local panel = vgui.Create( "DPanel", parent )
        panel:SetTall( dimensions.headerHeight )
        panel:Dock( TOP )
        panel:DockMargin( 0, mtop, 0, mbottom )
        panel:SetBackgroundColor( colors.scrollBackground )

        StyledTheme.Apply( panel )

        local label = vgui.Create( "DLabel", panel )
        label:SetText( text )
        label:SetContentAlignment( 5 )
        label:SizeToContents()
        label:Dock( FILL )

        StyledTheme.Apply( label )

        return panel
    end

    function StyledTheme.CreateFormLabel( parent, text )
        local label = vgui.Create( "DLabel", parent )
        label:Dock( TOP )
        label:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )
        label:SetText( text )
        label:SetTall( dimensions.buttonHeight )

        StyledTheme.Apply( label )

        return label
    end

    function StyledTheme.CreateFormButton( parent, label, callback )
        local button = vgui.Create( "DButton", parent )
        button:SetText( label )
        button:Dock( TOP )
        button:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )
        button.DoClick = callback

        StyledTheme.Apply( button )

        return button
    end

    function StyledTheme.CreateFormToggle( parent, label, isChecked, callback )
        local button = vgui.Create( "DButton", parent )
        button:SetIcon( isChecked and "icon16/accept.png" or "icon16/cancel.png" )
        button:SetText( label )
        button:Dock( TOP )
        button:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )
        button.isToggle = true
        button.isChecked = isChecked

        StyledTheme.Apply( button )

        button.SetChecked = function( s, value )
            value = value == true
            s.isChecked = value
            button:SetIcon( value and "icon16/accept.png" or "icon16/cancel.png" )
            callback( value )
        end

        button.DoClick = function( s )
            s:SetChecked( not s.isChecked )
        end

        return button
    end

    function StyledTheme.CreateFormSlider( parent, label, default, min, max, decimals, callback )
        local slider = vgui.Create( "DNumSlider", parent )
        slider:SetText( label )
        slider:SetMin( min )
        slider:SetMax( max )
        slider:SetValue( default )
        slider:SetDecimals( decimals )
        slider:Dock( TOP )
        slider:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )

        slider.PerformLayout = function( s )
            s.Label:SetWide( dimensions.formLabelWidth )
        end

        StyledTheme.Apply( slider )

        slider.OnValueChanged = function( _, value )
            callback( decimals == 0 and math.floor( value ) or math.Round( value, decimals ) )
        end

        return slider
    end

    function StyledTheme.CreateFormCombo( parent, text, options, defaultIndex, callback )
        local panel = vgui.Create( "DPanel", parent )
        panel:SetTall( dimensions.buttonHeight )
        panel:SetPaintBackground( false )
        panel:Dock( TOP )
        panel:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )

        local label = vgui.Create( "DLabel", panel )
        label:Dock( LEFT )
        label:DockMargin( 0, 0, 0, 0 )
        label:SetText( text )
        label:SetWide( dimensions.formLabelWidth )

        StyledTheme.Apply( label )

        local combo = vgui.Create( "DComboBox", panel )
        combo:Dock( FILL )
        combo:SetSortItems( false )

        for _, v in ipairs( options ) do
            combo:AddChoice( v )
        end

        if defaultIndex then
            combo:ChooseOptionID( defaultIndex )
        end

        StyledTheme.Apply( combo )

        combo.OnSelect = function( _, index )
            callback( index )
        end
    end

    function StyledTheme.CreateFormBinder( parent, text, defaultKey )
        local panel = vgui.Create( "DPanel", parent )
        panel:SetTall( dimensions.buttonHeight )
        panel:SetPaintBackground( false )
        panel:Dock( TOP )
        panel:DockMargin( dimensions.formPadding, 0, dimensions.formPadding, dimensions.formSeparator )

        local label = vgui.Create( "DLabel", panel )
        label:Dock( LEFT )
        label:DockMargin( 0, 0, 0, 0 )
        label:SetText( text )
        label:SetWide( dimensions.formLabelWidth )

        StyledTheme.Apply( label )

        local binder = vgui.Create( "DBinder", panel )
        binder:SetValue( defaultKey or KEY_NONE )
        binder:Dock( FILL )

        StyledTheme.Apply( binder )

        return binder
    end
end

--[[
    Custom tabbed frame
]]
do
    local colors = StyledTheme.colors
    local dimensions = StyledTheme.dimensions

    local TAB_BUTTON = {}

    AccessorFunc( TAB_BUTTON, "iconPath", "Icon", FORCE_STRING )

    function TAB_BUTTON:Init()
        self:SetCursor( "hand" )
        self:SetIcon( "icon16/bricks.png" )

        self.isSelected = false
        self.notificationCount = 0
        self.animHover = 0
    end

    function TAB_BUTTON:OnMousePressed( keyCode )
        if keyCode == MOUSE_LEFT then
            self:GetParent():GetParent():SetActiveTab( self.tab )
        end
    end

    local Lerp = Lerp
    local FrameTime = FrameTime
    local DrawRect = StyledTheme.DrawRect
    local DrawIcon = StyledTheme.DrawIcon

    local COLOR_INDICATOR = Color( 200, 0, 0, 255 )

    function TAB_BUTTON:Paint( w, h )
        self.animHover = Lerp( FrameTime() * 10, self.animHover, self:IsHovered() and 1 or 0 )

        DrawRect( 0, 0, w, h, colors.buttonBorder )
        DrawRect( 1, 1, w - 2, h - 2, colors.panelBackground )
        DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )

        if self.isSelected then
            DrawRect( 1, 1, w - 2, h - 2, colors.buttonPress )
        end

        local iconSize = math.floor( math.max( w, h ) * 0.5 )
        DrawIcon( self.iconPath, ( w * 0.5 ) - ( iconSize * 0.5 ), ( h * 0.5 ) - ( iconSize * 0.5 ), iconSize, iconSize )

        if self.notificationCount > 0 then
            local size = dimensions.indicatorSize
            local margin = math.floor( h * 0.05 )
            local x = w - size - margin
            local y = h - size - margin

            draw.RoundedBox( size * 0.5, x, y, size, size, COLOR_INDICATOR )
            draw.SimpleText( self.notificationCount, "StyledTheme_Tiny", x + size * 0.5, y + size * 0.5, colors.buttonText, 1, 1 )
        end
    end

    vgui.Register( "Styled_TabButton", TAB_BUTTON, "DPanel" )

    local TABBED_FRAME = {}
    local ScaleSize = StyledTheme.ScaleSize

    function TABBED_FRAME:Init()
        StyledTheme.Apply( self, "DFrame" )

        local w = ScaleSize( 850 )
        local h = ScaleSize( 600 )

        self:SetSize( w, h )
        self:SetSizable( true )
        self:SetDraggable( true )
        self:SetDeleteOnClose( true )
        self:SetScreenLock( true )
        self:SetMinWidth( w )
        self:SetMinHeight( h )

        self.tabList = vgui.Create( "DPanel", self )
        self.tabList:SetWide( ScaleSize( 64 ) )
        self.tabList:Dock( LEFT )
        self.tabList:DockPadding( 0, 0, 0, 0 )
        self.tabList:SetPaintBackground( false )
        --StyledTheme.Apply( self.tabList )

        self.contentContainer = vgui.Create( "DPanel", self )
        self.contentContainer:Dock( FILL )
        self.contentContainer:DockMargin( ScaleSize( 4 ), 0, 0, 0 )
        self.contentContainer:DockPadding( 0, 0, 0, 0 )
        self.contentContainer:SetPaintBackground( false )

        self.tabs = {}
    end

    function TABBED_FRAME:AddTab( icon, tooltip )
        local tab = {}

        tab.button = vgui.Create( "Styled_TabButton", self.tabList )
        tab.button:SetIcon( icon )
        tab.button:SetTall( ScaleSize( 64 ) )
        tab.button:SetTooltip( tooltip )
        tab.button:Dock( TOP )
        tab.button:DockMargin( 0, 0, 0, 2 )
        tab.button.tab = tab

        tab.panel = vgui.Create( "DScrollPanel", self.contentContainer )
        tab.panel:Dock( FILL )
        tab.panel:DockMargin( 0, 0, 0, 0 )
        tab.panel:DockPadding( 0, 0, 0, 0 )
        tab.panel:SetPaintBackground( false )
        tab.panel:SetVisible( false )

        StyledTheme.Apply( tab.panel )

        self.tabs[#self.tabs + 1] = tab

        if #self.tabs == 1 then
            self:SetActiveTab( tab )
        end

        return tab.panel
    end

    function TABBED_FRAME:SetActiveTab( tab )
        for i, t in ipairs( self.tabs ) do
            local isThisOne = t == tab

            t.button.isSelected = isThisOne
            t.panel:SetVisible( isThisOne )

            if isThisOne then
                self.lastTabIndex = i
            end
        end
    end

    function TABBED_FRAME:SetActiveTabByIndex( index )
        if self.tabs[index] then
            self:SetActiveTab( self.tabs[index] )
        end
    end

    function TABBED_FRAME:SetTabNotificationCountByIndex( index, count )
        if self.tabs[index] then
            self.tabs[index].button.notificationCount = count
        end
    end

    vgui.Register( "Styled_TabbedFrame", TABBED_FRAME, "DFrame" )
end

--[[
    Custom file open/save frame
]]
do
    function StyledTheme.CreateFileBrowser()
        local frame = vgui.Create( "Styled_FileBrowser" )
        frame:Center()
        frame:MakePopup()

        return frame
    end

    local FILE_ICONS = {
        ["default"] = "icon16/page_white.png",
        ["lua"] = "icon16/page_white_code.png",

        ["mdl"] = "icon16/page_white_powerpoint.png",
        ["vtf"] = "icon16/page_white_swoosh.png",
        ["vmt"] = "icon16/page_white_code.png",

        ["png"] = "icon16/page_white_picture.png",
        ["jpg"] = "icon16/page_white_picture.png",
        ["gif"] = "icon16/page_white_picture.png",

        ["txt"] = "icon16/page_white_text.png",
        ["md"] = "icon16/page_white_text.png",

        ["conf"] = "icon16/page_white_gear.png",
        ["ini"] = "icon16/page_white_gear.png",
        ["properties"] = "icon16/page_white_gear.png",

        ["wav"] = "icon16/sound.png",
        ["ogg"] = "icon16/sound.png",
        ["mp3"] = "icon16/sound.png",
    }

    local L = StyledTheme.GetUpperLanguagePhrase
    local ScaleSize = StyledTheme.ScaleSize
    local BROWSER = {}

    function BROWSER:Init()
        local w, h = ScaleSize( 800 ), ScaleSize( 600 )

        self:SetIcon( "icon16/folder.png" )
        self:SetTitle( L"file" )
        self:SetSize( w, h )
        self:SetMinWidth( w )
        self:SetMinHeight( h )
        self:SetSizable( true )
        self:SetDraggable( true )
        self:SetDeleteOnClose( true )
        self:SetScreenLock( true )
        self:SetBackgroundBlur( true )

        local separator = ScaleSize( 8 )

        self.panelHeader = vgui.Create( "DPanel", self )
        self.panelHeader:SetTall( ScaleSize( 40 ) )
        self.panelHeader:Dock( TOP )
        self.panelHeader:DockMargin( 0, 0, 0, separator )
        self.panelHeader:DockPadding( separator, separator, separator, separator )
        self.panelHeader:SetBackgroundColor( StyledTheme.colors.accent )

        self.panelHeader.PerformLayout = function( s )
            local extraNavWidth = ScaleSize( 10 )

            for _, child in ipairs( s:GetChildren() ) do
                child:SizeToContentsX( extraNavWidth )
            end
        end

        self.scrollFiles = vgui.Create( "DScrollPanel", self )
        self.scrollFiles:Dock( FILL )

        self.panelOptions = vgui.Create( "DPanel", self )
        self.panelOptions:SetTall( ScaleSize( 50 ) )
        self.panelOptions:Dock( BOTTOM )
        self.panelOptions:DockMargin( 0, separator, 0, 0 )
        self.panelOptions:DockPadding( separator, separator, separator, separator )
        self.panelOptions:SetPaintBackground( false )

        self.buttonCancel = vgui.Create( "DButton", self.panelOptions )
        self.buttonCancel:SetText( L"cancel" )
        self.buttonCancel:SizeToContentsX( ScaleSize( 60 ) )
        self.buttonCancel:Dock( RIGHT )
        self.buttonCancel:DockMargin( separator, 0, 0, 0 )

        self.buttonCancel.DoClick = function()
            self:Close()
        end

        self:SetBasePath( "/" )
        self:NavigateTo( "/" )
        self:SetExtensionFilter( nil )

        self.OnConfirmPath = function( _path ) end

        StyledTheme.Apply( self, "DFrame" )
        StyledTheme.Apply( self.panelHeader )
        StyledTheme.Apply( self.scrollFiles )
        StyledTheme.Apply( self.buttonCancel )
    end

    function BROWSER:EnableSaveMode( defaultFileName )
        self.saveMode = true
        self.updateFiles = true

        self.entryName = vgui.Create( "DTextEntry", self.panelOptions )
        self.entryName:SetText( defaultFileName or "untitled.txt" )
        self.entryName:Dock( FILL )

        local DoSave = function()
            local path = self.basePath .. table.concat( self.currentNavigation, "/" ) .. "/" .. self.entryName:GetValue()
            self.OnConfirmPath( self:NormalizePath( path ) )
            self:Close()
        end

        self.entryName.OnEnter = DoSave
        StyledTheme.Apply( self.entryName )

        self.buttonSave = vgui.Create( "DButton", self.panelOptions )
        self.buttonSave:SetText( L"preset.okay" )
        self.buttonSave:SizeToContentsX( ScaleSize( 60 ) )
        self.buttonSave:Dock( RIGHT )
        self.buttonSave:DockMargin( ScaleSize( 8 ), 0, 0, 0 )
        self.buttonSave.DoClick = DoSave

        StyledTheme.Apply( self.buttonSave )
    end

    function BROWSER:SetBasePath( path )
        self.basePath = path
        self.updateFiles = true
    end

    function BROWSER:SetExtensionFilter( extensionFilter )
        if extensionFilter then
            local filter = {}

            for _, ext in ipairs( extensionFilter ) do
                filter[ext] = true
            end

            self.extensionFilter = filter
        else
            self.extensionFilter = nil
        end

        self.updateFiles = true
    end

    function BROWSER:NormalizePath( path )
        path = string.gsub( path, "/+", "/" )

        if path:sub( 1, 1 ) == "/" then
            path = path:sub( 2 )
        end

        return path
    end

    function BROWSER:NavigateTo( dir )
        dir = self:NormalizePath( dir )

        local nav = { "/" }

        for _, part in ipairs( string.Explode( "/", dir, false ) ) do
            if part ~= "" then
                nav[#nav + 1] = part
            end
        end

        self.updateFiles = true
        self.currentNavigation = nav
    end

    local BaseClass = baseclass.Get( "DFrame" )

    function BROWSER:Think()
        BaseClass.Think( self )

        if not self.updateFiles then return end

        self.updateFiles = false

        -- Update navigation header
        self.panelHeader:Clear()

        local OnClickNav = function( s )
            self:NavigateTo( s._path )
        end

        local pathSoFar = ""
        local separator = ScaleSize( 4 )

        for i, piece in ipairs( self.currentNavigation ) do
            pathSoFar = pathSoFar .. "/" .. piece

            if i == 1 then
                piece = self.basePath
            end

            local item = vgui.Create( "DButton", self.panelHeader )
            item:SetText( piece )
            item:Dock( LEFT )
            item:DockMargin( 0, 0, separator, 0 )
            item.DoClick = OnClickNav
            item._path = pathSoFar

            StyledTheme.Apply( item )
        end

        -- Update file list
        self.scrollFiles:Clear()

        local currentDir = self:NormalizePath( table.concat( self.currentNavigation, "/" ) .. "/" )
        local normalizedDir = self:NormalizePath( self.basePath .. currentDir .. "*" )
        local files, dirs = file.Find( normalizedDir, "GAME", "nameasc" )

        if #self.currentNavigation > 1 then
            local itemUpDir = self.scrollFiles:Add( "Styled_FileBrowserItem" )
            itemUpDir:SetItemName( ".." )
            itemUpDir:SetIconPath( "icon16/arrow_up.png" )
            itemUpDir:SetTall( 28 )
            itemUpDir:Dock( TOP )
            itemUpDir:DockMargin( 0, separator, 0, 0 )
            itemUpDir.onClick = OnClickNav

            local upNavigation = table.Copy( self.currentNavigation )
            table.remove( upNavigation, #upNavigation )
            itemUpDir._path = self:NormalizePath( table.concat( upNavigation, "/" ) .. "/" )
        end

        if dirs then
            for _, name in ipairs( dirs ) do
                local item = self.scrollFiles:Add( "Styled_FileBrowserItem" )
                item:SetItemName( name )
                item:SetTall( 28 )
                item:Dock( TOP )
                item:DockMargin( 0, separator, 0, 0 )
                item.onClick = OnClickNav
                item._path = currentDir .. name
            end
        end

        local OnClickOpen = function( s )
            if self.saveMode then
                self.entryName:SetText( s:GetItemName() )
                return
            end

            local path = self:NormalizePath( s._path )

            self:Close()
            self.OnConfirmPath( self:NormalizePath( self.basePath .. path ) )
        end

        if files then
            local filter = self.extensionFilter
            local itemHeight = ScaleSize( 40 )

            for _, name in ipairs( files ) do
                local ext = string.GetExtensionFromFilename( name )

                if filter == nil or filter[ext] then
                    local item = self.scrollFiles:Add( "Styled_FileBrowserItem" )
                    item:SetItemName( name )
                    item:SetIconPath( FILE_ICONS[ext] or FILE_ICONS.default )
                    item:SetTall( itemHeight )
                    item:Dock( TOP )
                    item:DockMargin( 0, separator, 0, 0 )

                    item.onClick = OnClickOpen
                    item._path = currentDir .. name
                end
            end
        end
    end

    vgui.Register( "Styled_FileBrowser", BROWSER, "DFrame" )

    local ITEM = {}

    AccessorFunc( ITEM, "itemName", "ItemName", FORCE_STRING )
    AccessorFunc( ITEM, "iconPath", "IconPath", FORCE_STRING )
    AccessorFunc( ITEM, "iconScale", "IconScale", FORCE_NUMBER )

    function ITEM:Init()
        self:SetItemName( "Item" )
        self:SetIconPath( "icon16/folder.png" )
        self:SetIconScale( 0.7 )

        self.isPressed = false
        self.animHover = 0
        self.animPress = 0
    end

    function ITEM:OnMousePressed( keyCode )
        if keyCode == MOUSE_LEFT then
            self.isPressed = true
        end
    end

    function ITEM:OnMouseReleased( keyCode )
        if keyCode == MOUSE_LEFT and self.isPressed and self.onClick then
            self:onClick()
        end

        self.isPressed = false
    end

    function ITEM:OnCursorExited()
        self.isPressed = false
    end

    local Lerp = Lerp
    local FrameTime = FrameTime

    function ITEM:Think()
        local dt = FrameTime()

        self.animHover = Lerp( dt * 10, self.animHover, self:IsHovered() and 1 or 0 )
        self.animPress = Lerp( dt * 20, self.animPress, self.isPressed and 1 or 0 )
    end

    local Floor = math.floor
    local SimpleText = draw.SimpleText
    local DrawIcon = StyledTheme.DrawIcon
    local DrawRect = StyledTheme.DrawRect
    local colors = StyledTheme.colors

    function ITEM:Paint( w, h )
        DrawRect( 0, 0, w, h, colors.buttonBorder )
        DrawRect( 1, 1, w - 2, h - 2, colors.panelBackground )
        DrawRect( 1, 1, w - 2, h - 2, colors.buttonHover, self.animHover )
        DrawRect( 1, 1, w - 2, h - 2, colors.buttonPress, self.animPress )

        local iconSize = Floor( h * self.iconScale )

        DrawIcon( self.iconPath, h * 0.1, ( h * 0.5 ) - ( iconSize * 0.5 ), iconSize, iconSize )
        SimpleText( self.itemName, "DermaDefault", iconSize * 1.3, h * 0.5, colors.buttonText, 0, 1 )
    end

    vgui.Register( "Styled_FileBrowserItem", ITEM, "Panel" )
end
