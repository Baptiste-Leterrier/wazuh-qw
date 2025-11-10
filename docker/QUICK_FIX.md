# Docker Build - Quick Fix Guide

## If Your Build is Failing, Try This:

### Option 1: Use the Fixed Dockerfile (Recommended)

```bash
cd docker

# Backup current Dockerfile
mv Dockerfile Dockerfile.original

# Use the fixed version
cp Dockerfile.fixed Dockerfile

# Clean and rebuild
docker compose down
docker system prune -f  # Optional: cleans old images
docker compose build --no-cache
```

### Option 2: Reduce Memory Usage

If you're getting "Killed" errors or out of memory:

```bash
cd docker

# Edit .env to use fewer parallel jobs
echo "BUILD_JOBS=2" >> .env

# Rebuild
docker compose build --no-cache
```

### Option 3: Check What's Failing

Get detailed error output:

```bash
cd docker
docker compose build --no-cache --progress=plain 2>&1 | tee build-error.log

# Then share build-error.log for help
```

## Main Fixes in Dockerfile.fixed

The fixed Dockerfile addresses these common issues:

1. ✅ **Fixed install.sh environment variables**
   - Changed `USER_BINARYINSTALL="y"` to `USER_BINARYINSTALL="yes"`
   - Added all required USER_* variables

2. ✅ **Better error handling**
   - Added error messages at each stage
   - Shows logs when installation fails

3. ✅ **Removed problematic dependencies**
   - Removed `librocksdb-dev` (built by make deps instead)
   - RocksDB comes from Wazuh's external dependencies

4. ✅ **Fixed Python pip for Ubuntu 22.04+**
   - Added `--break-system-packages` flag fallback
   - Handles externally-managed Python environment

5. ✅ **Made scripts executable**
   - Explicitly chmod +x all shell scripts
   - Prevents permission denied errors

6. ✅ **Better file copying**
   - Only copies necessary files first
   - Uses .dockerignore to skip unnecessary files
   - Improves build cache efficiency

7. ✅ **Improved CMD handling**
   - Changed CMD to simple "start" parameter
   - Entrypoint handles the complexity

## What to Share If Still Failing

If the fixed Dockerfile still doesn't work, please run this and share the output:

```bash
# 1. Get system info
echo "=== System Info ===" > debug-info.txt
docker --version >> debug-info.txt
docker compose version >> debug-info.txt
uname -a >> debug-info.txt
df -h >> debug-info.txt
free -h >> debug-info.txt
echo "" >> debug-info.txt

# 2. Get build error
echo "=== Build Error ===" >> debug-info.txt
cd docker
docker compose build --no-cache --progress=plain 2>&1 | tee -a ../debug-info.txt

# 3. Share debug-info.txt
```

## Common Error Messages and Fixes

| Error Message | Fix |
|---------------|-----|
| `make deps` failed | Check network connection, try again |
| `g++: fatal error: Killed` | Reduce BUILD_JOBS to 2 or 1 |
| `librocksdb-dev` not found | Use Dockerfile.fixed |
| `externally-managed-environment` | Use Dockerfile.fixed |
| `Permission denied` on install.sh | Use Dockerfile.fixed |
| `USER_BINARYINSTALL` not set | Use Dockerfile.fixed |
| Build context too large | Ensure .dockerignore exists |
| `COPY failed: file not found` | Build from repo root |

## Testing After Build

Once the build succeeds:

```bash
# Start services
docker compose up -d

# Check Wazuh logs
docker compose logs -f wazuh-manager

# Verify Wazuh is running
docker exec wazuh-manager /var/ossec/bin/wazuh-control status

# Verify connectivity to Quickwit
docker exec wazuh-manager curl http://quickwit-server:7280/health

# Test external access
curl http://localhost:7280/health
```

## Still Need Help?

1. Check [DOCKER_BUILD_TROUBLESHOOTING.md](DOCKER_BUILD_TROUBLESHOOTING.md) for detailed debugging
2. Share your build-error.log and debug-info.txt
3. Include:
   - What stage it's failing at
   - Your system specs (OS, RAM, Disk space)
   - Docker version

## Files Created to Help You

- `Dockerfile.fixed` - Fixed version of Dockerfile
- `.dockerignore` - Speeds up builds, skips unnecessary files
- `DOCKER_BUILD_TROUBLESHOOTING.md` - Detailed troubleshooting guide
- `QUICK_FIX.md` - This file

## Next Steps After Successful Build

1. See [README.md](README.md) for usage
2. See [../DOCKER_QUICKWIT_SETUP.md](../DOCKER_QUICKWIT_SETUP.md) for full documentation
3. Run `./scripts/manage_stack.sh test` to verify everything works
