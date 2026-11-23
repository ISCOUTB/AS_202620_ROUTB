# Etapa 1: compilar Flutter Web
FROM ubuntu:24.04 AS builder

# Versión fijada para que el despliegue sea reproducible. Debe ser compatible
# con el SDK de Dart declarado en pubspec.yaml (^3.13.1).
ARG FLUTTER_VERSION=3.47.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

WORKDIR /app

# Copia primero los manifiestos para reutilizar la capa de dependencias.
COPY pubspec.yaml pubspec.lock ./
RUN flutter config --enable-web \
    && flutter pub get

COPY . .

# La URL debe ser la del frontend seguida de /api: Nginx quita ese prefijo y
# reenvía la petición al backend. Se puede sobreescribir en Dokploy con
# --build-arg ROUTB_API_BASE_URL=...
ARG ROUTB_API_BASE_URL=https://approutb.iscoutb.dev/api

# La versión web usa el catálogo local de barrios.
RUN flutter build web --release \
    --dart-define=ROUTB_API_BASE_URL="${ROUTB_API_BASE_URL}"

# Etapa 2: servir la aplicación con Nginx
FROM ghcr.io/nginx/nginx-unprivileged:stable-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

USER 101
EXPOSE 8080
