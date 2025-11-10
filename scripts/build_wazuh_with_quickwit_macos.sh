#!/bin/bash
# Copyright (C) 2015, Wazuh Inc.
# Build script for Wazuh with Quickwit support on macOS
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET="agent"
DEBUG="0"
TEST="0"
JOBS=$(sysctl -n hw.ncpu)
PREFIX="/var/ossec"
SKIP_DEPS="no"
SKIP_BUILD="no"
SETUP_QUICKWIT="no"
CLEAN="no"
QUICKWIT_VERSION="0.8.1"
QUICKWIT_PORT="7280"
QUICKWIT_DIR="${HOME}/.quickwit"

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build Wazuh with Quickwit integration support on macOS.

Options:
  --target TYPE        Build target: agent, server (default: agent)
  --debug              Enable debug build (DEBUG=1)
  --test               Enable unit tests (TEST=1)
  --jobs N             Number of parallel jobs (default: CPU count)
  --prefix DIR         Installation prefix (default: /var/ossec)
  --skip-deps          Skip dependency installation
  --skip-build         Skip Wazuh build
  --setup-quickwit     Download and setup Quickwit server
  --quickwit-version V Quickwit version to install (default: 0.8.1)
  --quickwit-dir DIR   Quickwit installation directory (default: ~/.quickwit)
  --clean              Clean previous build artifacts
  --help               Show this help message

Examples:
  # Standard development build with debug symbols
  $(basename "$0") --debug

  # Build with tests enabled
  $(basename "$0") --debug --test

  # Full setup including Quickwit server
  $(basename "$0") --debug --setup-quickwit

  # Clean build with custom installation directory
  $(basename "$0") --clean --debug --prefix /opt/wazuh-dev

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --debug)
            DEBUG="1"
            shift
            ;;
        --test)
            TEST="1"
            shift
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --skip-deps)
            SKIP_DEPS="yes"
            shift
            ;;
        --skip-build)
            SKIP_BUILD="yes"
            shift
            ;;
        --setup-quickwit)
            SETUP_QUICKWIT="yes"
            shift
            ;;
        --quickwit-version)
            QUICKWIT_VERSION="$2"
            shift 2
            ;;
        --quickwit-dir)
            QUICKWIT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN="yes"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate target
if [[ "$TARGET" != "agent" && "$TARGET" != "server" ]]; then
    log_error "Invalid target: $TARGET. Must be 'agent' or 'server'"
    exit 1
fi

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    log_success "Running on macOS $(sw_vers -productVersion)"
}

# Check for Homebrew
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed"
        log_info "Install Homebrew from: https://brew.sh"
        exit 1
    fi
    log_success "Homebrew found: $(brew --version | head -n1)"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies via Homebrew..."

    local packages=(
        "cmake"
        "make"
        "git"
        "wget"
        "curl"
        "pkg-config"
        "openssl@3"
        "sqlite"
        "rocksdb"
        "nlohmann-json"
        "simdjson"
        "cjson"
        "libarchive"
        "pcre2"
        "zlib"
        "bzip2"
        "xz"
        "python@3.10"
    )

    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "✓ $package already installed"
        else
            log_info "Installing $package..."
            brew install "$package" || log_warning "Failed to install $package"
        fi
    done

    log_success "Dependencies installed"
}

# Setup environment variables
setup_environment() {
    log_info "Setting up environment variables..."

    # OpenSSL
    export OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
    export PKG_CONFIG_PATH="$OPENSSL_ROOT_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-L$OPENSSL_ROOT_DIR/lib $LDFLAGS"
    export CPPFLAGS="-I$OPENSSL_ROOT_DIR/include $CPPFLAGS"

    # Python
    export PATH="$(brew --prefix python@3.10)/bin:$PATH"

    log_success "Environment configured"
    log_info "OpenSSL: $OPENSSL_ROOT_DIR"
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning previous build artifacts..."

    cd "$REPO_ROOT/src"

    # Clean main build
    if [[ -f Makefile ]]; then
        make clean 2>/dev/null || true
    fi

    # Clean CMake builds
    find . -type d -name "build" -exec rm -rf {} + 2>/dev/null || true

    # Clean object files
    find . -type f \( -name "*.o" -o -name "*.a" -o -name "*.dylib" \) -delete 2>/dev/null || true

    log_success "Build artifacts cleaned"
}

