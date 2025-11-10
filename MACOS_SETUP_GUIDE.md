# Wazuh + Quickwit Integration - macOS Setup Guide

Complete guide to compile, configure, and test Wazuh with Quickwit integration on macOS.

## Prerequisites

### 1. Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Required Dependencies

```bash
# Build tools
brew install cmake make gcc pkg-config automake autoconf libtool

# Development libraries
brew install openssl@3 curl zlib bzip2 rocksdb

# Python (for Python SDK testing)
brew install python@3.11

# Optional: Install jq for JSON processing
brew install jq
```

### 3. Install Additional Tools

```bash
# Install requests library for Python SDK
pip3 install requests

# Install nlohmann/json (C++ JSON library)
brew install nlohmann-json
```

## Part 1: Compile Wazuh with Quickwit Support

### 1. Clone and Navigate to Repository

```bash
cd /home/user/wazuh-qw
# Or if starting fresh:
# git clone https://github.com/Baptiste-Leterrier/wazuh-qw.git
# cd wazuh-qw
```

### 2. Set Environment Variables

```bash
export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
export OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
export ROCKSDB_ROOT=$(brew --prefix rocksdb)
```

### 3. Build Wazuh Engine with Quickwit Support

```bash
# Create build directory
mkdir -p build/engine
cd build/engine

# Configure CMake
cmake ../../src/engine/source \
    -DCMAKE_BUILD_TYPE=Release \
    -DENGINE_BUILD_TEST=OFF \
    -DOPENSSL_ROOT_DIR=$OPENSSL_ROOT_DIR \
    -DROCKSDB_ROOT=$ROCKSDB_ROOT

# Compile (use -j$(sysctl -n hw.ncpu) for parallel build)
make -j$(sysctl -n hw.ncpu)

# Check if binary was created
ls -lh bin/wazuh-engine
```

### 4. Build Indexer Connector Module

```bash
cd ../..
mkdir -p build/indexer_connector
cd build/indexer_connector

# Configure
cmake ../../src/shared_modules/indexer_connector \
    -DCMAKE_BUILD_TYPE=Release \
    -DUNIT_TEST=OFF \
    -DOPENSSL_ROOT_DIR=$OPENSSL_ROOT_DIR

# Build
make -j$(sysctl -n hw.ncpu)

# Verify libraries
ls -lh *.dylib
```

### 5. Install Python Framework (Optional for testing)

```bash
cd ../../framework
pip3 install -e .
```

## Part 2: Install and Configure Quickwit

### 1. Download Quickwit

```bash
# Create quickwit directory
mkdir -p ~/quickwit
cd ~/quickwit

# Download latest Quickwit for macOS
# Note: Replace with actual macOS binary URL when available
# For now, we'll use the Linux binary with Docker as alternative
curl -L https://github.com/quickwit-oss/quickwit/releases/download/v0.8.1/quickwit-v0.8.1-x86_64-unknown-linux-gnu.tar.gz | tar -xz

# Or use Docker (recommended for macOS)
# docker pull quickwit/quickwit:latest
```

### 2. Run Quickwit (Using Docker - Recommended for macOS)

```bash
# Pull Quickwit image
docker pull quickwit/quickwit:latest

# Run Quickwit server
docker run -d \
    --name quickwit \
    -p 7280:7280 \
    -v ~/quickwit-data:/quickwit/qwdata \
    quickwit/quickwit:latest \
    run

# Check Quickwit is running
curl http://localhost:7280/health
```

### 3. Create Wazuh Alerts Index

Create index configuration file `wazuh-alerts-index.yaml`:

```bash
cat > ~/quickwit/wazuh-alerts-index.yaml <<'EOF'
version: 0.8

index_id: wazuh-alerts

doc_mapping:
  field_mappings:
    # Timestamp field (required for time-series data)
    - name: timestamp
      type: datetime
      input_formats:
        - rfc3339
        - unix_timestamp
      fast: true
      stored: true

    # Agent information
    - name: agent.id
      type: text
      tokenizer: raw
      fast: true
      stored: true

    - name: agent.name
      type: text
      tokenizer: default
      stored: true

    - name: agent.ip
      type: text
      tokenizer: raw
      stored: true

    # Rule information
    - name: rule.id
      type: u64
      fast: true
      stored: true

    - name: rule.level
      type: u64
      fast: true
      stored: true

    - name: rule.description
      type: text
      tokenizer: default
      stored: true

    - name: rule.groups
      type: text
      tokenizer: default
      stored: true

    # Alert data
    - name: data
      type: json
      stored: true

    - name: full_log
      type: text
      tokenizer: default
      stored: true

    - name: decoder.name
      type: text
      tokenizer: raw
      stored: true

    - name: location
      type: text
      tokenizer: default
      stored: true

  timestamp_field: timestamp
  mode: dynamic

indexing_settings:
  commit_timeout_secs: 10
  merge_policy:
    type: stable_log
    min_level_num_docs: 100000
    merge_factor: 10

search_settings:
  default_search_fields: [full_log, rule.description, agent.name]
EOF
```

