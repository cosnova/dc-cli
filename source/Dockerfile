FROM node:alpine

COPY . .

RUN npm install -g @amplience/dc-cli
RUN dc-cli --version
CMD ["dc-cli", "--version"]