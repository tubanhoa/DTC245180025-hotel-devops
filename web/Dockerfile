FROM node:20.18.0-alpine3.20

WORKDIR /app

# Cài đặt curl/wget cho healthcheck
RUN apk add --no-cache curl wget

COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY . .

# Tạo thư mục uploads và phân quyền
RUN mkdir -p /app/public/uploads && chown -R node:node /app

EXPOSE 3000

USER node

CMD ["node", "src/server.js"]
