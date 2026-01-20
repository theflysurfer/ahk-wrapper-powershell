"""GitHub CLI wrapper service."""
import asyncio
import json
import logging
import subprocess
from typing import Optional

logger = logging.getLogger(__name__)

# Repository for issues
GITHUB_REPO = "theflysurfer/ahk-wrapper-powershell"


async def create_github_issue(
    title: str,
    body: str,
    labels: Optional[list[str]] = None
) -> dict:
    """
    Create a GitHub issue using gh CLI.

    Args:
        title: Issue title
        body: Issue body (Markdown)
        labels: Optional list of labels

    Returns:
        Dict with success, url, number, or error
    """
    logger.info(f"Creating issue: {title[:50]}...")

    cmd = [
        "gh", "issue", "create",
        "--repo", GITHUB_REPO,
        "--title", title,
        "--body", body
    ]

    if labels:
        for label in labels:
            cmd.extend(["--label", label])

    try:
        result = await asyncio.to_thread(
            subprocess.run,
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30
        )

        if result.returncode == 0:
            # gh outputs the issue URL on success
            url = result.stdout.strip()
            # Extract issue number from URL
            number = url.split("/")[-1] if url else "?"

            logger.info(f"Issue created: {url}")
            return {
                "success": True,
                "url": url,
                "number": number
            }
        else:
            error_msg = result.stderr or result.stdout or "Unknown error"
            logger.error(f"gh issue create failed: {error_msg}")
            return {
                "success": False,
                "error": error_msg
            }

    except FileNotFoundError:
        return {
            "success": False,
            "error": "gh CLI not found. Install from https://cli.github.com/"
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": "gh command timed out"
        }
    except Exception as e:
        logger.exception(f"Error creating issue: {e}")
        return {
            "success": False,
            "error": str(e)
        }


async def list_github_issues(state: str = "open", limit: int = 30) -> dict:
    """
    List GitHub issues using gh CLI.

    Args:
        state: "open", "closed", or "all"
        limit: Maximum number of issues to return

    Returns:
        Dict with success and issues list, or error
    """
    logger.info(f"Listing issues: state={state}, limit={limit}")

    cmd = [
        "gh", "issue", "list",
        "--repo", GITHUB_REPO,
        "--state", state,
        "--limit", str(limit),
        "--json", "number,title,state,labels,createdAt,url"
    ]

    try:
        result = await asyncio.to_thread(
            subprocess.run,
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30
        )

        if result.returncode == 0:
            issues = json.loads(result.stdout) if result.stdout else []
            return {
                "success": True,
                "issues": issues
            }
        else:
            return {
                "success": False,
                "error": result.stderr or "Failed to list issues"
            }

    except FileNotFoundError:
        return {
            "success": False,
            "error": "gh CLI not found"
        }
    except Exception as e:
        logger.exception(f"Error listing issues: {e}")
        return {
            "success": False,
            "error": str(e)
        }


async def get_github_issue(issue_number: int) -> dict:
    """
    Get a specific GitHub issue.

    Args:
        issue_number: Issue number

    Returns:
        Dict with issue details or error
    """
    logger.info(f"Getting issue #{issue_number}")

    cmd = [
        "gh", "issue", "view",
        "--repo", GITHUB_REPO,
        str(issue_number),
        "--json", "number,title,body,state,labels,createdAt,url,author,comments"
    ]

    try:
        result = await asyncio.to_thread(
            subprocess.run,
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30
        )

        if result.returncode == 0:
            issue = json.loads(result.stdout) if result.stdout else {}
            return {
                "success": True,
                "issue": issue
            }
        else:
            return {
                "success": False,
                "error": result.stderr or f"Issue #{issue_number} not found"
            }

    except FileNotFoundError:
        return {
            "success": False,
            "error": "gh CLI not found"
        }
    except Exception as e:
        logger.exception(f"Error getting issue: {e}")
        return {
            "success": False,
            "error": str(e)
        }
