FROM node:22-alpine

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

# Generate Prisma client + compile TypeScript
RUN pnpm prisma generate && pnpm build

EXPOSE 5000

# Run migrations then start
CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/main"]
