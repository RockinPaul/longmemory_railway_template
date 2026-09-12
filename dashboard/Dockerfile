# LongMemory dashboard: the Next.js web UI.
#
# It talks to the server through its own server-side proxy route (app/api/longmemory/[...path]),
# so the API key is read from LONGMEMORY_API_URL/LONGMEMORY_API_KEY in the Node process and never
# reaches the browser bundle. Upstream's NEXT_PUBLIC_* variables would expose it; they are not used.
ARG LM_COMMIT=188a1dec829c69a97e6de6fe359ea0dd98080c10
ARG NODE_IMAGE=node:20-alpine

FROM ${NODE_IMAGE} AS build
ARG LM_COMMIT
RUN apk add --no-cache git
WORKDIR /workspace
RUN git init -q src \
    && git -C src remote add origin https://github.com/CaviraOSS/LongMemory.git \
    && git -C src fetch -q --depth 1 origin "${LM_COMMIT}" \
    && git -C src checkout -q FETCH_HEAD \
    && actual="$(git -C src rev-parse HEAD)" \
    && if [ "$actual" != "${LM_COMMIT}" ]; then \
         echo "expected ${LM_COMMIT}, got ${actual}" >&2; exit 1; \
       fi
WORKDIR /workspace/src/dashboard
RUN npm ci && npm run build

FROM ${NODE_IMAGE} AS runtime
WORKDIR /app
COPY --from=build /workspace/src/dashboard/package.json ./package.json
COPY --from=build /workspace/src/dashboard/package-lock.json ./package-lock.json
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /workspace/src/dashboard/.next ./.next
COPY --from=build /workspace/src/dashboard/public ./public
COPY --from=build /workspace/src/dashboard/next.config.js ./next.config.js
RUN addgroup -g 1001 -S nodejs \
    && adduser -u 1001 -S nextjs -G nodejs \
    && chown -R nextjs:nodejs /app
USER nextjs
ENV NODE_ENV=production
EXPOSE 3000
# HOSTNAME is deliberately NOT set here. Railway injects it with the container's own hostname at
# run time, which overrides any ENV baked into the image, and Next.js binds whatever it finds.
COPY --chmod=755 entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