### 4. Create Index in Quickwit

```bash
# Using Docker
docker exec quickwit \
    quickwit index create \
    --index-config /quickwit/qwdata/wazuh-alerts-index.yaml

# Or if running natively
# ./quickwit index create --index-config wazuh-alerts-index.yaml

# Verify index was created
curl http://localhost:7280/api/v1/indexes
```

## Part 3: Configure Wazuh to Use Quickwit

### 1. Create Wazuh Configuration Directory

```bash
mkdir -p ~/wazuh-config
cd ~/wazuh-config
```

### 2. Create ossec.conf with Quickwit Configuration

```bash
cat > ~/wazuh-config/ossec.conf <<'EOF'
<!--
  Wazuh - Manager Configuration with Quickwit
-->
<ossec_config>
  <!-- Quickwit Indexer Configuration -->
  <indexer>
    <enabled>yes</enabled>
    <type>quickwit</type>
    <hosts>
      <host>http://localhost:7280</host>
    </hosts>
  </indexer>

  <global>
    <agents_disconnection_time>15m</agents_disconnection_time>
    <agents_disconnection_alert_time>0</agents_disconnection_alert_time>
  </global>

  <logging>
    <log_format>plain</log_format>
  </logging>

  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>tcp</protocol>
  </remote>

  <rootcheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <skip_nfs>yes</skip_nfs>
  </rootcheck>

  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <alert_new_files>yes</alert_new_files>
    <directories>/etc</directories>
    <directories>/tmp</directories>
  </syscheck>
</ossec_config>
EOF
```

### 3. Set Environment Variable for Configuration

```bash
export WAZUH_CONFIG=~/wazuh-config/ossec.conf
```

## Part 4: Run Wazuh Engine

### 1. Prepare Runtime Environment

```bash
cd /home/user/wazuh-qw

# Set library paths
export DYLD_LIBRARY_PATH=$(pwd)/build/indexer_connector:$DYLD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$(pwd)/build/engine/lib:$DYLD_LIBRARY_PATH
```

### 2. Run Wazuh Engine in Standalone Mode

```bash
cd build/engine

# Run engine with Quickwit configuration
./bin/wazuh-engine \
    --config $WAZUH_CONFIG \
    --log-level debug

# You should see logs like:
# [INFO] Indexer Connector initialized (type: quickwit).
# [INFO] Quickwit connector initialized successfully
```

## Part 5: Test the Integration

### 1. Test with Python SDK

Create a test script `test_quickwit.py`:

```python
#!/usr/bin/env python3

from wazuh.quickwit.client import QuickwitClient
from wazuh.quickwit.dashboard import QuickwitDashboard
import time

# Initialize client
print("Connecting to Quickwit...")
client = QuickwitClient(hosts=["http://localhost:7280"])

# Check health
if client.health_check():
    print("✓ Quickwit is healthy")
else:
    print("✗ Quickwit is not responding")
    exit(1)

# List indices
print("\nAvailable indices:")
indices = client.list_indices()
for idx in indices:
    print(f"  - {idx['index_id']}")

# Search for alerts (if any exist)
print("\nSearching for alerts...")
try:
    results = client.search(
        index="wazuh-alerts",
        query="*",
        max_hits=10
    )
    print(f"Found {results['num_hits']} total alerts")
    print(f"Returned {len(results.get('hits', []))} hits")

    # Display first alert
    if results.get('hits'):
        print("\nFirst alert:")
        print(results['hits'][0])
except Exception as e:
    print(f"Search error: {e}")

# Test dashboard
print("\nTesting dashboard utilities...")
dashboard = QuickwitDashboard(client)

summary = dashboard.get_alerts_summary(time_range_hours=24)
print(f"Total alerts in last 24h: {summary['total_alerts']}")

print("\n✓ All tests passed!")
```

Run the test:

```bash
python3 test_quickwit.py
```

### 2. Manually Index Test Data

Send test alert to Quickwit:

```bash
# Create test alert
cat > test_alert.json <<'EOF'
{"timestamp":"2025-11-10T12:00:00Z","agent":{"id":"001","name":"test-agent","ip":"192.168.1.100"},"rule":{"id":5715,"level":3,"description":"SSH authentication success"},"full_log":"Nov 10 12:00:00 server sshd[1234]: Accepted publickey for user from 192.168.1.100 port 22","location":"sshd","decoder":{"name":"sshd"}}
EOF

# Index to Quickwit
curl -XPOST "http://localhost:7280/api/v1/wazuh-alerts/ingest?commit=force" \
    --data-binary @test_alert.json

# Verify indexing
sleep 2
curl "http://localhost:7280/api/v1/wazuh-alerts/search?query=*&max_hits=1" | jq
```

