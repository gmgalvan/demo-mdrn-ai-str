# --- Build stage: compile the Angular app ---
FROM node:22-alpine AS builder

WORKDIR /build

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build -- --configuration production

# --- Runtime stage: serve the static build behind nginx ---
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=builder /build/dist/webui/browser /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Overridden in k8s to point at the payment-api Service DNS name.
ENV PAYMENTS_API_URL=http://payment-api.demo.svc.cluster.local

EXPOSE 8080
