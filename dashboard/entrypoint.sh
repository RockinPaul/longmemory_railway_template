#!/bin/sh
# Bind dual-stack, then start Next.js.
#
# Next.js binds the address in HOSTNAME. Railway injects HOSTNAME at run time with the container's
# hostname, overriding anything set in the image, and the result is a listener the platform's
# health check cannot reach. Exporting it here is the only place that wins.
set -eu

if [ -z "${LONGMEMORY_API_URL:-}" ]; then
  echo "LONGMEMORY_API_URL is empty; the dashboard needs the longmemory service's private URL" >&2
  exit 1
fi
if [ -z "${LONGMEMORY_API_KEY:-}" ]; then
  echo "LONGMEMORY_API_KEY is empty; it must match the longmemory service's key" >&2
  exit 1
fi

export HOSTNAME="${NEXT_BIND_HOST:-::}"
echo "dashboard binding [${HOSTNAME}]:${PORT:-3000}, proxying to ${LONGMEMORY_API_URL}"
exec npm start
