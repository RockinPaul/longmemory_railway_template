# Deploy and Host LongMemory on Railway

[LongMemory](https://github.com/CaviraOSS/LongMemory) is an open-source persistent memory store for
LLM applications. It gives assistants and agents somewhere to remember things between sessions,
through a REST API and an MCP endpoint that Claude Desktop, GitHub Copilot, Codex and other MCP
clients connect to directly.

## About Hosting LongMemory

This template deploys two services: the memory server and its web dashboard. There is no external
database to run, because LongMemory keeps everything in SQLite on a volume, which makes this a
genuinely small deployment for what it does. The server gets a public HTTPS domain so MCP clients
can reach it, the dashboard gets its own, and the two talk over Railway's private network. An API
key is generated for you and the server refuses to start without one, so the deployment is never
briefly open while you configure it.

One thing is worth doing before you rely on it. LongMemory can use OpenAI, Gemini, AWS Bedrock or
Ollama for embeddings, and none of them is required, but without one it falls back to a built-in
provider that hashes words into vectors. That never raises an error, so it looks like it is working,
yet only queries repeating a memory's actual words retrieve it reliably. Set an embedding key on
the server and recall becomes semantic; until you do, every boot logs a warning saying so.

## Common Use Cases

- Give Claude Desktop, Copilot or Codex a shared memory that survives across sessions and machines.
- Keep an agent's long-term memory on infrastructure you control rather than a hosted memory SaaS.
- Browse, search and prune what your assistants have remembered through the included dashboard.

## Dependencies for LongMemory Hosting

- A volume for the SQLite database, which the template creates.
- Optionally an embedding provider key (OpenAI, Gemini or AWS Bedrock) for semantic recall.
- An MCP-capable client, if you want to connect one rather than use the REST API.

### Deployment Dependencies

- [LongMemory](https://github.com/CaviraOSS/LongMemory) — the upstream project (Apache-2.0).
- [LongMemory documentation](https://github.com/CaviraOSS/LongMemory/blob/main/docs/api.md) — the
  REST API reference.
- [Model Context Protocol](https://modelcontextprotocol.io) — the protocol MCP clients speak.

### Implementation Details

Two services build from this template's repository, each from its own directory:

- **longmemory** — the server, built from upstream source at a pinned commit. Upstream publishes no
  pullable image, and its release tags cannot be used as pins because the default branch is more
  than 150 commits past the newest tag while reporting a lower version number, so both Dockerfiles
  fetch one commit and assert its SHA. It listens dual-stack, keeps its database in a subdirectory
  of the volume because a Railway volume root holds a root-owned lost+found, and drops privileges
  after preparing that directory. Healthcheck on `/health`; MCP on `/mcp`.
- **dashboard** — the upstream Next.js dashboard. It reads the API key server-side and proxies
  requests through its own route, so the key never reaches the browser. Healthcheck on
  `/api/settings`.

After deploying, open the dashboard's URL to browse memories. To connect an MCP client, point it at
the longmemory service's domain with `/mcp` appended and send `LONGMEMORY_API_KEY` as a bearer
token. That key is the only access boundary: anyone holding it can read and write everything, and
the `user_id` field on the API is metadata rather than a tenancy boundary, so recalls are not
separated by it.

Telemetry is disabled in this template; upstream enables it by default.

## Why Deploy LongMemory on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying LongMemory on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
