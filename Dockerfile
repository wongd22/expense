FROM node:24-alpine
WORKDIR /app
COPY dist ./dist
COPY server ./server
COPY shared ./shared
USER node
ENV PORT=3000
EXPOSE 3000
CMD ["node","server/index.mjs"]
