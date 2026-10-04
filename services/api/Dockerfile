# Build context is the repository root (see docker-compose.yml).
FROM node:22.11.0-alpine3.20 AS build
WORKDIR /repo/services/api
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci
COPY services/api/ ./
COPY packages/domain/ /repo/packages/domain/
RUN npm run build

FROM node:22.11.0-alpine3.20
WORKDIR /app
ENV NODE_ENV=production
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /repo/services/api/dist ./dist
COPY services/api/migrations ./migrations
ENV MIGRATIONS_DIR=/app/migrations
COPY services/api/api ./api
ENV CONTRACT_PATH=/app/api/openapi.yaml
USER node
EXPOSE 8787
CMD ["node", "dist/server.js"]
