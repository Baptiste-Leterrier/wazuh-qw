# Docker Build Troubleshooting Guide

This guide helps you diagnose and fix common Docker build issues for Wazuh with Quickwit.

## Quick Diagnostics

Run these commands to diagnose the issue:

```bash
# 1. Check Docker is working
docker --version
docker info

# 2. Try building with verbose output
cd docker
docker compose build --no-cache --progress=plain 2>&1 | tee build.log

# 3. Check available disk space (need at least 20GB)
df -h

# 4. Check available memory (need at least 4GB)
free -h
```

## Common Issues and Fixes

### Issue 1: "make deps" fails

**Symptoms:**
```
ERROR: Failed to download dependencies
```

**Causes:**
- Network connectivity issues
- Missing build tools
- Insufficient disk space

**Fixes:**
```bash
# Try with updated Dockerfile
cp docker/Dockerfile.fixed docker/Dockerfile

# Or build with more verbose output
docker build --no-cache --progress=plain -f docker/Dockerfile ..
```

### Issue 2: Installation script fails

**Symptoms:**
```
ERROR: Installation failed
./install.sh: line X: ...
```

**Cause:** install.sh not finding required environment variables

**Fix:** Use the fixed Dockerfile which sets all required variables:
```bash
cp docker/Dockerfile.fixed docker/Dockerfile
docker compose build --no-cache
```

### Issue 3: Out of memory

**Symptoms:**
```
g++: fatal error: Killed signal terminated program cc1plus
make: *** [Makefile:XX] Error 1
```

**Cause:** Not enough RAM for compilation

**Fix:**
```bash
# Reduce parallel jobs in .env
echo "BUILD_JOBS=2" >> docker/.env

# Or increase Docker memory limit (Docker Desktop)
# Settings -> Resources -> Memory -> 6GB+

# Rebuild
docker compose build
```

### Issue 4: librocksdb not found

**Symptoms:**
```
E: Unable to locate package librocksdb-dev
```

**Cause:** RocksDB not available in Ubuntu repos

