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
    [string]$AhkVersion = "Auto"
)

# AHK Launcher PowerShell - Script Validation AutoHotkey avec Extraction Erreurs
# Version: 1.1 - EnumWindows Implementation
# Objectif: Validation rapide scripts AHK + extraction erreurs via APIs Windows

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

public class WindowInfo 
{
    public IntPtr Handle { get; set; }
    public string Title { get; set; }
}
'@
function Write-StructuredOutput {
    param(
        [string]$Status,
        [string]$Message,
        [string]$TrayIcon = "NOT_CHECKED",
        [string]$Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    )
    
    Write-Output "STATUS: $Status"
    Write-Output "MESSAGE: $Message"
    Write-Output "TRAY_ICON: $TrayIcon"
    Write-Output "TIMESTAMP: $Timestamp"
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
            
            # 1. Titre exact = nom du script ET vérifier si c'est vraiment une erreur
            if ($title -eq $scriptName -or $title -eq $scriptBaseName) {
                Write-Verbose "POTENTIAL: Script name match for '$title' - checking if error window..."
                # Extraire le texte pour vérifier si c'est une vraie erreur
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
            # 2bis. AutoHotkey spécifique (mais pas Explorateur de fichiers)
            elseif ($title -match "(?i)autohotkey" -and 
                    $title -notmatch "(?i)(explorateur|file explorer|scripts.*explorateur)" -and 
                    $title.Length -lt 80) {
                Write-Verbose "MATCH: AutoHotkey specific match for '$title'"
                $isErrorWindow = $true
            }
            # 3. Titre tres court mais contient le nom du script
            elseif ($title.Contains($scriptBaseName) -and $title.Length -lt 50) {
                Write-Verbose "MATCH: Script basename match for '$title'"
                $isErrorWindow = $true
            }
            
            if ($isErrorWindow) {
                Write-Verbose "Potential error window found: '$title' - extracting full text..."
                
                # Extraire le texte complet de la fenetre (titre + contenu)
                $fullText = Get-WindowTextRecursive -WindowHandle $window.Handle
                
                if ($fullText -and $fullText.Length -gt 10) {
                    Write-Verbose "Successfully extracted error text: '$fullText'"
                    return $fullText
                }
                else {
                    Write-Verbose "Could not extract meaningful text from error window"
                    # Retourner au moins le titre si on ne peut pas avoir plus
                    return "Error detected in window: $title"
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
    return if ($ahkProcesses) { "FOUND" } else { "NOT_FOUND" }
}

# MAIN WORKFLOW
try {
    Write-Verbose "Starting AHK Launcher - Script: $ScriptPath, Timeout: ${TimeoutMs}ms"
    
    # 1. VALIDATION PARAMETRES
    if (-not (Test-Path $ScriptPath)) {
        Write-StructuredOutput -Status "ERROR" -Message "Script file not found: $ScriptPath"
        exit 2
    }
    
    $ScriptPath = Resolve-Path $ScriptPath
    Write-Verbose "Resolved script path: $ScriptPath"    
    # 2. DETECTION AUTOHOTKEY
    $ahkExecutable = Test-AutohotkeyAvailable -CustomPath $AhkExecutable -PreferredVersion $AhkVersion
    if (-not $ahkExecutable) {
        Write-StructuredOutput -Status "ERROR" -Message "AutoHotkey executable not found in PATH, portable locations, or custom path"
        exit 2
    }
    
    Write-Verbose "Found AutoHotkey: $ahkExecutable"
    
    # 3. MODE SIMULATION (-WhatIf)
    if ($WhatIf) {
        Write-StructuredOutput -Status "SUCCESS" -Message "Would execute: $ahkExecutable `"$ScriptPath`" (simulation mode)" -TrayIcon "SIMULATION"
        exit 0
    }
    
    # 4. LANCEMENT PROCESSUS AVEC MONITORING
    Write-Verbose "Launching AutoHotkey process..."
    $ahkProcess = Start-Process -FilePath $ahkExecutable -ArgumentList "`"$ScriptPath`"" -PassThru
    
    if (-not $ahkProcess) {
        Write-StructuredOutput -Status "ERROR" -Message "Failed to start AutoHotkey process"
        exit 1
    }
    
    Write-Verbose "Process started - PID: $($ahkProcess.Id)"
    
    # 5. MONITORING AVEC TIMEOUT
    $startTime = Get-Date
    $timeoutReached = $false
    $errorDetected = $false
    $errorMessage = ""    
    while (-not $timeoutReached -and -not $errorDetected) {
        # Verifier si le processus a termine de facon inattendue
        if ($ahkProcess.HasExited) {
            Write-Verbose "Process exited with code: $($ahkProcess.ExitCode)"
            if ($ahkProcess.ExitCode -ne 0) {
                $errorDetected = $true
                $errorMessage = "AutoHotkey process exited with error code: $($ahkProcess.ExitCode)"
            } else {
                # Processus termine avec code 0 mais tres rapidement - probable erreur
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalMilliseconds -lt 500) {
                    Write-Verbose "Process exited very quickly ($($elapsed.TotalMilliseconds)ms) - likely syntax error"
                    $errorDetected = $true
                    $errorMessage = "AutoHotkey process exited quickly (likely syntax error) - duration: $($elapsed.TotalMilliseconds)ms"
                }
            }
            break
        }
        
        # Rechercher fenetres d'erreur (polling plus frequent)
        $elapsed = (Get-Date) - $startTime
        Write-Verbose "Checking for error windows... (elapsed: $($elapsed.TotalMilliseconds)ms)"
        $errorText = Get-ErrorWindowText
        if ($errorText) {
            Write-Verbose "Error window detected with text: $errorText"
            $errorDetected = $true
            $errorMessage = $errorText
            
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
    if ($errorDetected) {
        Write-StructuredOutput -Status "ERROR" -Message $errorMessage -TrayIcon "NOT_FOUND"
        exit 1
    }
    elseif ($timeoutReached) {
        # Timeout atteint - probable succes (script lance, pas d'erreur detectee)
        $trayStatus = Test-TrayIconPresent
        Write-StructuredOutput -Status "SUCCESS" -Message "Script launched successfully (no error detected within timeout)" -TrayIcon $trayStatus
        exit 0
    }
    else {
        # Processus termine normalement
        $trayStatus = Test-TrayIconPresent
        Write-StructuredOutput -Status "SUCCESS" -Message "Script completed successfully" -TrayIcon $trayStatus
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
    Write-StructuredOutput -Status "ERROR" -Message "Unexpected error: $($_.Exception.Message)"
    exit 1
}