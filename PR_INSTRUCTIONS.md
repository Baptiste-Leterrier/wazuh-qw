# Pull Request Ready for Review

## Branch Information

**Branch Name:** `claude/wazuh-quickwit-integration-011CUtDuqbiktgxhYVoitjLx`

**Status:** ✅ Committed and Pushed to origin

**Commit:** `cc11f5e0` - feat: Add Quickwit integration as alternative indexer backend

## Create the Pull Request

### Option 1: Via GitHub Web Interface

Visit this URL to create the PR:
```
https://github.com/Baptiste-Leterrier/wazuh-qw/pull/new/claude/wazuh-quickwit-integration-011CUtDuqbiktgxhYVoitjLx
```

### Option 2: Via Command Line

If you have permissions, run:
```bash
cd /home/user/wazuh-qw
gh pr create --title "feat: Add Quickwit integration as alternative indexer backend" --body-file /tmp/pr_body.md
```

## PR Title
```
feat: Add Quickwit integration as alternative indexer backend
```

## PR Description

The full PR description is available in `/tmp/pr_body.md`

**Summary:**
This PR introduces comprehensive Quickwit support as a storage backend for Wazuh logs and alerts, providing a cloud-native alternative to OpenSearch/Elasticsearch.

## Changes Summary

### Statistics
- **15 files changed**
- **2,268 insertions**
- **3 deletions**

### Files Created (12)
1. `QUICKWIT_INTEGRATION.md` - Complete integration guide (366 lines)
2. `etc/ossec-quickwit.conf` - Example configuration (54 lines)
3. `framework/wazuh/quickwit/README.md` - Python SDK docs (267 lines)
4. `framework/wazuh/quickwit/__init__.py` - Module init (11 lines)
5. `framework/wazuh/quickwit/client.py` - REST API client (260 lines)
6. `framework/wazuh/quickwit/dashboard.py` - Dashboard utilities (318 lines)
7. `src/shared_modules/indexer_connector/include/quickwitConnector.hpp` (116 lines)
8. `src/shared_modules/indexer_connector/src/quickwitConnectorAsync.cpp` (95 lines)
9. `src/shared_modules/indexer_connector/src/quickwitConnectorAsyncImpl.hpp` (401 lines)
10. `src/engine/source/wiconnector/include/wiconnector/wquickwitconnector.hpp` (95 lines)
11. `src/engine/source/wiconnector/include/wiconnector/connectorFactory.hpp` (148 lines)
12. `src/engine/source/wiconnector/src/wquickwitconnector.cpp` (124 lines)

### Files Modified (3)
1. `src/config/indexer-config.c` - Added 'type' field support
2. `src/engine/source/main.cpp` - Use ConnectorFactory for initialization
3. `src/engine/source/wiconnector/CMakeLists.txt` - Include Quickwit sources

## Key Features

✅ Drop-in replacement for OpenSearch
✅ NDJSON bulk indexing optimized for Quickwit
✅ Factory pattern for backend selection
✅ Thread-safe async operations
✅ Complete Python SDK with dashboard utilities
✅ SSL/TLS support
✅ Connection pooling and failover
✅ Backward compatible (defaults to OpenSearch)

## Testing the Integration

### 1. Install Quickwit
```bash
curl -L https://github.com/quickwit-oss/quickwit/releases/latest/download/quickwit-latest-x86_64-unknown-linux-gnu.tar.gz | tar -xz
cd quickwit-*
./quickwit run
```

### 2. Create Wazuh Index
See `QUICKWIT_INTEGRATION.md` for the complete index schema.

### 3. Configure Wazuh
Use the example in `etc/ossec-quickwit.conf` or add to `ossec.conf`:
```xml
<indexer>
  <enabled>yes</enabled>
  <type>quickwit</type>
  <hosts>
    <host>http://localhost:7280</host>
  </hosts>
</indexer>
```

### 4. Test Python SDK
```python
from wazuh.quickwit.client import QuickwitClient
from wazuh.quickwit.dashboard import QuickwitDashboard

client = QuickwitClient(hosts=["http://localhost:7280"])
dashboard = QuickwitDashboard(client)

# Get alert summary
summary = dashboard.get_alerts_summary(time_range_hours=24)
print(f"Total alerts: {summary['total_alerts']}")
```

## Documentation

Complete documentation available in:
- `QUICKWIT_INTEGRATION.md` - Integration guide
- `framework/wazuh/quickwit/README.md` - Python SDK reference

## Review Checklist

- [ ] Code compiles successfully
- [ ] No breaking changes to existing OpenSearch functionality
- [ ] Configuration parser accepts new 'type' field
- [ ] Factory correctly selects backend based on type
- [ ] Python SDK can query Quickwit successfully
- [ ] Documentation is clear and complete
- [ ] Example configuration works

## Next Steps After Review

If approved, consider:
- Unit tests for Quickwit connector
- Integration tests with real Quickwit instance
- Performance benchmarking
- CI/CD pipeline updates
- Release notes

---

**Branch is ready for review!** 🚀
