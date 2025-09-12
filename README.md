# AHK Wrapper PowerShell - AutoHotkey Script Launcher

> **Wrapper PowerShell professionnel pour validation et exécution scripts AutoHotkey avec extraction d'erreurs complète**

## 🎯 Vue d'ensemble

AHK Wrapper PowerShell v1.1 est un lanceur de scripts AutoHotkey avec détection intelligente des erreurs et support des versions V1/V2. Il extrait automatiquement les messages d'erreur des fenêtres éphémères AutoHotkey pour intégration dans des workflows automatisés.

📋 **[Guide d'utilisation LLM →](LLM_USAGE_GUIDE.md)** *Documentation simplifiée pour développement AHK assisté par IA*

### Fonctionnalités principales
- ✅ **Support V1/V2** : Détection automatique ou sélection forcée version AutoHotkey
- ✅ **Extraction erreurs** : Capture messages fenêtres d'erreur éphémères avec EnumWindows API
- ✅ **Détection portable** : Recherche automatique installations portables OneDrive
- ✅ **Sortie structurée** : Format machine-readable pour intégration MCP/LLM
- ✅ **Monitoring processus** : Détection erreurs par codes de sortie + timing
- ✅ **Mode simulation** : Test commandes sans exécution (--WhatIf)

## 🚀 Installation et Usage

### Prérequis
- Windows PowerShell 5.1+
- AutoHotkey V1 et/ou V2 installés (standard ou portable)

### Syntaxe
```powershell
.\ahklauncher.ps1 <ScriptPath> [-AhkVersion V1|V2|Auto] [-TimeoutMs 3000] [-WhatIf] [-Verbose]
```

### Exemples d'utilisation

#### Usage basique
```powershell
# Lancement avec auto-détection version
.\ahklauncher.ps1 "mon_script.ahk"

# Forcer AutoHotkey V1
.\ahklauncher.ps1 "script_v1.ahk" -AhkVersion V1

# Test sans exécution
.\ahklauncher.ps1 "script.ahk" -WhatIf -Verbose
```

#### Intégration workflow
```powershell
# Validation avec gestion erreurs
$result = .\ahklauncher.ps1 "validation.ahk" -Verbose
if ($LASTEXITCODE -eq 0) {
    Write-Host "Script validé avec succès"
} else {
    Write-Error "Erreur détectée dans le script"
}
```

## 📊 Format de sortie

### Sortie SUCCESS
```
STATUS: SUCCESS
MESSAGE: Script launched successfully (no error detected within timeout)
TRAY_ICON: NOT_CHECKED
TIMESTAMP: 2025-09-12 18:23:10
```

### Sortie ERROR avec extraction
```
STATUS: ERROR  
MESSAGE: test_simple_error.ahk | Ceci ne devrait jamais s'afficher car il y a une erreur de syntaxe au-dessus.
TRAY_ICON: NOT_FOUND
TIMESTAMP: 2025-09-12 18:23:10
```

### Codes de sortie
- `0` : Succès, script exécuté sans erreur
- `1` : Erreur détectée (fenêtre d'erreur ou processus défaillant)
- `2` : Erreur configuration (fichier introuvable, AutoHotkey absent)

## ⚙️ Configuration

### Détection AutoHotkey
Le script recherche AutoHotkey dans cet ordre :
1. Chemin custom (`-AhkExecutable`)
2. Installation portable OneDrive (V1/V2)
3. Installation système PATH
4. Emplacements standards Windows

### Emplacements portables par défaut
```
%USERPROFILE%\OneDrive\Portable Softwares\Autohotkey scripts\
├── AutohotkeyV1\AutoHotkeyU64.exe
└── AutohotkeyV2\AutoHotkey64.exe
```

## 🔧 Fonctionnement technique

### Détection d'erreurs avancée
1. **EnumWindows API** : Énumération toutes fenêtres visibles
2. **Matching intelligent** : Titre = nom script + mots-clés erreur
3. **Extraction recursive** : Texte fenêtre principale + contrôles enfants
4. **Monitoring processus** : Codes sortie + timing rapide (< 500ms = erreur)

### Architecture modulaire
- **Test-AutohotkeyAvailable** : Détection installations
- **Get-ErrorWindowText** : Extraction erreurs fenêtres via Win32API
- **Get-WindowTextRecursive** : Parcours récursif contrôles UI
- **Write-StructuredOutput** : Format sortie standardisé

## 🧪 Tests et validation

### Scripts de test inclus
```
tests/
├── test_simple_error.ahk    # Erreur syntaxe V1 (variable$)
├── test_success.ahk         # Script fonctionnel V1
└── test_success_v2.ahk      # Script fonctionnel V2
```

### Validation manuelle
```powershell
# Test erreur V1
.\ahklauncher.ps1 tests\test_simple_error.ahk -AhkVersion V1 -Verbose

# Test succès V2
.\ahklauncher.ps1 tests\test_success_v2.ahk -AhkVersion V2 -Verbose
```

## 🔗 Intégration MCP/LLM

Format de sortie optimisé pour parsing automatique :
- **STATUS** : SUCCESS|ERROR (parsing état)
- **MESSAGE** : Texte erreur extrait ou confirmation succès
- **TIMESTAMP** : Horodatage précis exécution
- **Exit codes** : Standard système pour workflows

### Exemple intégration Claude MCP
```javascript
const result = await exec(`powershell -Command "& '${ahkLauncher}' '${scriptPath}' -Verbose"`);
const output = parseStructuredOutput(result.stdout);
if (output.STATUS === "ERROR") {
    return `AutoHotkey Error: ${output.MESSAGE}`;
}
```

## 📋 Roadmap

- [ ] Test AutoHotkey V2 avec scripts erreur spécifiques
- [ ] Support détection icônes tray avancée
- [ ] Amélioration patterns détection erreurs runtime
- [ ] Documentation API Win32 utilisées
- [ ] Templates scripts test étendus

## 🤝 Support

Pour rapporter bugs ou suggestions :
- Logs détaillés avec `-Verbose` 
- Version AutoHotkey utilisée
- Contenu script testé
- Sortie complète ahklauncher.ps1