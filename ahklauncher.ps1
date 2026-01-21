param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ScriptPath,

    [Parameter(Mandatory=$false)]
    [int]$TimeoutMs = 3000,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [string]$AhkExecutable = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("", "V1", "V2", "Auto")]
    [string]$AhkVersion = "Auto",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Text", "JSON")]
    [string]$OutputFormat = "Text",

    [Parameter(Mandatory=$false)]
    [switch]$LogFile,

    [Parameter(Mandatory=$false)]
    [switch]$Screenshot,

    [Parameter(Mandatory=$false)]
    [string]$ScreenshotPath = ""
)

# AHK Launcher PowerShell - Script Validation AutoHotkey avec Extraction Erreurs
# Version: 1.5 - Smart Error Extraction with Window Class Detection
# Objectif: Validation rapide scripts AHK + extraction erreurs intelligente via APIs Windows
# v1.5: Smart error extraction - separate error content from buttons using GetClassName
# v1.4: JSON output format + automatic log file generation + screenshot capture

# Add-Type pour APIs Windows necessaires + EnumWindows fonctionnel
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class Win32API {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    // GetWindow constants
    public const uint GW_CHILD = 5;
    public const uint GW_HWNDNEXT = 2;

    // EnumWindows delegate et fonction
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    // Screenshot APIs - Capture de fenÃªtre spÃ©cifique
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    public const uint PW_CLIENTONLY = 0x00000001;
    public const uint PW_RENDERFULLCONTENT = 0x00000002;

    // Classe pour collecter les fenetres trouvees
    public static List<WindowInfo> FoundWindows = new List<WindowInfo>();

    public static bool EnumWindowCallback(IntPtr hWnd, IntPtr lParam)
    {
        if (IsWindowVisible(hWnd))
        {
            StringBuilder sb = new StringBuilder(256);
            int length = GetWindowText(hWnd, sb, sb.Capacity);
            if (length > 0)
            {
                FoundWindows.Add(new WindowInfo { Handle = hWnd, Title = sb.ToString() });
            }
        }
        return true; // Continue enumeration
    }

    public static void EnumerateWindows()
    {
        FoundWindows.Clear();
        EnumWindows(EnumWindowCallback, IntPtr.Zero);
    }
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;

    public int Width { get { return Right - Left; } }
    public int Height { get { return Bottom - Top; } }
}

public class WindowInfo
{
    public IntPtr Handle { get; set; }
    public string Title { get; set; }
}
'@

# Add-Type pour screenshot - System.Drawing et System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Write-StructuredOutput {
    param(
        [string]$Status,
        [string]$Message,
        [hashtable]$ErrorDetails = $null,
        [string]$WindowHandle = "",
        [string]$TrayIcon = "NOT_CHECKED",
        [string]$Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        [int]$ExecutionTimeMs = 0,
        [string]$Format = "Text",
        [string]$ScreenshotFile = ""
    )

    if ($Format -eq "JSON") {
        $result = @{
            status = $Status
            message = $Message
            trayIcon = $TrayIcon
            timestamp = $Timestamp
            executionTimeMs = $ExecutionTimeMs
            scriptPath = $ScriptPath
        }

        # v1.5: Add structured error details
        if ($ErrorDetails) {
            $result.errorDetails = $ErrorDetails
        }

        if ($WindowHandle) {
            $result.windowHandle = $WindowHandle
        }

        if ($ScreenshotFile) {
            $result.screenshot = $ScreenshotFile
        }

        Write-Output ($result | ConvertTo-Json -Depth 5 -Compress)
    } else {
        Write-Output "STATUS: $Status"
        Write-Output "MESSAGE: $Message"
        if ($ErrorDetails) {
            Write-Output "ERROR_DETAILS: $($ErrorDetails | ConvertTo-Json -Compress)"
        }
        Write-Output "TRAY_ICON: $TrayIcon"
        Write-Output "TIMESTAMP: $Timestamp"
        if ($ExecutionTimeMs -gt 0) {
            Write-Output "EXECUTION_TIME: ${ExecutionTimeMs}ms"
        }
        if ($ScreenshotFile) {
            Write-Output "SCREENSHOT: $ScreenshotFile"
        }
    }
}

# Global log file path (si activÃ©)
$global:LogFilePath = $null

function Write-LogFile {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    if ($global:LogFilePath -and $LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $global:LogFilePath -Value $logEntry -Encoding UTF8
    }
}

function Initialize-LogFile {
    if ($LogFile) {
        $logDir = Join-Path $PSScriptRoot "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $global:LogFilePath = Join-Path $logDir "${scriptBaseName}_${timestamp}.log"

        Write-LogFile "=== AHK Launcher v1.5 ===" "INFO"
        Write-LogFile "Script: $ScriptPath" "INFO"
        Write-LogFile "Timeout: ${TimeoutMs}ms" "INFO"
        Write-LogFile "AHK Version: $AhkVersion" "INFO"
        Write-LogFile "Output Format: $OutputFormat" "INFO"
        Write-LogFile "=========================" "INFO"
    }
}

