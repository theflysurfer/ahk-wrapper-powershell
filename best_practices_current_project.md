# Best Practices - AHK Wrapper PowerShell

> **Wrapper PowerShell professionnel avec Win32 APIs pour validation scripts AutoHotkey V1/V2**

## 🏗️ ARCHITECTURE PROJET

### Structure Modulaire
```
Ahk Wrapper Powershell/
├── ahklauncher.ps1           # Script principal launcher
├── tests/                    # Scripts test AutoHotkey
│   ├── test_simple_error.ahk # Test erreur syntaxe V1
│   ├── test_success.ahk      # Test succès V1
│   └── test_success_v2.ahk   # Test succès V2
├── README.md                 # Documentation utilisateur
├── action_plan.md            # Plan session LLM
└── best_practices.md         # Référence technique (ce fichier)
```

### Modules Principaux
- **ahklauncher.ps1** : Core launcher avec Win32 APIs + détection erreurs
- **Test-AutohotkeyAvailable** : Fonction détection installations V1/V2
- **Get-ErrorWindowText** : Fonction extraction erreurs fenêtres via EnumWindows
- **Get-WindowTextRecursive** : Fonction parcours récursif contrôles UI
- **Write-StructuredOutput** : Fonction sortie standardisée machine-readable

## 📋 CONVENTIONS NOMMAGE

### Fichiers et Modules
- **Script principal** : `ahklauncher.ps1` (entry point)
- **Tests** : `test_[type]_[version].ahk` (test_simple_error.ahk, test_success_v2.ahk)
- **Documentation** : `README.md`, `action_plan.md`, `best_practices.md`

### Code PowerShell
- **Fonctions** : `Verb-NounContext()` (Test-AutohotkeyAvailable, Get-ErrorWindowText)
- **Variables locales** : `$camelCase` (ex: $ahkProcess, $errorText)
- **Paramètres** : `$PascalCase` (ex: $ScriptPath, $AhkVersion, $TimeoutMs)
- **Constantes Win32** : `GW_CHILD`, `GW_HWNDNEXT` (standards Win32API)

### Exemples Concrets
```powershell
# Fonction module detection
function Test-AutohotkeyAvailable {
    param([string]$CustomPath, [string]$PreferredVersion)
}

# Variable processus
$ahkProcess = Start-Process -FilePath $ahkExecutable

# APIs Win32
[Win32API]::GetWindow($WindowHandle, [Win32API]::GW_CHILD)
```

## 🛠️ POWERSHELL + WIN32 SPÉCIFIQUE

### Version et Syntaxe
- **PowerShell version** : 5.1+ (Windows natif)
- **Add-Type obligatoire** : Win32 APIs via C# inline pour EnumWindows/GetWindowText
- **IntPtr casting** : Handles fenêtres nécessitent IntPtr pour interop Win32

### Contraintes Techniques
- **APIs Win32 required** : EnumWindows + GetWindowText seules méthodes fiables détection fenêtres éphémères
- **Callback delegate** : EnumWindowsProc callback en C# pour énumération fenêtres
- **StringBuilder Win32** : GetWindowText requiert StringBuilder, pas String simple
- **Process monitoring** : Start-Process -PassThru requis pour monitoring HasExited + ExitCode

### Erreurs Courantes à Éviter
```powershell
# ❌ String directe avec GetWindowText
$text = [Win32API]::GetWindowText($handle, "", 256)

# ✅ StringBuilder requis Win32
$buffer = New-Object System.Text.StringBuilder(256)
[Win32API]::GetWindowText($handle, $buffer, $buffer.Capacity)
$text = $buffer.ToString()

# ❌ Processus sans monitoring
Start-Process $executable $args

# ✅ PassThru pour monitoring codes sortie + timing
$process = Start-Process $executable $args -PassThru
if ($process.HasExited -and $process.ExitCode -ne 0) { }
```

## ⚙️ GESTION SYSTÈME

### Détection AutoHotkey Hiérarchique
1. **Custom path** : Paramètre `-AhkExecutable` priorité absolue
2. **Portable OneDrive** : `%USERPROFILE%\OneDrive\Portable Softwares\Autohotkey scripts\`
3. **Système PATH** : `Get-Command "AutoHotkey.exe"`
4. **Standards Windows** : Program Files, Program Files (x86)

### Structure Portable Obligatoire
```
%USERPROFILE%\OneDrive\Portable Softwares\Autohotkey scripts\
├── AutohotkeyV1\AutoHotkeyU64.exe    # Version 1.1 Unicode 64-bit
└── AutohotkeyV2\AutoHotkey64.exe     # Version 2.0 64-bit
```

### Variables Système Utilisées
- `$env:USERNAME` : Construction chemins portables utilisateur
- `${env:ProgramFiles}` : Détection installations système
- `$env:PATH` : Recherche AutoHotkey.exe global

### Format Sortie Standardisé
```
STATUS: SUCCESS|ERROR
MESSAGE: [Description technique ou message erreur extrait]
TRAY_ICON: NOT_CHECKED|NOT_FOUND|FOUND
TIMESTAMP: yyyy-MM-dd HH:mm:ss
```

## 📊 WIN32 APIs & DÉTECTION ERREURS

### APIs Win32 Core Utilisées
- **`EnumWindows(callback, lParam)`** : Énumération toutes fenêtres top-level visibles
- **`GetWindowText(hWnd, StringBuilder, nMaxCount)`** : Extraction titre fenêtre
- **`IsWindowVisible(hWnd)`** : Validation visibilité fenêtre
- **`GetWindow(hWnd, uCmd)`** : Navigation contrôles enfants (GW_CHILD, GW_HWNDNEXT)

### Pattern Détection Erreurs AutoHotkey
```powershell
# Énumération fenêtres + callback C#
[Win32API]::EnumerateWindows()  # Static method clearing + EnumWindows

