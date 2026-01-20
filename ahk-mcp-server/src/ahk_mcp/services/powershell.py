"""PowerShell wrapper service for ahklauncher.ps1."""
import asyncio
import json
import logging
import subprocess
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Path to the PowerShell wrapper script (relative to MCP server)
MCP_SERVER_ROOT = Path(__file__).parent.parent.parent.parent
WRAPPER_SCRIPT = MCP_SERVER_ROOT.parent / "ahklauncher.ps1"
SCREENSHOTS_DIR = MCP_SERVER_ROOT.parent / "screenshots"


def _build_ps_command(
    script_path: str,
    version: str = "Auto",
    timeout_ms: int = 3000,
    screenshot: bool = True,
    screenshot_path: Optional[str] = None
) -> list[str]:
    """Build PowerShell command arguments."""
    args = [
        "powershell.exe",
        "-ExecutionPolicy", "Bypass",
        "-NoProfile",
        "-File", str(WRAPPER_SCRIPT),
        "-ScriptPath", script_path,
        "-AhkVersion", version,
        "-TimeoutMs", str(timeout_ms),
        "-OutputFormat", "JSON"
    ]

    if screenshot:
        args.append("-Screenshot")
        if screenshot_path:
            args.extend(["-ScreenshotPath", screenshot_path])

    return args


def _parse_json_output(stdout: str, stderr: str) -> dict:
    """Parse JSON output from PowerShell wrapper."""
    # The wrapper outputs JSON on the last line
    lines = stdout.strip().split('\n')

    # Find JSON line (starts with '{')
    json_line = None
    for line in reversed(lines):
        line = line.strip()
        if line.startswith('{'):
            json_line = line
            break

    if not json_line:
        logger.error(f"No JSON found in stdout: {stdout[:500]}")
        return {
            "status": "CONFIG_ERROR",
            "message": f"Failed to parse wrapper output. Stderr: {stderr[:500] if stderr else 'None'}",
            "executionTimeMs": 0,
            "scriptPath": ""
        }

    try:
        return json.loads(json_line)
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}. Line: {json_line[:200]}")
        return {
            "status": "CONFIG_ERROR",
            "message": f"Invalid JSON from wrapper: {str(e)}",
            "executionTimeMs": 0,
            "scriptPath": ""
        }


async def run_ahk_launcher(
    script_path: str,
    version: str = "Auto",
    timeout_ms: int = 3000,
    screenshot: bool = True,
    screenshot_path: Optional[str] = None
) -> dict:
    """
    Execute ahklauncher.ps1 and return parsed JSON result.

    Args:
        script_path: Absolute path to .ahk script
        version: AHK version ("V1", "V2", or "Auto")
        timeout_ms: Timeout in milliseconds
        screenshot: Whether to capture screenshot on result
        screenshot_path: Optional custom screenshot directory

    Returns:
        Dict with status, message, errorDetails, screenshot path, etc.
    """
    logger.info(f"Running AHK script: {script_path} (version={version}, timeout={timeout_ms}ms)")

    # Validate script exists
    if not Path(script_path).exists():
        return {
            "status": "CONFIG_ERROR",
            "message": f"Script not found: {script_path}",
            "executionTimeMs": 0,
            "scriptPath": script_path
        }

    # Validate wrapper exists
    if not WRAPPER_SCRIPT.exists():
        return {
            "status": "CONFIG_ERROR",
            "message": f"Wrapper script not found: {WRAPPER_SCRIPT}",
            "executionTimeMs": 0,
            "scriptPath": script_path
        }

    cmd = _build_ps_command(script_path, version, timeout_ms, screenshot, screenshot_path)
    logger.debug(f"Command: {' '.join(cmd)}")

    # Calculate subprocess timeout (add buffer for PS startup)
    subprocess_timeout = (timeout_ms / 1000) + 10

    try:
        # Run in thread to avoid blocking
        result = await asyncio.to_thread(
            subprocess.run,
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=subprocess_timeout,
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
        )

        logger.debug(f"Exit code: {result.returncode}")
        logger.debug(f"Stdout: {result.stdout[:500] if result.stdout else 'None'}")
        if result.stderr:
            logger.debug(f"Stderr: {result.stderr[:500]}")

        return _parse_json_output(result.stdout or "", result.stderr or "")

    except subprocess.TimeoutExpired:
        logger.error(f"Subprocess timeout after {subprocess_timeout}s")
        return {
            "status": "TIMEOUT",
            "message": f"PowerShell wrapper timed out after {subprocess_timeout}s",
            "executionTimeMs": int(subprocess_timeout * 1000),
            "scriptPath": script_path
        }
    except Exception as e:
        logger.exception(f"Error running wrapper: {e}")
        return {
            "status": "CONFIG_ERROR",
            "message": f"Failed to execute wrapper: {str(e)}",
            "executionTimeMs": 0,
            "scriptPath": script_path
        }