# v1.2 CORRECTION CRITIQUE: Fonction pour dÃ©tecter les vrais boutons d'erreur AutoHotkey
function Test-WindowHasErrorButtons {
    param(
        [IntPtr]$WindowHandle,
        [string[]]$ErrorButtons = @("&Abort", "&Help", "&Edit", "&Reload", "E&xitApp", "&Continue")
    )
    
    try {
        # v1.2 CORRECTION CRITIQUE: Utiliser GetWindow pour parcourir les enfants
        # au lieu d'une fonction GetChildWindows inexistante
        $allChildTexts = @()
        
        # Obtenir le premier enfant
        $childHandle = [Win32API]::GetWindow($WindowHandle, [Win32API]::GW_CHILD)
        
        # Parcourir tous les enfants
        while ($childHandle -ne [IntPtr]::Zero) {
            $buffer = New-Object System.Text.StringBuilder(256)
            $length = [Win32API]::GetWindowText($childHandle, $buffer, $buffer.Capacity)
            if ($length -gt 0) {
                $text = $buffer.ToString().Trim()
                if ($text.Length -gt 0) {
                    $allChildTexts += $text
                }
            }
            
            # Passer au sibling suivant
            $childHandle = [Win32API]::GetWindow($childHandle, [Win32API]::GW_HWNDNEXT)
        }
        
        # VÃ©rifier si on a au moins 3 boutons d'erreur typiques AutoHotkey
        $errorButtonsFound = 0
        foreach ($buttonText in $ErrorButtons) {
            if ($allChildTexts -contains $buttonText) {
                $errorButtonsFound++
            }
        }
        
        # Une vraie fenÃªtre d'erreur AutoHotkey a gÃ©nÃ©ralement 3+ boutons spÃ©cifiques
        $isErrorWindow = $errorButtonsFound -ge 3
        
        Write-Verbose "Window buttons found: $($allChildTexts -join ', ') | Error buttons: $errorButtonsFound/$($ErrorButtons.Count) | IsError: $isErrorWindow"
        return $isErrorWindow

    } catch {
        Write-Verbose "Error checking window buttons: $($_.Exception.Message)"
        return $false
    }
}

# v1.6: Fonction pour détecter une fenêtre SUCCESS (fenêtre du script SANS contenu erreur)
function Test-WindowIsSuccess {
    param(
        [string]$ScriptName
    )

    try {
        # Énumérer toutes les fenêtres visibles via Win32API
        [Win32API]::EnumerateWindows()

        foreach ($win in [Win32API]::FoundWindows) {
            # Vérifier si le titre contient le nom du script
            if ($win.Title -like "*$ScriptName*") {
                # Vérifier que ce n'est PAS une fenêtre d'erreur via les boutons
                $hasErrorButtons = Test-WindowHasErrorButtons -WindowHandle $win.Handle

                if ($hasErrorButtons) {
                    Write-Verbose "Window has error buttons, skipping: $($win.Title)"
                    continue
                }

                # v1.6.1: Vérifier aussi le CONTENU textuel pour détecter les erreurs sans boutons typiques
                # (ex: "Error at line", "requires AutoHotkey v2", etc.)
                $windowText = Get-WindowTextRecursive -WindowHandle $win.Handle
                $hasErrorContent = $false

                if ($windowText) {
                    # Patterns d'erreur AHK (même sans boutons d'erreur typiques)
                    $errorPatterns = @(
                        "(?i)Error at line",
                        "(?i)Error in #include",
                        "(?i)requires AutoHotkey",
                        "(?i)syntax error",
                        "(?i)runtime error",
                        "(?i)fatal error",
                        "(?i)access violation",
                        "(?i)division by zero",
                        "(?i)invalid memory",
                        "(?i)The program will exit",
                        "(?i)Script exited",
                        "(?i)Current interpreter:"
                    )

                    foreach ($pattern in $errorPatterns) {
                        if ($windowText -match $pattern) {
                            Write-Verbose "Window contains error text pattern '$pattern': $windowText"
                            $hasErrorContent = $true
                            break
                        }
                    }
                }

                if (-not $hasErrorContent) {
                    Write-Verbose "SUCCESS window found: $($win.Title) (Handle: $($win.Handle))"
                    return @{
                        Found = $true
                        Handle = $win.Handle
                        Title = $win.Title
                    }
                } else {
                    Write-Verbose "Window has error content, not SUCCESS: $($win.Title)"
                }
            }
        }

        return @{ Found = $false }

    } catch {
        Write-Verbose "Error checking for success window: $($_.Exception.Message)"
        return @{ Found = $false }
    }
}