# Build Wazuh dependencies
build_dependencies() {
    log_info "Building Wazuh external dependencies..."

    cd "$REPO_ROOT/src"

    make deps TARGET="$TARGET" || {
        log_error "Failed to build dependencies"
        exit 1
    }

    log_success "Dependencies built successfully"
}

# Build Wazuh
build_wazuh() {
    log_info "Building Wazuh (target: $TARGET, debug: $DEBUG, test: $TEST)..."

    cd "$REPO_ROOT/src"

    local build_cmd="make TARGET=$TARGET"

    if [[ "$DEBUG" == "1" ]]; then
        build_cmd="$build_cmd DEBUG=1"
    fi

    if [[ "$TEST" == "1" ]]; then
        build_cmd="$build_cmd TEST=1"
    fi

    # macOS specific: force flat namespace
    export DYLD_FORCE_FLAT_NAMESPACE=1

    build_cmd="$build_cmd build -j$JOBS"

    log_info "Running: $build_cmd"
    eval "$build_cmd" || {
        log_error "Build failed"
        exit 1
    }

    log_success "Wazuh built successfully"
}

# Verify Quickwit connector was built
verify_build() {
    log_info "Verifying Quickwit connector build..."

    local connector_lib="$REPO_ROOT/src/shared_modules/indexer_connector/build/libindexer_connector.dylib"

    if [[ -f "$connector_lib" ]]; then
        log_success "Quickwit connector library found: $connector_lib"

        # Check for Quickwit symbols
        if nm "$connector_lib" 2>/dev/null | grep -i quickwit &>/dev/null; then
            log_success "Quickwit symbols found in connector library"
        else
            log_warning "Quickwit symbols not found in connector library"
        fi
    else
        log_warning "Connector library not found at expected location"
    fi

    # Check engine connector
    local engine_lib="$REPO_ROOT/src/engine/build/source/wiconnector/libwIndexerConnector_wIndexerConnector.a"
    if [[ -f "$engine_lib" ]]; then
        log_success "Engine connector library found"
    else
        log_warning "Engine connector library not found"
    fi
}

# Setup Quickwit
setup_quickwit() {
    log_info "Setting up Quickwit server..."

    mkdir -p "$QUICKWIT_DIR"
    cd "$QUICKWIT_DIR"

    # Detect architecture
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        arch="x86_64"
    elif [[ "$arch" == "arm64" ]]; then
        arch="aarch64"
    else
        log_error "Unsupported architecture: $arch"
        exit 1
    fi

    local quickwit_archive="quickwit-v${QUICKWIT_VERSION}-${arch}-apple-darwin.tar.gz"
    local download_url="https://github.com/quickwit-oss/quickwit/releases/download/v${QUICKWIT_VERSION}/${quickwit_archive}"

    log_info "Downloading Quickwit v${QUICKWIT_VERSION} for ${arch}..."
    log_info "URL: $download_url"

    if ! curl -L "$download_url" -o "$quickwit_archive"; then
        log_error "Failed to download Quickwit"
        log_info "Please download manually from: https://github.com/quickwit-oss/quickwit/releases"
        exit 1
    fi

    log_info "Extracting Quickwit..."
    tar -xzf "$quickwit_archive"

    # Find the extracted directory
    local quickwit_bin=$(find . -name "quickwit" -type f -perm +111 | head -n1)

    if [[ -z "$quickwit_bin" ]]; then
        log_error "Quickwit binary not found after extraction"
        exit 1
    fi

    local quickwit_extracted_dir=$(dirname "$quickwit_bin")

    # Create symlink
    ln -sf "$quickwit_extracted_dir" current

    log_success "Quickwit installed to: $QUICKWIT_DIR/current"

    # Create index configuration
    create_quickwit_index_config
}

