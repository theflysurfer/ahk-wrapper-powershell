#!/usr/bin/env python3
"""
AHK MCP Server - Entry point
Standalone entry point that works with absolute path (no cwd needed).
Compatible with reloaderoo hot-reload.
"""
import sys
from pathlib import Path

# Add project root to Python path
PROJECT_ROOT = Path(__file__).parent.resolve()
SRC_PATH = PROJECT_ROOT / "src"
if str(SRC_PATH) not in sys.path:
    sys.path.insert(0, str(SRC_PATH))

# Setup early logging before any imports
import logging
from logging.handlers import RotatingFileHandler

log_dir = PROJECT_ROOT / "logs"
log_dir.mkdir(exist_ok=True)

# Configure logging
log_file = log_dir / "mcp-server.log"
handler = RotatingFileHandler(
    log_file,
    maxBytes=2 * 1024 * 1024,  # 2MB
    backupCount=5,
    encoding="utf-8"
)
handler.setFormatter(logging.Formatter(
    "[%(asctime)s] %(levelname)s [%(name)s]: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
))

# Setup root logger
root_logger = logging.getLogger()
root_logger.addHandler(handler)
root_logger.setLevel(logging.DEBUG)

# Also log to stderr for MCP inspector debugging
stderr_handler = logging.StreamHandler(sys.stderr)
stderr_handler.setFormatter(logging.Formatter("[%(levelname)s] %(message)s"))
stderr_handler.setLevel(logging.INFO)
root_logger.addHandler(stderr_handler)

logger = logging.getLogger("ahk_mcp")
logger.info("=" * 50)
logger.info("AHK MCP Server starting...")
logger.info(f"Project root: {PROJECT_ROOT}")
logger.info(f"Python: {sys.executable}")
logger.info("=" * 50)

# Now import and run the server
try:
    from ahk_mcp.server import mcp
    logger.info("Server module loaded successfully")
except Exception as e:
    logger.exception(f"Failed to import server module: {e}")
    raise

if __name__ == "__main__":
    logger.info("Starting MCP server...")
    mcp.run()