function Test-AutohotkeyAvailable {
    param(
        [string]$CustomPath = "",
        [string]$PreferredVersion = "Auto"
    )
    
    # Si un chemin custom est specifie, l'utiliser en priorite
    if ($CustomPath -and (Test-Path $CustomPath)) {
        return $CustomPath
    }
    
    # 1. Recherche dans PATH systeme (standard)
    try {
        $ahkCommand = Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue
        if ($ahkCommand -and $PreferredVersion -eq "Auto") {
            Write-Verbose "Found AutoHotkey in PATH: $($ahkCommand.Source)"
            return $ahkCommand.Source
        }
    }
    catch {
        Write-Verbose "No AutoHotkey found in PATH"
    }    
    # 2. Recherche versions portables dans OneDrive
    $portableBasePath = "C:\Users\$env:USERNAME\OneDrive\Portable Softwares\Autohotkey scripts"
    
    # Selon la version preferee ou detecter automatiquement
    if ($PreferredVersion -eq "V1") {
        $v1Path = "$portableBasePath\AutohotkeyV1\AutoHotkeyU64.exe"
        if (Test-Path $v1Path) {
            Write-Verbose "Found portable AutoHotkey V1 : $v1Path"
            return $v1Path
        }
    }
    elseif ($PreferredVersion -eq "V2") {
        $v2Path = "$portableBasePath\AutohotkeyV2\AutoHotkey64.exe"
        if (Test-Path $v2Path) {
            Write-Verbose "Found portable AutoHotkey V2 : $v2Path"
            return $v2Path
        }
    }
    else {
        # Auto detection - chercher V2 puis V1
        $v2Path = "$portableBasePath\AutohotkeyV2\AutoHotkey64.exe"
        if (Test-Path $v2Path) {
            Write-Verbose "Found portable AutoHotkey V2 : $v2Path"
            return $v2Path
        }
        
        $v1Path = "$portableBasePath\AutohotkeyV1\AutoHotkeyU64.exe"
        if (Test-Path $v1Path) {
            Write-Verbose "Found portable AutoHotkey V1 : $v1Path"
            return $v1Path
        }
    }
    
    # 3. Fallback: emplacements standards Windows
    $standardPaths = @(
        "${env:ProgramFiles}\AutoHotkey\AutoHotkey.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe",
        ".\AutoHotkey.exe"
    )
    
    foreach ($path in $standardPaths) {
        if (Test-Path $path) {
            Write-Verbose "Found AutoHotkey in standard location: $path"
            return $path
        }
    }
    
    return $null
}

