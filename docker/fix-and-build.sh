#!/bin/bash
# Automatic Docker Build Fix and Build Script
# Copyright (C) 2015, Wazuh Inc.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

log_info "Wazuh Docker Build - Automatic Fix and Build"
echo ""

# Check we're in the right directory
if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    log_error "Not in docker directory. Please run from docker/ directory"
    exit 1
fi

# Step 1: Backup original Dockerfile
if [ -f "$SCRIPT_DIR/Dockerfile" ] && [ ! -f "$SCRIPT_DIR/Dockerfile.original" ]; then
    log_info "Backing up original Dockerfile..."
    cp "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/Dockerfile.original"
    log_success "Backup created: Dockerfile.original"
fi

# Step 2: Apply fixed Dockerfile
log_info "Applying fixed Dockerfile..."
if [ -f "$SCRIPT_DIR/Dockerfile.fixed" ]; then
    cp "$SCRIPT_DIR/Dockerfile.fixed" "$SCRIPT_DIR/Dockerfile"
    log_success "Fixed Dockerfile applied"
else
    log_error "Dockerfile.fixed not found!"
    exit 1
fi

# Step 3: Ensure .dockerignore exists
log_info "Checking .dockerignore..."
if [ ! -f "$SCRIPT_DIR/.dockerignore" ]; then
    log_warning ".dockerignore not found - build may be slow"
else
    log_success ".dockerignore found"
fi

# Step 4: Check .env file
log_info "Checking .env configuration..."
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log_warning ".env not found, creating from .env.example..."
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        log_success ".env created"
    fi
fi

# Step 5: Optimize for low memory if needed
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 6000 ]; then
    log_warning "Low memory detected ($TOTAL_MEM MB)"
    log_info "Setting BUILD_JOBS=2 for memory efficiency..."

    if ! grep -q "BUILD_JOBS" "$SCRIPT_DIR/.env" 2>/dev/null; then
        echo "BUILD_JOBS=2" >> "$SCRIPT_DIR/.env"
    else
        sed -i 's/BUILD_JOBS=.*/BUILD_JOBS=2/' "$SCRIPT_DIR/.env" 2>/dev/null || true
    fi
    log_success "BUILD_JOBS set to 2"
fi

# Step 6: Check disk space
AVAILABLE_DISK=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_DISK" -lt 20 ]; then
    log_error "Insufficient disk space! Need at least 20GB, have ${AVAILABLE_DISK}GB"
    log_info "Try: docker system prune -a -f"
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        exit 1
    fi
fi

# Step 7: Clean old images (optional)
log_info "Cleaning old Docker artifacts..."
read -p "Clean old images and containers? This will free up space (yes/no): " -r
if [[ $REPLY =~ ^[Yy]es$ ]]; then
    docker compose down 2>/dev/null || true
    docker system prune -f
    log_success "Cleanup complete"
else
    log_info "Skipping cleanup"
fi

echo ""
log_info "========================================="
log_info "Starting Docker build..."
log_info "========================================="
echo ""
log_info "This may take 20-60 minutes depending on your system"
log_info "Build output will be saved to: build.log"
echo ""

# Step 8: Build with detailed output
if docker compose build --no-cache --progress=plain 2>&1 | tee "$SCRIPT_DIR/build.log"; then
    echo ""
    log_success "========================================="
    log_success "Build completed successfully!"
    log_success "========================================="
    echo ""

    log_info "Next steps:"
    echo "  1. Start services:    docker compose up -d"
    echo "  2. Check logs:        docker compose logs -f"
    echo "  3. Test:              ./scripts/manage_stack.sh test"
    echo ""

    # Offer to start services
    read -p "Start services now? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        log_info "Starting services..."
        docker compose up -d
        sleep 5
        log_info "Checking status..."
        docker compose ps
        echo ""
        log_success "Services started!"
        log_info "View logs with: docker compose logs -f"
    fi
else
    echo ""
    log_error "========================================="
    log_error "Build failed!"
    log_error "========================================="
    echo ""

    log_error "Build log saved to: $SCRIPT_DIR/build.log"
    echo ""
    log_info "To diagnose the issue:"
    echo "  1. Check the last 50 lines: tail -50 build.log"
    echo "  2. Search for errors:       grep -i error build.log"
    echo "  3. See troubleshooting:     cat DOCKER_BUILD_TROUBLESHOOTING.md"
    echo ""
    log_info "Common fixes:"
    echo "  - Reduce BUILD_JOBS in .env (if out of memory)"
    echo "  - Run: docker system prune -f (if out of disk)"
    echo "  - Check network connection (if deps download fails)"
    echo ""

    exit 1
fi
