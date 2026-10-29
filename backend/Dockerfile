# syntax=docker/dockerfile:1

FROM node:22.23.4-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da AS base
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*
# npm 自己的 HTTP client 與應用圖分開修補，不改寫 npm 版號。
RUN npm install --prefix /tmp/npm-security --ignore-scripts --no-audit --no-fund undici@6.29.1 \
  && rm -rf /usr/local/lib/node_modules/npm/node_modules/undici \
  && cp -a /tmp/npm-security/node_modules/undici /usr/local/lib/node_modules/npm/node_modules/undici \
  && rm -rf /tmp/npm-security \
  && node -e "if(require('/usr/local/lib/node_modules/npm/node_modules/undici/package.json').version!=='6.29.1')process.exit(1)"

FROM base AS production-dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM base AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY scripts ./scripts
COPY public ./public
RUN npm run build

FROM base AS runtime
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000
WORKDIR /app
COPY --from=production-dependencies /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json package-lock.json ./
COPY migrations ./migrations
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]
CMD ["sh", "-c", "node dist/scripts/preflight.js && if [ \"$DATA_PROVIDER\" = \"postgres\" ]; then node dist/scripts/migrate.js; fi && exec node dist/src/main.js"]
