FROM node:alpine

RUN pwd
COPY . .

RUN npm install
RUN npm run build
RUN npm install -g . --force
RUN dc-cli --version
CMD ["dc-cli", "--version"]
