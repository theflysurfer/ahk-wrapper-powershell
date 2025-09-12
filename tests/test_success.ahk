; Test script pour validation SUCCESS
; Ce script doit se lancer avec succès et créer une icône tray

#NoEnv
#SingleInstance Force
#Persistent

; Créer un menu tray simple pour confirmer le lancement
Menu, Tray, Icon, %A_WinDir%\System32\shell32.dll, 1
Menu, Tray, Tip, AHK Test Success - Validation Script

; Script simple qui reste actif
SetTimer, KeepAlive, 30000
return

KeepAlive:
; Simple routine pour maintenir le script actif
; En production réelle, le script ferait son travail ici
return

; Hotkey de test pour démontrer que le script fonctionne
F12::
MsgBox, 0, Test Success, Script AHK fonctionnel ! Appuyez sur F11 pour quitter.
return

F11::
ExitApp

; Gestion propre de la fermeture
OnExit, CleanExit
CleanExit:
ExitApp
