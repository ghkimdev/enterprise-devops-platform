# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

ARG APP_VERSION=dev
ENV VITE_APP_VERSION=${APP_VERSION}

# Nexus npm proxy 사용 시 npm config로 registry 변경
# RUN npm config set registry http://nexus.example.com/repository/npm-proxy/

COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 헬스 체크용 엔드포인트는 nginx.conf 에 정의됨
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O - http://localhost/healthz || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
