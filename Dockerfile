FROM node:alpine

RUN pwd
COPY . .

RUN npm install
RUN npm run build

