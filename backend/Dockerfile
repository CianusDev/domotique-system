FROM node:22-alpine

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# No --frozen-lockfile: pnpm reads pnpm-workspace.yaml for onlyBuiltDependencies
# allowing prisma/esbuild/etc. build scripts to run
RUN pnpm install --prefer-frozen-lockfile

COPY . .

RUN pnpm prisma generate && pnpm build

# Fail fast if build produced no output
RUN test -f dist/main.js || (echo "ERROR: dist/main.js missing — build failed" && exit 1)

EXPOSE 5000

CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/main"]
