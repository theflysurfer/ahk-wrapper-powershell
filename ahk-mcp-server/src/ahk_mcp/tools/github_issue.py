"""Tool: ahk_create_github_issue - Create issues on the AHK repo."""
import logging
from typing import Annotated, Optional

from fastmcp import Context
from pydantic import Field

from ..services.github_cli import create_github_issue

logger = logging.getLogger(__name__)


async def ahk_create_github_issue(
    ctx: Context,
    title: Annotated[str, Field(description="Issue title (5-200 characters)", min_length=5, max_length=200)],
    body: Annotated[str, Field(description="Issue body in Markdown format", min_length=10)],
    labels: Annotated[Optional[list[str]], Field(description="Labels for the issue")] = None,
) -> str:
    """
    Create a GitHub issue on the ahk-wrapper-powershell repository.

    Use this to report bugs, request features, or track tasks related to the AHK wrapper.

    Args:
        title: Short descriptive title for the issue
        body: Detailed description in Markdown format
        labels: Optional list of labels (e.g., ["bug"], ["enhancement"])

    Returns:
        URL of the created issue
    """
    logger.info(f"Creating GitHub issue: {title}")

    result = await create_github_issue(
        title=title,
        body=body,
        labels=labels
    )

    if result.get("success"):
        issue_url = result.get("url", "")
        issue_number = result.get("number", "?")

        return (
            f"## Issue Created Successfully\n\n"
            f"**Issue #{issue_number}**: [{title}]({issue_url})\n\n"
            f"URL: {issue_url}"
        )
    else:
        error = result.get("error", "Unknown error")
        return (
            f"## Failed to Create Issue\n\n"
            f"**Error**: {error}\n\n"
            "Please ensure:\n"
            "- `gh` CLI is installed and authenticated\n"
            "- You have write access to the repository"
        )
