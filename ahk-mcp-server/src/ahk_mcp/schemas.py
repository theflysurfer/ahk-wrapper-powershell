"""Pydantic schemas for AHK MCP Server inputs and outputs."""
from typing import Literal, Optional
from pydantic import BaseModel, Field


class RunScriptInput(BaseModel):
    """Input for ahk_run_script tool."""
    script_path: str = Field(
        ...,
        description="Absolute path to the .ahk script file to execute"
    )
    version: Optional[Literal["V1", "V2", "Auto"]] = Field(
        default="Auto",
        description="AutoHotkey version to use: V1, V2, or Auto (auto-detect)"
    )
    timeout_ms: Optional[int] = Field(
        default=3000,
        ge=500,
        le=30000,
        description="Timeout in milliseconds to wait for script execution (500-30000)"
    )


class CaptureUIInput(BaseModel):
    """Input for ahk_capture_ui tool."""
    window_title: Optional[str] = Field(
        default=None,
        description="Window title to capture (partial match). If not provided, uses script name."
    )
    window_handle: Optional[str] = Field(
        default=None,
        description="Window handle (hwnd) from previous ahk_run_script result"
    )


class CreateIssueInput(BaseModel):
    """Input for ahk_create_github_issue tool."""
    title: str = Field(
        ...,
        min_length=5,
        max_length=200,
        description="Issue title (5-200 characters)"
    )
    body: str = Field(
        ...,
        min_length=10,
        description="Issue body in Markdown format"
    )
    labels: Optional[list[str]] = Field(
        default=None,
        description="Optional labels for the issue (e.g., ['bug', 'enhancement'])"
    )


class ErrorDetails(BaseModel):
    """Structured error details from AHK error window."""
    title: str = Field(description="Error window title")
    error_content: list[str] = Field(description="Error message lines")
    source_code: list[str] = Field(description="Source code context with line numbers")
    buttons: list[str] = Field(description="Error window buttons")


class RunScriptResult(BaseModel):
    """Result from ahk_run_script tool."""
    status: Literal["SUCCESS", "ERROR", "TIMEOUT", "CONFIG_ERROR"]
    message: str
    error_details: Optional[ErrorDetails] = None
    screenshot_path: Optional[str] = None
    window_handle: Optional[str] = None
    tray_icon: Optional[Literal["FOUND", "NOT_FOUND"]] = None
    execution_time_ms: int
    script_path: str
    ahk_version: Optional[str] = None


class CaptureUIResult(BaseModel):
    """Result from ahk_capture_ui tool."""
    success: bool
    screenshot_path: Optional[str] = None
    window_title: Optional[str] = None
    window_dimensions: Optional[dict] = None
    error: Optional[str] = None