function Get-ErrorWindowText {
    # NOUVELLE APPROCHE: Enumeration complete et efficace de toutes les fenetres
    Write-Verbose "Enumerating all visible windows using Win32API.EnumerateWindows()..."
    
    try {
        # Vider la liste et enumerer toutes les fenetres visibles
        [Win32API]::EnumerateWindows()
        
        # Nom du script pour recherche ciblee
        $scriptName = Split-Path -Leaf $ScriptPath
        $scriptBaseName = $scriptName.Replace(".ahk", "")
        
        Write-Verbose "Found $([Win32API]::FoundWindows.Count) visible windows"        
        # Chercher les fenetres qui correspondent a notre script d'erreur
        foreach ($window in [Win32API]::FoundWindows) {
            $title = $window.Title
            Write-Verbose "Inspecting window: '$title' (Handle: $($window.Handle))"
            
            # Correspondances possibles pour fenetres d'erreur AutoHotkey
            $isErrorWindow = $false
            
            # 1. Titre exact = nom du script ET vÃ©rifier si c'est vraiment une erreur
            if ($title -eq $scriptName -or $title -eq $scriptBaseName) {
                Write-Verbose "POTENTIAL: Script name match for '$title' - checking if error window..."
                # Extraire le texte pour vÃ©rifier si c'est une vraie erreur
                $fullText = Get-WindowTextRecursive -WindowHandle $window.Handle
                if ($fullText -and ($fullText -match "(?i)(&Abort|&Help|&Edit|&Reload|E&xitApp|&Continue|Error|Erreur|Fatal|Syntax|Runtime|Access Violation|Division by zero|Invalid memory)")) {
                    Write-Verbose "CONFIRMED: This is an error window with buttons: '$fullText'"
                    $isErrorWindow = $true
                } else {
                    Write-Verbose "IGNORED: Script window but not error (normal script window): '$fullText'"
                    $isErrorWindow = $false
                }
            }
            # 2. Titre contient des mots-cles d'erreur MAIS pas l'Explorateur
            elseif ($title -match "(?i)(error|erreur|syntax|fatal|runtime|access.violation|division.by.zero|invalid.memory)" -and 
                    $title -notmatch "(?i)(explorateur|file explorer|chrome|notepad|visual studio|teams)" -and 
                    $title.Length -lt 100) {
                Write-Verbose "MATCH: Error keyword match for '$title'"
                $isErrorWindow = $true
            }
            # 2bis. AutoHotkey spÃ©cifique (mais pas Explorateur de fichiers)
            elseif ($title -match "(?i)autohotkey" -and 
                    $title -notmatch "(?i)(explorateur|file explorer|scripts.*explorateur)" -and 
                    $title.Length -lt 80) {
                Write-Verbose "MATCH: AutoHotkey specific match for '$title'"
                $isErrorWindow = $true
            }
            # 3. Titre contient le nom du script - VÉRIFICATION INTELLIGENTE v1.6
            elseif ($title.Contains($scriptBaseName) -and $title.Length -lt 100) {
                Write-Verbose "POTENTIAL: Script basename match for '$title' - checking if error window..."

                # v1.2: Vérifier si c'est vraiment une erreur via les boutons
                $hasErrorButtons = Test-WindowHasErrorButtons -WindowHandle $window.Handle

                if ($hasErrorButtons) {
                    Write-Verbose "CONFIRMED: This is an error window with buttons: '$title'"
                    $isErrorWindow = $true
                } else {
                    # v1.6: Vérifier aussi le CONTENU textuel pour détecter les erreurs sans boutons typiques
                    $windowText = Get-WindowTextRecursive -WindowHandle $window.Handle
                    $hasErrorContent = $false

                    if ($windowText) {
                        # Patterns d'erreur AHK (même sans boutons d'erreur typiques)
                        $errorPatterns = @(
                            "(?i)Error at line",
                            "(?i)Error in #include",
                            "(?i)requires AutoHotkey",
                            "(?i)syntax error",
                            "(?i)runtime error",
                            "(?i)fatal error",
                            "(?i)access violation",
                            "(?i)division by zero",
                            "(?i)invalid memory",
                            "(?i)The program will exit",
                            "(?i)Script exited",
                            "(?i)Current interpreter:"
                        )

                        foreach ($pattern in $errorPatterns) {
                            if ($windowText -match $pattern) {
                                Write-Verbose "Window contains error text pattern '$pattern': $windowText"
                                $hasErrorContent = $true
                                break
                            }
                        }
                    }

                    if ($hasErrorContent) {
                        Write-Verbose "CONFIRMED: This is an error window with error text content: '$title'"
                        $isErrorWindow = $true
                    } else {
                        Write-Verbose "SUCCESS: This is a normal script window, not an error: '$title'"
                        # C'est une fenêtre normale du script = SUCCESS
                        return @{Status="SUCCESS"; Message="Script window detected: $title"; WindowType="SUCCESS_WINDOW"; WindowHandle=$window.Handle}
                    }
                }
            }
            # 4. DÃ‰SACTIVÃ‰E TEMPORAIREMENT: DÃ©tection gÃ©nÃ©rale trop permissive (faux positifs)
            # elseif ($title.Length -gt 3 -and $title.Length -lt 80 -and 
            #         $title -notmatch "(?i)(explorateur|file explorer|chrome|notepad|visual studio|teams|outlook|program manager|_WINDOWTOP_|experience|paramÃ¨tres|settings|calendar|mail|teams|courrier|julien|fernandez|elyse|energy|intralinks|project)" -and
            #         $title -notmatch "(?i)(error|erreur|syntax|fatal|runtime|access.violation|division.by.zero|invalid.memory|microsoft|windows|office)" -and
            #         $title -notmatch "(?i)(id \d+|pid \d+|did \d+|handle: \d+|@)" -and
            #         $title -ne "Program Manager") {
            #     Write-Verbose "POTENTIAL: General MsgBox candidate '$title' - checking if error window..."
                
            #     # VÃ©rifier si c'est une fenÃªtre d'erreur AutoHotkey via les boutons
            #     $hasErrorButtons = Test-WindowHasErrorButtons -WindowHandle $window.Handle
                
            #     if ($hasErrorButtons) {
            #         Write-Verbose "CONFIRMED: This is an error window with AutoHotkey buttons: '$title'"
            #         $isErrorWindow = $true
            #     } else {
            #         Write-Verbose "SUCCESS: General MsgBox detected as SUCCESS window: '$title'"
            #         # C'est probablement une MsgBox normale = SUCCESS
            #         return @{Status="SUCCESS"; Message="Script window detected: $title"; WindowType="SUCCESS_MSGBOX"}
            #     }
            # }
            
            if ($isErrorWindow) {
                Write-Verbose "Potential error window found: '$title' - extracting smart text..."

                # v1.5: Use smart extraction with control class detection
                $smartResult = Get-WindowTextSmart -WindowHandle $window.Handle

                # Build comprehensive error message from smart extraction
                $errorMessage = ""
                if ($smartResult.errorContent.Count -gt 0) {
                    $errorMessage = $smartResult.errorContent -join "`n"
                }
                if ($smartResult.sourceCode.Count -gt 0) {
                    if ($errorMessage) { $errorMessage += "`n`n" }
                    $errorMessage += "Source Code:`n" + ($smartResult.sourceCode -join "`n")
                }

                if ($errorMessage -and $errorMessage.Length -gt 10) {
                    Write-Verbose "Successfully extracted smart error text: $($smartResult.errorContent.Count) error lines, $($smartResult.sourceCode.Count) source lines"
                    return @{
                        Status="ERROR"
                        Message=$errorMessage
                        ErrorDetails=$smartResult
                        WindowType="ERROR_WINDOW"
                        WindowHandle=$window.Handle
                    }
                }
                else {
                    Write-Verbose "Could not extract meaningful text from error window, falling back to simple extraction"
                    # Fallback: utiliser méthode simple
                    $fullText = Get-WindowTextRecursive -WindowHandle $window.Handle
                    if ($fullText) {
                        return @{Status="ERROR"; Message=$fullText; WindowType="ERROR_WINDOW"; WindowHandle=$window.Handle}
                    } else {
                        return @{Status="ERROR"; Message="Error detected in window: $title"; WindowType="ERROR_WINDOW"; WindowHandle=$window.Handle}
                    }
                }
            }
        }        
        Write-Verbose "No error windows found matching script '$scriptName'"
        return $null
        
    }
    catch {
        Write-Verbose "Window enumeration failed: $($_.Exception.Message)"
        return $null
    }
}

