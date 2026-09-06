# Portable image for hosts without a Node buildpack (Fly.io, Koyeb, Cloud Run).
# On Render the native Node runtime in render.yaml is simpler and this is unused.
FROM node:22-alpine

WORKDIR /app

# Dependencies first so a code change does not reinstall them.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY db ./db

# Don't run as root.
USER node

ENV NODE_ENV=production
ENV PORT=4000
EXPOSE 4000

# The server migrates and seeds on boot, so there is no separate release step.
CMD ["node", "src/server.js"]
