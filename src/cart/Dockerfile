# === ETAPA 1: Construcción (Builder) ===
FROM python:3.12-slim AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt


# === ETAPA 2: Producción (Imagen limpia y segura) ===
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ENV PATH=/home/appuser/.local/bin:$PATH

RUN useradd -u 1001 -m appuser

COPY --from=builder /root/.local /home/appuser/.local

COPY ./app ./app

RUN chown -R appuser:appuser /app /home/appuser

USER appuser

EXPOSE 8080

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
