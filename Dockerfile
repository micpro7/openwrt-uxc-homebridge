# syntax=docker/dockerfile:1

# ==========================================================
# Homebridge UXC - Alpine
# Based on the official Homebridge Docker architecture
# ==========================================================

FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="Homebridge UXC"
LABEL org.opencontainers.image.description="Homebridge for OpenWrt UXC using Alpine Linux"
LABEL org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# ==========================================================
# Runtime environment
# ==========================================================

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    HOME=/root \
    TZ=Europe/London \
    USER=root \
    NPM_CONFIG_PREFIX=/usr/local \
    NPM_CONFIG_CACHE=/tmp/.npm \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_DEVDIR=/tmp/.node-gyp \
    XDG_CONFIG_HOME=/tmp/.config \
    NODE_PATH=/usr/local/lib/node_modules \
    UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules \
    HOMEBRIDGE_CONFIG_UI=1 \
    HOMEBRIDGE_CONFIG_UI_TERMINAL=1 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# ==========================================================
# Install required Alpine packages
# ==========================================================

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
        libgcc \
        libstdc++ \
        libatomic \
        avahi \
        avahi-compat-libdns_sd \
        avahi-tools \
        dbus \
        dbus-libs \
        linux-headers \
        libc6-compat; \
    mkdir -p \
        /var/lib/homebridge \
        /var/lib/homebridge/node_modules \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp; \
    chmod 1777 /tmp/.npm /tmp/.config /tmp/.node-gyp

# ==========================================================
# Verify Node.js / npm
# ==========================================================

RUN set -eux; \
    node --version; \
    npm --version; \
    npm config set prefix /usr/local; \
    npm config set cache /tmp/.npm

# ==========================================================
# Install Homebridge
# ==========================================================

RUN set -eux; \
    if [ "${HOMEBRIDGE_VERSION}" = "latest" ]; then \
        npm install --location=global --omit=dev homebridge; \
    else \
        npm install --location=global --omit=dev "homebridge@${HOMEBRIDGE_VERSION}"; \
    fi

# ==========================================================
# Install Homebridge Config UI X
# ==========================================================

RUN set -eux; \
    if [ "${CONFIG_UI_VERSION}" = "latest" ]; then \
        npm install --location=global --omit=dev homebridge-config-ui-x; \
    else \
        npm install --location=global --omit=dev "homebridge-config-ui-x@${CONFIG_UI_VERSION}"; \
    fi

# ==========================================================
# Make Homebridge executables explicit
# ==========================================================

RUN set -eux; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/homebridge; \
    test -x /usr/local/bin/hb-service; \
    test -d /usr/local/lib/node_modules/homebridge; \
    test -d /usr/local/lib/node_modules/homebridge-config-ui-x

# ==========================================================
# Persistent plugin directory
#
# IMPORTANT:
# This is deliberately outside /usr/local.
# Homebridge core and UI remain in the immutable image.
# User-installed plugins live in the persistent UXC mount.
# ==========================================================

RUN set -eux; \
    mkdir -p /var/lib/homebridge/node_modules; \
    chmod 0755 /var/lib/homebridge /var/lib/homebridge/node_modules

# ==========================================================
# Tell Config UI X exactly where custom plugins live
# ==========================================================

RUN set -eux; \
    mkdir -p /etc/homebridge; \
    cat > /etc/homebridge/environment <<'EOF'
UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules
HOMEBRIDGE_CONFIG_UI=1
HOMEBRIDGE_CONFIG_UI_TERMINAL=1
NODE_PATH=/usr/local/lib/node_modules
NPM_CONFIG_PREFIX=/usr/local
NPM_CONFIG_CACHE=/tmp/.npm
EOF

# ==========================================================
# Optional compatibility links
#
# Do NOT copy Homebridge into the persistent plugin directory.
# The real Homebridge installation remains under /usr/local.
# ==========================================================

RUN set -eux; \
    ln -sf /usr/local/bin/homebridge /usr/local/bin/hb-homebridge; \
    ln -sf /usr/local/bin/hb-service /usr/local/bin/hb-homebridge-service

# ==========================================================
# Homebridge configuration
# ==========================================================

WORKDIR /var/lib/homebridge

# ==========================================================
# Runtime checks
# ==========================================================

RUN set -eux; \
    /usr/local/bin/node -e '\
      const fs = require("fs"); \
      const hb = "/usr/local/lib/node_modules/homebridge"; \
      const ui = "/usr/local/lib/node_modules/homebridge-config-ui-x"; \
      const plugins = "/var/lib/homebridge/node_modules"; \
      if (!fs.existsSync(hb)) throw new Error("Homebridge missing"); \
      if (!fs.existsSync(ui)) throw new Error("Config UI X missing"); \
      if (!fs.existsSync(plugins)) throw new Error("Plugin directory missing"); \
      console.log("Homebridge:", require(hb + "/package.json").version); \
      console.log("Config UI X:", require(ui + "/package.json").version); \
      console.log("Plugin path:", plugins); \
    '

# ==========================================================
# UXC container entrypoint
#
# -P is intentionally retained.
# UIX_CUSTOM_PLUGIN_PATH is also baked into the environment.
# ==========================================================

ENTRYPOINT ["/sbin/tini", "-g", "--"]

CMD ["/bin/sh", "-c", \
     "while true; do \
        /usr/local/bin/hb-service run \
          --allow-root \
          -U /var/lib/homebridge \
          -P /var/lib/homebridge/node_modules; \
        echo \"$(date) Homebridge crashed - restarting in 3s\"; \
        sleep 3; \
      done"]