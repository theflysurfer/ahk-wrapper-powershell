# Best Practices - AHK Wrapper PowerShell

> **Wrapper PowerShell pour monitoring et exécution scripts AutoHotkey avec détection intelligente des erreurs**

## 🏗️ ARCHITECTURE PROJET

### Structure Modulaire
```
Ahk Wrapper Powershell/
├── ahklauncher.ps1           # Script principal monolithique
│   ├── Win32API Integration  # Enumerates windows, text extraction
│   ├── Process Management    # AutoHotkey process isolation
│   ├── Window Detection      # Smart error/success classification  
│   └── Output Formatting     # Structured results
├── tests/                    # Scripts validation AutoHotkey
│   ├── test_success_v2.ahk   # Validation SUCCESS detection
│   ├── test_simple_error.ahk # Validation ERROR detection
│   ├── test_ultra_simple_v2.ahv # Test isolation processus
│   └── test_exit_immediate.ahk  # Test minimal
├── logs/ (auto-créé)         # Logs temporaires execution
└── [documents]              # README, action_plan, best_practices
```

### Modules Principaux
- **Process Launcher** : Isolation et monitoring processus AutoHotkey
- **Window Detection** : Enumération + classification fenêtres via Win32API
- **Text Extraction** : Capture complète texte des fenêtres (récursive)
- **Output Formatter** : Sortie structurée STATUS/MESSAGE/METADATA

## 📋 CONVENTIONS NOMMAGE

### Fichiers et Modules
- **Script principal** : `ahklauncher.ps1` (monolithique)
- **Tests AutoHotkey** : `test_[fonction]_v[version].ahk`
- **Logs** : `logs/main.log` (session courante, réécrit)

### Code PowerShell
- **Fonctions principales** : `Get-ErrorWindowText()`, `Test-AutohotkeyAvailable()`
- **Variables globales** : `$ahkProcess`, `$scriptBaseName`, `$timeoutMs`
- **APIs Win32** : `[Win32API]::EnumerateWindows()`, `[Win32API]::GetWindowText()`
- **Constantes** : `$G_AUTOHOTKEY_VERSIONS = @("V2", "V1")`

### Exemples Concrets
```powershell
# Fonction detection erreurs
function Get-ErrorWindowText {
    # Classification intelligente des fenêtres
}

# Variable globale processus  
$ahkProcess = Start-Process -FilePath $ahkExecutable -PassThru

# API Win32 pour fenêtres
[Win32API]::GetWindowText($handle, $buffer, $buffer.Capacity)
```

## 🛠️ POWERSHELL SPÉCIFIQUE

### Version et Syntaxe
- **Version requise** : PowerShell 5.1+ (pas PowerShell Core 6+)
- **Add-Type obligatoire** : Win32API integration via C# inline
- **Start-Process isolation** : `-PassThru -WindowStyle Hidden -NoNewWindow:$false`

### Contraintes Techniques
- **Win32API requis** : EnumWindows + GetWindowText seules méthodes fiables détection fenêtres éphémères
- **StringBuilder obligatoire** : GetWindowText requiert StringBuilder, pas String simple
- **Process isolation** : AutoHotkey doit tourner dans processus séparé (pas Invoke-Expression)
- **Timeout intelligent** : Polling 50ms + early exit sur détection fenêtres

### Erreurs Courantes à Éviter
```powershell
# ❌ String directe avec GetWindowText (ne fonctionne pas)
$text = [Win32API]::GetWindowText($handle, "", 256)

# ✅ StringBuilder requis (syntaxe correcte)
$buffer = New-Object System.Text.StringBuilder(256)
[Win32API]::GetWindowText($handle, $buffer, $buffer.Capacity)
$text = $buffer.ToString()

# ❌ Processus sans isolation (génère erreurs PowerShell)
Invoke-Expression $scriptContent

# ✅ Processus isolé (AutoHotkey séparé)
$ahkProcess = Start-Process -FilePath $ahkExecutable -ArgumentList $scriptPath -PassThru -WindowStyle Hidden -NoNewWindow:$false
```

## ⚙️ GESTION SYSTÈME

### Configuration Processus AutoHotkey
- **Détection automatique** : Recherche V2 puis V1 dans chemins standards
- **Chemins portables** : `C:\Users\$env:USERNAME\OneDrive\Portable Softwares\Autohotkey scripts\`  
- **Arguments** : `Start-Process -FilePath $ahkExe -ArgumentList "`"$ScriptPath`""`
- **Monitoring** : PID tracking + HasExited + ExitCode

### Variables Environnement
- `$env:USERNAME` : Résolution chemins portables AutoHotkey
- `${ScriptPath}` : Chemin absolu script AutoHotkey validé  
- **Résolution** : `Test-Path` + `Resolve-Path` pour validation

### Chemins et Emplacements
- **AutoHotkey V2** : `OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV2\AutoHotkey64.exe`
- **AutoHotkey V1** : `OneDrive\Portable Softwares\Autohotkey scripts\V1+V2\AutoHotkeyV1.exe`  
- **Logs temporaires** : `logs\main.log` (réécrit chaque execution)

## 📊 LOGGING & DEBUG

### Fonctions de Log  
- **`Write-Verbose`** : Diagnostic détaillé (activé avec -Verbose)
- **`Write-StructuredOutput`** : Sortie formatée finale STATUS/MESSAGE
- **`Write-Output`** : Sortie standard pour parsing externe
- **Try-Catch global** : Capture exceptions avec trace complète

### Configuration Logs
- **Fichiers** : `logs\main.log` (principal session), pas accumulation
- **Mode** : Réécrit complet chaque exécution (orientation scripts ponctuels)
- **Format** : Sortie structurée + logs verbeux optionnels
- **Gestion** : Logs temporaires, extraction immédiate recommandée

