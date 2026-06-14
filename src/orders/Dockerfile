# === ETAPA 1: Compilación (Builder) ===
FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

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
