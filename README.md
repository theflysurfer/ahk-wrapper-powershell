# AHK Wrapper PowerShell v1.4

> **Wrapper PowerShell pour exécution et monitoring des scripts AutoHotkey avec détection intelligente des erreurs, JSON output, logging automatique, et capture d'écran**

## 🚀 Utilisation Rapide

```powershell
# Exécuter un script AutoHotkey avec monitoring (format texte)
.\ahklauncher.ps1 "script.ahk" -Verbose

# Format JSON pour parsing automatique (LLM-friendly)
.\ahklauncher.ps1 "script.ahk" -OutputFormat JSON

# Avec log file automatique pour debugging
.\ahklauncher.ps1 "script.ahk" -LogFile

# Complet : JSON + logs + screenshot + timeout custom
.\ahklauncher.ps1 "script.ahk" -OutputFormat JSON -LogFile -Screenshot -TimeoutMs 2000

# Screenshot avec chemin personnalisé
.\ahklauncher.ps1 "script.ahk" -Screenshot -ScreenshotPath "C:\screenshots"
```

## ✅ Fonctionnalités v1.4

### Nouvelles fonctionnalités v1.4
- ✨ **Screenshot Capture** : `-Screenshot` capture automatiquement l'écran lors SUCCESS/ERROR
- ✨ **Custom Screenshot Path** : `-ScreenshotPath` pour dossier personnalisé (défaut: `screenshots/`)
- ✨ **Smart Naming** : Screenshots nommés `{script}_{timestamp}_{status}.png`
- ✨ **Resource Cleanup** : Libération automatique ressources GDI+
- ✨ **JSON Integration** : Chemin screenshot inclus dans output structuré

### Fonctionnalités v1.3
- ✨ **JSON Output Format** : `-OutputFormat JSON` pour parsing automatique (parfait pour LLM/CI)
- ✨ **Log File Automatique** : `-LogFile` génère logs détaillés dans `logs/` avec timestamps
- ✨ **Execution Time Tracking** : Temps d'exécution inclus dans output

### Détection Intelligente (v1.2+)
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

#### Format Texte (défaut)
```
STATUS: SUCCESS/ERROR
MESSAGE: [Contenu extrait ou message d'erreur]
TRAY_ICON: FOUND/NOT_FOUND/NOT_CHECKED
EXECUTION_TIME: 1234ms
```

#### Format JSON (v1.4+)
```json
{
  "status": "SUCCESS",
  "message": "Script launched successfully",
  "trayIcon": "FOUND",
  "timestamp": "2025-10-09 23:16:53",
  "executionTimeMs": 1234,
  "scriptPath": "C:\\path\\to\\script.ahk"
}
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
├── logs/ (auto-généré)       # Logs d'exécution\n├── screenshots/ (auto-généré) # Screenshots de validation\n└── README.md                 # Ce fichier
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

## 🤖 Pour Assistants IA (Claude Code / LLM)

### ⚠️ Problème fréquent : Interprétation incorrecte des timeouts

**Erreur commune des LLMs** :
```bash
# ❌ MAUVAIS : Timeout = on ne sait pas si succès ou erreur
timeout 3 && bin/AutoHotkey.exe script.ahk
# Résultat : "Command timed out" → LLM pense "ça marche" alors qu'il y a une erreur
```

**Pourquoi ?**
- Un timeout peut signifier :
  - ✅ GUI lancée avec succès (fenêtre ouverte)
  - ❌ MsgBox d'erreur affichée (fenêtre bloquante)
- **Impossible de distinguer sans lire l'output du wrapper**

### ✅ Workflow correct pour LLM

#### 1. **TOUJOURS capturer output + exit code**

**Recommandé v1.4 : Utiliser JSON output + screenshot**
```bash
# Dans Claude Code (Bash) - Format JSON
output=$(cd "path/to/wrapper" && powershell -ExecutionPolicy Bypass -File ahklauncher.ps1 \
    -ScriptPath "C:/path/to/script.ahk" \
    -AhkExecutable "C:/path/to/AutoHotkey.exe" \
    -AhkVersion "V2" \
    -OutputFormat JSON \
    -LogFile \
    -TimeoutMs 2000 2>&1)
exit_code=$?

echo "$output"
```

```powershell
# Dans PowerShell - Format JSON
$output = & .\ahklauncher.ps1 -ScriptPath "script.ahk" -OutputFormat JSON -LogFile -TimeoutMs 2000 2>&1
$exitCode = $LASTEXITCODE

