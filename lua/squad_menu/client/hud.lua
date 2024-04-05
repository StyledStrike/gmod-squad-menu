local squad, nameDistance

local COLORS = {
    WHITE = Color( 255, 255, 255, 255 ),
    HEALTH = Color( 94, 253, 255, 255 ),
    LOW_HEALTH = Color( 250, 20, 20, 255 ),
    BOX_BG = Color( 0, 0, 0, 200 )
}

function SquadMenu:RemoveMembersHUD()
    if self.membersPanel then
        self.membersPanel:Remove()
    end

    self.membersPanel = nil

    hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    hook.Remove( "HUDPaint", "SquadMenu.DrawMemberTags" )
    hook.Remove( "HUDDrawTargetID", "SquadMenu.HideTargetInfo" )
end

function SquadMenu:UpdateMembersHUD()
    squad = self.mySquad

    nameDistance = self.GetNameRenderDistance()
    nameDistance = nameDistance * nameDistance

    if self.mySquad.enableRings then
        hook.Add( "PrePlayerDraw", "SquadMenu.DrawRing", self.DrawRing )
    else
        hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    end

    hook.Add( "HUDPaint", "SquadMenu.DrawMemberTags", self.DrawMemberTags )
    hook.Add( "HUDDrawTargetID", "SquadMenu.HideTargetInfo", self.HideTargetInfo )

    if self.membersPanel then return end

    local panel = vgui.Create( "DPanel" )
    panel:SetPaintBackground( false )
    panel:ParentToHUD()
    panel._OriginalInvalidateLayout = panel.InvalidateLayout

    panel.InvalidateLayout = function( s, layoutNow )
        local screenW, screenH = ScrW(), ScrH()

        local childCount = #s:GetChildren()
        local childH = math.Round( screenH * 0.04 )
        local childOffset = math.max( 1, math.Round( screenH * 0.002 ) )

        local w = screenH * 0.22
        local h = ( childH + childOffset ) * childCount

        s.childH = childH
        s.childOffset = childOffset

        s:SetSize( w, h )
        s:SetPos( screenW - w - ( screenH * 0.02 ), ( screenH * 0.5 ) - ( h * 0.5 ) )
        s:_OriginalInvalidateLayout( layoutNow )
    end

    panel.PerformLayout = function( s, w )
        local children = s:GetChildren()
        if #children == 0 then return end

        local offset = s.childOffset or 1
        local height = s.childH or 24
        local y = 0

        for _, p in ipairs( children ) do
            p:SetSize( w, height )
            p:SetPos( 0, y )

            y = y + height + offset
        end
    end

    self.membersPanel = panel
end

function SquadMenu:AddMemberToHUD( member )
    member.panel = vgui.Create( "Squad_MemberInfo", self.membersPanel )
    member.panel:SetPlayer( member.id, member.name )

    self.membersPanel:InvalidateLayout()
end

function SquadMenu:RemoveMemberFromHUD( member )
    if member.panel then
        member.panel:Remove()
        member.panel = nil
    end
end

----------

local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local DrawOutlinedRect = surface.DrawOutlinedRect

local function DrawBar( x, y, w, h, health, armor )
    if armor > 0 then
        SetColor( 255, 255, 255, 255 )
        DrawOutlinedRect( x - 1, y - 1, ( w + 2 ) * armor, h + 2, 1 )
    end

    SetColor( 20, 20, 20, 255 )
    DrawRect( x, y, w, h )

    x, y = x + 1, y + 1
    w, h = w - 2, h - 2

    local color = health < 0.3 and COLORS.LOW_HEALTH or COLORS.HEALTH

    SetColor( color:Unpack() )
    DrawRect( x, y, w * health, h )
end

----------

local IsValid = IsValid
local Clamp = math.Clamp
local RealTime = RealTime
local FrameTime = FrameTime
local Approach = math.Approach

local SetMaterial = surface.SetMaterial
local DrawSimpleText = draw.SimpleText
local DrawTexturedRect = surface.DrawTexturedRect

local matGradient = Material( "vgui/gradient-r" )

local PANEL = {}

function PANEL:Init()
    self.avatar = vgui.Create( "AvatarImage", self )
    self:InvalidateLayout()
    self:SetPlayer()
end

function PANEL:SetPlayer( id, name )
    self.playerId = id
    self.validateTimer = 0

    self.name = name or ""
    self.health = 1
    self.armor = 0
    self.alive = true

    self.healthAnim = 0
    self.armorAnim = 0
end

