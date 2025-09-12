# Action Plan - AHK Wrapper PowerShell v1.1 - AutoHotkey Script Launcher

## CONTEXTE PROJET
**Projet:** AHK Wrapper PowerShell v1.1 - Wrapper professionnel pour validation scripts AutoHotkey
**Architecture:** PowerShell + Win32 APIs (EnumWindows, GetWindowText) + détection installations portables
**Status:** ✅ Core fonctionnel - Extraction erreurs V1 validée, tests V2 requis

## ÉTAT RÉEL PROJET - FONCTIONNALITÉS

### ✅ Opérationnel et Validé
- **Extraction erreurs fenêtres V1** : EnumWindows API + Get-WindowTextRecursive extraient correctement messages erreurs AutoHotkey V1 (testé sur test_simple_error.ahk)
- **Support versions multiples** : Paramètre -AhkVersion V1|V2|Auto avec détection portables OneDrive fonctionnel
- **Détection installations** : Test-AutohotkeyAvailable trouve V1/V2 portable + installations système + PATH
- **Sortie structurée** : Write-StructuredOutput génère format STATUS/MESSAGE/TIMESTAMP pour intégration MCP/LLM
- **Monitoring processus** : Détection erreurs codes sortie + timing rapide (< 500ms) pour scripts défaillants

### 🔄 Partiellement Implémenté (avec % avancement)
- **Validation AutoHotkey V2** : [Avancement: 80%] Code support présent, détection V2 fonctionne, mais pas testé avec scripts erreur V2 spécifiques
- **Tests automatisés** : [Avancement: 60%] test_simple_error.ahk validé V1, test_success.ahk créé mais pas test_success_v2.ahk

### ✅ Non Fonctionnel / Bugs Identifiés
- **Aucun bug critique identifié** : Fonctionnalité core extraction erreurs V1 opérationnelle

### 📋 À Implémenter (Roadmap Priorisée)
- **Scripts test V2** : Créer test_simple_error_v2.ahk + test_success_v2.ahk pour validation complète V2 (Priorité 1, Effort: 30min)
- **Amélioration patterns erreurs** : Étendre détection mots-clés erreurs runtime + syntaxe (Priorité 2, Effort: 1h)
- **Documentation API Win32** : Documenter EnumWindows + GetWindowText usage (Priorité 3, Effort: 45min)

## ACTIONS PRIORITAIRES PROCHAINE SESSION

### 1. **VALIDATION AUTOHOTKEY V2 COMPLÈTE** (Priorité 1)
**Status:** Support V2 implémenté, détection portable fonctionne, tests spécifiques manquants
**Fichier:** `tests/` (scripts test) + `ahklauncher.ps1` ligne 140-160 (détection V2)
**Actions:**
- Créer test_simple_error_v2.ahk avec erreur syntaxe V2 (ex: MsgBox syntax V1 dans contexte V2)
- Créer test_success_v2.ahk avec script fonctionnel V2 basique
- Tester extraction erreurs V2 : .\ahklauncher.ps1 test_simple_error_v2.ahk -AhkVersion V2 -Verbose
- Valider format messages erreurs V2 vs V1 (différences possibles classes fenêtres)
**Test:** Lancer script erreur V2 → STATUS: ERROR avec message erreur extrait + VERSION V2 détectée

### 2. **DOCUMENTATION TECHNIQUE WIN32 API** (Priorité 2)
**Status:** EnumWindows + Get-WindowTextRecursive fonctionnels, patterns extraction validés V1
**Fichier:** `ahklauncher.ps1` lignes 25-70 (Add-Type Win32API) + lignes 190-250 (Get-ErrorWindowText)
**Actions:**
- Documenter dans README.md : EnumWindows callback pattern utilisé
- Expliquer Get-WindowTextRecursive : parcours récursif contrôles enfants fenêtres
- Ajouter exemples classes fenêtres détectées : #32770, AutoHotkeyGUI patterns
- Créer section troubleshooting : fenêtres non détectées, faux positifs Explorateur
**Test:** Documentation complète permet reproduction approche technique sur autre projet

