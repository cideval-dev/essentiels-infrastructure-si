
FROM node:24-alpine
WORKDIR /app
COPY package.json server.js test.js ./
USER node
EXPOSE 3000
CMD ["node", "server.js"]