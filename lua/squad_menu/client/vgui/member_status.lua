local IsValid = IsValid
local Clamp = math.Clamp
local RealTime = RealTime
local FrameTime = FrameTime
local Approach = math.Approach

local SetColor = surface.SetDrawColor
local SetMaterial = surface.SetMaterial
local DrawOutlinedText = draw.SimpleTextOutlined
local DrawTexturedRect = surface.DrawTexturedRect
local DrawRect = surface.DrawRect

local DrawHealthBar = SquadMenu.DrawHealthBar
local matGradient = Material( "vgui/gradient-r" )

local COLORS = {
    WHITE = Color( 255, 255, 255, 255 ),
    LOW_HEALTH = Color( 250, 20, 20, 255 ),
    OUTLINE = Color( 0, 0, 0, 255 )
}

local PANEL = {}

function PANEL:Init()
    self.avatar = vgui.Create( "AvatarImage", self )
    self:InvalidateLayout()
    self:SetPlayer()
end

function PANEL:SetPlayer( id, name )
    self.playerId = id
    self.validateTimer = 0

    self.name = SquadMenu.ValidateString( name, "", 20 )
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
        self.name = SquadMenu.ValidateString( ply:Nick(), "-", 20 )
        self.avatar:SetPlayer( ply, 64 )
    end
end

function PANEL:Paint( w, h )
    local split = h

    SetColor( self.squad.color:Unpack() )
    DrawRect( w - split, 0, split, h )

    SetColor( 0, 0, 0, 240 )
    SetMaterial( matGradient )
    DrawTexturedRect( 0, 0, w - split, h )

    local dt = FrameTime()

    self.healthAnim = Approach( self.healthAnim, self.health, dt * 2 )
    self.armorAnim = Approach( self.armorAnim, self.armor, dt )

    if self.alive then
        local barH = h * 0.2
        DrawHealthBar( 2, h - barH - 5, w - split - 6, barH, self.healthAnim, self.armorAnim )
    end

    DrawOutlinedText( self.name, "SquadMenuInfo", 2, 2 + h * 0.5,
        self.alive and COLORS.WHITE or COLORS.LOW_HEALTH, 0, self.alive and 4 or 1, 1, COLORS.OUTLINE )
end

function PANEL:PerformLayout( w, h )
    local size = h - 4

    self.avatar:SetSize( size, size )
    self.avatar:SetPos( w - size - 2, 2 )
end

vgui.Register( "Squad_MemberInfo", PANEL, "DPanel" )