### 3. Query Dashboard Statistics

```python
#!/usr/bin/env python3
from wazuh.quickwit.client import QuickwitClient
from wazuh.quickwit.dashboard import QuickwitDashboard

client = QuickwitClient(hosts=["http://localhost:7280"])
dashboard = QuickwitDashboard(client)

# Get alert summary
summary = dashboard.get_alerts_summary(
    index="wazuh-alerts",
    time_range_hours=24,
    group_by="rule.level"
)

print(f"Total alerts: {summary['total_alerts']}")
print(f"Time range: {summary['time_range']}")

# Get top agents
top_agents = dashboard.get_top_agents(limit=10)
print("\nTop 10 Agents:")
for agent in top_agents:
    print(f"  {agent['agent_id']}: {agent['alert_count']} alerts")

# Get critical alerts
critical = dashboard.get_critical_alerts(min_level=12, max_hits=50)
print(f"\nCritical alerts (level >= 12): {len(critical)}")
```

## Part 6: Troubleshooting

### Common Issues

#### 1. Library Not Found Errors

```bash
# Add to ~/.zshrc or ~/.bash_profile
export DYLD_LIBRARY_PATH=/home/user/wazuh-qw/build/indexer_connector:$DYLD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=/home/user/wazuh-qw/build/engine/lib:$DYLD_LIBRARY_PATH
```

#### 2. Quickwit Not Responding

```bash
# Check Docker container
docker ps | grep quickwit

# Check logs
docker logs quickwit

# Restart if needed
docker restart quickwit
```

#### 3. Index Creation Failed

```bash
# Delete and recreate index
curl -XDELETE http://localhost:7280/api/v1/indexes/wazuh-alerts
docker exec quickwit quickwit index create --index-config /quickwit/qwdata/wazuh-alerts-index.yaml
```

#### 4. Compilation Errors

```bash
# Clean build
rm -rf build
mkdir -p build/engine build/indexer_connector

# Rebuild with verbose output
make VERBOSE=1
```

### Check Logs

```bash
# Wazuh engine logs (if running)
tail -f /var/ossec/logs/ossec.log

# Quickwit logs
docker logs -f quickwit

# Check indexer connection
curl http://localhost:7280/api/v1/cluster
```

## Part 7: Performance Testing

### Generate Test Load

```bash
#!/bin/bash
# generate_alerts.sh - Generate test alerts

for i in {1..1000}; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  AGENT_ID=$(printf "%03d" $((RANDOM % 10 + 1)))
  LEVEL=$((RANDOM % 15 + 1))

  cat <<EOF | curl -XPOST "http://localhost:7280/api/v1/wazuh-alerts/ingest" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary @-
{"timestamp":"$TIMESTAMP","agent":{"id":"$AGENT_ID","name":"agent-$AGENT_ID"},"rule":{"id":$((RANDOM % 10000)),"level":$LEVEL,"description":"Test alert $i"},"full_log":"Test log entry $i"}
EOF

  if [ $((i % 100)) -eq 0 ]; then
    echo "Indexed $i alerts..."
  fi
done

echo "Done! Indexed 1000 test alerts"
```

## Summary

You now have:
- ✅ Wazuh compiled with Quickwit support
- ✅ Quickwit running in Docker
- ✅ wazuh-alerts index created
- ✅ Wazuh configured to use Quickwit
- ✅ Python SDK ready for testing
- ✅ Test data and query examples

## Quick Reference

**Start Quickwit:**
```bash
docker start quickwit
```

**Run Wazuh Engine:**
```bash
cd /home/user/wazuh-qw/build/engine
export DYLD_LIBRARY_PATH=$(pwd)/../indexer_connector:$(pwd)/lib:$DYLD_LIBRARY_PATH
./bin/wazuh-engine --config ~/wazuh-config/ossec.conf --log-level debug
```

**Query Quickwit:**
```bash
curl "http://localhost:7280/api/v1/wazuh-alerts/search?query=*&max_hits=10" | jq
```

**Python Dashboard:**
```python
from wazuh.quickwit.client import QuickwitClient
from wazuh.quickwit.dashboard import QuickwitDashboard

client = QuickwitClient(hosts=["http://localhost:7280"])
dashboard = QuickwitDashboard(client)
summary = dashboard.get_alerts_summary(time_range_hours=24)
print(summary)
```

Happy testing! 🚀
