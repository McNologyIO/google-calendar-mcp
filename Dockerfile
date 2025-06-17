FROM node:22-alpine

RUN apk add --no-cache python3 py3-pip git bash

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

# Set working directory
WORKDIR /app

# Copy package files for dependency caching
COPY package*.json ./

# Copy build scripts and source files needed for build
COPY scripts ./scripts
COPY src ./src
COPY tsconfig.json .

# Install all dependencies (including dev dependencies for build)
RUN npm ci --no-audit --no-fund --silent

# Build the project
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production --silent

# Create config directory and set permissions
RUN mkdir -p /home/nodejs/.config/google-calendar-mcp && \
    chown -R nodejs:nodejs /home/nodejs/.config && \
    chown -R nodejs:nodejs /app

RUN pip install git+https://github.com/sparfenyuk/mcp-proxy.git --break-system-packages

# Switch to non-root user
USER nodejs

# Create entrypoint script that serves on /sse
RUN echo '#!/bin/bash\n\
mcp-proxy --sse-port=8000 --sse-host=0.0.0.0 --pass-environment -- node build/index.js' \
> /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
