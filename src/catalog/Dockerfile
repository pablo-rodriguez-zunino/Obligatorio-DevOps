# === ETAPA 1: Compilación (Builder) ===
FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

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
