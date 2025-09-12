[CmdletBinding()]
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

# ================================================================================================
# AHK Launcher PowerShell - Script Validation AutoHotkey avec Extraction Erreurs
# Version: 1.0 MVP
# Objectif: Validation rapide scripts AHK + extraction erreurs via APIs Windows
# ================================================================================================

# Add-Type pour APIs Windows nécessaires à l'extraction d'erreurs + EnumWindows fonctionnel
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class Win32API {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, 
                                           string lpszClass, string lpszWindow);
    
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
    
    // Classe pour collecter les fenêtres trouvées
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
        return true; // Continue enumération
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
    
    # 1. Recherche dans PATH système (standard)
    try {
        $ahkCommand = Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue
        if ($ahkCommand -and $PreferredVersion -eq "Auto") {
            Write-Verbose "Found AutoHotkey in PATH: $($ahkCommand.Source)"
            return $ahkCommand.Source
        }
    }
    catch {
        Write-Verbose "AutoHotkey not found in PATH"
    }
    
    # 2. Recherche portable basée sur version préférée
    $userProfile = $env:USERPROFILE
    $portablePaths = @()
    
    if ($PreferredVersion -eq "V1") {
        # Priorité V1 uniquement
        $portablePaths = @(
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyU64.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyU32.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyA32.exe"
        )
    }
    elseif ($PreferredVersion -eq "V2") {
        # Priorité V2 uniquement
        $portablePaths = @(
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV2\AutoHotkey64.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV2\AutoHotkey32.exe"
        )
    }
    else {
        # Auto ou vide : priorité V2 puis V1
        $portablePaths = @(
            # AutoHotkey V2 (priorité par défaut)
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV2\AutoHotkey64.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV2\AutoHotkey32.exe",
            
            # AutoHotkey V1 (fallback)
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyU64.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyU32.exe",
            "$userProfile\OneDrive\Portable Softwares\Autohotkey scripts\AutohotkeyV1\AutoHotkeyA32.exe"
        )
    }
    
    foreach ($path in $portablePaths) {
        if (Test-Path $path) {
            $version = if ($path -match "AutohotkeyV1") { "V1" } else { "V2" }
            Write-Verbose "Found portable AutoHotkey $version : $path"
            return $path
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
        # Vider la liste et énumérer toutes les fenêtres visibles
        [Win32API]::EnumerateWindows()
        
        # Nom du script pour recherche ciblée
        $scriptName = Split-Path -Leaf $ScriptPath
        $scriptBaseName = $scriptName.Replace(".ahk", "")
        
        Write-Verbose "Found $([Win32API]::FoundWindows.Count) visible windows"
        
        # Chercher les fenêtres qui correspondent à notre script d'erreur
        foreach ($window in [Win32API]::FoundWindows) {
            $title = $window.Title
            Write-Verbose "Inspecting window: '$title' (Handle: $($window.Handle))"
            
            # Correspondances possibles pour fenêtres d'erreur AutoHotkey
            $isErrorWindow = $false
            
            # 1. Titre exact = nom du script
            if ($title -eq $scriptName -or $title -eq $scriptBaseName) {
                Write-Verbose "MATCH: Script name match for '$title'"
                $isErrorWindow = $true
            }
            # 2. Titre contient des mots-clés d'erreur
            elseif ($title -match "(?i)(error|erreur|syntax|autohotkey)" -and $title.Length -lt 100) {
                Write-Verbose "MATCH: Error keyword match for '$title'"
                $isErrorWindow = $true
            }
            # 3. Titre très court mais contient le nom du script
            elseif ($title.Contains($scriptBaseName) -and $title.Length -lt 50) {
                Write-Verbose "MATCH: Script basename match for '$title'"
                $isErrorWindow = $true
            }
            
            if ($isErrorWindow) {
                Write-Verbose "Potential error window found: '$title' - extracting full text..."
                
                # Extraire le texte complet de la fenêtre (titre + contenu)
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
    
    # Texte de la fenêtre principale
    $buffer = New-Object System.Text.StringBuilder(512)
    $length = [Win32API]::GetWindowText($WindowHandle, $buffer, $buffer.Capacity)
    if ($length -gt 0) {
        $mainText = $buffer.ToString()
        if ($mainText -and $mainText -notmatch "^(OK|Cancel|&OK|&Cancel)$") {
            $allText += $mainText + " | "
        }
    }
    
    # Parcourir tous les contrôles enfants
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
    return if ($allText) { $allText } else { $null }
}

function Test-TrayIconPresent {
    # Implémentation basique : vérifier si des processus AutoHotkey sont toujours actifs
    # Une implémentation plus avancée rechercherait dans la zone de notification
    try {
        $ahkProcesses = Get-Process -Name "AutoHotkey*" -ErrorAction SilentlyContinue
        return if ($ahkProcesses) { "DETECTED" } else { "NOT_FOUND" }
    }
    catch {
        return "NOT_CHECKED"
    }
}

# ================================================================================================
# MAIN WORKFLOW
# ================================================================================================

try {
    Write-Verbose "Starting AHK Launcher - Script: $ScriptPath, Timeout: ${TimeoutMs}ms"
    
    # 1. VALIDATION PARAMÈTRES
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
        # Vérifier si le processus a terminé de façon inattendue
        if ($ahkProcess.HasExited) {
            Write-Verbose "Process exited with code: $($ahkProcess.ExitCode)"
            if ($ahkProcess.ExitCode -ne 0) {
                $errorDetected = $true
                $errorMessage = "AutoHotkey process exited with error code: $($ahkProcess.ExitCode)"
            } else {
                # Processus terminé avec code 0 mais très rapidement - probable erreur
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalMilliseconds -lt 500) {
                    Write-Verbose "Process exited very quickly ($($elapsed.TotalMilliseconds)ms) - likely syntax error"
                    $errorDetected = $true
                    $errorMessage = "AutoHotkey process exited quickly (likely syntax error) - duration: $($elapsed.TotalMilliseconds)ms"
                }
            }
            break
        }
        
        # Rechercher fenêtres d'erreur (polling plus fréquent)
        $elapsed = (Get-Date) - $startTime
        Write-Verbose "Checking for error windows... (elapsed: $($elapsed.TotalMilliseconds)ms)"
        $errorText = Get-ErrorWindowText
        if ($errorText) {
            Write-Verbose "Error window detected with text: $errorText"
            $errorDetected = $true
            $errorMessage = $errorText
            
            # Fermer le processus AutoHotkey défaillant
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
        
        # Vérifier timeout
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalMilliseconds -ge $TimeoutMs) {
            $timeoutReached = $true
            Write-Verbose "Timeout reached after $($elapsed.TotalMilliseconds)ms"
            break
        }
        
        Start-Sleep -Milliseconds 50
    }
    
    # 6. DÉTERMINATION RÉSULTAT ET SORTIE
    if ($errorDetected) {
        Write-StructuredOutput -Status "ERROR" -Message $errorMessage -TrayIcon "NOT_FOUND"
        exit 1
    }
    elseif ($timeoutReached) {
        # Timeout atteint - probable succès (script lancé, pas d'erreur détectée)
        $trayStatus = Test-TrayIconPresent
        Write-StructuredOutput -Status "SUCCESS" -Message "Script launched successfully (no error detected within timeout)" -TrayIcon $trayStatus
        exit 0
    }
    else {
        # Processus terminé sans erreur dans le délai
        $trayStatus = Test-TrayIconPresent  
        Write-StructuredOutput -Status "SUCCESS" -Message "Script executed and completed successfully" -TrayIcon $trayStatus
        exit 0
    }
}
catch {
    Write-Verbose "Unexpected error: $($_.Exception.Message)"
    Write-StructuredOutput -Status "ERROR" -Message "Unexpected error: $($_.Exception.Message)"
    exit 1
}
finally {
    # Nettoyage si nécessaire
    if ($ahkProcess -and -not $ahkProcess.HasExited) {
        Write-Verbose "Cleaning up AutoHotkey process"
        try {
            $ahkProcess.CloseMainWindow()
            if (-not $ahkProcess.WaitForExit(2000)) {
                $ahkProcess.Kill()
            }
        }
        catch {
            Write-Verbose "Process cleanup failed: $($_.Exception.Message)"
        }
    }
}

# ================================================================================================
# END OF SCRIPT
# ================================================================================================
