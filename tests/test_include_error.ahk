; Test script pour erreur d'inclusion de fichier
; Ce script essaie d'inclure un fichier inexistant

#NoEnv
#SingleInstance Force

; ERREUR: Tentative d'inclusion d'un fichier qui n'existe pas
#Include NonExistentFile.ahk

; Code qui ne devrait jamais s'exécuter à cause de l'erreur d'include
MsgBox, This message should never appear because of the include error above.

F12::
MsgBox, Script loaded successfully
return

F11::
ExitApp
