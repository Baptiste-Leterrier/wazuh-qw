#!/bin/bash
# Setup Quickwit with Docker for macOS

set -e

echo "======================================"
echo "Quickwit Setup Script for macOS"
echo "======================================"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo -e "${GREEN}✓ Docker found${NC}"

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Create data directory
QUICKWIT_DATA="$HOME/quickwit-data"
mkdir -p "$QUICKWIT_DATA"

echo -e "\n${YELLOW}Data directory: $QUICKWIT_DATA${NC}"

# Pull Quickwit image
echo -e "\n${YELLOW}Pulling Quickwit Docker image...${NC}"
docker pull quickwit/quickwit:latest

# Stop and remove existing container
if docker ps -a | grep -q quickwit; then
    echo -e "${YELLOW}Stopping existing Quickwit container...${NC}"
    docker stop quickwit 2>/dev/null || true
    docker rm quickwit 2>/dev/null || true
fi

# Start Quickwit
echo -e "\n${YELLOW}Starting Quickwit container...${NC}"
docker run -d \
    --name quickwit \
    -p 7280:7280 \
    -v "$QUICKWIT_DATA:/quickwit/qwdata" \
    quickwit/quickwit:latest \
    run

# Wait for Quickwit to start
echo -e "${YELLOW}Waiting for Quickwit to start...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:7280/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Quickwit is running${NC}"
        break
    fi
    echo -n "."
    sleep 1
done

if ! curl -s http://localhost:7280/health > /dev/null 2>&1; then
    echo -e "${RED}✗ Quickwit failed to start${NC}"
    echo "Check logs with: docker logs quickwit"
    exit 1
fi

# Create index configuration
echo -e "\n${YELLOW}Creating Wazuh alerts index...${NC}"

cat > "$QUICKWIT_DATA/wazuh-alerts-index.yaml" <<'EOF'
version: 0.8
index_id: wazuh-alerts

doc_mapping:
  field_mappings:
    - name: timestamp
      type: datetime
      input_formats:
        - rfc3339
        - unix_timestamp
      fast: true
      stored: true

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

    - name: full_log
      type: text
      tokenizer: default
      stored: true

    - name: decoder.name
      type: text
      tokenizer: raw
      stored: true

  timestamp_field: timestamp
  mode: dynamic

indexing_settings:
  commit_timeout_secs: 10

search_settings:
  default_search_fields: [full_log, rule.description]
EOF

# Create index
echo -e "${YELLOW}Creating index in Quickwit...${NC}"
docker exec quickwit \
    quickwit index create \
    --index-config /quickwit/qwdata/wazuh-alerts-index.yaml

# Verify
echo -e "\n${YELLOW}Verifying index...${NC}"
curl -s http://localhost:7280/api/v1/indexes | python3 -m json.tool

# Summary
echo -e "\n${GREEN}======================================"
echo "Quickwit setup completed!"
echo "======================================${NC}"
echo ""
echo "Quickwit UI: http://localhost:7280"
echo "API Endpoint: http://localhost:7280/api/v1"
echo "Data Directory: $QUICKWIT_DATA"
echo ""
echo "Useful commands:"
echo "  Check status: docker ps | grep quickwit"
echo "  View logs: docker logs -f quickwit"
echo "  Stop: docker stop quickwit"
echo "  Start: docker start quickwit"
echo "  Query: curl 'http://localhost:7280/api/v1/wazuh-alerts/search?query=*&max_hits=10'"
echo ""
