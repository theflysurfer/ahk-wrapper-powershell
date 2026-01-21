; Test script: Instant Exit - AutoHotkey V2
; Ce script fait une opération rapide et sort avec code 0
; Doit être détecté comme SUCCESS (pas de fenêtre erreur)
#Requires AutoHotkey v2.0

; Petite pause pour éviter le faux positif "< 500ms = erreur"
Sleep(600)

; Sortie propre avec code 0
ExitApp(0)
