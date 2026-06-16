FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
ENV NODE_ENV=production
ENV PORT=8080
ENV NODE_OPTIONS="--require ./tracing.js"

COPY --from=deps /app/node_modules ./node_modules
COPY server.js tracing.js ./

USER node
EXPOSE 8080

CMD ["node", "server.js"]