function PANEL:Think()
    if IsValid( self.ply ) then
        self.health = Clamp( self.ply:Health() / 100, 0, 1 )
        self.armor = Clamp( self.ply:Armor() / 100, 0, 1 )
        self.alive = self.ply:Alive()

        return
    end

    -- Keep trying to get the player entity periodically
    if RealTime() < self.validateTimer then return end

    self.validateTimer = RealTime() + 1

    local ply = player.GetBySteamID( self.playerId )

    if ply then
        self.ply = ply
        self.name = ply:Nick()
        self.avatar:SetPlayer( ply, 64 )
    end
end

function PANEL:Paint( w, h )
    local split = h

    SetColor( squad.color:Unpack() )
    DrawRect( w - split, 0, split, h )

    SetColor( 0, 0, 0, 240 )
    SetMaterial( matGradient )
    DrawTexturedRect( 0, 0, w - split, h )

    local dt = FrameTime()

    self.healthAnim = Approach( self.healthAnim, self.health, dt * 2 )
    self.armorAnim = Approach( self.armorAnim, self.armor, dt )

    if self.alive then
        local barH = h * 0.2
        DrawBar( 2, h - barH - 6, w - split - 6, barH, self.healthAnim, self.armorAnim )
    end

    DrawSimpleText( self.name, "TargetIDSmall", 2, 2 + h * 0.5,
        self.alive and COLORS.WHITE or COLORS.LOW_HEALTH, 0, self.alive and 4 or 1, 1 )
end

function PANEL:PerformLayout( w, h )
    local size = h - 4

    self.avatar:SetSize( size, size )
    self.avatar:SetPos( w - size - 2, 2 )
end

vgui.Register( "Squad_MemberInfo", PANEL, "DPanel" )

----------

local LocalPlayer = LocalPlayer

do
    local Start3D2D = cam.Start3D2D
    local End3D2D = cam.End3D2D

    local ringMaxDist = 3000 * 3000
    local ringAngle = Angle( 0, 0, 0 )
    local ringOffset = Vector( 0, 0, 5 )
    local ringMat = Material( "squad_menu/ring.png" )

    SquadMenu.DrawRing = function( ply )
        if ply == LocalPlayer() then return end
        if not squad.membersById[ply:SteamID()] then return end

        local pos = ply:GetPos()
        local mult = Clamp( pos:DistToSqr( EyePos() ) / ringMaxDist, 0, 1 )
        local size = 300 + 1000 * mult

        Start3D2D( pos + ringOffset * mult, ringAngle, 0.08 )

        SetMaterial( ringMat )
        SetColor( squad.color:Unpack() )
        DrawTexturedRect( -size * 0.5, -size * 0.5, size, size )

        End3D2D()
    end
end

----------

SquadMenu.HideTargetInfo = function()
    local trace = util.TraceLine( util.GetPlayerTrace( LocalPlayer() ) )
    if not trace.Hit or not trace.HitNonWorld then return end

    local ply = trace.Entity
    if not ply:IsPlayer() then return end

    if squad.membersById[ply:SteamID()] and EyePos():DistToSqr( ply:EyePos() ) < nameDistance then
        return false
    end
end

----------

local GetTextSize = surface.GetTextSize
local SetAlphaMultiplier = surface.SetAlphaMultiplier

local function DrawTag( ply )
    local text = ply:Nick()
    local isAlive = ply:Alive()

    local pos = ply:EyePos():ToScreen()
    local boxW = GetTextSize( text )

    local h = isAlive and 18 or 28
    local x = pos.x - boxW * 0.5
    local y = pos.y - 48

    SetColor( COLORS.BOX_BG:Unpack() )
    DrawRect( x - 2, y, boxW + 4, h )

    DrawSimpleText( text, "TargetIDSmall", pos.x, y, COLORS.WHITE, 1, 0 )

    if isAlive then
        DrawBar( x - 2, y + 16, boxW + 4, 4, Clamp( ply:Health() / 100, 0, 1 ), ply:Armor() / 100 )
    else
        DrawSimpleText( "*", "TargetIDSmall", pos.x, y + 14, COLORS.LOW_HEALTH, 1, 0 )
    end
end

SquadMenu.DrawMemberTags = function()
    surface.SetFont( "TargetIDSmall" )

    local origin = EyePos()
    local me = LocalPlayer()
    local players = SquadMenu.AllPlayersBySteamID()

    for _, member in ipairs( squad.members ) do
        local ply = players[member.id]

        if ply and ply ~= me then
            dist = origin:DistToSqr( ply:EyePos() )

            if dist < nameDistance then
                SetAlphaMultiplier( 1 - dist / nameDistance )
                DrawTag( ply )
            end
        end
    end

    SetAlphaMultiplier( 1 )
end