# Parser JSON
$result = $output | ConvertFrom-Json
Write-Host "Status: $($result.status)"
Write-Host "Message: $($result.message)"
Write-Host "Execution time: $($result.executionTimeMs)ms"
```

#### 2. **Parser le format structuré**

**v1.3+ : Avec JSON (recommandé)**
```bash
# Bash - JSON parsing avec jq
status=$(echo "$output" | jq -r '.status')
message=$(echo "$output" | jq -r '.message')
exec_time=$(echo "$output" | jq -r '.executionTimeMs')

if [ "$status" = "ERROR" ]; then
    echo "❌ Erreur AHK: $message"
    exit 1
elif [ "$status" = "SUCCESS" ]; then
    echo "✅ Script OK: $message (${exec_time}ms)"
    exit 0
fi
```

```powershell
# PowerShell - JSON parsing natif
$result = $output | ConvertFrom-Json
if ($result.status -eq "ERROR") {
    Write-Error "Erreur AHK: $($result.message)"
    exit 1
} else {
    Write-Host "✅ Script OK: $($result.message) ($($result.executionTimeMs)ms)"
    exit 0
}
```

**Legacy : Format texte**
```bash
# Bash
status=$(echo "$output" | grep "STATUS:" | cut -d' ' -f2)
message=$(echo "$output" | grep "MESSAGE:" | cut -d' ' -f2-)
```

#### 3. **Table de décision rapide**

| Observation | Signification | Action LLM |
|-------------|---------------|------------|
| `STATUS: SUCCESS` + exit 0 | ✅ Script OK | Continuer |
| `STATUS: ERROR` + MESSAGE contient "Syntax error" + ligne | ❌ Erreur syntaxe | Corriger la ligne indiquée |
| `STATUS: ERROR` + MESSAGE contient "This Class cannot be used as output variable" | ❌ Nom réservé utilisé | Renommer (ex: `gui` → `mainGui`) |
| `STATUS: ERROR` + MESSAGE contient "for i := 1 to n" | ❌ Syntaxe AHK v1 dans script v2 | Remplacer par `Loop n` avec `A_Index` |
| `STATUS: ERROR` + MESSAGE contient boutons (&Abort, &Help, &Edit) | ❌ Fenêtre d'erreur détectée | Lire le message complet dans MESSAGE |
| Timeout sans STATUS | ⚠️ Ambigu | Relancer avec `-Verbose` pour diagnostic |
| Exit 2 + MESSAGE "not found" | ❌ Fichier ou AHK absent | Vérifier les chemins |

#### 4. **Erreurs AHK typiques et leurs solutions**

| MESSAGE contient | Problème | Solution |
|-----------------|----------|----------|
| `Syntax error` + `for i := 1 to n` | Boucle v1 dans script v2 | Remplacer par `Loop n { i := A_Index ... }` |
| `This Class cannot be used as output variable` + `Specifically: Gui` | Variable `gui` = nom de classe | Renommer : `gui` → `mainGui` |
| `Error: Illegal assignment` + `global gui := ""` | Même problème | Utiliser autre nom de variable |
| `Unrecognized action` | Syntaxe incorrecte | Vérifier documentation AHK v2 |
| `Access Violation` | Erreur mémoire/DllCall | Vérifier les appels DLL |

#### 5. **Checklist pré-commit pour LLM**

Avant tout commit de code AutoHotkey :

- [ ] 1. Lancer wrapper avec timeout approprié (2-3 sec pour GUI, 1 sec pour syntax check)
- [ ] 2. Capturer output complet (pas juste timeout/exit code)
- [ ] 3. Vérifier que `STATUS: SUCCESS` est présent
- [ ] 4. Si `STATUS: ERROR` → lire MESSAGE, corriger, re-tester
- [ ] 5. Si timeout sans STATUS → relancer avec `-Verbose` pour comprendre
- [ ] 6. Valider exit code = 0
- [ ] 7. (Optionnel v1.4+) Prendre screenshot avec `-Screenshot` pour validation visuelle

#### 6. **Exemples concrets de débogage**

##### Cas réel 1 : Variable `gui` interdite
```
Input : gui := ""
Output : STATUS: ERROR
         MESSAGE: WorkspaceManager.ahk | Error: This Class cannot be used as output variable. | Specifically: Gui | 021: workspaces := Map() | 022: activeWorkspaces := Map() | 023: gui := "" | &Abort | &Help | &Edit | &Reload | E&xitApp | &Continue

