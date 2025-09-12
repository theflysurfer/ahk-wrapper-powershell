; Test script avec erreur de syntaxe GARANTIE - AutoHotkey V1

; ERREUR FATALE : Commande inexistante
ThisCommandDoesNotExist()

; ERREUR DE SYNTAXE : If sans condition
If 
{
    MsgBox, Ne devrait jamais s'afficher
}
