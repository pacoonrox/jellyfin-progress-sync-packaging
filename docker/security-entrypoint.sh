#!/bin/sh
set -eu

SECURITY_ALERTS_CONFIG="${SECURITY_ALERTS_CONFIG:-/config/security-alerts.json}"

python3 /opt/jellyfin-security/security_agent.py --config "$SECURITY_ALERTS_CONFIG" &
SECURITY_AGENT_PID="$!"

/jellyfin/jellyfin "$@" &
JELLYFIN_PID="$!"

cleanup() {
    if kill -0 "$SECURITY_AGENT_PID" 2>/dev/null; then
        kill "$SECURITY_AGENT_PID" 2>/dev/null || true
    fi
    if kill -0 "$JELLYFIN_PID" 2>/dev/null; then
        kill "$JELLYFIN_PID" 2>/dev/null || true
    fi
}

trap cleanup INT TERM EXIT

wait "$JELLYFIN_PID"
