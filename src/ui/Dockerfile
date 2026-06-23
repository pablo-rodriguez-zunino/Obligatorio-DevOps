# === ETAPA 1: Compilación (Builder) ===
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

RUN npm prune --production


# === ETAPA 2: Producción (Imagen final ligera y segura) ===
FROM node:22-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/public ./public

# Cambiamos temporalmente a root para actualizar el npm global de la imagen base
USER root
RUN npm install -g npm@latest

# Volvemos al usuario seguro de la aplicación
USER node

EXPOSE 8080

CMD ["node", "dist/app.js"]