# v1.5: Smart text extraction with control class detection
function Get-WindowTextSmart {
    param([IntPtr]$WindowHandle)

    $result = @{
        title = ""
        errorContent = @()
        sourceCode = @()
        buttons = @()
    }

    # Titre de la fenêtre
    $titleBuffer = New-Object System.Text.StringBuilder(512)
    [Win32API]::GetWindowText($WindowHandle, $titleBuffer, $titleBuffer.Capacity) | Out-Null
    $result.title = $titleBuffer.ToString()

    # Parcourir tous les contrôles enfants
    $childWindow = [Win32API]::GetWindow($WindowHandle, [Win32API]::GW_CHILD)
    $orderIndex = 0

    while ($childWindow -ne [IntPtr]::Zero) {
        # Obtenir la classe du contrôle
        $classBuffer = New-Object System.Text.StringBuilder(256)
        [Win32API]::GetClassName($childWindow, $classBuffer, $classBuffer.Capacity) | Out-Null
        $className = $classBuffer.ToString()

        # Obtenir le texte du contrôle (buffer plus grand pour Edit)
        $textBuffer = New-Object System.Text.StringBuilder(4096)
        $textLength = [Win32API]::GetWindowText($childWindow, $textBuffer, $textBuffer.Capacity)

        if ($textLength -gt 0) {
            $text = $textBuffer.ToString().Trim()

            Write-Verbose "Control [$orderIndex]: Class='$className', Text='$text'"

            # Classifier selon le type de contrôle
            if ($className -eq "Button") {
                # C'est un bouton
                if ($text -match "^(&Abort|&Help|&Edit|&Reload|E&xitApp|&Continue)$") {
                    $result.buttons += $text
                }
            }
            elseif ($className -eq "Static") {
                # C'est un contrôle Static (texte statique, peut être multiline)
                if ($text.Length -gt 3 -and $text -notmatch "^(OK|Cancel)$") {
                    # Split by newlines to process each line individually
                    $lines = $text -split "`r?`n"
                    foreach ($line in $lines) {
                        $line = $line.Trim()
                        if ($line.Length -gt 0) {
                            # Identifier si c'est du code source (ligne commençant par numéro)
                            if ($line -match "^\s*\d{3,4}:" -or $line -match "^--->\s*\d{3,4}:") {
                                $result.sourceCode += $line
                            } elseif ($line -notmatch "^(Line#|Line\s*#)$") {
                                # Ignorer les séparateurs comme "Line#"
                                $result.errorContent += $line
                            }
                        }
                    }
                }
            }
            elseif ($className -eq "Edit") {
                # C'est un contrôle Edit (peut contenir code source multilignes)
                $lines = $text -split "`r?`n"
                foreach ($line in $lines) {
                    $line = $line.Trim()
                    if ($line.Length -gt 0) {
                        if ($line -match "^\s*\d{3,4}:") {
                            $result.sourceCode += $line
                        } else {
                            $result.errorContent += $line
                        }
                    }
                }
            }
        }

        $childWindow = [Win32API]::GetWindow($childWindow, [Win32API]::GW_HWNDNEXT)
        $orderIndex++
    }

    Write-Verbose "Smart extraction result: $($result.errorContent.Count) error lines, $($result.sourceCode.Count) source lines, $($result.buttons.Count) buttons"
    return $result
}

function Get-WindowTextRecursive {
    param([IntPtr]$WindowHandle)

    $allText = ""

    # Texte de la fenetre principale
    $buffer = New-Object System.Text.StringBuilder(512)
    $length = [Win32API]::GetWindowText($WindowHandle, $buffer, $buffer.Capacity)
    if ($length -gt 0) {
        $mainText = $buffer.ToString()
        if ($mainText -and $mainText -notmatch "^(OK|Cancel|&OK|&Cancel)$") {
            $allText += $mainText + " | "
        }
    }

    # Parcourir tous les controles enfants
    $childWindow = [Win32API]::GetWindow($WindowHandle, [Win32API]::GW_CHILD)

    while ($childWindow -ne [IntPtr]::Zero) {
        $buffer = New-Object System.Text.StringBuilder(512)
        $length = [Win32API]::GetWindowText($childWindow, $buffer, $buffer.Capacity)

        if ($length -gt 0) {
            $text = $buffer.ToString().Trim()
            Write-Verbose "Found child window text: '$text'"
            # Filtrer le texte significatif
            if ($text -and $text.Length -gt 3 -and $text -notmatch "^(OK|Cancel|&OK|&Cancel|Button)$") {
                $allText += $text + " | "
            }
        }

        $childWindow = [Win32API]::GetWindow($childWindow, [Win32API]::GW_HWNDNEXT)
    }

    # Nettoyer et retourner le texte
    $allText = $allText.TrimEnd(" | ").Trim()
    if ($allText) {
        return $allText
    } else {
        return $null
    }
}

