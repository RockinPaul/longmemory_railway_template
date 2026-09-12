#!/bin/sh
# Prepare the volume, pick an embedding provider, then drop privileges and start the server.
#
# Runs as root only long enough to fix ownership of the volume subdirectory: Railway mounts a
# volume whose root is owned by root and contains lost+found, and the server runs unprivileged.
set -eu

DB_DIR="$(dirname "${LONGMEMORY_DB_PATH:-/data/db/longmemory.db}")"

# The upstream default for this variable is EMPTY, which serves the API and MCP endpoint to anyone
# who finds the URL. A public Railway domain makes that unacceptable, so refuse to start.
if [ -z "${LONGMEMORY_API_KEY:-}" ]; then
  echo "LONGMEMORY_API_KEY is empty; refusing to start an unauthenticated memory store on a public URL" >&2
  exit 1
fi
if [ "${#LONGMEMORY_API_KEY}" -lt 16 ]; then
  echo "LONGMEMORY_API_KEY must be at least 16 characters" >&2
  exit 1
fi

mkdir -p "$DB_DIR"
chown -R longmemory:longmemory "$DB_DIR"

# Choose the embedding provider from whichever credential is present. Without one, LongMemory
# falls back to its "synthetic" provider, which is a bag of SHA-256 token hashes: texts that share
# words match, texts that share only meaning do not. That is lexical recall, not semantic, and it
# never raises an error - so say so loudly rather than let it look like a working feature.
if [ -z "${LONGMEMORY_EMBEDDING_PROVIDER:-}" ]; then
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    LONGMEMORY_EMBEDDING_PROVIDER=openai
  elif [ -n "${GEMINI_API_KEY:-}" ]; then
    LONGMEMORY_EMBEDDING_PROVIDER=gemini
  elif [ -n "${LONGMEMORY_OLLAMA_URL:-}" ]; then
    LONGMEMORY_EMBEDDING_PROVIDER=ollama
  elif [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    LONGMEMORY_EMBEDDING_PROVIDER=aws
  else
    LONGMEMORY_EMBEDDING_PROVIDER=synthetic
  fi
  export LONGMEMORY_EMBEDDING_PROVIDER
fi

if [ "$LONGMEMORY_EMBEDDING_PROVIDER" = "synthetic" ]; then
  echo "WARNING: no embedding credential found, using the built-in 'synthetic' provider." >&2
  echo "         Recall will match on shared WORDS, not on meaning. Set OPENAI_API_KEY or" >&2
  echo "         GEMINI_API_KEY on this service and redeploy for semantic recall." >&2
else
  echo "embedding provider: $LONGMEMORY_EMBEDDING_PROVIDER"
fi

echo "listening on [${LONGMEMORY_HOST}]:${PORT:-${LONGMEMORY_PORT:-7331}}, database in $DB_DIR"
exec gosu longmemory ./node_modules/.bin/longmemory serve --mcp-http "$@"
