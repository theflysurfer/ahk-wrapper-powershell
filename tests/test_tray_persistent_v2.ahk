; Test script: Tray Persistent - AutoHotkey V2
; Ce script crée une icône tray et reste actif
; Doit être détecté comme RUNNING (process actif après timeout)
#Requires AutoHotkey v2.0
#SingleInstance Force

; Configurer l'icône tray
A_IconTip := "test_tray_persistent_v2 - Script actif"
TraySetIcon("shell32.dll", 44)

; Créer menu tray
trayMenu := A_TrayMenu
trayMenu.Delete()
trayMenu.Add("Status", (*) => MsgBox("Script is running!", "test_tray_persistent_v2"))
trayMenu.Add()
trayMenu.Add("Exit", (*) => ExitApp())

; Le script reste actif indéfiniment
; Appuyer F12 pour afficher un message, F11 pour quitter
F12:: MsgBox("Script tray actif!", "test_tray_persistent_v2")
F11:: ExitApp()
