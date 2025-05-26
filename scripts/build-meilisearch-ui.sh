#!/bin/bash
set -e

# Default values
DIST_DIR="./dist"
DOCKER_TEMP_CONTAINER="meilisearch-ui-build-temp"
DOCKERFILE_PATH="./scripts/Dockerfile"

# Get tag from argument or exit with error message
if [ -z "$1" ]; then
  echo "Usage: $0 <tag>"
  echo "Please provide a tag for the meilisearch-ui build."
  exit 1
fi
TAG=$1

echo "==> Building meilisearch-ui with tag: $TAG"

# Build Docker image using the Dockerfile with TAG argument
echo "==> Building Docker image for meilisearch-ui..."
docker build --build-arg TAG=$TAG -t meilisearch-ui-build:latest -f $DOCKERFILE_PATH .

# Create a temporary container to extract the build files
echo "==> Creating temporary container to extract build files..."
docker create --name $DOCKER_TEMP_CONTAINER meilisearch-ui-build:latest

# Clean dist directory
echo "==> Cleaning dist directory..."
rm -rf $DIST_DIR
mkdir -p $DIST_DIR

# Copy build files from the container to the dist directory
echo "==> Copying build files to dist directory..."
docker cp $DOCKER_TEMP_CONTAINER:/opt/meilisearch-ui/dist/. $DIST_DIR/

# Clean up
echo "==> Cleaning up..."
docker rm $DOCKER_TEMP_CONTAINER
docker rmi meilisearch-ui-build:latest

echo "==> Build completed successfully!"
echo "==> meilisearch-ui (tag: $TAG) has been built and copied to $DIST_DIR"
