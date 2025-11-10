# Quick Start Guide - macOS

Get Wazuh with Quickwit running on macOS in 15 minutes.

## Prerequisites

- macOS 11.0 or later
- Docker Desktop installed and running
- Xcode Command Line Tools: `xcode-select --install`

## Step 1: Build Wazuh (5 minutes)

```bash
cd /path/to/wazuh-qw

# Run automated build script
./scripts/macos-build.sh

# Clean build (if needed)
# ./scripts/macos-build.sh --clean
```

This script will:
- ✅ Install dependencies via Homebrew
- ✅ Build indexer connector
- ✅ Build Wazuh engine
- ✅ Install Python SDK
- ✅ Create run script

## Step 2: Setup Quickwit (3 minutes)

```bash
# Run Quickwit setup script
./scripts/setup-quickwit.sh
```

This script will:
- ✅ Pull Quickwit Docker image
- ✅ Start Quickwit container
- ✅ Create wazuh-alerts index

Verify Quickwit is running:
```bash
curl http://localhost:7280/health
# Should return: {"status":"healthy"}
```

## Step 3: Configure Wazuh (2 minutes)

Use the provided example configuration:

```bash
# Copy example config
cp etc/ossec-quickwit.conf config/ossec.conf

# Or create minimal config
cat > config/ossec.conf <<'EOF'
<ossec_config>
  <indexer>
    <enabled>yes</enabled>
    <type>quickwit</type>
    <hosts>
      <host>http://localhost:7280</host>
    </hosts>
  </indexer>
</ossec_config>
EOF
```

## Step 4: Run Wazuh Engine (1 minute)

```bash
# Start Wazuh with Quickwit
./run-wazuh.sh --log-level debug

# You should see:
# [INFO] Indexer Connector initialized (type: quickwit).
# [INFO] Quickwit connector initialized successfully
```

## Step 5: Test Integration (4 minutes)

In a new terminal:

```bash
# Run integration tests
./scripts/test-integration.py
```

This will:
1. ✅ Check Quickwit connection
2. ✅ List indices
3. ✅ Index test data
4. ✅ Search alerts
5. ✅ Test dashboard utilities

## Manual Testing

### Index Sample Alert

```bash
curl -XPOST "http://localhost:7280/api/v1/wazuh-alerts/ingest?commit=force" \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "agent": {"id": "001", "name": "test-agent"},
    "rule": {"id": 5715, "level": 3, "description": "SSH authentication"},
    "full_log": "Test log entry"
  }'
```

### Query Alerts

```bash
# Search all alerts
curl "http://localhost:7280/api/v1/wazuh-alerts/search?query=*&max_hits=10" | python3 -m json.tool

# Search by agent
curl "http://localhost:7280/api/v1/wazuh-alerts/search?query=agent.id:001" | python3 -m json.tool

# Search high severity
curl "http://localhost:7280/api/v1/wazuh-alerts/search?query=rule.level:>=10" | python3 -m json.tool
```

### Python Dashboard

```python
#!/usr/bin/env python3
from wazuh.quickwit.client import QuickwitClient
from wazuh.quickwit.dashboard import QuickwitDashboard

# Connect
client = QuickwitClient(hosts=["http://localhost:7280"])
dashboard = QuickwitDashboard(client)

# Get summary
summary = dashboard.get_alerts_summary(time_range_hours=24)
print(f"Total alerts: {summary['total_alerts']}")

# Top agents
agents = dashboard.get_top_agents(limit=10)
for agent in agents:
    print(f"{agent['agent_id']}: {agent['alert_count']} alerts")

# Critical alerts
critical = dashboard.get_critical_alerts(min_level=12)
print(f"Critical alerts: {len(critical)}")
```

## Useful Commands

### Quickwit Management

```bash
# Check status
docker ps | grep quickwit

# View logs
docker logs -f quickwit

# Restart
docker restart quickwit

# Stop
docker stop quickwit

# Start
docker start quickwit

# Access UI
open http://localhost:7280
```

