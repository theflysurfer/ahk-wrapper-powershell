"""GitHub CLI wrapper service."""
import asyncio
import json
import logging
import subprocess
import tempfile
import os
from typing import Optional

logger = logging.getLogger(__name__)

# Repository for issues
GITHUB_REPO = "theflysurfer/ahk-wrapper-powershell"


# Cached token (loaded once at module import)
_cached_gh_token: Optional[str] = None


def _load_gh_token_sync() -> Optional[str]:
    """Synchronously load GH token (called at module import)."""
    # First check environment variable
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        logger.info("Using GH_TOKEN from environment")
        return token

    # Try to get token from gh auth
    try:
        result = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            logger.info("Loaded GH token from 'gh auth token'")
            return result.stdout.strip()
    except Exception as e:
        logger.debug(f"Could not get token from gh auth: {e}")

    return None


# Load token at module import (runs in main process context)
_cached_gh_token = _load_gh_token_sync()


async def _get_gh_token() -> Optional[str]:
    """Get GitHub token (uses cached value)."""
    global _cached_gh_token

    if _cached_gh_token:
        return _cached_gh_token

    # Fallback: check env again (might have been set after import)
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        _cached_gh_token = token
        return token

    return None


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

    # Get token for subprocess environment (avoids keyring access issues)
    token = await _get_gh_token()
    if not token:
        return {
            "success": False,
            "error": (
                "No GitHub token found. The MCP subprocess cannot access Windows Credential Manager.\n"
                "Solution: Set GH_TOKEN environment variable before starting Claude Code:\n"
                "  PowerShell: $env:GH_TOKEN = (gh auth token)\n"
                "  Or add to your profile: $env:GH_TOKEN = 'ghp_yourtoken'"
            )
        }

    # Build environment with token
    env = os.environ.copy()
    env["GH_TOKEN"] = token

    # Write body to temp file to avoid shell escaping issues with long bodies
    body_file = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
    body_file.write(body)
    body_file.close()

    cmd = [
        "gh", "issue", "create",
        "--repo", GITHUB_REPO,
        "--title", title,
        "--body-file", body_file.name
    ]

    if labels:
        for label in labels:
            cmd.extend(["--label", label])

    # Use temp file for output to avoid pipe issues
    output_file = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8')
    output_file.close()
    error_file = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8')
    error_file.close()

    try:
        # Use Popen with file output to avoid pipe inheritance issues
        with open(output_file.name, 'w', encoding='utf-8') as stdout_f, \
             open(error_file.name, 'w', encoding='utf-8') as stderr_f:
            process = subprocess.Popen(
                cmd,
                stdout=stdout_f,
                stderr=stderr_f,
                env=env,  # Pass GH_TOKEN to avoid keyring issues
                creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
            )

            # Wait with timeout
            try:
                exit_code = await asyncio.wait_for(
                    asyncio.to_thread(process.wait),
                    timeout=25  # Leave margin for MCP timeout
                )
            except asyncio.TimeoutError:
                process.kill()
                process.wait()
                return {
                    "success": False,
                    "error": "gh command timed out (25s). Check network connection."
                }

        # Read output
        stdout = ""
        stderr = ""
        if os.path.exists(output_file.name):
            with open(output_file.name, 'r', encoding='utf-8') as f:
                stdout = f.read().strip()
        if os.path.exists(error_file.name):
            with open(error_file.name, 'r', encoding='utf-8') as f:
                stderr = f.read().strip()

        if exit_code == 0:
            # gh outputs the issue URL on success
            url = stdout
            # Extract issue number from URL
            number = url.split("/")[-1] if url else "?"

            logger.info(f"Issue created: {url}")
            return {
                "success": True,
                "url": url,
                "number": number
            }
        else:
            error_msg = stderr or stdout or "Unknown error"
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
    except Exception as e:
        logger.exception(f"Error creating issue: {e}")
        return {
            "success": False,
            "error": str(e)
        }
    finally:
        # Cleanup temp files
        for f in [body_file.name, output_file.name, error_file.name]:
            try:
                if os.path.exists(f):
                    os.unlink(f)
            except Exception:
                pass


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
