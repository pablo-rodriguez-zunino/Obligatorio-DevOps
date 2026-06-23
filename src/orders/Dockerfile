# === ETAPA 1: Compilación (Builder) ===
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Instalamos git por si alguna dependencia lo requiere
RUN apk add --no-cache git

# 1. Copiamos todo el código fuente primero
COPY . .

# 2. Reconstruimos el go.sum con las firmas de pgx v5.9.0 usando el código presente
RUN go mod tidy

# 3. Compilamos el binario de forma segura
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o orders-app .


# === ETAPA 2: Producción (Imagen final ligera y segura) ===
FROM alpine:3.20

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/orders-app .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

CMD ["./orders-app"]