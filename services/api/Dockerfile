# Build context is the repository root (see docker-compose.yml).
FROM node:22.11.0-alpine3.20 AS build
WORKDIR /repo/services/api
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci
COPY services/api/ ./
RUN npm run build

FROM node:22.11.0-alpine3.20
WORKDIR /app
ENV NODE_ENV=production
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /repo/services/api/dist ./dist
USER node
EXPOSE 8787
CMD ["node", "dist/server.js"]
