# Debug Your Build Failure - Step by Step

Your build is failing at 26% during content_manager compilation. Let's find out why.

## Step 1: Check Which Dockerfile You're Using

```bash
cd docker
grep 'USER_BINARYINSTALL=' Dockerfile | head -1
```

**Expected output:** `export USER_BINARYINSTALL="yes"`

**If you see:** `USER_BINARYINSTALL="y"` → You're using the OLD Dockerfile!

### Fix:
```bash
# Pull latest changes
git pull origin claude/document-automate-merge-011CUyYTHfrckeT2JpMMHvCv

# OR manually copy the fixed version
cp Dockerfile.fixed Dockerfile
```

## Step 2: Get the REAL Error (Not Just "Error 2")

```bash
cd docker
chmod +x get-build-error.sh
./get-build-error.sh
```

This will:
- Check if you have the updated Dockerfile
- Build with full error output (takes 10-30 min)
- Extract actual C++ compilation errors
- Save detailed log to `build-detailed-error.log`

## Step 3: Analyze the Error

After running the script, look at the output. Common errors:

### A) Out of Memory Error
```
g++: fatal error: Killed signal terminated program cc1plus
```
**Solution:**
```bash
echo "BUILD_JOBS=1" > .env
docker compose build --no-cache
```

### B) Missing Header Files
```
fatal error: someheader.h: No such file or directory
```
**Solution:** Missing dependency, check Dockerfile has all packages

### C) Undefined References
```
undefined reference to 'some_function'
```
**Solution:** Linking issue, may need additional libraries

### D) Compiler Errors
```
error: 'variable' was not declared in this scope
```
**Solution:** Code compatibility issue with compiler version

## Step 4: Try Minimal Dockerfile

If the main Dockerfile keeps failing, try the minimal version:

```bash
cd docker
cp Dockerfile.minimal Dockerfile
BUILD_JOBS=1 docker compose build --no-cache
```

The minimal Dockerfile:
- Single-stage (no multi-stage build)
- Simpler structure
- Easier to debug
- Uses BUILD_JOBS=1 by default

## Step 5: Build Interactively for Debugging

If you need to debug the build process:

```bash
# Start a build container
docker run -it --rm \
  -v $(pwd)/..:/build \
  -w /build \
  ubuntu:22.04 \
  bash

# Inside the container:
apt-get update
apt-get install -y build-essential cmake make git curl \
  libssl-dev libsqlite3-dev python3 python3-dev

cd /build/src
make deps TARGET=server
make TARGET=server build -j1  # Single job for debugging

# Watch for specific errors
```

## Step 6: Check System Resources

```bash
# Check available RAM
free -h

# Check available disk
df -h

# Check if Docker has enough resources
docker info | grep -E "Memory|CPUs"
```

**Minimum requirements:**
- RAM: 4GB (8GB recommended)
- Disk: 20GB free
- CPUs: 2 cores

## Common Solutions

### Solution 1: Reduce Parallel Jobs
```bash
echo "BUILD_JOBS=1" >> docker/.env
docker compose build --no-cache
```

### Solution 2: Clean Everything and Retry
```bash
cd docker
docker compose down
docker system prune -a -f
docker compose build --no-cache
```

### Solution 3: Use Minimal Dockerfile
```bash
cd docker
cp Dockerfile.minimal Dockerfile
docker compose build --no-cache
```

### Solution 4: Increase Docker Memory (Docker Desktop)
1. Open Docker Desktop Settings
2. Go to Resources → Memory
3. Increase to 8GB
4. Apply & Restart
5. Retry build

## What to Share If Still Stuck

1. **Run this command:**
   ```bash
   cd docker
   ./get-build-error.sh
   ```

2. **Share these files:**
   ```bash
   # Create a debug package
   tar -czf wazuh-docker-debug.tar.gz \
       docker/build-detailed-error.log \
       docker/Dockerfile \
       docker/.env
   ```

3. **Include this info:**
   ```bash
   echo "=== System Info ===" > debug-info.txt
   docker --version >> debug-info.txt
   docker compose version >> debug-info.txt
   free -h >> debug-info.txt
   df -h >> debug-info.txt
   uname -a >> debug-info.txt
   ```

## Quick Decision Tree

```
Build fails at 26%?
│
├─ Shows "Killed" → Out of Memory
│  └─ Set BUILD_JOBS=1, increase Docker memory
│
├─ Shows "error: header not found" → Missing dependency
│  └─ Check Dockerfile has all packages
│
├─ Shows "undefined reference" → Linking issue
│  └─ Check library is installed and linked
│
└─ Shows generic "Error 2" → Need more info
   └─ Run ./get-build-error.sh
```

## Expected Build Time

- With BUILD_JOBS=1: 40-90 minutes
- With BUILD_JOBS=2: 20-60 minutes
- With BUILD_JOBS=4: 10-30 minutes (needs 8GB+ RAM)

## Next Steps After This Guide

1. Run `./get-build-error.sh` to get the real error
2. Look at `build-detailed-error.log` for details
3. Try the solution that matches your error type
4. If still stuck, share the debug info above

---

**TIP:** The error "make[2]: *** Error 2" is generic. We need to see what happened BEFORE that line to know the real problem. That's why the `get-build-error.sh` script is important.
