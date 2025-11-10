#!/bin/bash
# Wazuh + Quickwit Build Script for macOS

set -e

echo "======================================"
echo "Wazuh + Quickwit macOS Build Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "\n${YELLOW}Project root: $PROJECT_ROOT${NC}"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: Homebrew is not installed${NC}"
    echo "Install it from: https://brew.sh"
    exit 1
fi

echo -e "${GREEN}✓ Homebrew found${NC}"

# Install dependencies
echo -e "\n${YELLOW}Installing dependencies...${NC}"
brew list cmake &>/dev/null || brew install cmake
brew list pkg-config &>/dev/null || brew install pkg-config
brew list openssl@3 &>/dev/null || brew install openssl@3
brew list rocksdb &>/dev/null || brew install rocksdb
brew list nlohmann-json &>/dev/null || brew install nlohmann-json

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Set environment variables
export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
export OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
export ROCKSDB_ROOT=$(brew --prefix rocksdb)

echo -e "\n${YELLOW}Environment:${NC}"
echo "  MACOSX_DEPLOYMENT_TARGET: $MACOSX_DEPLOYMENT_TARGET"
echo "  OPENSSL_ROOT_DIR: $OPENSSL_ROOT_DIR"
echo "  ROCKSDB_ROOT: $ROCKSDB_ROOT"

# Clean old build
if [ "$1" == "--clean" ]; then
    echo -e "\n${YELLOW}Cleaning old build...${NC}"
    rm -rf "$PROJECT_ROOT/build"
    echo -e "${GREEN}✓ Build directory cleaned${NC}"
fi

# Create build directories
mkdir -p "$PROJECT_ROOT/build/engine"
mkdir -p "$PROJECT_ROOT/build/indexer_connector"

# Build indexer connector
echo -e "\n${YELLOW}Building indexer connector...${NC}"
cd "$PROJECT_ROOT/build/indexer_connector"

cmake "$PROJECT_ROOT/src/shared_modules/indexer_connector" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUNIT_TEST=OFF \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
    -DROCKSDB_ROOT="$ROCKSDB_ROOT"

make -j$(sysctl -n hw.ncpu)

if [ -f "libindexer_connector.dylib" ]; then
    echo -e "${GREEN}✓ Indexer connector built successfully${NC}"
else
    echo -e "${RED}✗ Indexer connector build failed${NC}"
    exit 1
fi

# Build engine
echo -e "\n${YELLOW}Building Wazuh engine...${NC}"
cd "$PROJECT_ROOT/build/engine"

cmake "$PROJECT_ROOT/src/engine/source" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENGINE_BUILD_TEST=OFF \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
    -DROCKSDB_ROOT="$ROCKSDB_ROOT"

make -j$(sysctl -n hw.ncpu)

if [ -f "bin/wazuh-engine" ]; then
    echo -e "${GREEN}✓ Wazuh engine built successfully${NC}"
else
    echo -e "${RED}✗ Wazuh engine build failed${NC}"
    exit 1
fi

# Install Python SDK
echo -e "\n${YELLOW}Installing Python SDK...${NC}"
cd "$PROJECT_ROOT/framework"
pip3 install -e . --quiet

echo -e "${GREEN}✓ Python SDK installed${NC}"

# Create run script
echo -e "\n${YELLOW}Creating run script...${NC}"
cat > "$PROJECT_ROOT/run-wazuh.sh" <<'EOF'
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export DYLD_LIBRARY_PATH="$SCRIPT_DIR/build/indexer_connector:$SCRIPT_DIR/build/engine/lib:$DYLD_LIBRARY_PATH"
export WAZUH_CONFIG="${WAZUH_CONFIG:-$SCRIPT_DIR/config/ossec.conf}"

cd "$SCRIPT_DIR/build/engine"

echo "Starting Wazuh Engine with Quickwit support..."
echo "Config: $WAZUH_CONFIG"
echo ""

./bin/wazuh-engine --config "$WAZUH_CONFIG" "$@"
EOF

chmod +x "$PROJECT_ROOT/run-wazuh.sh"

echo -e "${GREEN}✓ Run script created: $PROJECT_ROOT/run-wazuh.sh${NC}"

# Summary
echo -e "\n${GREEN}======================================"
echo "Build completed successfully!"
echo "======================================${NC}"
echo ""
echo "Binaries:"
echo "  Engine: $PROJECT_ROOT/build/engine/bin/wazuh-engine"
echo "  Connector: $PROJECT_ROOT/build/indexer_connector/libindexer_connector.dylib"
echo ""
echo "Next steps:"
echo "  1. Setup Quickwit: ./scripts/setup-quickwit.sh"
echo "  2. Run Wazuh: ./run-wazuh.sh"
echo ""
