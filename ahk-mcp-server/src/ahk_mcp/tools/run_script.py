"""Tool: ahk_run_script - Execute and test AutoHotkey scripts."""
import logging
from typing import Annotated
from pathlib import Path

from fastmcp import Context
from pydantic import Field

from ..services.powershell import run_ahk_launcher

logger = logging.getLogger(__name__)


async def ahk_run_script(
    ctx: Context,
    script_path: Annotated[str, Field(description="Absolute path to the .ahk script file to execute")],
    version: Annotated[str, Field(description="AutoHotkey version: V1, V2, or Auto (default)")] = "Auto",
    timeout_ms: Annotated[int, Field(description="Timeout in milliseconds (500-30000)", ge=500, le=30000)] = 3000,
) -> str:
    """
    Execute an AutoHotkey script and detect if it works or has errors.

    This tool runs an AHK script (V1 or V2, auto-detected) and monitors for error windows.
    If an error window appears, it captures a screenshot of the error and extracts the error message.

    Returns:
    - SUCCESS: Script runs without error window (no syntax/runtime errors detected)
    - ERROR: Error window detected - includes screenshot path and error details
    - TIMEOUT: Script monitoring timed out (usually means SUCCESS for GUI scripts)
    - CONFIG_ERROR: Configuration issue (script not found, AHK not installed, etc.)

    The screenshot of the error window (if any) is returned in the result and can be
    viewed by the LLM to understand the exact error.
    """
    logger.info(f"ahk_run_script called: {script_path} (version={version}, timeout={timeout_ms})")

    # Validate version parameter
    if version not in ("V1", "V2", "Auto"):
        version = "Auto"

    # Run the script through PowerShell wrapper
    result = await run_ahk_launcher(
        script_path=script_path,
        version=version,
        timeout_ms=timeout_ms,
        screenshot=True  # Always capture screenshot on error
    )

    # Format response for LLM consumption
    status = result.get("status", "CONFIG_ERROR")
    message = result.get("message", "Unknown error")
    screenshot = result.get("screenshot")
    error_details = result.get("errorDetails")
    window_handle = result.get("windowHandle")
    execution_time = result.get("executionTimeMs", 0)
    tray_icon = result.get("trayIcon", "NOT_CHECKED")

    # Build response
    response_lines = [
        f"## Result: {status}",
        "",
        f"**Script**: `{script_path}`",
        f"**Execution Time**: {execution_time}ms",
    ]

    if status == "SUCCESS":
        response_lines.extend([
            "",
            "The script executed without any error window being detected.",
            f"Tray Icon: {tray_icon}",
        ])
        if window_handle:
            response_lines.append(f"Window Handle: {window_handle} (use with ahk_capture_ui to screenshot the UI)")

    elif status == "ERROR":
        response_lines.extend([
            "",
            f"**Error Message**: {message}",
        ])

        if error_details:
            response_lines.append("")
            response_lines.append("### Error Details")

            if error_details.get("title"):
                response_lines.append(f"**Window Title**: {error_details['title']}")

            if error_details.get("errorContent"):
                response_lines.append("")
                response_lines.append("**Error Content**:")
                for line in error_details["errorContent"]:
                    response_lines.append(f"  {line}")

            if error_details.get("sourceCode"):
                response_lines.append("")
                response_lines.append("**Source Code Context**:")
                response_lines.append("```")
                for line in error_details["sourceCode"]:
                    response_lines.append(line)
                response_lines.append("```")

            if error_details.get("buttons"):
                response_lines.append("")
                response_lines.append(f"**Buttons**: {', '.join(error_details['buttons'])}")

        if screenshot and Path(screenshot).exists():
            response_lines.extend([
                "",
                f"**Error Screenshot**: `{screenshot}`",
                "",
                "_The screenshot shows the exact error window. Use Read tool to view it._"
            ])

    elif status == "TIMEOUT":
        response_lines.extend([
            "",
            "The script monitoring timed out. This typically means:",
            "- The script is running successfully (e.g., GUI script with tray icon)",
            "- No error window was detected within the timeout period",
            "",
            "Use `ahk_capture_ui` to take a screenshot of the running script's UI."
        ])

    else:  # CONFIG_ERROR
        response_lines.extend([
            "",
            f"**Configuration Error**: {message}",
            "",
            "Please check:",
            "- Script path exists and is absolute",
            "- AutoHotkey V1 or V2 is installed",
            "- The script has valid .ahk extension"
        ])

    return "\n".join(response_lines)
