# syntax=docker/dockerfile:1

# ============================================================
# Base image
# ============================================================

FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ============================================================
# System packages
# ============================================================

RUN set -eux; \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        wget \
        tzdata \
        jq \
        openssl \
        sudo \
        nano \
        vim \
        procps \
        psmisc \
        iputils \
        iproute2 \
        net-tools \
        logrotate \
        git \
        make \
        g++ \
        python3 \
        py3-pip \
        py3-setuptools \
        python3-dev \
        linux-headers \
        libgcc \
        libstdc++ \
        libatomic \
        avahi \
        avahi-compat-libdns_sd \
        avahi-tools \
        dbus \
        dbus-libs \
        libc6-compat

# ============================================================
# Required directories
# ============================================================

RUN set -eux; \
    mkdir -p \
        /opt/homebridge \
        /var/lib/homebridge \
        /var/lib/homebridge/node_modules \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp; \
    chmod 1777 \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp

# ============================================================
# Node / npm configuration
#
# Node remains completely intact under /usr/local.
# ============================================================

RUN set -eux; \
    node --version; \
    npm --version; \
    npm config set prefix /usr/local; \
    npm config set cache /tmp/.npm

# ============================================================
# Homebridge application installation
#
# Application lives in /opt/homebridge.
# Persistent data/plugins live in /var/lib/homebridge.
# ============================================================

RUN set -eux; \
    cd /opt/homebridge; \
    printf '{\n  "private": true\n}\n' > package.json; \
    if [ "${HOMEBRIDGE_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge; \
    else \
        npm install --omit=dev "homebridge@${HOMEBRIDGE_VERSION}"; \
    fi

# ============================================================
# Homebridge Config UI X
# ============================================================

RUN set -eux; \
    cd /opt/homebridge; \
    if [ "${CONFIG_UI_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge-config-ui-x; \
    else \
        npm install --omit=dev "homebridge-config-ui-x@${CONFIG_UI_VERSION}"; \
    fi

# ============================================================
# Verify Homebridge installation
# ============================================================

RUN set -eux; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x; \
    test -f /opt/homebridge/node_modules/homebridge/package.json; \
    test -f /opt/homebridge/node_modules/homebridge-config-ui-x/package.json; \
    test -x /opt/homebridge/node_modules/.bin/hb-service

# ============================================================
# Expose Homebridge executables in /usr/local/bin
#
# This is important because the UXC config calls:
#
#   /usr/local/bin/hb-service
#
# The actual npm executable lives at:
#
#   /opt/homebridge/node_modules/.bin/hb-service
# ============================================================

RUN set -eux; \
    ln -