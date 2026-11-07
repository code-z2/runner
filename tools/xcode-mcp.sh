#!/bin/sh
# Xcode MCP bridge for agent sessions.
#
# One-time prerequisites (need your password):
#   sudo xcode-select -s /Applications/Xcode.app
#   sudo xcrun mcp-server enable
#   sudo xcrun mcp-server allow-folder ~/Developer/runner
#   xcrun mcp-server open ~/Developer/runner/apps/ios/Runner.xcodeproj
#
# Usage: tools/xcode-mcp.sh
# Speaks MCP JSON-RPC on stdin/stdout. Prefers the open Xcode app when one
# is running, otherwise reaches the headless MCP server.
set -u

XCODE_PID=$(osascript -e 'tell application "System Events" to get unix id of (first process whose name is "Xcode")' 2>/dev/null || true)
if [ -n "$XCODE_PID" ]; then
    export MCP_XCODE_PID="$XCODE_PID"
fi
exec xcrun mcpbridge
