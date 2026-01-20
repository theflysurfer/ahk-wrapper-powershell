"""GitHub issues resource for AHK MCP Server."""
import logging
import json
from ..services.github_cli import list_github_issues, get_github_issue

logger = logging.getLogger(__name__)


async def get_issues_list() -> str:
    """
    Get list of GitHub issues.

    URI: github://issues

    Returns formatted list of issues.
    """
    result = await list_github_issues(state="all", limit=50)

    if not result.get("success"):
        return f"Error: {result.get('error', 'Unknown error')}"

    issues = result.get("issues", [])

    if not issues:
        return "No issues found in the repository."

    lines = [
        "# GitHub Issues - ahk-wrapper-powershell",
        "",
        f"Total: {len(issues)} issues",
        "",
        "| # | Title | State | Labels |",
        "|---|-------|-------|--------|"
    ]

    for issue in issues:
        number = issue.get("number", "?")
        title = issue.get("title", "Untitled")[:50]
        state = issue.get("state", "unknown")
        labels = ", ".join([l.get("name", "") for l in issue.get("labels", [])])
        lines.append(f"| {number} | {title} | {state} | {labels} |")

    return "\n".join(lines)


async def get_issue_detail(issue_number: str) -> str:
    """
    Get details of a specific GitHub issue.

    URI: github://issues/{issue_number}

    Args:
        issue_number: The issue number as string

    Returns formatted issue details.
    """
    try:
        num = int(issue_number)
    except ValueError:
        return f"Error: Invalid issue number: {issue_number}"

    result = await get_github_issue(num)

    if not result.get("success"):
        return f"Error: {result.get('error', 'Unknown error')}"

    issue = result.get("issue", {})

    lines = [
        f"# Issue #{issue.get('number', '?')}: {issue.get('title', 'Untitled')}",
        "",
        f"**State**: {issue.get('state', 'unknown')}",
        f"**Author**: {issue.get('author', {}).get('login', 'unknown')}",
        f"**Created**: {issue.get('createdAt', 'unknown')}",
        f"**URL**: {issue.get('url', '')}",
    ]

    labels = issue.get("labels", [])
    if labels:
        label_names = ", ".join([l.get("name", "") for l in labels])
        lines.append(f"**Labels**: {label_names}")

    lines.extend([
        "",
        "## Description",
        "",
        issue.get("body", "_No description_"),
    ])

    comments = issue.get("comments", [])
    if comments:
        lines.extend([
            "",
            f"## Comments ({len(comments)})",
        ])
        for comment in comments[:10]:  # Limit to 10 comments
            author = comment.get("author", {}).get("login", "unknown")
            body = comment.get("body", "")[:200]
            lines.extend([
                "",
                f"**@{author}**:",
                body,
            ])

    return "\n".join(lines)
