# AHK Wrapper PowerShell v1.2

> **Wrapper PowerShell pour exécution et monitoring des scripts AutoHotkey avec détection intelligente des erreurs**

## 🚀 Utilisation Rapide

```powershell
# Exécuter un script AutoHotkey avec monitoring
.\ahklauncher.ps1 "script.ahk" -Verbose

# Modes d'exécution
.\ahklauncher.ps1 "script.ahk" -Mode Silent          # Détection erreurs uniquement
.\ahklauncher.ps1 "script.ahk" -Mode Interactive     # Attend interactions utilisateur  
.\ahklauncher.ps1 "script.ahv" -Mode Validation      # Détecte SUCCESS + ERROR
```

## ✅ Fonctionnalités v1.2

### Détection Intelligente
- ✅ **Distinction SUCCESS vs ERROR** : Analyse des boutons de fenêtres AutoHotkey
- ✅ **Extraction complète du texte** : Messages d'erreur complets pour diagnostic
- ✅ **Isolation processus** : Scripts AutoHotkey exécutés sans interference PowerShell
- ✅ **Support AutoHotkey V1 + V2** : Détection automatique de version

### ⚠️ CONTRAINTE IMPORTANTE - Détection SUCCESS
**Pour que la détection SUCCESS fonctionne, le titre de la MsgBox doit contenir le nom du script :**
```autohotkey
; ✅ CORRECT - Détecté comme SUCCESS
MsgBox("Message", "monscript.ahk - SUCCESS", 0)
MsgBox("Message", "monscript", 0)

; ❌ INCORRECT - Non détecté (timeout)  
MsgBox("Message", "Succès", 0)
MsgBox("Message", "Information", 0)
```
**Raison technique** : Le wrapper identifie les MsgBox SUCCESS en cherchant le nom du script dans le titre de la fenêtre, puis vérifie l'absence de boutons d'erreur AutoHotkey.

### Formats de Sortie Structurés
```
STATUS: SUCCESS/ERROR/WAITING_INPUT
MESSAGE: [Contenu extrait ou message d'erreur]  
WINDOW_TYPE: ERROR_DIALOG/SUCCESS_WINDOW/INTERACTIVE_DIALOG/NONE
TRAY_ICON: FOUND/NOT_FOUND
EXECUTION_TIME: 1234ms
TIMESTAMP: 2025-09-16 15:30:45
```

### Modes d'Exécution
- **Silent** : Détection erreurs seulement, sortie immédiate
- **Interactive** : Attend les interactions utilisateur (InputBox, etc.)
- **Validation** : Détecte aussi les fenêtres de succès normales

## 📁 Structure Projet

```
Ahk Wrapper Powershell/
├── ahklauncher.ps1           # Script principal
├── tests/                    # Scripts de test AutoHotkey
│   ├── test_success_v2.ahk   # Test SUCCESS
│   ├── test_simple_error.ahk # Test ERROR  
│   └── test_ultra_simple_v2.ahk
├── logs/ (auto-généré)       # Logs d'exécution
└── README.md                 # Ce fichier
```

## 🔧 Installation et Prérequis

### Prérequis
- **PowerShell 5.1+** avec Add-Type disponible
- **AutoHotkey V1 ou V2** portable ou installé
- **Windows 10/11** (APIs Win32 requises)

### Installation
1. Cloner ou télécharger le projet
2. Vérifier que PowerShell peut exécuter des scripts : `Set-ExecutionPolicy RemoteSigned`
3. Tester l'installation : `.\ahklauncher.ps1 tests\test_simple_success.ahk -Verbose`

## 📊 Exemples d'Utilisation

### Test de Script AutoHotkey
```powershell
# Script qui fonctionne normalement
.\ahklauncher.ps1 tests\test_success_v2.ahk -Verbose
# Résultat attendu: STATUS: SUCCESS

# Script avec erreur
.\ahklauncher.ps1 tests\test_simple_error.ahk -Verbose  
# Résultat attendu: STATUS: ERROR avec message détaillé
```

### Intégration CI/CD
```powershell
# Usage dans pipeline de déploiement
$result = .\ahklauncher.ps1 "deploy_script.ahk" -Mode Silent
if ($result -like "*STATUS: ERROR*") {
    throw "Déploiement échoué: $($result | Select-String 'MESSAGE:')"
}
Write-Host "Déploiement réussi"
```

### Diagnostic Avancé  
```powershell
# Extraction texte complète des fenêtres
.\ahklauncher.ps1 "script_problematique.ahk" -TextExtraction Full -Verbose
# Sortie: Texte complet des fenêtres AutoHotkey pour debugging
```

## 🐛 Résolution de Problèmes

### Problèmes Courants

**Erreur "Le terme « if » n'est pas reconnu"**
- ✅ **Résolu en v1.2** : Isolation processus complète  
- Cause : Anciennement PowerShell interprétait le code AutoHotkey
- Solution : Mise à jour vers v1.2

**Scripts SUCCESS détectés comme ERROR**
- ✅ **Résolu en v1.2** : Détection intelligente des boutons  
- Cause : Anciennement toute fenêtre avec nom du script = erreur
- Solution : Analyse des boutons de fenêtre AutoHotkey

**Texte d'erreur incomplet**  
- ✅ **Résolu en v1.2** : Extraction texte universelle
- Cause : Get-WindowText basique insuffisant
- Solution : Extraction récursive avec APIs Win32

### Diagnostic
```powershell  
# Activer les logs verbeux
.\ahklauncher.ps1 "script.ahk" -Verbose

# Vérifier les fenêtres détectées
# Le log verbose affiche toutes les fenêtres inspectées et leur classification
```

## 🔄 Historique Versions

### v1.2 (Actuel) - Corrections Critiques
- ✅ **Isolation processus complète** : Fini les erreurs PowerShell
- ✅ **Détection intelligente** : SUCCESS vs ERROR basé sur boutons de fenêtres  
- ✅ **Extraction texte universelle** : Messages complets pour diagnostic
- ✅ **Modes d'exécution configurables** : Silent, Interactive, Validation

### v1.1 (Précédent)
- ❌ Scripts SUCCESS détectés comme ERROR
- ❌ Erreurs PowerShell "Le terme « if » n'est pas reconnu"  
- ❌ Extraction texte incomplète des fenêtres

## 🤝 Contribution

### Structure de Test
Tous les nouveaux scripts de test doivent être ajoutés dans `tests/` avec nomenclature :
- `test_[fonction]_v[version].ahk` pour les tests de fonctionnalité
- `test_simple_[type].ahk` pour les tests basiques

### Validation  
```powershell
# Avant commit : validation complète
.\tests\validate_wrapper_v12.ps1
```

## 📞 Support

- **Issues** : Utiliser les logs verbeux (`-Verbose`) pour diagnostic
- **Debug** : Logs stockés temporairement, extraire le contenu immédiatement  
- **Documentation** : `action_plan.md` pour développeurs, `best_practices_current_project.md` pour architecture

---

**AHK Wrapper PowerShell v1.2** - Monitoring fiable des scripts AutoHotkey avec détection intelligente
