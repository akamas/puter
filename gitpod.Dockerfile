FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package files and turbo config
COPY package.json ./
COPY package-lock.json ./
COPY turbo.json ./

# Copy all workspace directories to ensure npm ci can resolve dependencies
COPY apps/ ./apps/
COPY packages/ ./packages/

# Install all dependencies (including workspace dependencies)
RUN npm ci

# Build the web application
RUN npm run build --workspace=apps/web

# Stage 2: Production Nginx server
FROM nginx:alpine AS runner

# Create custom Nginx configuration directly in the Dockerfile for SPA routing
RUN echo "server {" > /etc/nginx/conf.d/default.conf \
    && echo "    listen 80;" >> /etc/nginx/conf.d/default.conf \
    && echo "    server_name localhost;" >> /etc/nginx/conf.d/default.conf \
    && echo "" >> /etc/nginx/conf.d/default.conf \
    && echo "    root /usr/share/nginx/html;" >> /etc/nginx/conf.d/default.conf \
    && echo "    index index.html index.htm;" >> /etc/nginx/conf.d/default.conf \
    && echo "" >> /etc/nginx/conf.d/default.conf \
    && echo "    location / {" >> /etc/nginx/conf.d/default.conf \
    && echo "        try_files \$uri \$uri/ /index.html;" >> /etc/nginx/conf.d/default.conf \
    && echo "    }" >> /etc/nginx/conf.d/default.conf \
    && echo "" >> /etc/nginx/conf.d/default.conf \
    && echo "    error_page 500 502 503 504 /50x.html;" >> /etc/nginx/conf.d/default.conf \
    && echo "    location = /50x.html {" >> /etc/nginx/conf.d/default.conf \
    && echo "        root /usr/share/nginx/html;" >> /etc/nginx/conf.d/default.conf \
    && echo "    }" >> /etc/nginx/conf.d/default.conf \
    && echo "}" >> /etc/nginx/conf.d/default.conf

# Copy built assets from the builder stage
COPY --from=builder /app/apps/web/dist /usr/share/nginx/html

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
