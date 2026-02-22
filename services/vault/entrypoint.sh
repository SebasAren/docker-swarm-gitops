#!/bin/sh
set -e

RAFT_PATH="/vault/data"

if [ -d "$RAFT_PATH" ]; then
    chown -R 100:1000 "$RAFT_PATH"
    chmod -R 770 "$RAFT_PATH"
fi

exec su-exec vault:vault vault server -config=/vault/config/config.hcl
