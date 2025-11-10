#!/usr/bin/env python3
"""
Test script for Wazuh-Quickwit integration
"""

import sys
import time
import json
from datetime import datetime

try:
    from wazuh.quickwit.client import QuickwitClient
    from wazuh.quickwit.dashboard import QuickwitDashboard
except ImportError:
    print("Error: Wazuh Python SDK not installed")
    print("Run: cd framework && pip3 install -e .")
    sys.exit(1)

# Colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def print_status(message, status="info"):
    """Print colored status message"""
    colors = {
        "success": GREEN,
        "error": RED,
        "warning": YELLOW,
        "info": BLUE
    }
    color = colors.get(status, NC)
    symbol = {
        "success": "✓",
        "error": "✗",
        "warning": "⚠",
        "info": "ℹ"
    }
    print(f"{color}{symbol.get(status, ' ')} {message}{NC}")

def test_connection(client):
    """Test connection to Quickwit"""
    print("\n" + "="*50)
    print("Test 1: Connection to Quickwit")
    print("="*50)

    try:
        if client.health_check():
            print_status("Quickwit is healthy", "success")
            return True
        else:
            print_status("Quickwit health check failed", "error")
            return False
    except Exception as e:
        print_status(f"Connection failed: {e}", "error")
        return False

def test_list_indices(client):
    """Test listing indices"""
    print("\n" + "="*50)
    print("Test 2: List Indices")
    print("="*50)

    try:
        indices = client.list_indices()
        print_status(f"Found {len(indices)} indices", "success")
        for idx in indices:
            print(f"  - {idx['index_id']}")
        return True
    except Exception as e:
        print_status(f"Failed to list indices: {e}", "error")
        return False

def test_index_test_data(client):
    """Index test data"""
    print("\n" + "="*50)
    print("Test 3: Index Test Data")
    print("="*50)

    test_alerts = [
        {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "agent": {
                "id": "001",
                "name": "test-agent-1",
                "ip": "192.168.1.100"
            },
            "rule": {
                "id": 5715,
                "level": 3,
                "description": "SSH authentication success"
            },
            "full_log": "Nov 10 12:00:00 server sshd[1234]: Accepted publickey for user",
            "decoder": {"name": "sshd"}
        },
        {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "agent": {
                "id": "002",
                "name": "test-agent-2",
                "ip": "192.168.1.101"
            },
            "rule": {
                "id": 5716,
                "level": 5,
                "description": "SSH authentication failed"
            },
            "full_log": "Nov 10 12:01:00 server sshd[1235]: Failed password for invalid user",
            "decoder": {"name": "sshd"}
        },
        {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "agent": {
                "id": "001",
                "name": "test-agent-1",
                "ip": "192.168.1.100"
            },
            "rule": {
                "id": 31100,
                "level": 12,
                "description": "Multiple authentication failures"
            },
            "full_log": "Critical: Multiple failed login attempts detected",
            "decoder": {"name": "sshd"}
        }
    ]

    try:
        import requests

        # Convert to NDJSON
        ndjson = "\n".join(json.dumps(alert) for alert in test_alerts)

        response = requests.post(
            "http://localhost:7280/api/v1/wazuh-alerts/ingest?commit=force",
            headers={"Content-Type": "application/x-ndjson"},
            data=ndjson
        )

        if response.status_code in [200, 201]:
            print_status(f"Indexed {len(test_alerts)} test alerts", "success")
            time.sleep(2)  # Wait for indexing
            return True
        else:
            print_status(f"Indexing failed: {response.status_code}", "error")
            return False
    except Exception as e:
        print_status(f"Failed to index test data: {e}", "error")
        return False

def test_search(client):
    """Test search functionality"""
    print("\n" + "="*50)
    print("Test 4: Search Alerts")
    print("="*50)

    try:
        results = client.search(
            index="wazuh-alerts",
            query="*",
            max_hits=10
        )

        print_status(f"Found {results['num_hits']} total alerts", "success")
        print_status(f"Returned {len(results.get('hits', []))} hits", "info")

        if results.get('hits'):
            print("\nSample alert:")
            alert = results['hits'][0]
            print(f"  Agent: {alert.get('agent', {}).get('name', 'N/A')}")
            print(f"  Rule ID: {alert.get('rule', {}).get('id', 'N/A')}")
            print(f"  Level: {alert.get('rule', {}).get('level', 'N/A')}")
            print(f"  Description: {alert.get('rule', {}).get('description', 'N/A')}")

        return True
    except Exception as e:
        print_status(f"Search failed: {e}", "error")
        return False

def test_dashboard(client):
    """Test dashboard functionality"""
    print("\n" + "="*50)
    print("Test 5: Dashboard Utilities")
    print("="*50)

    try:
        dashboard = QuickwitDashboard(client)

        # Alert summary
        summary = dashboard.get_alerts_summary(
            index="wazuh-alerts",
            time_range_hours=24
        )
        print_status(f"Total alerts in last 24h: {summary['total_alerts']}", "success")

        # Top agents
        top_agents = dashboard.get_top_agents(limit=5)
        if top_agents:
            print("\nTop agents:")
            for agent in top_agents:
                print(f"  {agent['agent_id']}: {agent['alert_count']} alerts")

        # Critical alerts
        critical = dashboard.get_critical_alerts(min_level=12, max_hits=50)
        print_status(f"Critical alerts (level >= 12): {len(critical)}", "info")

        return True
    except Exception as e:
        print_status(f"Dashboard test failed: {e}", "error")
        return False

def main():
    """Run all tests"""
    print("\n" + "="*70)
    print("Wazuh-Quickwit Integration Test Suite")
    print("="*70)

    # Initialize client
    client = QuickwitClient(hosts=["http://localhost:7280"])

    # Run tests
    tests = [
        ("Connection", lambda: test_connection(client)),
        ("List Indices", lambda: test_list_indices(client)),
        ("Index Test Data", lambda: test_index_test_data(client)),
        ("Search", lambda: test_search(client)),
        ("Dashboard", lambda: test_dashboard(client))
    ]

    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print_status(f"Test '{name}' crashed: {e}", "error")
            results.append((name, False))

    # Summary
    print("\n" + "="*70)
    print("Test Summary")
    print("="*70)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = "success" if result else "error"
        print_status(f"{name}: {'PASSED' if result else 'FAILED'}", status)

    print(f"\n{passed}/{total} tests passed")

    if passed == total:
        print_status("All tests passed! ✨", "success")
        return 0
    else:
        print_status(f"{total - passed} tests failed", "error")
        return 1

if __name__ == "__main__":
    sys.exit(main())
