# Dockerfile for Wazuh with Quickwit Support
# Copyright (C) 2015, Wazuh Inc.
# Multi-stage build for optimized image size

# Build stage
FROM ubuntu:22.04 AS builder

# Build arguments
ARG WAZUH_VERSION=4.9.0
ARG BUILD_JOBS=4
ARG BUILD_DEBUG=0
ARG BUILD_TARGET=server

# Set environment variables for build
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    BUILD_JOBS=${BUILD_JOBS} \
    BUILD_DEBUG=${BUILD_DEBUG}

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    gcc \
    g++ \
    make \
    git \
    wget \
    curl \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    libarchive-dev \
    libpcre2-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    python3-dev \
    python3-pip \
    libjemalloc-dev \
    librocksdb-dev \
    nlohmann-json3-dev \
    libcjson-dev \
    libsystemd-dev \
    libyaml-dev \
    libffi-dev \
    autoconf \
    automake \
    libtool \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source code
COPY . /build/

# Build Wazuh with Quickwit support
RUN cd /build/src && \
    # Download external dependencies
    make deps TARGET=${BUILD_TARGET} && \
    # Build Wazuh
    make TARGET=${BUILD_TARGET} DEBUG=${BUILD_DEBUG} build -j${BUILD_JOBS} && \
    # Create installation directory
    mkdir -p /var/ossec && \
    # Run installation
    cd /build && \
    USER_LANGUAGE="en" \
    USER_NO_STOP="y" \
    USER_INSTALL_TYPE="${BUILD_TARGET}" \
    USER_DIR="/var/ossec" \
    USER_BINARYINSTALL="y" \
    ./install.sh

# Runtime stage
FROM ubuntu:22.04

# Runtime arguments
ARG WAZUH_VERSION=4.9.0

# Labels
LABEL maintainer="Wazuh Inc." \
      version="${WAZUH_VERSION}" \
      description="Wazuh Manager with Quickwit integration support"

# Set environment variables
ENV WAZUH_HOME=/var/ossec \
    WAZUH_USER=ossec \
    WAZUH_GROUP=ossec \
    DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    QUICKWIT_HOST=quickwit-server \
    QUICKWIT_PORT=7280 \
    QUICKWIT_INDEX=wazuh-alerts

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    libc6 \
    libgcc-s1 \
    libssl3 \
    libsqlite3-0 \
    libarchive13 \
    libpcre2-8-0 \
    zlib1g \
    libbz2-1.0 \
    liblzma5 \
    python3 \
    python3-pip \
    libjemalloc2 \
    librocksdb6.11 \
    libcjson1 \
    libsystemd0 \
    libyaml-0-2 \
    libffi8 \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install --no-cache-dir requests

# Copy Wazuh installation from builder
COPY --from=builder /var/ossec /var/ossec

# Copy framework (Python SDK)
COPY --from=builder /build/framework /var/ossec/framework

# Create necessary directories
RUN mkdir -p \
    /var/ossec/logs \
    /var/ossec/etc \
    /var/ossec/queue \
    /var/ossec/stats \
    /var/ossec/tmp \
    /var/ossec/var/run

# Create Wazuh user and group
RUN groupadd -r ossec && \
    useradd -r -g ossec -d /var/ossec -s /sbin/nologin ossec && \
    # Set permissions
    chown -R ossec:ossec /var/ossec && \
    chmod -R 750 /var/ossec/logs \
                  /var/ossec/queue \
                  /var/ossec/stats \
                  /var/ossec/tmp \
                  /var/ossec/var

# Copy entrypoint and healthcheck scripts
COPY docker/scripts/entrypoint.sh /usr/local/bin/
COPY docker/scripts/healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Expose ports
# 55000: API
# 1514: Agent communication (TCP)
# 1514: Agent communication (UDP)
# 1515: Agent enrollment
# 1516: Cluster communication
EXPOSE 55000 1514/tcp 1514/udp 1515 1516

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Set working directory
WORKDIR /var/ossec

# Volume for persistent data
VOLUME ["/var/ossec/logs", "/var/ossec/etc", "/var/ossec/queue", "/var/ossec/stats"]

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["/var/ossec/bin/wazuh-control", "start"]
