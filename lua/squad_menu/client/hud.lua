local L = SquadMenu.GetLanguageText
local DrawRing, DrawMemberInfo, HideTargetInfo

local squadColor = Color( 0, 0, 0 )
local ringWhitelist, drawDistance

function SquadMenu:RemoveMembersHUD()
    if self.membersPanel then
        self.membersPanel:Remove()
    end

    self.membersPanel = nil
    self.memberPanelsById = nil

    ringWhitelist = nil

    hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    hook.Remove( "HUDPaint", "SquadMenu.DrawMemberInfo" )
    hook.Remove( "HUDDrawTargetID", "SquadMenu.HideTargetInfo" )
end

function SquadMenu:CreateMembersHUD()
    self:RemoveMembersHUD()

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
    self.memberPanelsById = {}
end

function SquadMenu:UpdateHUDMembers( memberIds, printMessages )
    squadColor = self.mySquad.color
    ringWhitelist = {}

    drawDistance = self.GetNameRenderDistance()
    drawDistance = drawDistance * drawDistance

    if self.mySquad.enableRings then
        hook.Add( "PrePlayerDraw", "SquadMenu.DrawRing", DrawRing )
    else
        hook.Remove( "PrePlayerDraw", "SquadMenu.DrawRing" )
    end

    hook.Add( "HUDPaint", "SquadMenu.DrawMemberInfo", DrawMemberInfo )
    hook.Add( "HUDDrawTargetID", "SquadMenu.HideTargetInfo", HideTargetInfo )

    local localPlayer = LocalPlayer()
    local players = SquadMenu.AllPlayersBySteamID()
    local panelsById = self.memberPanelsById
    local membersById = {}

    -- Find the player entities and only create panels for new members
    local ply

    for _, id in ipairs( memberIds ) do
        ply = players[id]
        membersById[id] = true

        if ply and ply ~= localPlayer then
            ringWhitelist[ply] = true
        end

        if ply and not panelsById[id] then
            panelsById[id] = vgui.Create( "Squad_MemberInfo", self.membersPanel )
            panelsById[id]:SetPlayer( ply )

            if printMessages then
                self.ChatPrint( string.format( L"member_joined", ply:Nick() ) )
            end
        end
    end

    -- Cleanup players that exist on panelsById but not on membersById
    for id, panel in pairs( panelsById ) do
        if not membersById[id] then
            panel:Remove()
            panelsById[id] = nil

            if printMessages and players[id] then
                self.ChatPrint( string.format( L"member_left", players[id]:Nick() ) )
            end
        end
    end

    self.membersPanel:InvalidateLayout()
end

----------

local IsValid = IsValid
local FrameTime = FrameTime
local Approach = math.Approach
local Clamp = math.Clamp

local SetColor = surface.SetDrawColor
local SetMaterial = surface.SetMaterial
local DrawRect = surface.DrawRect
local DrawOutlinedRect = surface.DrawOutlinedRect
local DrawTexturedRect = surface.DrawTexturedRect
local DrawSimpleText = draw.SimpleText

local matGradient = Material( "vgui/gradient-r" )
local colorHealth = Color( 94, 253, 255, 255 )
local colorLow = Color( 250, 20, 20, 255 )
local colorName = Color( 255, 255, 255, 255 )

local function DrawBar( x, y, w, h, health, armor, heal )
    if armor > 0 then
        SetColor( 255, 255, 255, 255 )
        DrawOutlinedRect( x - 1, y - 1, ( w + 2 ) * armor, h + 2, 1 )
    end

    SetColor( 20, 20, 20, 255 )
    DrawRect( x, y, w, h )

    if heal > 0 then
        SetColor( 0, 255, 0, 255 * heal )
        DrawOutlinedRect( x - 1, y - 1, w + 2, h + 2, 1 )
    end

    x, y = x + 1, y + 1
    w, h = w - 2, h - 2

    local color = health < 0.3 and colorLow or colorHealth

    SetColor( color:Unpack() )
    DrawRect( x, y, w * health, h )
end

local PANEL = {}

function PANEL:Init()
    self.avatar = vgui.Create( "AvatarImage", self )

    self.nick = ""
    self.health = 1
    self.armor = 0
    self.alive = true

    self.lastHealth = 0
    self.healthAnim = 0
    self.armorAnim = 0
    self.healAnim = 0
