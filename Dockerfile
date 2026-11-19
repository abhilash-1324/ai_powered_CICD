FROM node:22-alpine
WORKDIR /app
COPY app ./app
USER node
EXPOSE 3000
CMD ["node","app/server.cjs"]
