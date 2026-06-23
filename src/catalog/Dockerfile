# === ETAPA 1: Compilación (Builder) ===
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Instalamos git por si alguna dependencia lo requiere
RUN apk add --no-cache git

# 1. Copiamos ABSOLUTAMENTE TODO el código fuente primero
COPY . .

# 2. Ahora que los archivos .go están presentes, Go puede analizar el proyecto,
# descargar pgx v5.9.0 y grpc v1.79.3, y meter sus firmas criptográficas en go.sum
RUN go mod tidy

# 3. Compilamos el binario de forma segura
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o catalog-app .


# === ETAPA 2: Producción (Imagen final ligera y segura) ===
FROM alpine:3.20

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/catalog-app .
COPY --from=builder /app/repository ./repository

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

CMD ["./catalog-app"]