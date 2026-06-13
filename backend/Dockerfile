FROM node:22-alpine

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# --ignore-scripts skips native build scripts (bcrypt removed, prisma generated manually)
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY . .

# Generate Prisma client (downloads binary) + compile TypeScript
RUN node_modules/.bin/prisma generate && pnpm build

EXPOSE 5000

# Run migrations then start
CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/main"]
