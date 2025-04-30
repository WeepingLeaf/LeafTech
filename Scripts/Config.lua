if _leafConfigLoaded then return end
_leafConfigLoaded = true

dofile "$MOD_DATA/Scripts/Leaf.lua"

sm.interactable.connectionType.data = 16384

LF = {
    Lift = {},
    Protected = {}
}

Leaf:InstallHooks()