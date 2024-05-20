local PlayerMeta = FindMetaTable( "Player" )

function PlayerMeta:GetSquadID()
    return self:GetNWInt( "squad_menu.id", -1 )
end