function Test-TrayIconPresent {
    # Implementation basique : verifier si des processus AutoHotkey sont toujours actifs
    $ahkProcesses = Get-Process | Where-Object { $_.ProcessName -like "*AutoHotkey*" }
    if ($ahkProcesses -and $ahkProcesses.Count -gt 0) {
        return "FOUND"
    }
    return "NOT_FOUND"
}

function Take-Screenshot {
    param(
        [string]$OutputPath,
        [string]$ScriptName,
        [string]$Status,
        [IntPtr]$WindowHandle = [IntPtr]::Zero
    )

    try {
        Write-Verbose "Taking screenshot..."
        Write-LogFile "Taking screenshot (WindowHandle: $WindowHandle)" "INFO"

        # CrÃ©er le dossier screenshots si nÃ©cessaire
        $screenshotDir = if ($OutputPath) { $OutputPath } else { Join-Path $PSScriptRoot "screenshots" }
        if (-not (Test-Path $screenshotDir)) {
            New-Item -ItemType Directory -Path $screenshotDir -Force | Out-Null
            Write-Verbose "Created screenshot directory: $screenshotDir"
        }

        # GÃ©nÃ©rer nom de fichier avec timestamp et status
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "${ScriptName}_${timestamp}_${Status}.png"
        $fullPath = Join-Path $screenshotDir $filename

        # Si handle fourni, capturer la fenÃªtre spÃ©cifique
        if ($WindowHandle -ne [IntPtr]::Zero) {
            Write-Verbose "Capturing specific window (Handle: $WindowHandle)"

            # Obtenir dimensions de la fenÃªtre
            $rect = New-Object RECT
            $success = [Win32API]::GetWindowRect($WindowHandle, [ref]$rect)

            if (-not $success -or $rect.Width -le 0 -or $rect.Height -le 0) {
                Write-Verbose "Invalid window dimensions, falling back to full screen"
                throw "Invalid window rect"
            }

            # CrÃ©er bitmap aux dimensions de la fenÃªtre
            $bitmap = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $hdc = $graphics.GetHdc()

            # PrintWindow capture la fenÃªtre mÃªme si sur autre bureau virtuel
            $printed = [Win32API]::PrintWindow($WindowHandle, $hdc, [Win32API]::PW_RENDERFULLCONTENT)

            $graphics.ReleaseHdc($hdc)

            if (-not $printed) {
                Write-Verbose "PrintWindow failed, trying GDI capture"
                # Fallback: copier depuis DC de la fenÃªtre
                $srcDC = [Win32API]::GetDC($WindowHandle)
                $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($rect.Width, $rect.Height))
                [Win32API]::ReleaseDC($WindowHandle, $srcDC) | Out-Null
            }

            # Sauvegarder en PNG haute qualitÃ©
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 95)
            $pngEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/png" }

            $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)

            # LibÃ©rer ressources
            $graphics.Dispose()
            $bitmap.Dispose()

            Write-Verbose "Window screenshot saved: $fullPath ($($rect.Width)x$($rect.Height))"
            Write-LogFile "Window screenshot saved: $fullPath" "INFO"
        }
        else {
            Write-Verbose "No window handle provided, capturing full screen"

            # Capturer l'Ã©cran complet (fallback)
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen
            $bounds = $screen.Bounds
            $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
            $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $graphics.Dispose()
            $bitmap.Dispose()

            Write-Verbose "Full screen screenshot saved: $fullPath"
            Write-LogFile "Full screen screenshot saved: $fullPath" "INFO"
        }

        return $fullPath
    }
    catch {
        Write-Verbose "Error taking screenshot: $($_.Exception.Message)"
        Write-LogFile "Error taking screenshot: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# MAIN WORKFLOW
try {
    # Initialize log file if requested
    Initialize-LogFile

    Write-Verbose "Starting AHK Launcher v1.5 - Script: $ScriptPath, Timeout: ${TimeoutMs}ms"
    Write-LogFile "Starting AHK Launcher v1.5" "INFO"

    # Track execution time
    $global:ExecutionStartTime = Get-Date

    # Initialize screenshot path, error window handle, and error details
    $global:ScreenshotPath = $null
    $global:ErrorWindowHandle = [IntPtr]::Zero
    $global:ErrorDetails = $null
    $scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $ScriptPath))

    # 1. VALIDATION PARAMETRES
    if (-not (Test-Path $ScriptPath)) {
        Write-LogFile "Script file not found: $ScriptPath" "ERROR"
        Write-StructuredOutput -Status "ERROR" -Message "Script file not found: $ScriptPath" -Format $OutputFormat
        exit 2
    }

    $ScriptPath = Resolve-Path $ScriptPath
    Write-Verbose "Resolved script path: $ScriptPath"
    Write-LogFile "Resolved script path: $ScriptPath" "INFO"    
    # 2. DETECTION AUTOHOTKEY
    $ahkExecutable = Test-AutohotkeyAvailable -CustomPath $AhkExecutable -PreferredVersion $AhkVersion
    if (-not $ahkExecutable) {
        Write-LogFile "AutoHotkey executable not found" "ERROR"
        Write-StructuredOutput -Status "ERROR" -Message "AutoHotkey executable not found in PATH, portable locations, or custom path" -Format $OutputFormat
        exit 2
    }

    Write-Verbose "Found AutoHotkey: $ahkExecutable"
    Write-LogFile "Found AutoHotkey: $ahkExecutable" "INFO"
    
    # 3. MODE SIMULATION (-WhatIf)
    if ($WhatIf) {
        Write-LogFile "WhatIf mode: Would execute $ahkExecutable" "INFO"
        Write-StructuredOutput -Status "SUCCESS" -Message "Would execute: $ahkExecutable `"$ScriptPath`" (simulation mode)" -TrayIcon "SIMULATION" -Format $OutputFormat
        exit 0
    }
    
    # 4. LANCEMENT PROCESSUS AVEC MONITORING - v1.2 ISOLATION COMPLÃˆTE
    Write-Verbose "Launching AutoHotkey process with full isolation..."
    Write-LogFile "Launching AutoHotkey process" "INFO"
    $ahkProcess = Start-Process -FilePath $ahkExecutable -ArgumentList "`"$ScriptPath`"" -PassThru -WindowStyle Hidden -NoNewWindow:$false

    if (-not $ahkProcess) {
        Write-LogFile "Failed to start AutoHotkey process" "ERROR"
        Write-StructuredOutput -Status "ERROR" -Message "Failed to start AutoHotkey process" -Format $OutputFormat
        exit 1
    }

    Write-Verbose "Process started - PID: $($ahkProcess.Id)"
    Write-LogFile "Process started - PID: $($ahkProcess.Id)" "INFO"
    
    # 5. MONITORING AVEC TIMEOUT
    $startTime = Get-Date
    $timeoutReached = $false
    $errorDetected = $false
    $errorMessage = ""    
    while (-not $timeoutReached -and -not $errorDetected) {
        # Verifier si le processus a termine de facon inattendue
        if ($ahkProcess.HasExited) {
            Write-Verbose "Process exited with code: $($ahkProcess.ExitCode)"
            Write-LogFile "Process exited with code: $($ahkProcess.ExitCode)" "INFO"
            if ($ahkProcess.ExitCode -ne 0) {
                $errorDetected = $true
                $errorMessage = "AutoHotkey process exited with error code: $($ahkProcess.ExitCode)"
                Write-LogFile $errorMessage "ERROR"
            } else {
                # Processus termine avec code 0 mais tres rapidement - probable erreur
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalMilliseconds -lt 500) {
                    Write-Verbose "Process exited very quickly ($($elapsed.TotalMilliseconds)ms) - likely syntax error"
                    $errorDetected = $true
                    $errorMessage = "AutoHotkey process exited quickly (likely syntax error) - duration: $($elapsed.TotalMilliseconds)ms"
                    Write-LogFile $errorMessage "ERROR"
                }
            }
            break
        }
        
        # Rechercher fenetres d'erreur (polling plus frequent) - v1.2 DETECTION INTELLIGENTE
        $elapsed = (Get-Date) - $startTime
        Write-Verbose "Checking for error windows... (elapsed: $($elapsed.TotalMilliseconds)ms)"
        $windowResult = Get-ErrorWindowText
        
        # v1.2: Traiter le nouveau format de retour (objet ou texte)
        if ($windowResult -is [hashtable]) {
            # Nouveau format v1.2 avec dÃ©tection SUCCESS
            if ($windowResult.Status -eq "SUCCESS") {
                Write-Verbose "SUCCESS detected: $($windowResult.Message)"
                Write-LogFile "SUCCESS: $($windowResult.Message)" "INFO"

                # Take screenshot if requested
                if ($Screenshot) {
                    $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "SUCCESS" -WindowHandle $windowResult.WindowHandle
                }

                # Calculate execution time
                $execTime = [int]((Get-Date) - $global:ExecutionStartTime).TotalMilliseconds
                Write-StructuredOutput -Status "SUCCESS" -Message $windowResult.Message -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
                Write-LogFile "Total execution time: ${execTime}ms" "INFO"
                return
            } elseif ($windowResult.Status -eq "ERROR") {
                Write-Verbose "ERROR detected via intelligent detection: $($windowResult.Message)"
                Write-LogFile "ERROR detected: $($windowResult.Message)" "ERROR"
                $errorDetected = $true
                $errorMessage = $windowResult.Message
                $global:ErrorWindowHandle = $windowResult.WindowHandle
                $global:ErrorDetails = $windowResult.ErrorDetails
            }
        } elseif ($windowResult) {
            # Format ancien (texte simple) = ERROR dÃ©tectÃ©
            Write-Verbose "Error window detected with text: $windowResult"
            Write-LogFile "Error window: $windowResult" "ERROR"
            $errorDetected = $true
            $errorMessage = $windowResult
            $global:ErrorWindowHandle = [IntPtr]::Zero  # Ancien format n'a pas de handle
        }
        
        # v1.6: Vérifier si une fenêtre SUCCESS (non-erreur) est présente
        if (-not $errorDetected) {
            $successWindow = Test-WindowIsSuccess -ScriptName $scriptBaseName
            if ($successWindow.Found) {
                Write-Verbose "SUCCESS window detected: $($successWindow.Title)"
                Write-LogFile "SUCCESS window detected: $($successWindow.Title)" "INFO"

                # Take screenshot if requested
                if ($Screenshot) {
                    $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "SUCCESS" -WindowHandle $successWindow.Handle
                }

                # Calculate execution time
                $execTime = [int]((Get-Date) - $global:ExecutionStartTime).TotalMilliseconds
                Write-StructuredOutput -Status "SUCCESS" -Message "Script window detected: $($successWindow.Title)" -WindowHandle $successWindow.Handle -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
                Write-LogFile "Total execution time: ${execTime}ms" "INFO"
                exit 0
            }
        }

        # Si une erreur a été détectée, fermer le processus et arrêter
        if ($errorDetected) {
            # Fermer le processus AutoHotkey defaillant
            try {
                if (-not $ahkProcess.HasExited) {
                    $ahkProcess.Kill()
                    $ahkProcess.WaitForExit(1000)
                }
            }
            catch {
                Write-Verbose "Could not terminate process cleanly"
            }
            break
        }        
        # Verifier timeout
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalMilliseconds -ge $TimeoutMs) {
            $timeoutReached = $true
            Write-Verbose "Timeout reached after $($elapsed.TotalMilliseconds)ms"
            break
        }
        
        Start-Sleep -Milliseconds 50
    }
    
    # 6. DETERMINATION RESULTAT ET SORTIE
    $execTime = [int]((Get-Date) - $global:ExecutionStartTime).TotalMilliseconds

    if ($errorDetected) {
        # Take screenshot if requested
        if ($Screenshot -and -not $global:ScreenshotPath) {
            $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "ERROR" -WindowHandle $global:ErrorWindowHandle
        }

        Write-LogFile "Final status: ERROR - $errorMessage" "ERROR"
        Write-LogFile "Total execution time: ${execTime}ms" "INFO"
        Write-StructuredOutput -Status "ERROR" -Message $errorMessage -ErrorDetails $global:ErrorDetails -WindowHandle $global:ErrorWindowHandle -TrayIcon "NOT_FOUND" -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
        exit 1
    }
    elseif ($timeoutReached) {
        # v1.6: Distinguer RUNNING (process actif) vs TIMEOUT (process terminé sans fenêtre)
        if (-not $ahkProcess.HasExited) {
            # Process still running = persistent script (tray icon, GUI, etc.)
            $trayStatus = Test-TrayIconPresent

            # Take screenshot if requested
            if ($Screenshot) {
                $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "RUNNING"
            }

            Write-LogFile "Process still running - persistent script (RUNNING)" "INFO"
            Write-LogFile "Total execution time: ${execTime}ms" "INFO"
            Write-StructuredOutput -Status "RUNNING" -Message "Script is running (persistent script with tray icon or GUI)" -TrayIcon $trayStatus -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
            exit 0
        } else {
            # Process terminated but no window detected = TIMEOUT (indeterminate)
            $trayStatus = Test-TrayIconPresent

            # Take screenshot if requested
            if ($Screenshot) {
                $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "TIMEOUT"
            }

            Write-LogFile "Process exited but no window detected - TIMEOUT" "INFO"
            Write-LogFile "Total execution time: ${execTime}ms" "INFO"
            Write-StructuredOutput -Status "TIMEOUT" -Message "Script exited but no window was detected" -TrayIcon $trayStatus -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
            exit 0
        }
    }
    else {
        # Take screenshot if requested
        if ($Screenshot) {
            $global:ScreenshotPath = Take-Screenshot -OutputPath $ScreenshotPath -ScriptName $scriptBaseName -Status "SUCCESS"
        }

        # Processus termine normalement
        $trayStatus = Test-TrayIconPresent
        Write-LogFile "Process completed normally" "INFO"
        Write-LogFile "Total execution time: ${execTime}ms" "INFO"
        Write-StructuredOutput -Status "SUCCESS" -Message "Script completed successfully" -TrayIcon $trayStatus -ExecutionTimeMs $execTime -Format $OutputFormat -ScreenshotFile $global:ScreenshotPath
        exit 0
    }
    
    # 7. NETTOYAGE PROCESSUS
    Write-Verbose "Cleaning up AutoHotkey process"
    try {
        if (-not $ahkProcess.HasExited) {
            $ahkProcess.Kill()
            $ahkProcess.WaitForExit(2000)
        }
        $ahkProcess.Dispose()
    }
    catch {
        Write-Verbose "Process cleanup encountered issues: $($_.Exception.Message)"
    }
}
catch {
    Write-LogFile "Unexpected error: $($_.Exception.Message)" "FATAL"
    Write-StructuredOutput -Status "ERROR" -Message "Unexpected error: $($_.Exception.Message)" -Format $OutputFormat
    exit 1
}