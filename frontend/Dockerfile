# ==========================================
# Stage 1: Build the Vite App
# ==========================================
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Accept the API URL passed from GitHub Actions during the build step
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

# Compile the React/Vite app into static HTML/JS/CSS (outputs to /dist)
RUN npm run build

# ==========================================
# Stage 2: Serve with Nginx
# ==========================================
FROM nginx:alpine

# Copy the compiled assets from the builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy our custom Nginx routing configuration (created in the next step)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80 for the AWS Load Balancer
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]