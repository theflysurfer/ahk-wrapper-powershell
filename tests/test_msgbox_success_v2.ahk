; Test script: MsgBox SUCCESS - AutoHotkey V2
; Ce script affiche un MsgBox et attend que l'utilisateur clique OK
; Le titre contient le nom du script pour permettre la détection SUCCESS
#Requires AutoHotkey v2.0

; Afficher MsgBox avec nom du script dans le titre
MsgBox("Ce script fonctionne correctement!", "test_msgbox_success_v2 - SUCCESS", "OK")

; Sortie propre
ExitApp()
