; Test script pour validation ERROR
; Ce script contient des erreurs de syntaxe volontaires pour tester l'extraction d'erreurs

#NoEnv
#SingleInstance Force

; ERREUR VOLONTAIRE 1: Variable illégale avec caractères interdits  
global_variable$ = "test"  ; Le caractère $ n'est pas autorisé dans les noms de variables

; ERREUR VOLONTAIRE 2: Commande inexistante
InvalidCommand("parameter")

; ERREUR VOLONTAIRE 3: Syntaxe incorrecte
If Variable = ; Syntaxe if incomplète
{
    MsgBox, This should not execute
}

; ERREUR VOLONTAIRE 4: Label mal formé
::invalid label format::
MsgBox, Bad hotstring

; ERREUR VOLONTAIRE 5: Accolades non fermées
Loop, 5 {
    MsgBox, Loop iteration
; } <- Accolade manquante volontairement

return
