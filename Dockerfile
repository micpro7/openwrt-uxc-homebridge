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
    ca-certificates \
    avahi-compat-libdns_sd \
    libstdc++ \
    sudo \
    # ------------------------------------------------------
    # 2. OPTIONAL RUNTIME ENHANCEMENTS (Remove to shrink)
    # ------------------------------------------------------
    curl \
    ffmpeg \
    # ------------------------------------------------------
    # 3. BUILD / COMPILATION TOOLS (Remove to shrink, but affects C/C++ builds)
    # ------------------------------------------------------
    python3 \
    make \
    g++ \
    git \
    linux-headers

# ==========================================================
# CRITICAL: Configure sudo to preserve NPM environment variables
# ==========================================================
RUN echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/homebridge \
 && echo "Defaults env_keep += \"NPM_CONFIG_CACHE NPM_CONFIG_TMP HOME NODE_ENV PATH\"" >> /etc/sudoers.d/homebridge

# ==========================================================
# Runtime environment & npm configuration
# ROUTING FIX: Move prefix to persistent volume path
# ==========================================================
ENV NPM_CONFIG_PREFIX=/var/lib/homebridge/plugins \
    PATH=/var/lib/homebridge/plugins/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    HOME=/var/lib/homebridge \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/var/lib/homebridge/.npm-cache \
    NPM_CONFIG_TMP=/var/lib/homebridge/.npm-tmp \
    HOMEBRIDGE_CONFIG_UI=1

RUN npm config set prefix /var/lib/homebridge/plugins \
 && npm config set update-notifier false \
 && npm config set audit false \
 && npm config set fund false

# ==========================================================
# Install core Homebridge (These remain in base image layers)
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
    test -f /var/lib/homebridge/plugins/lib/node_modules/homebridge/package.json; \
    test -f /var/lib/homebridge/plugins/lib/node_modules/homebridge-config-ui-x/package.json; \
    node --version; \
    npm --version; \
    /var/lib/homebridge/plugins/bin/homebridge --version

# ==========================================================
# Directory Setup & Target Working Directory
# ==========================================================
RUN mkdir -p /var/lib/homebridge/.npm-cache \
             /var/lib/homebridge/.npm-tmp \
             /var/lib/homebridge/plugins

WORKDIR /var/lib/homebridge