### 3. **EXTENSION PATTERNS DÉTECTION ERREURS** (Priorité 2)
**Status:** Patterns basiques fonctionnels (nom script, mots-clés "error|erreur|syntax")
**Fichier:** `ahklauncher.ps1` lignes 205-225 (matching fenêtres erreur)
**Actions:**
- Ajouter patterns erreurs runtime : "Runtime Error", "Access Violation", "Memory"
- Améliorer filtrage faux positifs : exclure "Explorateur" + chemins longs
- Tester avec scripts erreurs différentes : division zéro, accès fichier inexistant
- Optimiser regex matching : performance + précision détection
**Test:** Scripts avec erreurs runtime/access → détection correcte sans faux positifs

## ARCHITECTURE TECHNIQUE ACTUELLE

### Fichiers Modifiés Récemment
ahklauncher.ps1 - Script principal réécrit complet
├── Lignes 25-70 : Add-Type Win32API avec EnumWindows + callback C#
├── Lignes 120-180 : Test-AutohotkeyAvailable détection V1/V2 portable
├── Lignes 190-260 : Get-ErrorWindowText avec EnumWindows énumération
├── Lignes 270-300 : Get-WindowTextRecursive extraction contrôles enfants  
└── Lignes 350-420 : Boucle monitoring + détection timing rapide < 500ms

tests/test_simple_error.ahk - Test erreur V1 validé
├── Lignes 1-9 : Erreur syntaxe variable$ + MsgBox V1
└── Status : Génère fenêtre "test_simple_error.ahk" avec message extractible

logs/ - Pas de logs persistants
├── Verbose PowerShell : Output temps réel session courante
└── Format : Write-Verbose pour debug, Write-StructuredOutput pour résultat

### Variables/Config Critiques
- `[Win32API]::FoundWindows` : Liste fenêtres énumérées par EnumWindows callback
- `$ScriptPath` : Chemin script résolu pour matching titre fenêtre erreur
- `$AhkVersion` : V1|V2|Auto sélection version AutoHotkey
- `$TimeoutMs` : 3000ms défaut polling fenêtres erreur

## TESTS & VALIDATION

### Tests Debug Immédiat (Format checklist)
- [x] **EnumWindows fonctionnel** : .\ahklauncher.ps1 tests\test_simple_error.ahk -AhkVersion V1 -Verbose → "Found X visible windows"
- [x] **Extraction erreurs V1** : Test ci-dessus → STATUS: ERROR avec texte "Ceci ne devrait jamais s'afficher..."
- [ ] **Validation V2** : Créer + tester script erreur V2 → STATUS: ERROR avec message V2
- [ ] **Scripts succès** : Tester test_success.ahk + test_success_v2.ahk → STATUS: SUCCESS

### Métriques Succès Session
- ✅ **Détection V1 erreurs** : 100% extraction messages fenêtres éphémères
- ✅ **Support versions** : V1/V2 détection installations portable + système
- 🔄 **Couverture tests** : V1 validé, V2 requis pour complétude

## RÉFÉRENCES TECHNIQUES

### Commandes Validation Testées
```powershell
# Test extraction erreur V1 - VALIDÉ
.\ahklauncher.ps1 tests\test_simple_error.ahk -AhkVersion V1 -Verbose

# Test détection portable V2 - VALIDÉ
.\ahklauncher.ps1 tests\test_simple_error.ahk -AhkVersion V2 -Verbose
```

### APIs Win32 Utilisées
- `EnumWindows(callback, IntPtr.Zero)` : Énumération fenêtres top-level visibles
- `GetWindowText(hWnd, StringBuilder, capacity)` : Extraction titre fenêtre
- `IsWindowVisible(hWnd)` : Filtrage fenêtres visibles uniquement
- `GetWindow(hWnd, GW_CHILD|GW_HWNDNEXT)` : Parcours récursif contrôles enfants

---

**✅ STATUS SESSION** - 🎯 Core Fonctionnel V1 
**🎯 Next Actions:** Tests V2 + Documentation API + Extension patterns erreurs
**📋 Timeline:** 2-3h pour validation complète V2 + documentation technique