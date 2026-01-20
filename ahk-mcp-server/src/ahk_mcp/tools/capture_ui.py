"""Tool: ahk_capture_ui - Capture screenshot of AHK window UI."""
import logging
from typing import Annotated, Optional
from pathlib import Path

from fastmcp import Context
from pydantic import Field

from ..services.powershell import capture_window_screenshot

logger = logging.getLogger(__name__)


async def ahk_capture_ui(
    ctx: Context,
    window_title: Annotated[Optional[str], Field(description="Window title to capture (partial match)")] = None,
    window_handle: Annotated[Optional[str], Field(description="Window handle from ahk_run_script result")] = None,
) -> str:
    """
    Capture a screenshot of an AutoHotkey script's window/UI.

    Use this tool AFTER running ahk_run_script with SUCCESS to verify the UI looks correct.
    You can provide either:
    - window_title: Partial match of the window title (e.g., script name)
    - window_handle: The exact window handle from ahk_run_script result

    The screenshot allows visual verification that the AHK script's UI matches the expected design.

    Returns the path to the captured screenshot image.
    """
    logger.info(f"ahk_capture_ui called: title={window_title}, handle={window_handle}")

    if not window_title and not window_handle:
        return (
            "## Error: Missing Parameter\n\n"
            "Please provide either `window_title` or `window_handle`.\n\n"
            "- `window_title`: Partial match of the window title (e.g., script name)\n"
            "- `window_handle`: The window handle from a previous ahk_run_script result"
        )

    result = await capture_window_screenshot(
        window_title=window_title,
        window_handle=window_handle
    )

    if result.get("success"):
        screenshot_path = result.get("screenshot_path", "")
        window_title_found = result.get("window_title", "Unknown")
        dimensions = result.get("window_dimensions", {})

        response_lines = [
            "## UI Screenshot Captured",
            "",
            f"**Window Title**: {window_title_found}",
            f"**Dimensions**: {dimensions.get('width', 0)}x{dimensions.get('height', 0)}",
            f"**Position**: ({dimensions.get('left', 0)}, {dimensions.get('top', 0)})",
            "",
            f"**Screenshot Path**: `{screenshot_path}`",
            "",
            "_Use the Read tool to view the screenshot and verify the UI design._"
        ]

        return "\n".join(response_lines)

    else:
        error = result.get("error", "Unknown error")
        return (
            f"## Screenshot Failed\n\n"
            f"**Error**: {error}\n\n"
            "Possible causes:\n"
            "- Window not found (check if script is still running)\n"
            "- Invalid window handle\n"
            "- Window is minimized or hidden"
        )