### Wazuh Management

```bash
# Run with custom config
WAZUH_CONFIG=/path/to/ossec.conf ./run-wazuh.sh

# Run with debug logging
./run-wazuh.sh --log-level debug

# Run in background
./run-wazuh.sh > wazuh.log 2>&1 &
```

### Development

```bash
# Rebuild after code changes
./scripts/macos-build.sh --clean

# Run specific test
python3 -c "
from wazuh.quickwit.client import QuickwitClient
c = QuickwitClient(hosts=['http://localhost:7280'])
print(c.search('wazuh-alerts', query='*', max_hits=5))
"

# Check compiled libraries
ls -lh build/indexer_connector/*.dylib
ls -lh build/engine/bin/wazuh-engine
```

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
rm -rf build
./scripts/macos-build.sh --clean

# Check dependencies
brew list | grep -E 'cmake|openssl|rocksdb'
```

### Quickwit Issues

```bash
# Check Docker
docker --version
docker ps

# Restart Quickwit
docker restart quickwit

# View logs
docker logs quickwit --tail 50

# Recreate container
docker stop quickwit && docker rm quickwit
./scripts/setup-quickwit.sh
```

### Library Not Found

```bash
# Add to ~/.zshrc or ~/.bash_profile
export DYLD_LIBRARY_PATH="/path/to/wazuh-qw/build/indexer_connector:/path/to/wazuh-qw/build/engine/lib:$DYLD_LIBRARY_PATH"

# Reload shell
source ~/.zshrc  # or source ~/.bash_profile
```

### Connection Refused

1. Verify Quickwit is running: `curl http://localhost:7280/health`
2. Check port is not in use: `lsof -i :7280`
3. Restart Docker Desktop
4. Check firewall settings

## What's Next?

- 📖 Read full documentation: [QUICKWIT_INTEGRATION.md](QUICKWIT_INTEGRATION.md)
- 🐍 Explore Python SDK: [framework/wazuh/quickwit/README.md](framework/wazuh/quickwit/README.md)
- 🔍 Learn Quickwit queries: https://quickwit.io/docs/reference/query-language
- 🎨 Build custom dashboards using the Python SDK

## Architecture

```
┌─────────────┐
│ Wazuh Agent │
└──────┬──────┘
       │
       v
┌─────────────┐
│   Wazuh     │
│   Manager   │
└──────┬──────┘
       │
       v
┌─────────────────┐
│ Wazuh Engine    │
│ (wiconnector)   │
└──────┬──────────┘
       │
       v
┌─────────────────┐      ┌──────────────┐
│ Connector       │──────│ OpenSearch   │
│ Factory         │      └──────────────┘
└──────┬──────────┘
       │
       v
┌─────────────────┐
│ Quickwit        │
│ Connector       │
└──────┬──────────┘
       │
       │ NDJSON
       │ Bulk API
       v
┌─────────────────┐
│   Quickwit      │
│   (Docker)      │
│   Port 7280     │
└─────────────────┘
```

## Files Overview

- `scripts/macos-build.sh` - Automated build script
- `scripts/setup-quickwit.sh` - Quickwit setup script
- `scripts/test-integration.py` - Integration test suite
- `run-wazuh.sh` - Run Wazuh engine
- `config/ossec.conf` - Wazuh configuration
- `MACOS_SETUP_GUIDE.md` - Detailed setup guide

## Getting Help

- 📖 Documentation: [QUICKWIT_INTEGRATION.md](QUICKWIT_INTEGRATION.md)
- 🐛 Issues: https://github.com/Baptiste-Leterrier/wazuh-qw/issues
- 💬 Wazuh Docs: https://documentation.wazuh.com
- 🚀 Quickwit Docs: https://quickwit.io/docs

Happy testing! 🎉