### Patterns Debug Efficaces  
```powershell
# Isolation processus avec monitoring
Write-Verbose "Launching AutoHotkey process with full isolation..."
$ahkProcess = Start-Process -FilePath $ahkExecutable -ArgumentList "`"$ScriptPath`"" -PassThru -WindowStyle Hidden

# Enumeration fenêtres avec logging
Write-Verbose "Enumerating all visible windows using Win32API.EnumerateWindows()..."
[Win32API]::EnumerateWindows()
Write-Verbose "Found $([Win32API]::GetWindowCount()) visible windows"

# Gestion erreurs avec codes
try {
    $windowResult = Get-ErrorWindowText
} catch {
    Write-StructuredOutput -Status "ERROR" -Message "Unexpected error: $($_.Exception.Message)"
    exit 1
}
```

## 🔄 WORKFLOW DÉVELOPPEMENT

### Tests et Validation
- **Test principal** : `tests\test_success_v2.ahk` (validation SUCCESS detection)  
- **Commande validation** : `.\ahklauncher.ps1 tests\test_success_v2.ahk -Verbose`
- **Critères succès** : `STATUS: SUCCESS` (pas ERROR) + pas erreur PowerShell "if"
- **Stratégie** : Tests incrémentaux après chaque modification critique

### Étapes Validation Environnement
1. **AutoHotkey disponible** : `Test-AutohotkeyAvailable` → chemin valide
2. **APIs Win32 opérationnelles** : `[Win32API]::EnumerateWindows()` → sans erreur
3. **Isolation processus** : Scripts avec `if`/`switch` → pas erreur PowerShell
4. **Détection intelligente** : Fenêtres SUCCESS → `STATUS: SUCCESS`

### Commandes Debug Standard
```powershell
# Test isolation complète (plus d'erreur PowerShell)
.\ahklauncher.ps1 tests\test_ultra_simple_v2.ahk -Verbose

# Test détection SUCCESS (fenêtre normale)  
.\ahklauncher.ps1 tests\test_success_v2.ahk -Verbose | Select-String "STATUS:"

# Debug classification fenêtres
.\ahklauncher.ps1 script.ahk -Verbose 2>&1 | Select-String "Inspecting window"
```

### Métriques Qualité
- **Performance** : Timeout 3000ms maximum, polling 50ms optimisé
- **Fiabilité** : SUCCESS/ERROR classification 100% précise  
- **Isolation** : Zéro interference PowerShell avec syntaxe AutoHotkey

## 🎨 INTERFACE LIGNE DE COMMANDE

### Format Sortie Standard
```
STATUS: SUCCESS/ERROR/WAITING_INPUT
MESSAGE: [Message principal ou texte d'erreur extrait]  
WINDOW_TYPE: ERROR_DIALOG/SUCCESS_WINDOW/INTERACTIVE_DIALOG/NONE
TRAY_ICON: FOUND/NOT_FOUND
EXECUTION_TIME: 1234ms
TIMESTAMP: 2025-09-16 15:30:45
```

### Paramètres CLI
- **ScriptPath** : Chemin script AutoHotkey (obligatoire)
- **-Verbose** : Logs détaillés diagnostic
- **-Mode** : Silent/Interactive/Validation (futur v1.3)
- **-TextExtraction** : Full/Summary/None (futur v1.3)

### Gestion Erreurs Interface
- **Exit codes** : 0=Success, 1=Error script, 2=Config error
- **Messages structurés** : STATUS + MESSAGE lisibles programmatiquement  
- **Recovery** : Logs verbeux pour diagnostic détaillé

## 🔧 MAINTENANCE

### Gestion Erreurs Win32API
- **Exception handling** : Try-catch autour EnumerateWindows + GetWindowText
- **Fallback** : Si APIs échouent, timeout standard vers SUCCESS
- **Logging** : Exceptions Win32 loggées avec trace complète
- **Recovery** : Processus AutoHotkey jamais bloqué par erreur wrapper

### Bonnes Pratiques Code  
- **Modularité** : Fonctions séparées (process, detection, extraction, output)
- **Performance** : Early exit sur détection, polling optimisé 50ms
- **Lisibilité** : Comments détaillés pour logique Win32API complexe
- **Logging intégré** : Write-Verbose systématique étapes critiques

### Intégrations Externes
- **AutoHotkey V1/V2** : Détection version automatique + chemins portables
- **PowerShell ISE/Terminal** : Compatible tous environnements PowerShell 5.1+
- **CI/CD Pipelines** : Sortie structurée parsable automatiquement
- **Scripts monitoring** : Exit codes standardisés pour automation

### Architecture Win32API
```csharp
// APIs Win32 requises - Add-Type inline
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

[DllImport("user32.dll", CharSet = CharSet.Auto)]  
public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);

[DllImport("user32.dll")]
public static extern bool EnumChildWindows(IntPtr hwnd, EnumWindowsProc lpEnumFunc, IntPtr lParam);

// Callback delegate pour énumération
public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
```

### Sécurité & Validation
- **Path validation** : `Test-Path` systématique avant Start-Process
- **Script isolation** : AutoHotkey processus séparé, pas execution inline
- **Input sanitization** : Paramètres CLI validés avant utilisation  
- **Permissions** : Fonctionne avec permissions utilisateur standard

### Évolution Architecture v1.2 → Future
- **v1.3** : Modes d'exécution configurables (Silent, Interactive, Validation)
- **v1.4** : Extraction texte paramétrable (Full, Summary, None)
- **v2.0** : Architecture modulaire + support cross-platform via Wine

---

**Best Practices AHK Wrapper PowerShell v1.2** - Architecture stable pour continuité développement
