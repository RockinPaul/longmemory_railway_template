# Changelog

## 2026-09-30

- Server build applies `longmemory/patches/` on top of the pinned commit.
- First patch: project-scoped writes (`longmemory_ingest` with `project_id`,
  `longmemory_remember_decision`, connector imports) are now embedded. Upstream stored them with no
  semantic vector, so they never received a vector score in recall
  ([CaviraOSS/LongMemory#216](https://github.com/CaviraOSS/LongMemory/issues/216), fix in
  [#217](https://github.com/CaviraOSS/LongMemory/pull/217)).

## 2026-09-12

Initial template.

- Two services: `longmemory` (server, volume) and `dashboard` (Next.js UI).
- Both pinned to upstream commit `188a1dec829c69a97e6de6fe359ea0dd98080c10`, asserted at build time
  because upstream's release tags are behind its default branch and report a lower version.
- Server refuses to start without a `LONGMEMORY_API_KEY` of at least 16 characters; upstream
  defaults it to empty, which serves the API to anyone.
- `LONGMEMORY_HOST=::` for the IPv6 private network; `HOSTNAME=::` exported in the dashboard
  entrypoint because Railway injects `HOSTNAME` at run time and Next.js binds it.
- Database in `/data/db`, created and chowned as root before dropping privileges with `gosu`.
- Embedding provider selected automatically from whichever credential is present, with a startup
  warning when falling back to the built-in `synthetic` provider.
- Telemetry off by default (upstream enables it).
