# Use the official Node.js image with Debian (Playwright requires additional deps)
FROM mcr.microsoft.com/playwright:v1.48.0-jammy

WORKDIR /usr/src/app

COPY package.json tsconfig.json ./

# Install all dependencies including dev deps for building
RUN npm install && \
    npx playwright install --with-deps chromium

COPY src ./src

# Build TypeScript
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production

ENV NODE_ENV=production

EXPOSE 8080

CMD ["npm", "start"]


