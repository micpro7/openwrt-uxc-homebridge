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
    sudo \
    # Required by Homebridge Config UI-X's hardcoded setup execution.
    \
    # ------------------------------------------------------
    # 2. OPTIONAL RUNTIME ENHANCEMENTS (Recommended)
    # ------------------------------------------------------
    bash \
    # Many Homebridge plugins assume Bash is available.
    tini \
    # Lightweight init process for proper signal handling and zombie process cleanup.
    curl \
    # Useful for script health checks and local diagnostics.
    ffmpeg \
    # Critical for camera/video processing plugins (e.g., Ring, Nest, RTSP streams).
    # If you do not run camera streams inside Homebridge, you can safely remove this.
    \
    # ------------------------------------------------------
    # 3. BUILD / COMPILATION TOOLS
    # ------------------------------------------------------
    python3 \
    # Required by node-gyp as the build system orchestrator.
    make \
    # Standard GNU utility used to build and compile code from source.
    g++ \
    # GNU C++ compiler used to compile native Node.js modules.
    git \
    # Required by npm to install plugins directly from GitHub repositories.
    linux-headers
    # Linux kernel headers required by some native compilation processes.

# ==========================================================
# CRITICAL: Configure sudo to preserve NPM environment variables
# ==========================================================
RUN echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/homebridge \
 && echo "Defaults env_keep += \"NPM_CONFIG_CACHE NPM_CONFIG_TMP HOME NODE_ENV PATH\"" >> /etc/sudoers.d/homebridge

# ==========================================================
# Runtime environment & npm configuration
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
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

# ==========================================================
# Health Check
# ==========================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD homebridge --version >/dev/null || exit 1

# ==========================================================
# Directory Setup
# ==========================================================
RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/backups \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/plugins

WORKDIR /var/lib/homebridge

# Persistent Homebridge data
VOLUME ["/var/lib/homebridge"]

# Homebridge Config UI X
EXPOSE 8581

# ==========================================================
# Container Startup
# ==========================================================
ENTRYPOINT ["/sbin/tini","--"]

CMD ["homebridge"]