# ==========================================
# Stage 1: Build the Node App
# ==========================================
FROM node:22-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json first (optimizes Docker caching)
COPY package*.json ./

# Install all dependencies cleanly (including devDependencies for tsc)
RUN npm ci

# Copy the rest of your backend code and build
COPY . .
RUN npm run build

# ==========================================
# Stage 2: Production Final Image
# ==========================================
FROM node:22-alpine

WORKDIR /app

# Copy only package.json and package-lock.json to install prod dependencies
COPY package*.json ./

# Install ONLY production dependencies
RUN npm ci --omit=dev

# Copy compiled output from the builder stage
COPY --from=builder /app/dist ./dist

# Expose the port Fastify is running on
EXPOSE 8080

# Run the Fastify server using the compiled node entrypoint
CMD ["node", "dist/server.js"]