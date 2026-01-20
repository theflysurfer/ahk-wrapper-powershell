"""
AHK MCP Server - Main server module.

Provides tools for LLMs to test AutoHotkey scripts:
- ahk_run_script: Execute AHK scripts and detect errors
- ahk_capture_ui: Capture screenshots of AHK windows
- ahk_create_github_issue: Create issues on the repo
"""
import logging
from fastmcp import FastMCP

from .tools.run_script import ahk_run_script
from .tools.capture_ui import ahk_capture_ui
from .tools.github_issue import ahk_create_github_issue
from .resources.github import get_issues_list, get_issue_detail

logger = logging.getLogger(__name__)

# Initialize FastMCP server
mcp = FastMCP(
    name="ahk-mcp",
    instructions="""
AHK MCP Server - AutoHotkey Testing Tools for LLMs

This MCP server provides tools to test AutoHotkey (V1 and V2) scripts:

## Tools

### ahk_run_script
Execute an AHK script and detect if it works or has errors.
- Automatically detects AHK V1 vs V2
- Captures screenshot of error windows
- Extracts error messages with line numbers

### ahk_capture_ui
Capture a screenshot of a running AHK script's window.
- Use after ahk_run_script returns SUCCESS
- Verify the UI matches expected design

### ahk_create_github_issue
Create issues on the ahk-wrapper-powershell repository.

## Workflow

1. Write your AHK script
2. Run `ahk_run_script` to test it
3. If SUCCESS, use `ahk_capture_ui` to verify the UI
4. If ERROR, read the screenshot and error details to fix the script
5. Report bugs using `ahk_create_github_issue`
"""
)


# Register tools
@mcp.tool(
    name="ahk_run_script",
    description="Execute an AutoHotkey script and detect if it works or has errors. Returns SUCCESS, ERROR (with screenshot), TIMEOUT, or CONFIG_ERROR."
)
async def run_script_tool(
    script_path: str,
    version: str = "Auto",
    timeout_ms: int = 3000
) -> str:
    """Execute an AHK script and detect errors."""
    return await ahk_run_script(None, script_path, version, timeout_ms)


@mcp.tool(
    name="ahk_capture_ui",
    description="Capture a screenshot of an AutoHotkey script's window to verify the UI design."
)
async def capture_ui_tool(
    window_title: str | None = None,
    window_handle: str | None = None
) -> str:
    """Capture screenshot of AHK window."""
    return await ahk_capture_ui(None, window_title, window_handle)


@mcp.tool(
    name="ahk_create_github_issue",
    description="Create a GitHub issue on the ahk-wrapper-powershell repository."
)
async def create_issue_tool(
    title: str,
    body: str,
    labels: list[str] | None = None
) -> str:
    """Create a GitHub issue."""
    return await ahk_create_github_issue(None, title, body, labels)


# Register resources
@mcp.resource("github://issues")
async def issues_resource() -> str:
    """List all GitHub issues on the ahk-wrapper-powershell repository."""
    return await get_issues_list()


@mcp.resource("github://issues/{issue_number}")
async def issue_detail_resource(issue_number: str) -> str:
    """Get details of a specific GitHub issue."""
    return await get_issue_detail(issue_number)


logger.info("AHK MCP Server initialized with tools: ahk_run_script, ahk_capture_ui, ahk_create_github_issue")
logger.info("Resources: github://issues, github://issues/{issue_number}")
