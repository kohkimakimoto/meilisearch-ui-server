FROM node:22 AS build

# Setting working directory
WORKDIR /opt/meilisearch-ui

# Install pnpm
RUN npm install -g pnpm

# Define build arguments
ARG TAG

# Clone the repository with specific tag
RUN git clone --depth 1 --branch ${TAG} https://github.com/riccox/meilisearch-ui.git .

# Installing dependencies
RUN pnpm install

# Build the app
RUN npm run build
