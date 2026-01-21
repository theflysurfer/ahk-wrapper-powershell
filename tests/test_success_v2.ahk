; Test script pour validation SUCCESS - AutoHotkey V2 Compatible
; Ce script doit se lancer avec succès et créer une icône tray

#SingleInstance Force
#Persistent

; Créer un menu tray simple pour confirmer le lancement
A_TrayMenu.Delete()
A_TrayMenu.Add("Script Status", MenuHandler)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit Script", MenuHandler)
TraySetIcon("shell32.dll", 1)
TraySetToolTip("AHK Test Success V2 - Validation Script")

; Script simple qui reste actif
SetTimer(KeepAlive, 30000)

KeepAlive() {
    ; Simple routine pour maintenir le script actif
    ; En production réelle, le script ferait son travail ici
}

; Hotkey de test pour démontrer que le script fonctionne  
F12::{
    MsgBox("Script AHK V2 fonctionnel ! Appuyez sur F11 pour quitter.", "Test Success", 0)
}

F11::{
    ExitApp()
}

MenuHandler(ItemName, ItemPos, MyMenu) {
    if (ItemName = "Exit Script") {
        ExitApp()
    } else if (ItemName = "Script Status") {
        MsgBox("Script AutoHotkey V2 running successfully!", "Status", 0)
    }
}

; Gestion propre de la fermeture
OnExit(CleanExit)
CleanExit(ExitReason, ExitCode) {
    ExitApp()
}
