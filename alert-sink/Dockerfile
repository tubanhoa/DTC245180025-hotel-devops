FROM node:20.18.0-alpine3.20
WORKDIR /app
COPY server.js .
RUN mkdir -p /var/log/alerts && chown -R node:node /app /var/log/alerts
USER node
EXPOSE 8080
CMD ["node", "server.js"]
