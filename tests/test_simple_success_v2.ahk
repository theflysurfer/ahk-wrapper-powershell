; Test script pour validation SUCCESS - AutoHotkey V2 Compatible - CORRIGE
; Ce script doit se lancer avec succès sans erreur

#SingleInstance Force

; Script simple qui affiche un message et se ferme
; Pas de persistance ni de tray pour éviter les erreurs

; Hotkey simple qui fonctionne avec V2
F12:: {
    MsgBox("Script AHK V2 fonctionnel ! Appuyez sur F11 pour quitter.", "Test Success", 0)
}

F11:: {
    ExitApp()
}

; Attendre 2 secondes puis fermer automatiquement 
; (pour test automatique)
SetTimer(() => ExitApp(), 2000)