# Create Quickwit index configuration
create_quickwit_index_config() {
    log_info "Creating Wazuh index configuration for Quickwit..."

    local index_config="$QUICKWIT_DIR/wazuh-alerts-index.yaml"

    cat > "$index_config" << 'EOF'
version: 0.8

index_id: wazuh-alerts

doc_mapping:
  field_mappings:
    - name: timestamp
      type: datetime
      input_formats:
        - rfc3339
      fast: true

    - name: agent.id
      type: text
      tokenizer: raw
      fast: true

    - name: agent.name
      type: text
      tokenizer: default

    - name: rule.id
      type: u64
      fast: true

    - name: rule.level
      type: u64
      fast: true

    - name: rule.description
      type: text
      tokenizer: default

    - name: data
      type: json

    - name: full_log
      type: text
      tokenizer: default

  timestamp_field: timestamp
  mode: dynamic

indexing_settings:
  commit_timeout_secs: 10

search_settings:
  default_search_fields: [full_log, rule.description]
EOF

    log_success "Index configuration created: $index_config"

    # Create index
    log_info "Creating Wazuh alerts index in Quickwit..."

    "$QUICKWIT_DIR/current/quickwit" index create --index-config "$index_config" 2>/dev/null || {
        log_info "Index creation will be done when Quickwit server starts"
    }

    # Create start script
    create_quickwit_start_script
}

# Create Quickwit start script
create_quickwit_start_script() {
    local start_script="$QUICKWIT_DIR/start_quickwit.sh"

    cat > "$start_script" << EOF
#!/bin/bash
# Start Quickwit server

QUICKWIT_DIR="$QUICKWIT_DIR"
QUICKWIT_BIN="\${QUICKWIT_DIR}/current/quickwit"

echo "Starting Quickwit server..."
echo "Data directory: \${QUICKWIT_DIR}/qwdata"
echo "Index config: \${QUICKWIT_DIR}/wazuh-alerts-index.yaml"
echo ""

# Create index if it doesn't exist
"\$QUICKWIT_BIN" index create --index-config "\${QUICKWIT_DIR}/wazuh-alerts-index.yaml" 2>/dev/null || true

# Start server
"\$QUICKWIT_BIN" run
EOF

    chmod +x "$start_script"

    log_success "Start script created: $start_script"
    log_info "To start Quickwit, run: $start_script"
}

# Create configuration helper
create_config_helper() {
    log_info "Creating Wazuh configuration helper..."

    local config_helper="$REPO_ROOT/scripts/configure_quickwit.sh"

    cat > "$config_helper" << 'EOF'
#!/bin/bash
# Helper script to configure Wazuh for Quickwit

set -e

OSSEC_CONF="${1:-/var/ossec/etc/ossec.conf}"
QUICKWIT_HOST="${2:-http://localhost:7280}"

if [[ ! -f "$OSSEC_CONF" ]]; then
    echo "Creating new configuration file: $OSSEC_CONF"
    mkdir -p "$(dirname "$OSSEC_CONF")"

    cat > "$OSSEC_CONF" << CONF
<?xml version="1.0" encoding="UTF-8"?>
<ossec_config>
  <indexer>
    <enabled>yes</enabled>
    <type>quickwit</type>
    <hosts>
      <host>$QUICKWIT_HOST</host>
    </hosts>
  </indexer>
</ossec_config>
CONF

    echo "Configuration created: $OSSEC_CONF"
else
    echo "Configuration file exists: $OSSEC_CONF"
    echo "Please manually add the following to your ossec.conf:"
    echo ""
    cat << CONF
  <indexer>
    <enabled>yes</enabled>
    <type>quickwit</type>
    <hosts>
      <host>$QUICKWIT_HOST</host>
    </hosts>
  </indexer>
CONF
fi
EOF

    chmod +x "$config_helper"

    log_success "Configuration helper created: $config_helper"
}

