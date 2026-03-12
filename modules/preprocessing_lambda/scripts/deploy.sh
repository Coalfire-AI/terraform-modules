#!/usr/bin/env bash
# Deployment script for Preprocessing Lambda container image
# Usage: ./deploy.sh <ecr-repository-url> [image-tag]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <ecr-repository-url> [image-tag]"
    echo ""
    echo "Arguments:"
    echo "  ecr-repository-url  Full ECR repository URL (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/my-repo)"
    echo "  image-tag           Optional image tag (default: latest)"
    echo ""
    echo "Example:"
    echo "  $0 123456789012.dkr.ecr.us-west-2.amazonaws.com/nist-preprocessing latest"
    exit 1
fi

ECR_URL="$1"
IMAGE_TAG="${2:-latest}"

# Extract region from ECR URL
REGION=$(echo "$ECR_URL" | sed -n 's/.*\.dkr\.ecr\.\([^.]*\)\.amazonaws\.com.*/\1/p')
if [ -z "$REGION" ]; then
    log_error "Could not extract region from ECR URL: $ECR_URL"
    exit 1
fi

# Extract account ID from ECR URL
ACCOUNT_ID=$(echo "$ECR_URL" | sed -n 's/\([0-9]*\)\.dkr\.ecr\..*/\1/p')
if [ -z "$ACCOUNT_ID" ]; then
    log_error "Could not extract account ID from ECR URL: $ECR_URL"
    exit 1
fi

log_info "Deploying to ECR: $ECR_URL"
log_info "Region: $REGION"
log_info "Account: $ACCOUNT_ID"
log_info "Tag: $IMAGE_TAG"

# Get script directory (where Dockerfile is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")/docker"

if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
    log_error "Dockerfile not found at $DOCKER_DIR/Dockerfile"
    exit 1
fi

cd "$DOCKER_DIR"
log_info "Building from: $DOCKER_DIR"

# Check for Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

# Login to ECR
log_info "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Check if buildx is available for multi-platform builds
if docker buildx version &> /dev/null; then
    log_info "Using Docker Buildx for ARM64 build..."

    # Create builder if it doesn't exist
    if ! docker buildx inspect preprocessing-builder &> /dev/null; then
        log_info "Creating buildx builder..."
        docker buildx create --name preprocessing-builder --use
    else
        docker buildx use preprocessing-builder
    fi

    # Build and push in one step
    log_info "Building and pushing ARM64 image..."
    docker buildx build \
        --platform linux/arm64 \
        --tag "$ECR_URL:$IMAGE_TAG" \
        --push \
        .
else
    log_warn "Docker Buildx not available, using standard build..."
    log_warn "Note: If building on x86_64, the image may not work on Graviton (ARM64)"

    # Standard build
    log_info "Building image..."
    docker build -t "$ECR_URL:$IMAGE_TAG" .

    # Push
    log_info "Pushing image..."
    docker push "$ECR_URL:$IMAGE_TAG"
fi

log_info "Deployment complete!"
log_info ""
log_info "Image: $ECR_URL:$IMAGE_TAG"
log_info ""
log_info "Next steps:"
log_info "  1. Update Terraform with the image tag if needed"
log_info "  2. Run 'terraform apply' to deploy the Lambda function"
log_info "  3. Upload a PDF to the raw/ prefix to test"