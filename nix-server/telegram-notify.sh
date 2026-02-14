#!/bin/sh
set -a
. /home/nix/git/monorepo/nix-server/.env
set +a

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    STATUS="$1"
    TIMESTAMP=$(date '+%H:%M:%S on %Y-%m-%d')
    MESSAGE="${STATUS} at ${TIMESTAMP}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=Markdown" > /dev/null 2>&1 || true
fi