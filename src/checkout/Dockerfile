# === ETAPA 1: Compilación (Builder) ===
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn

RUN yarn install

COPY . .

RUN yarn build

RUN yarn workspaces focus --production


# === ETAPA 2: Producción (Imagen final ligera y segura) ===
FROM node:22-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080


COPY --from=builder --chown=node:node /app/package.json /app/yarn.lock /app/.yarnrc.yml ./
COPY --from=builder --chown=node:node /app/.yarn ./.yarn
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

USER node

EXPOSE 8080

CMD ["node", "dist/main.js"]