**Fix:** The fixed Dockerfile removes librocksdb-dev from dependencies (it's built by make deps):
```bash
cp docker/Dockerfile.fixed docker/Dockerfile
docker compose build
```

### Issue 5: Python pip issues

**Symptoms:**
```
error: externally-managed-environment
```

**Cause:** Ubuntu 22.04+ uses externally managed Python

**Fix:** Use --break-system-packages flag (already in Dockerfile.fixed):
```bash
pip3 install --break-system-packages requests
```

### Issue 6: Permission denied on install.sh

**Symptoms:**
```
bash: ./install.sh: Permission denied
```

**Cause:** Script not executable

**Fix:** The fixed Dockerfile makes scripts executable:
```bash
chmod +x install.sh gen_ossec.sh add_localfiles.sh
```

### Issue 7: Context too large / Slow build

**Symptoms:**
- Build takes very long to start
- "Sending build context" shows large size

**Cause:** Copying unnecessary files

**Fix:** Use .dockerignore file:
```bash
# Already created at docker/.dockerignore
# Verify it exists
ls -la docker/.dockerignore

# Rebuild
docker compose build
```

### Issue 8: Copy command fails

**Symptoms:**
```
COPY failed: file not found
```

**Cause:** File path incorrect or missing file

**Fix:** Check build context:
```bash
# Ensure you're building from the repo root
cd /path/to/wazuh-qw
docker build -f docker/Dockerfile .

# Or use docker compose from docker directory
cd docker
docker compose build
```

## Step-by-Step Debugging

### Step 1: Verify Prerequisites

```bash
# Check Docker
docker --version  # Should be 20.10+
docker compose version  # Should be 2.0+

# Check resources
df -h | grep -E '^/dev'  # Need 20GB+ free
free -h  # Need 4GB+ RAM

# Check network
curl -I https://github.com  # Should work
```

### Step 2: Try Fixed Dockerfile

```bash
# Backup current Dockerfile
cp docker/Dockerfile docker/Dockerfile.backup

# Use fixed version
cp docker/Dockerfile.fixed docker/Dockerfile

# Clean and rebuild
docker compose down
docker system prune -f
docker compose build --no-cache
```

### Step 3: Build Stage-by-Stage

```bash
# Build only the builder stage
docker build --target builder -f docker/Dockerfile -t wazuh-builder:debug .

# If that works, build full image
docker build -f docker/Dockerfile -t wazuh-quickwit:debug .
```

### Step 4: Interactive Debugging

```bash
# Start an interactive builder container
docker run -it --rm \
  -v $(pwd):/build \
  -w /build \
  ubuntu:22.04 \
  bash

# Inside container, manually run build steps:
apt-get update
apt-get install -y build-essential make cmake git curl
cd /build/src
make deps TARGET=server
make TARGET=server build -j2
```

### Step 5: Check Logs

```bash
# View full build log
docker compose build 2>&1 | tee docker/build-full.log

# Search for errors
grep -i error docker/build-full.log
grep -i fail docker/build-full.log

# Check specific stages
grep "===" docker/build-full.log
```

## Alternative: Simpler Dockerfile

If the full build keeps failing, use a simpler single-stage Dockerfile:

```dockerfile
FROM ubuntu:22.04

# Install runtime and build deps together
RUN apt-get update && apt-get install -y \
    build-essential cmake make git curl wget \
    libssl-dev libsqlite3-dev python3 python3-pip \
    procps net-tools iproute2 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy source
WORKDIR /opt/wazuh
COPY . .

# Build and install in place
RUN cd src && \
    make deps TARGET=server && \
    make TARGET=server build -j2 && \
    cd .. && \
    USER_BINARYINSTALL="yes" USER_DIR="/var/ossec" ./install.sh

# Setup
RUN groupadd -r ossec || true && \
    useradd -r -g ossec ossec || true && \
    chown -R ossec:ossec /var/ossec

CMD ["/var/ossec/bin/wazuh-control", "start"]
```

## Getting Help

If you're still stuck, please provide:

1. **Full build log:**
   ```bash
   docker compose build --no-cache --progress=plain 2>&1 | tee build-error.log
   ```

2. **System information:**
   ```bash
   docker --version
   docker compose version
   uname -a
   df -h
   free -h
   ```

3. **Error context:**
   - What command did you run?
   - At what stage did it fail?
   - Any specific error messages?

4. **Share the files:**
   ```bash
   # Create a debug archive
   tar -czf wazuh-docker-debug.tar.gz \
       docker/Dockerfile \
       docker/docker-compose.yml \
       docker/.env \
       build-error.log
   ```

## Quick Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| Build fails | `cp docker/Dockerfile.fixed docker/Dockerfile` |
| Out of memory | Set `BUILD_JOBS=2` in `.env` |
| Slow build | Ensure `docker/.dockerignore` exists |
| Can't find files | Build from repo root: `docker build -f docker/Dockerfile .` |
| librocksdb missing | Use Dockerfile.fixed (removes it) |
| Python pip error | Use Dockerfile.fixed (has --break-system-packages) |
| install.sh fails | Use Dockerfile.fixed (sets all env vars) |

## Testing the Fix

Once built successfully:

```bash
# Start services
docker compose up -d

# Check logs
docker compose logs wazuh-manager

# Test functionality
docker exec wazuh-manager /var/ossec/bin/wazuh-control status
curl http://localhost:7280/health
```

## Prevention

To avoid issues in future builds:

1. **Use .dockerignore** - Speeds up builds
2. **Pin versions** - In docker-compose.yml and Dockerfile
3. **Use build cache** - Only use --no-cache when debugging
4. **Monitor resources** - Ensure adequate disk/memory
5. **Keep Docker updated** - Use latest stable version

## Additional Resources

- [Wazuh Build Documentation](../BUILD_WITH_QUICKWIT.md)
- [Docker Documentation](../DOCKER_QUICKWIT_SETUP.md)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
