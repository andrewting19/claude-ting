FROM node:20-slim

# Install SSH client and tmux
RUN apt-get update && apt-get install -y \
    openssh-client \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm install

# Copy source code
COPY tsconfig.json ./
COPY src ./src

# Build TypeScript
RUN npm run build

# Remove dev dependencies after build
RUN npm prune --production

# Create data directory for SQLite database
RUN mkdir -p /data

# Set environment variables
ENV NODE_ENV=production
ENV PORT=6767

# Expose port
EXPOSE 6767

# Start the server
CMD ["npm", "start"]
