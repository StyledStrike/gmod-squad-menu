local Config = SquadMenu.Config or {}

SquadMenu.Config = Config

function Config:Reset()
    self.showMembers = true
    self.showRings = true
    self.showHalos = false
    self.enableSounds = true

    self.nameDistance = 3000
    self.haloDistance = 8000
    self.pingKey = KEY_B
end

function Config:Load()
    self:Reset()

    local data = file.Read( SquadMenu.DATA_FILE, "DATA" )
    if not data then return end

    data = SquadMenu.JSONToTable( data )

    self.showMembers = data.showMembers == true
    self.showRings = data.showRings == true
    self.showHalos = data.showHalos == true
    self.enableSounds = data.enableSounds == true

    self.nameDistance = SquadMenu.ValidateNumber( data.nameDistance, 3000, 500, 50000 )
    self.haloDistance = SquadMenu.ValidateNumber( data.haloDistance, 8000, 500, 50000 )
    self.pingKey = math.floor( SquadMenu.ValidateNumber( data.pingKey, KEY_B, 1, 159 ) )
end

function Config:Save( immediate )
    if not immediate then
        -- avoid spamming the file system
        timer.Remove( "SquadMenu.SaveConfigDelay" )
        timer.Create( "SquadMenu.SaveConfigDelay", 0.5, 1, function()
            self:Save( true )
        end )

        return
    end

    local path = SquadMenu.DATA_FILE

    local data = SquadMenu.TableToJSON( {
        showMembers = self.showMembers,
        showRings = self.showRings,
        showHalos = self.showHalos,
        enableSounds = self.enableSounds,
        pingKey = self.pingKey
    } )

    SquadMenu.PrintF( "%s: writing %s", path, string.NiceSize( string.len( data ) ) )
    file.Write( path, data )

    if SquadMenu.mySquad then
        SquadMenu:UpdateMembersHUD()
    end
end

Config:Load()
