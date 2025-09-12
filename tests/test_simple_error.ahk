; Test script avec erreur de syntaxe évidente - AutoHotkey V1
; Ce script doit absolument générer une erreur

; ERREUR FATALE : Variable avec caractère interdit
variable$ = "test"  

; Si cette erreur ne génère pas d'erreur, celle-ci le fera :
MsgBox, Ceci ne devrait jamais s'afficher car il y a une erreur de syntaxe au-dessus.
