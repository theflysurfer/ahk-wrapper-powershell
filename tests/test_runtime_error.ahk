; Test script avec erreur fatale - tentative d'exécution d'un fichier inexistant
; AutoHotkey V1

Run, C:\FichierQuiNExistePas.exe
; Cette ligne ne devrait jamais être atteinte car il y aura une erreur
MsgBox, Cette ligne ne devrait jamais s'afficher