# Matching intelligent titre fenêtres
if ($title -eq $scriptName -or $title -eq $scriptBaseName) {
    $isErrorWindow = $true
}
# Mots-clés erreur avec filtrage longueur
elseif ($title -match "(?i)(error|erreur|syntax|autohotkey)" -and $title.Length -lt 100) {
    $isErrorWindow = $true
}

# Extraction récursive contrôles enfants
$childWindow = [Win32API]::GetWindow($WindowHandle, [Win32API]::GW_CHILD)
while ($childWindow -ne [IntPtr]::Zero) {
    # GetWindowText sur chaque contrôle enfant
    $childWindow = [Win32API]::GetWindow($childWindow, [Win32API]::GW_HWNDNEXT)
}
```

### Classes Fenêtres AutoHotkey Détectées
- **#32770** : Dialogue Windows standard (MessageBox, erreurs syntax)
- **AutoHotkeyGUI** : Fenêtres GUI AutoHotkey custom
- **Titre = nom script** : fenêtre_script.ahk pour erreurs runtime

## 🔄 WORKFLOW DÉVELOPPEMENT

### Tests et Validation AutoHotkey
- **test_simple_error.ahk** : `variable$ = "invalid"` (syntax V1 error)
- **test_success.ahk** : `MsgBox, Hello V1` (fonctionnel V1)
- **test_success_v2.ahk** : `MsgBox("Hello V2")` (fonctionnel V2)

### Commandes Validation Standard
```powershell
# Test erreur V1 - extraction message fenêtre
.\ahklauncher.ps1 tests\test_simple_error.ahk -AhkVersion V1 -Verbose

# Test succès V2 - validation détection version
.\ahklauncher.ps1 tests\test_success_v2.ahk -AhkVersion V2 -Verbose

# Mode simulation - validation sans exécution
.\ahklauncher.ps1 script.ahk -WhatIf -Verbose
```

### Debugging Fenêtres Erreurs
```powershell
# Verbose logging détection fenêtres
Write-Verbose "Found $([Win32API]::FoundWindows.Count) visible windows"
Write-Verbose "Inspecting window: '$title' (Handle: $($window.Handle))"
Write-Verbose "MATCH: Script name match for '$title'"

# Extraction debug contrôles enfants
Write-Verbose "Found child window text: '$text'"
```

## 🎨 INTERFACE LIGNE COMMANDE

### Paramètres Standard
```powershell
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ScriptPath,           # Chemin script .ahk à valider
    
    [int]$TimeoutMs = 3000,        # Timeout détection erreurs (ms)
    [switch]$WhatIf,               # Mode simulation sans exécution
    [string]$AhkExecutable = "",   # Chemin custom AutoHotkey.exe
    
    [ValidateSet("", "V1", "V2", "Auto")]
    [string]$AhkVersion = "Auto"   # Sélection version forcée
)
```

### Messages Utilisateur Standardisés
- **SUCCESS** : `"Script launched successfully (no error detected within timeout)"`
- **ERROR** : Message fenêtre erreur extrait directement AutoHotkey
- **CONFIG ERROR** : `"Script file not found: [path]"`, `"AutoHotkey executable not found"`

### Exit Codes Standardisés
- **0** : Succès - script validé sans erreur détectée
- **1** : Erreur détection - fenêtre erreur trouvée ou processus défaillant  
- **2** : Erreur configuration - fichier absent, AutoHotkey non trouvé

## 🔧 MAINTENANCE

### Gestion Erreurs Win32 APIs
```powershell
# Try-catch Win32 API calls
try {
    [Win32API]::EnumerateWindows()
    foreach ($window in [Win32API]::FoundWindows) {
        # Process windows safely
    }
} catch {
    Write-Verbose "Window enumeration failed: $($_.Exception.Message)"
    return $null
}

# Process exit code validation
if ($ahkProcess.HasExited -and $ahkProcess.ExitCode -ne 0) {
    $errorDetected = $true
    $errorMessage = "AutoHotkey process exited with error code: $($ahkProcess.ExitCode)"
}
```

### Performance Optimisations
- **Polling 50ms** : `Start-Sleep -Milliseconds 50` balance réactivité/performance
- **Timeout 3000ms** : Défaut optimal scripts AutoHotkey (lancement + détection erreur)
- **Early exit timing** : Processus < 500ms durée = probable erreur syntaxe
- **StringBuilder 256/512** : Taille buffer optimale fenêtres titre/contenu

### Intégrations Externes AutoHotkey
- **Versions portables** : Support installations utilisateur non-admin
- **MCP/LLM output** : Format machine-readable STATUS/MESSAGE/TIMESTAMP
- **CI/CD ready** : Exit codes + format sortie pour intégration pipelines
- **Cross-version** : V1 (legacy) + V2 (moderne) support unifié

### Évolution Architecture
- **Win32 API stability** : EnumWindows + GetWindowText APIs stables Windows
- **AutoHotkey compatibility** : Patterns détection fenêtres robustes V1/V2
- **PowerShell version** : Compatible 5.1+ (Windows natif) à PowerShell 7+
- **Extension patterns** : Ajout nouveaux mots-clés erreur ou classes fenêtres