# Print summary
print_summary() {
    echo ""
    echo "================================================================"
    log_success "Wazuh build completed successfully!"
    echo "================================================================"
    echo ""
    echo "Build Configuration:"
    echo "  Target:           $TARGET"
    echo "  Debug:            $DEBUG"
    echo "  Tests:            $TEST"
    echo "  Jobs:             $JOBS"
    echo "  Installation:     $PREFIX"
    echo ""

    if [[ "$SETUP_QUICKWIT" == "yes" ]]; then
        echo "Quickwit Setup:"
        echo "  Version:          $QUICKWIT_VERSION"
        echo "  Directory:        $QUICKWIT_DIR"
        echo "  Start script:     $QUICKWIT_DIR/start_quickwit.sh"
        echo "  Index config:     $QUICKWIT_DIR/wazuh-alerts-index.yaml"
        echo ""
        echo "To start Quickwit:"
        echo "  $QUICKWIT_DIR/start_quickwit.sh"
        echo ""
        echo "Or manually:"
        echo "  cd $QUICKWIT_DIR/current"
        echo "  ./quickwit run"
        echo ""
    fi

    echo "Next Steps:"
    echo ""

    if [[ "$SKIP_BUILD" != "yes" ]]; then
        echo "1. Install Wazuh:"
        echo "   cd $REPO_ROOT"
        echo "   sudo ./install.sh"
        echo ""
    fi

    if [[ "$SETUP_QUICKWIT" == "yes" ]]; then
        echo "2. Start Quickwit server:"
        echo "   $QUICKWIT_DIR/start_quickwit.sh"
        echo ""
        echo "3. Configure Wazuh for Quickwit:"
        echo "   $REPO_ROOT/scripts/configure_quickwit.sh"
    else
        echo "2. Setup Quickwit (if not already done):"
        echo "   $(basename "$0") --setup-quickwit"
    fi
    echo ""

    echo "4. Verify the setup:"
    echo "   curl http://localhost:$QUICKWIT_PORT/health"
    echo "   curl http://localhost:$QUICKWIT_PORT/api/v1/indexes/wazuh-alerts"
    echo ""

    if [[ "$TEST" == "1" ]]; then
        echo "Run Tests:"
        echo "  cd $REPO_ROOT/src"
        echo "  python3 build.py -t shared_modules/indexer_connector"
        echo "  python3 build.py -t engine/source/wiconnector"
        echo ""
    fi

    echo "Documentation:"
    echo "  Build Guide:      $REPO_ROOT/BUILD_WITH_QUICKWIT.md"
    echo "  Integration:      $REPO_ROOT/QUICKWIT_INTEGRATION.md"
    echo "  Python SDK:       $REPO_ROOT/framework/wazuh/quickwit/README.md"
    echo ""
    echo "================================================================"
}

# Main execution
main() {
    log_info "Wazuh with Quickwit Support - Build Script for macOS"
    echo ""

    # Check prerequisites
    check_macos
    check_homebrew

    # Setup environment
    setup_environment

    # Install dependencies
    if [[ "$SKIP_DEPS" != "yes" ]]; then
        install_dependencies
    else
        log_info "Skipping dependency installation (--skip-deps)"
    fi

    # Clean if requested
    if [[ "$CLEAN" == "yes" ]]; then
        clean_build
    fi

    # Build Wazuh
    if [[ "$SKIP_BUILD" != "yes" ]]; then
        build_dependencies
        build_wazuh
        verify_build
    else
        log_info "Skipping Wazuh build (--skip-build)"
    fi

    # Setup Quickwit
    if [[ "$SETUP_QUICKWIT" == "yes" ]]; then
        setup_quickwit
    fi

    # Create helpers
    create_config_helper

    # Print summary
    print_summary
}

# Run main function
main "$@"
