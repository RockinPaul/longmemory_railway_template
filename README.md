# LongMemory on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/longmemory?referralCode=YqmMB-&utm_medium=integration&utm_source=template&utm_campaign=generic)

Self-host [LongMemory](https://github.com/CaviraOSS/LongMemory), a persistent memory store for LLM
applications. It gives your assistants a place to remember things across sessions, over a REST API
and an MCP endpoint that Claude Desktop, GitHub Copilot, Codex and other MCP clients connect to
directly.

This template deploys the server and its web dashboard, with the memory database on a volume.

## What gets deployed

| Service | Build | Public | Purpose |
|---|---|---|---|
| `longmemory` | upstream source, pinned commit | yes | REST API (`/v1/*`), MCP endpoint (`/mcp`), SQLite database on a volume |
| `dashboard` | upstream `dashboard/`, pinned commit | yes | Next.js UI to browse, search and manage memories |

There is no external database. LongMemory stores everything in SQLite on the `longmemory` service's
volume, which keeps this a cheap two-service deployment.

## First run

1. Deploy the template. Both services build from source, so the first deploy takes several minutes.
2. Open the `dashboard` service's URL to browse memories.
3. To connect an MCP client, point it at `https://YOUR-LONGMEMORY-DOMAIN/mcp` and send the
   `LONGMEMORY_API_KEY` as a bearer token. Copy that key from the `longmemory` service's variables.

## Set an embedding key, or recall will be poor

This is the one thing worth doing before you rely on it.

LongMemory supports OpenAI, Gemini, AWS Bedrock and Ollama embeddings, and **none is required**.
Without one it falls back to a built-in `synthetic` provider, which builds vectors by summing
SHA-256 hashes of the words in a text. It never errors, so it looks like it is working, but:

- Queries that share actual words with a memory do retrieve it (a query repeating three words of a
  stored sentence scored 0.656 in testing).
- Queries that share only *meaning* do not. Everything unrelated clusters around 0.265, which is
  noise rather than ranking.
- In `strict` recall mode the confidence floor then filters those weak matches out, so a query can
  fail to return the very memory it was describing. `associative` mode still returns it.

Set `OPENAI_API_KEY` or `GEMINI_API_KEY` on the `longmemory` service and redeploy. The entrypoint
picks the provider automatically from whichever key it finds, and logs a warning on every boot
while it is running on `synthetic`.

## Variables

Everything is wired for you; these are the ones worth knowing.

| Service | Variable | Default | Purpose |
|---|---|---|---|
| `longmemory` | `LONGMEMORY_API_KEY` | generated (48 chars) | Bearer token for the API and MCP endpoint. The container refuses to start if it is empty or under 16 characters. |
| `longmemory` | `OPENAI_API_KEY` | empty | Enables real semantic embeddings. See above. |
| `longmemory` | `GEMINI_API_KEY` | empty | Alternative embedding provider. |
| `longmemory` | `LONGMEMORY_TELEMETRY` | `false` | Upstream defaults this to `true`; this template turns it off. |
| `dashboard` | `LONGMEMORY_API_URL` | private URL | Set by reference; the dashboard reaches the server over the private network. |
| `dashboard` | `LONGMEMORY_API_KEY` | reference | Must match the server's key; set by reference. |

## Security notes

- **The API key is the only boundary.** Anyone holding it can read and write every memory.
- **`user_id` is metadata, not tenancy.** A recall sent with one `user_id` returns memories ingested
  under a different one; they all live in one store. Do not treat `user_id` as separation between
  customers or colleagues. Upstream's `worlds` concept is the thing to look at if you need that.
- **`/health` is intentionally unauthenticated** so the platform can probe it. It reports readiness
  and store counts (nodes, edges, entities) but no memory content.
- The dashboard reads the key server-side and proxies requests through its own route, so the key is
  never in the browser bundle. Upstream also offers `NEXT_PUBLIC_API_KEY` for direct browser calls;
  this template does not use it, because any `NEXT_PUBLIC_*` value ships to the client.

## How it fits together

- The browser talks to `dashboard`; `dashboard` talks to `longmemory` over Railway's private
  network; MCP clients talk to `longmemory` directly over HTTPS.
- `LONGMEMORY_HOST=::` gives the server a dual-stack socket. Railway's private network is IPv6, and
  upstream's default of `0.0.0.0` is reachable from the public edge but not from the dashboard.
- The dashboard's entrypoint exports `HOSTNAME=::` before starting Next.js. Railway injects
  `HOSTNAME` with the container's own hostname at run time, overriding anything set in the image,
  and Next.js binds whatever it finds there.
- The database lives in `/data/db`, a subdirectory of the volume, because a Railway volume root
  contains a root-owned `lost+found`. The entrypoint creates and chowns it as root, then drops to
  an unprivileged user with `gosu`.
- Healthchecks are `/health` on the server and `/api/settings` on the dashboard.

## Bumping LongMemory

Upstream's releases are not usable as version pins: `main` is over 150 commits past the `v1.3.0`
tag, and `package.json` on `main` reports a *lower* version than that tag. Both Dockerfiles
therefore pin a commit SHA and assert it after fetching, so a moved branch fails the build instead
of silently changing it.

Change `LM_COMMIT` in `longmemory/Dockerfile` and `dashboard/Dockerfile` to the same new SHA.

## Component licenses

The wrapper files here are MIT (see `LICENSE`). LongMemory itself is Apache-2.0.
