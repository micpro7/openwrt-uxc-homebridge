# syntax=docker/dockerfile:1

# Using node:24-alpine guarantees Node.js 24 while pulling the latest compatible Alpine Linux base
FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ==========================================================
# System dependencies
# ==========================================================
RUN apk add --no-cache \
    # ------------------------------------------------------
    # 1. MANDATORY CORE RUNTIME (Do not remove)
    # ------------------------------------------------------
    tzdata \
    # Required to map timezones accurately so scheduled automations run on time.
    ca-certificates \
    # Required for secure HTTPS outgoing connections to cloud APIs (e.g., Tuya, Ring).
    avahi-compat-libdns_sd \
    # Required for mDNS/Bonjour advertising so Apple Home can discover Homebridge.
    libstdc++ \
    # Required by Node.js and various pre-compiled binary modules.
    \
    # ------------------------------------------------------
    # 2. OPTIONAL RUNTIME ENHANCEMENTS (Remove to shrink)
    # ------------------------------------------------------
    curl \
    # Useful for script health checks and local diagnostics. [~1.5 MB]
    ffmpeg \
    # Critical for camera/video processing plugins (e.g., Ring, Nest, RTSP streams). 
    # If you do not run camera streams inside Homebridge, you can safely remove this. [~40-50 MB]
    \
    # ------------------------------------------------------
    # 3. BUILD / COMPILATION TOOLS (Remove to shrink, but affects C/C++ builds)
    #
    # If you delete this group, you will shrink the image footprint 
    # by roughly ~100MB. However, you will no longer be able to 
    # install plugins that compile native C/C++ modules on the fly 
    # (e.g., Bluetooth/BLE trackers, Zigbee local USB drivers, or 
    # raw network socket controllers).
    # ------------------------------------------------------
    python3 \
    # Required by node-gyp as the build system orchestrator. [~45 MB]
    make \
    # Standard GNU utility used to build and compile code from source. [~0.5 MB]
    g++ \
    # The GNU C++ Compiler used to compile native C++ plugins. [~35 MB]
    git \
    # Required by npm to pull and install plugins hosted directly on GitHub URLs. [~7 MB]
    linux-headers
    # Provides Linux kernel headers required for compiling native drivers. [~5 MB]

# ==========================================================
# Runtime environment & npm configuration
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    HOME=/var/lib/homebridge \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/var/lib/homebridge/.npm-cache \
    NPM_CONFIG_TMP=/var/lib/homebridge/.npm-tmp \
    HOMEBRIDGE_CONFIG_UI=1

RUN npm config set prefix /usr/local \
 && npm config set update-notifier false \
 && npm config set audit false \
 && npm config set fund false

# ==========================================================
# Install Homebridge
# ==========================================================
RUN npm install -g \
    --unsafe-perm \
    homebridge@${HOMEBRIDGE_VERSION} \
    homebridge-config-ui-x@${CONFIG_UI_VERSION} \
 && npm cache clean --force

# ==========================================================
# Validate installation
# ==========================================================
RUN set -eux; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    node --version; \
    npm --version; \
    homebridge --version; \
    node -e "console.log(require('/usr/local/lib/node_modules/homebridge/package.json').version)"; \
    node -e "console.log(require('/usr/local/lib/node_modules/homebridge-config-ui-x/package.json').version)"

WORKDIR /var/lib/homebridge
