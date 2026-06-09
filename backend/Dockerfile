# ── Stage 1: build ──────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy manifests first for layer caching
COPY package.json pnpm-lock.yaml ./

# Install all deps (including devDeps needed for build)
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Generate Prisma client
RUN pnpm prisma generate

# Compile TypeScript
RUN pnpm build

# ── Stage 2: production image ────────────────────────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./

# Production deps only
RUN pnpm install --frozen-lockfile --prod

# Copy compiled output + generated Prisma client
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/generated ./generated

# Copy prisma schema (needed for migrations at runtime)
COPY prisma ./prisma

EXPOSE 5000

CMD ["node", "dist/main"]