async def capture_window_screenshot(
    window_title: Optional[str] = None,
    window_handle: Optional[str] = None,
    output_path: Optional[str] = None
) -> dict:
    """
    Capture a screenshot of a specific window.

    This runs a minimal PowerShell script that uses the same Win32API
    as ahklauncher.ps1 to capture a window screenshot.

    Args:
        window_title: Window title to search for (partial match)
        window_handle: Window handle (hwnd) as string
        output_path: Custom output directory

    Returns:
        Dict with success, screenshot_path, window_dimensions
    """
    logger.info(f"Capturing window: title={window_title}, handle={window_handle}")

    # Build PowerShell script for window capture
    screenshot_dir = output_path or str(SCREENSHOTS_DIR)

    ps_script = f'''
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Win32 API declarations
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class CaptureAPI {{
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    public const uint PW_RENDERFULLCONTENT = 0x00000002;

    public static List<KeyValuePair<IntPtr, string>> FoundWindows = new List<KeyValuePair<IntPtr, string>>();

    public static bool EnumCallback(IntPtr hWnd, IntPtr lParam) {{
        if (IsWindowVisible(hWnd)) {{
            StringBuilder sb = new StringBuilder(256);
            GetWindowText(hWnd, sb, sb.Capacity);
            if (sb.Length > 0) {{
                FoundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, sb.ToString()));
            }}
        }}
        return true;
    }}
}}

[StructLayout(LayoutKind.Sequential)]
public struct RECT {{
    public int Left, Top, Right, Bottom;
    public int Width {{ get {{ return Right - Left; }} }}
    public int Height {{ get {{ return Bottom - Top; }} }}
}}
'@

$hwnd = [IntPtr]::Zero
$windowTitle = ""

# Find window by handle or title
'''

    if window_handle:
        ps_script += f'''
$hwnd = [IntPtr]::new({window_handle})
$sb = [System.Text.StringBuilder]::new(256)
[CaptureAPI]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
$windowTitle = $sb.ToString()
'''
    elif window_title:
        ps_script += f'''
# Search for window by title
[CaptureAPI]::FoundWindows.Clear()
[CaptureAPI]::EnumWindows([CaptureAPI+EnumWindowsProc]{{ param($h, $l) [CaptureAPI]::EnumCallback($h, $l) }}, [IntPtr]::Zero)

$searchTitle = "{window_title}"
foreach ($kv in [CaptureAPI]::FoundWindows) {{
    if ($kv.Value -like "*$searchTitle*") {{
        $hwnd = $kv.Key
        $windowTitle = $kv.Value
        break
    }}
}}
'''
    else:
        # Return error - need either title or handle
        return {
            "success": False,
            "error": "Either window_title or window_handle must be provided"
        }

    ps_script += f'''
if ($hwnd -eq [IntPtr]::Zero) {{
    @{{ success = $false; error = "Window not found" }} | ConvertTo-Json -Compress
    exit 1
}}

# Get window rect
$rect = New-Object RECT
$success = [CaptureAPI]::GetWindowRect($hwnd, [ref]$rect)

if (-not $success -or $rect.Width -le 0 -or $rect.Height -le 0) {{
    @{{ success = $false; error = "Invalid window dimensions" }} | ConvertTo-Json -Compress
    exit 1
}}

# Create screenshot
$bitmap = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()

[CaptureAPI]::PrintWindow($hwnd, $hdc, [CaptureAPI]::PW_RENDERFULLCONTENT) | Out-Null
$graphics.ReleaseHdc($hdc)

# Save
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$screenshotDir = "{screenshot_dir}"
if (-not (Test-Path $screenshotDir)) {{ New-Item -ItemType Directory -Path $screenshotDir -Force | Out-Null }}
$filename = "capture_${{timestamp}}.png"
$fullPath = Join-Path $screenshotDir $filename
$bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()

@{{
    success = $true
    screenshot_path = $fullPath
    window_title = $windowTitle
    window_dimensions = @{{
        width = $rect.Width
        height = $rect.Height
        left = $rect.Left
        top = $rect.Top
    }}
}} | ConvertTo-Json -Compress
'''

    try:
        result = await asyncio.to_thread(
            subprocess.run,
            ["powershell.exe", "-ExecutionPolicy", "Bypass", "-NoProfile", "-Command", ps_script],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
        )

        if result.stdout:
            try:
                return json.loads(result.stdout.strip().split('\n')[-1])
            except json.JSONDecodeError:
                pass

        return {
            "success": False,
            "error": f"Failed to capture: {result.stderr or result.stdout}"
        }

    except Exception as e:
        logger.exception(f"Error capturing window: {e}")
        return {
            "success": False,
            "error": str(e)
        }
