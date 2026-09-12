# LongMemory server: REST API plus MCP over HTTP.
#
# Upstream publishes no pullable image (the GHCR package is not public), so this builds from a
# pinned commit. Releases are not usable as pins: main is 155 commits past the v1.3.0 tag and
# package.json reports a LOWER version than that tag, so a commit SHA is the only coherent anchor.
ARG LM_COMMIT=188a1dec829c69a97e6de6fe359ea0dd98080c10
ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${NODE_IMAGE} AS build
ARG LM_COMMIT
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
# Fetch exactly the pinned commit and prove it, so a moved branch cannot change the build.
RUN git init -q src \
    && git -C src remote add origin https://github.com/CaviraOSS/LongMemory.git \
    && git -C src fetch -q --depth 1 origin "${LM_COMMIT}" \
    && git -C src checkout -q FETCH_HEAD \
    && actual="$(git -C src rev-parse HEAD)" \
    && if [ "$actual" != "${LM_COMMIT}" ]; then \
         echo "expected ${LM_COMMIT}, got ${actual}" >&2; exit 1; \
       fi
WORKDIR /workspace/src
# Same build upstream's own Dockerfile performs: build the workspace, then pack a tarball so the
# runtime stage installs only production dependencies.
RUN corepack enable \
    && pnpm install --frozen-lockfile \
    && pnpm build \
    && pnpm pack --pack-destination /tmp/package

FROM ${NODE_IMAGE} AS runtime
# gosu drops privileges after the entrypoint has fixed volume ownership as root.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system longmemory \
    && useradd --system --gid longmemory --home /app longmemory
WORKDIR /app
COPY --from=build /tmp/package/*.tgz /tmp/longmemory.tgz
RUN npm install --omit=dev /tmp/longmemory.tgz && rm /tmp/longmemory.tgz

# LONGMEMORY_HOST=:: gives Node a dual-stack socket, which Railway's IPv6-only private network
# needs; the image default of 0.0.0.0 is reachable from the public edge but not from the dashboard.
# The database lives in a SUBDIRECTORY of the mount: a Railway volume root holds a root-owned
# lost+found, and the server runs unprivileged.
ENV NODE_ENV=production \
    LONGMEMORY_HOST=:: \
    LONGMEMORY_DB_PATH=/data/db/longmemory.db \
    LONGMEMORY_MCP_HTTP=true \
    LONGMEMORY_TELEMETRY=false
EXPOSE 7331
COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
