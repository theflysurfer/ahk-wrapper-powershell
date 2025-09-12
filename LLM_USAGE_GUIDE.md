# AHK Wrapper PowerShell - Guide LLM
*Wrapper pour tester et valider des scripts AutoHotkey V1/V2*

## 🎯 Usage Simple

```powershell
# Test basique - détection automatique de version
.\ahklauncher.ps1 "mon_script.ahk"

# Forcer version spécifique
.\ahklauncher.ps1 "mon_script.ahk" -AhkVersion V2

# Mode verbeux pour debug
.\ahklauncher.ps1 "mon_script.ahk" -Verbose -Timeout 5000
```

## 📋 Réponses Standard

**SUCCESS** ✅
```
STATUS: SUCCESS
MESSAGE: Script launched successfully (no error detected within timeout)
TRAY_ICON: FOUND
TIMESTAMP: 2025-09-12 18:45:33
```

**ERROR** ❌
```
STATUS: ERROR  
MESSAGE: test_error.ahk | &Abort | &Help | &Edit | &Reload | E&xitApp | &Continue
TRAY_ICON: NOT_FOUND
TIMESTAMP: 2025-09-12 18:45:33
```

## 🔧 Workflow LLM Recommandé

```powershell
# 1. Créer le script AHK
Write-Output "MsgBox('Hello AutoHotkey V2!')" > test.ahk

# 2. Tester avec le wrapper  
.\ahklauncher.ps1 "test.ahk" -AhkVersion V2 -Verbose

# 3. Analyser le STATUS
# SUCCESS = Script OK, ERROR = Problème détecté
```

## 📁 Scripts de Test Disponibles

```
tests/
├── test_simple_error_v2.ahk      # Erreur V2 garantie
├── test_success_immediate_v2.ahk  # Succès V2 immédiat  
├── test_simple_error.ahk          # Erreur V1 classique
├── test_success.ahk               # Succès V1 avec tray
└── test_runtime_error.ahk         # Test erreur runtime
```

## ⚡ Détection Intelligente

Le wrapper détecte automatiquement :
- ✅ **Erreurs de syntaxe** (V1 et V2)
- ✅ **Erreurs runtime** (division par zéro, etc.)  
- ✅ **Access violations**
- ✅ **Scripts qui fonctionnent** (pas de faux positifs)

**Méthode** : Analyse des fenêtres d'erreur AutoHotkey par EnumWindows API + validation du contenu (boutons &Abort, &Help, etc.)

## 🎯 Pour LLMs : Règles d'Or

1. **Toujours utiliser le wrapper** pour valider vos scripts AHK
2. **STATUS: SUCCESS** = Votre script fonctionne  
3. **STATUS: ERROR** = Correction nécessaire (voir MESSAGE)
4. **Timeout** = Durée max d'attente (défaut: 3000ms)
5. **Mode Verbose** = Activez pour déboguer des problèmes

---
*Wrapper v1.1 - Support V1/V2 - Intégration Claude MCP Ready*