Action LLM :
1. Identifier : "gui := ''" ligne 023
2. Comprendre : Gui est un nom de classe réservé en AHK v2
3. Corriger : Renommer toutes les occurences gui → mainGui
4. Re-tester : Lancer wrapper → STATUS: SUCCESS
```

##### Cas réel 2 : Boucle v1 dans script v2
```
Input : for i := 1 to n - 1 {
Output : STATUS: ERROR
         MESSAGE: SessionManager.ahk | Syntax error. | Text: for i := 1 to n - 1 { | Line: 140

Action LLM :
1. Identifier : Ligne 140 = syntaxe "for ... to" n'existe pas en v2
2. Comprendre : AHK v2 utilise Loop avec A_Index
3. Corriger :
   for i := 1 to n - 1 {  →  Loop n - 1 {
                                i := A_Index
4. Re-tester → STATUS: SUCCESS
```

#### 7. **Mode Verbose : Quand l'utiliser**

Utiliser `-Verbose` quand :
- Timeout sans message STATUS
- Besoin de comprendre quelles fenêtres sont détectées
- Debugging de faux positifs/négatifs

```powershell
.\ahklauncher.ps1 -ScriptPath "script.ahk" -TimeoutMs 2000 -Verbose
```

Logs verbose montrent :
```
Enumerating all visible windows...
Found 45 visible windows
Inspecting window: 'WorkspaceManager.ahk' (Handle: 123456)
POTENTIAL: Script name match for 'WorkspaceManager.ahk' - checking if error window...
Window buttons found: &Abort, &Help, &Edit, &Reload, E&xitApp, &Continue | Error buttons: 6/6 | IsError: true
CONFIRMED: This is an error window with buttons
```

→ Permet de comprendre pourquoi une fenêtre est classée ERROR vs SUCCESS

#### 8. **Intégration avec hooks Claude Code**

Créer `.claude/hooks/pre-commit.ps1` :
```powershell
# Auto-validation avant commit
$ahkFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -like "*.ahk" }

foreach ($file in $ahkFiles) {
    Write-Host "Validating $file..."
    $output = & "path/to/ahklauncher.ps1" -ScriptPath $file -TimeoutMs 2000 2>&1
    $status = ($output | Select-String "STATUS: (.+)").Matches.Groups[1].Value

    if ($status -eq "ERROR") {
        Write-Error "❌ Pre-commit blocked: $file has errors"
        Write-Error ($output | Select-String "MESSAGE:").Line
        exit 1
    }
}

Write-Host "✅ All AHK files validated"
```

---

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

### v1.4 (Actuel) - Screenshot Capture
- ✨ **Screenshot Capture** : `-Screenshot` pour capturer l'écran automatiquement
- ✨ **Custom Path** : `-ScreenshotPath` pour dossier personnalisé
- ✨ **Smart Naming** : `{script}_{timestamp}_{status}.png`
- ✨ **JSON Integration** : Chemin screenshot dans output structuré
- ✨ **WindowHandle Support** : WindowHandle intégré dans retours SUCCESS/ERROR pour screenshots ciblés
- ✅ **Resource Management** : Libération propre des ressources GDI+
- ✅ **V1 + V2 Compatible** : Fenêtres d'erreur identiques, détection automatique\n\n### v1.3 (Précédent) - JSON Output + Auto Logging
- ✨ **JSON Output Format** : `-OutputFormat JSON` pour parsing automatique
- ✨ **Log File Automatique** : `-LogFile` crée logs détaillés dans `logs/`
- ✨ **Execution Time Tracking** : Temps d'exécution en millisecondes
- ✅ **Amélioration LLM** : Section documentation dédiée aux assistants IA

### v1.2 - Corrections Critiques
- ✅ **Isolation processus complète** : Fini les erreurs PowerShell
- ✅ **Détection intelligente** : SUCCESS vs ERROR basé sur boutons de fenêtres
- ✅ **Extraction texte universelle** : Messages complets pour diagnostic

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

**AHK Wrapper PowerShell v1.4** - Monitoring fiable des scripts AutoHotkey avec détection intelligente et capture d'écran
