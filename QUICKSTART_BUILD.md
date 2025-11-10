# Quick Start: Building Wazuh with Quickwit Support

This is a quick reference guide for building Wazuh with Quickwit integration. For detailed documentation, see [BUILD_WITH_QUICKWIT.md](BUILD_WITH_QUICKWIT.md).

## Prerequisites (macOS)

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## One-Command Build

### Development Build (Recommended)

```bash
./scripts/build_wazuh_with_quickwit_macos.sh --debug --setup-quickwit
```

This will:
- Install all dependencies via Homebrew
- Build Wazuh with debug symbols
- Download and setup Quickwit server
- Create necessary configuration files

### Production Build

```bash
./scripts/build_wazuh_with_quickwit_macos.sh --setup-quickwit
```

## What Gets Built

The Quickwit integration includes:

1. **C++ Connector** - Core indexer connector in `src/shared_modules/indexer_connector/`
2. **Engine Integration** - Wazuh engine connector in `src/engine/source/wiconnector/`
3. **Python SDK** - Python client library in `framework/wazuh/quickwit/`

All components are built automatically - no special flags needed!

## After Building

### 1. Install Wazuh

```bash
sudo ./install.sh
```

### 2. Start Quickwit

```bash
~/.quickwit/start_quickwit.sh
```

Or manually:

```bash
cd ~/.quickwit/current
./quickwit run
```

### 3. Configure Wazuh for Quickwit

Edit `/var/ossec/etc/ossec.conf`:

```xml
<ossec_config>
  <indexer>
    <enabled>yes</enabled>
    <type>quickwit</type>
    <hosts>
      <host>http://localhost:7280</host>
    </hosts>
  </indexer>
</ossec_config>
```

Or use the helper script:

```bash
./scripts/configure_quickwit.sh
```

### 4. Start Wazuh

```bash
sudo /var/ossec/bin/wazuh-control start
```

## Verification

### Check Quickwit is running

```bash
curl http://localhost:7280/health
```

Expected output: `{"status":"ok"}`

### Check Wazuh index exists

```bash
curl http://localhost:7280/api/v1/indexes/wazuh-alerts
```

### Test with Python SDK

```python
from wazuh.quickwit.client import QuickwitClient

client = QuickwitClient(hosts=["http://localhost:7280"])
health = client.health_check()
print(f"Quickwit status: {health['status']}")

# Search for alerts
results = client.search(index="wazuh-alerts", query="*", max_hits=10)
print(f"Found {results['num_hits']} alerts")
```

## Build Script Options

```bash
./scripts/build_wazuh_with_quickwit_macos.sh [OPTIONS]

Common options:
  --debug              Build with debug symbols (recommended for dev)
  --test               Enable unit tests
  --setup-quickwit     Download and setup Quickwit server
  --clean              Clean previous build artifacts
  --help               Show all options
```

### Examples

```bash
# Development build with tests
./scripts/build_wazuh_with_quickwit_macos.sh --debug --test

# Clean rebuild
./scripts/build_wazuh_with_quickwit_macos.sh --clean --debug

# Custom installation directory
./scripts/build_wazuh_with_quickwit_macos.sh --prefix /opt/wazuh-dev

# Just setup Quickwit (skip build)
./scripts/build_wazuh_with_quickwit_macos.sh --skip-build --setup-quickwit
```

## Troubleshooting

### Build fails with OpenSSL errors

```bash
export OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
export PKG_CONFIG_PATH="$OPENSSL_ROOT_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
./scripts/build_wazuh_with_quickwit_macos.sh --debug
```

### Quickwit connection fails

1. Verify Quickwit is running: `curl http://localhost:7280/health`
2. Check Wazuh config: `grep -A 10 "<indexer>" /var/ossec/etc/ossec.conf`
3. Check logs: `tail -f /var/ossec/logs/ossec.log | grep -i quickwit`

### Dependencies missing

```bash
# Install all dependencies manually
./scripts/build_wazuh_with_quickwit_macos.sh --skip-build
```

## Development Workflow

### Make code changes

```bash
# Edit source files
vim src/shared_modules/indexer_connector/src/quickwitConnectorAsync.cpp
```

### Rebuild

```bash
cd src
make TARGET=server build -j$(sysctl -n hw.ncpu)
```

### Test

```bash
# Run unit tests
python3 build.py -t shared_modules/indexer_connector

# Test integration
sudo /var/ossec/bin/wazuh-control restart
tail -f /var/ossec/logs/ossec.log | grep -i quickwit
```

## Additional Resources

- **Comprehensive Build Guide**: [BUILD_WITH_QUICKWIT.md](BUILD_WITH_QUICKWIT.md)
  - Detailed prerequisites
  - Manual build steps
  - Architecture details
  - Advanced troubleshooting

- **Integration Guide**: [QUICKWIT_INTEGRATION.md](QUICKWIT_INTEGRATION.md)
  - Configuration options
  - Python SDK usage
  - Performance tuning
  - API reference

- **Python SDK**: [framework/wazuh/quickwit/README.md](framework/wazuh/quickwit/README.md)
  - Client documentation
  - Dashboard utilities
  - Query examples

## File Locations

After build:

```
Build artifacts:
  src/shared_modules/indexer_connector/build/
  src/engine/build/

Quickwit installation:
  ~/.quickwit/current/                    # Quickwit binary
  ~/.quickwit/wazuh-alerts-index.yaml    # Index config
  ~/.quickwit/start_quickwit.sh          # Start script

After installation:
  /var/ossec/                            # Wazuh installation
  /var/ossec/etc/ossec.conf              # Main configuration
  /var/ossec/logs/ossec.log              # Logs
```

## Need Help?

1. Check [BUILD_WITH_QUICKWIT.md](BUILD_WITH_QUICKWIT.md) for detailed troubleshooting
2. Review Wazuh logs: `/var/ossec/logs/ossec.log`
3. Check Quickwit logs: `~/.quickwit/current/qwdata/*/logs/`
4. Visit [Wazuh Documentation](https://documentation.wazuh.com)
5. Visit [Quickwit Documentation](https://quickwit.io/docs)

## What's Different from Standard Wazuh?

The Quickwit integration is **already included** in this Wazuh fork. When you build:

1. The indexer connector automatically includes Quickwit support
2. The factory pattern allows runtime selection between OpenSearch and Quickwit
3. No additional build flags needed - it's all there!
4. Just change `<type>` in config from `opensearch` to `quickwit`

The build process is identical to standard Wazuh - we've just added Quickwit as an additional backend option.
