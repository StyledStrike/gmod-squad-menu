local squad, nameDistance

function SquadMenu:RemoveMembersHUD()
    if self.membersPanel then
        self.membersPanel:Remove()
    end

    self.membersPanel = nil

    hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    hook.Remove( "PreDrawHalos", "SquadMenu.DrawHalos" )
    hook.Remove( "HUDPaint", "SquadMenu.DrawMemberTags" )
    hook.Remove( "HUDDrawTargetID", "SquadMenu.HideTargetInfo" )
end

function SquadMenu:UpdateMembersHUD()
    squad = self.mySquad

    nameDistance = self.GetNameRenderDistance()
    nameDistance = nameDistance * nameDistance

    if self.Config.showRings and self.mySquad.enableRings then
        hook.Add( "PrePlayerDraw", "SquadMenu.DrawRing", self.DrawRing )
    else
        hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    end

    if self.Config.showHalos then
        hook.Add( "PreDrawHalos", "SquadMenu.DrawHalos", self.DrawHalos )
    else
        hook.Remove( "PreDrawHalos", "SquadMenu.DrawHalos" )
    end

    hook.Add( "HUDPaint", "SquadMenu.DrawMemberTags", self.DrawMemberTags )
    hook.Add( "HUDDrawTargetID", "SquadMenu.HideTargetInfo", self.HideTargetInfo )

    if self.membersPanel then
        self.membersPanel:SetVisible( self.Config.showMembers )
        return
    end

    local panel = vgui.Create( "DPanel" )
    panel:SetVisible( self.Config.showMembers )
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

        local position = math.Clamp( SquadMenu.GetMembersPosition(), 1, 9 )
        local offset = screenH * 0.02
        local x, y

        if position == 1 or position == 4 or position == 7 then
            -- left
            x = offset

        elseif position == 2 or position == 5 or position == 8 then
            -- center
            x = ( screenW * 0.5 ) - ( w * 0.5 )
        else
            -- right
            x = screenW - w - offset
        end

        if position == 7 or position == 8 or position == 9 then
            -- top
            y = offset

        elseif position == 4 or position == 5 or position == 6 then
            -- center
            y = ( screenH * 0.5 ) - ( h * 0.5 )
        else
            -- bottom
            y = screenH - h - offset
        end

        s:SetPos( x, y )
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
    member.panel.squad = squad

    self.membersPanel:InvalidateLayout()
end

function SquadMenu:RemoveMemberFromHUD( member )
    if member.panel then
        member.panel:Remove()
        member.panel = nil
    end
end

----------

local COLORS = {
    WHITE = Color( 255, 255, 255, 255 ),
    HEALTH = Color( 94, 253, 255, 255 ),
    LOW_HEALTH = Color( 250, 20, 20, 255 ),
    BOX_BG = Color( 0, 0, 0, 200 )
}

local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local DrawOutlinedRect = surface.DrawOutlinedRect

local DrawHealthBar = function( x, y, w, h, health, armor )
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

SquadMenu.DrawHealthBar = DrawHealthBar

----------

local Clamp = math.Clamp
local SetMaterial = surface.SetMaterial
local DrawTexturedRect = surface.DrawTexturedRect
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

local AllPlayersBySteamID = SquadMenu.AllPlayersBySteamID

SquadMenu.DrawHalos = function()
    local players = AllPlayersBySteamID()
    local me = LocalPlayer()
    local i, t = 0, {}

    for _, member in ipairs( squad.members ) do
        local ply = players[member.id]

        if ply and ply ~= me then
            i = i + 1
            t[i] = ply
        end
    end

    halo.Add( t, squad.color, 2, 2, 1, true, true )
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

local DrawSimpleText = draw.SimpleText
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
        DrawHealthBar( x - 2, y + 16, boxW + 4, 4, Clamp( ply:Health() / 100, 0, 1 ), ply:Armor() / 100 )
    else
        DrawSimpleText( "*", "TargetIDSmall", pos.x, y + 14, COLORS.LOW_HEALTH, 1, 0 )
    end
end

SquadMenu.DrawMemberTags = function()
    surface.SetFont( "TargetIDSmall" )

    local origin = EyePos()
    local me = LocalPlayer()
    local players = AllPlayersBySteamID()

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