end

function PANEL:SetPlayer( ply )
    self.ply = ply
    self.nick = ply:Nick()
    self.avatar:SetPlayer( ply, 64 )
    self:InvalidateLayout()
end

function PANEL:Think()
    if not IsValid( self.ply ) then return end

    local health = self.ply:Health()
    local diff = health - self.lastHealth

    self.lastHealth = health
    self.health = Clamp( health / 100, 0, 1 )
    self.armor = Clamp( self.ply:Armor() / 100, 0, 1 )
    self.alive = self.ply:Alive()

    if diff > 0 then
        self.healAnim = 1
    end
end

function PANEL:Paint( w, h )
    local split = h

    SetColor( squadColor:Unpack() )
    DrawRect( w - split, 0, split, h )

    SetColor( 0, 0, 0, 240 )
    SetMaterial( matGradient )
    DrawTexturedRect( 0, 0, w - split, h )

    local dt = FrameTime()

    self.healthAnim = Approach( self.healthAnim, self.health, dt * 2 )
    self.armorAnim = Approach( self.armorAnim, self.armor, dt )
    self.healAnim = Approach( self.healAnim, 0, dt )

    if self.alive then
        local barH = h * 0.2
        DrawBar( 2, ( h * 0.5 ) + barH * 0.75, w - split - 4, barH, self.healthAnim, self.armorAnim, self.healAnim )
    end

    DrawSimpleText( self.nick, "TargetIDSmall", 2, h * 0.5,
        self.alive and colorName or colorLow, 0, self.alive and 4 or 1, 1 )
end

function PANEL:PerformLayout( w, h )
    local size = h - 4

    self.avatar:SetSize( size, size )
    self.avatar:SetPos( w - size - 2, 2 )
end

vgui.Register( "Squad_MemberInfo", PANEL, "DPanel" )

----------

local Start3D2D = cam.Start3D2D
local End3D2D = cam.End3D2D

local ringAngle = Angle( 0, 0, 0 )
local ringMat = Material( "squad_menu/ring.png" )

DrawRing = function( ply )
    if not ringWhitelist[ply] then return end

    Start3D2D( ply:GetPos(), ringAngle, 0.08 )

    SetMaterial( ringMat )
    SetColor( squadColor:Unpack() )
    DrawTexturedRect( -256, -256, 512, 512 )

    End3D2D()
end

----------

local GetTextSize = surface.GetTextSize
local SetAlphaMultiplier = surface.SetAlphaMultiplier
local boxColor = Color( 0, 0, 0, 200 )

DrawMemberInfo = function()
    surface.SetFont( "TargetIDSmall" )

    local myPos = EyePos()
    local health, text, isAlive, dist
    local pos, boxW, x, y, h

    for ply, _ in pairs( ringWhitelist ) do
        if IsValid( ply ) then
            dist = myPos:DistToSqr( ply:EyePos() )
            if dist > drawDistance then continue end

            SetAlphaMultiplier( 1 - dist / drawDistance )

            health = ply:Health()
            text = ply:Nick()
            isAlive = ply:Alive()

            pos = ply:EyePos():ToScreen()
            boxW = GetTextSize( text )

            h = isAlive and 18 or 28
            x = pos.x - boxW * 0.5
            y = pos.y - 48

            SetColor( boxColor:Unpack() )
            DrawRect( x - 2, y, boxW + 4, h )

            DrawSimpleText( text, "TargetIDSmall", pos.x, y, colorName, 1, 0 )

            if isAlive then
                DrawBar( x - 2, y + 16, boxW + 4, 4, Clamp( health / 100, 0, 1 ), ply:Armor() / 100, 0 )
            else
                DrawSimpleText( "*", "TargetIDSmall", pos.x, y + 14, colorLow, 1, 0 )
            end
        end
    end

    SetAlphaMultiplier( 1 )
end

----------

local LocalPlayer = LocalPlayer

HideTargetInfo = function()
    local trace = util.TraceLine( util.GetPlayerTrace( LocalPlayer() ) )
    if not trace.Hit or not trace.HitNonWorld then return end

    local ply = trace.Entity
    if not ply:IsPlayer() then return end

    if ringWhitelist[ply] and EyePos():DistToSqr( ply:EyePos() ) < drawDistance then
        return false
    end
end
