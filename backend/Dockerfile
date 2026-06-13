FROM node:22-alpine

WORKDIR /app

COPY package.json ./
RUN npm install

COPY . .

RUN npx prisma generate && npm run build

RUN test -f dist/src/main.js || (echo "ERROR: dist/src/main.js missing — build failed" && exit 1)

EXPOSE 5000

CMD ["sh", "-c", "npx prisma migrate deploy && npx prisma db seed && node dist/src/main"]
