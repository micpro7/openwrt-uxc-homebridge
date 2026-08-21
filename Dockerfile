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
    ln -sf /opt/homebridge/node_modules/.bin/hb-service /usr/local/bin/hb-service; \
    ln -sf /opt/homebridge/node_modules/.bin/homebridge /usr/local/bin/homebridge; \
    test -x /usr/local/bin/hb-service; \
    test -x /usr/local/bin/homebridge

# ============================================================
# Homebridge version manifest
# ============================================================

RUN set -eux; \
    HB_VER="$(node -p "require('/opt/homebridge/node_modules/homebridge/package.json').version")"; \
    UI_VER="$(node -p "require('/opt/homebridge/node_modules/homebridge-config-ui-x/package.json').version")"; \
    NODE_VER="$(node --version)"; \
    NPM_VER="$(npm --version)"; \
    cat > /opt/homebridge/Docker.manifest <<EOF
Homebridge=${HB_VER}
ConfigUIX=${UI_VER}
Node=${NODE_VER}
NPM=${NPM_VER}
EOF

# ============================================================
# UXC bootstrap helper
#
# Creates the persistent Homebridge directories without
# replacing the application installed in /opt/homebridge.
# ============================================================

RUN cat > /usr/local/bin/homebridge-uxc-bootstrap <<'EOF'
#!/bin/sh
set -eu

DATA="/var/lib/homebridge"
PLUGINS="${DATA}/node_modules"

mkdir -p \
    "${DATA}" \
    "${PLUGINS}" \
    "${DATA}/accessories" \
    "${DATA}/persist"

chmod 755 "${DATA}"
chmod 755 "${PLUGINS}"

# npm/plugin installation should resolve against the persistent
# Homebridge plugin directory.

if [ ! -f "${DATA}/package.json" ]; then
    cat > "${DATA}/package.json" <<'JSON'
{
  "private": true
}
JSON
fi

exit 0
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-bootstrap

# ============================================================
# UXC runtime helper
#
# Plugins are installed into /var/lib/homebridge/node_modules.
# Homebridge itself remains in /opt/homebridge.
# ============================================================

RUN cat > /usr/local/bin/homebridge-uxc-run <<'EOF'
#!/bin/sh
set -eu

DATA="/var/lib/homebridge"
PLUGINS="${DATA}/node_modules"

export HOME="${HOME:-/root}"
export NODE_ENV="${NODE_ENV:-production}"

export NPM_CONFIG_PREFIX="/usr/local"
export npm_config_prefix="/usr/local"

export NPM_CONFIG_CACHE="${NPM_CONFIG_CACHE:-/tmp/.npm}"
export npm_config_cache="${NPM_CONFIG_CACHE}"

export NPM_CONFIG_DEVDIR="${NPM_CONFIG_DEVDIR:-/tmp/.node-gyp}"
export npm_config_devdir="${NPM_CONFIG_DEVDIR}"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/.config}"

export NODE_PATH="/opt/homebridge/node_modules:${PLUGINS}:/usr/local/lib/node_modules"

mkdir -p \
    "${DATA}" \
    "${PLUGINS}" \
    /tmp/.npm \
    /tmp/.config \
    /tmp/.node-gyp

exec /usr/local/bin/hb-service \
    run \
    --allow-root \
    -U "${DATA}" \
    -P "${PLUGINS}"
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-run

# ============================================================
# Final installation verification
# ============================================================

RUN set -eux; \
    /usr/local/bin/node --version; \
    /usr/local/bin/npm --version; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/hb-service; \
    test -x /usr/local/bin/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x; \
    /usr/local/bin/hb-service --help >/dev/null 2>&1 || true

# ============================================================
# Environment
# ============================================================

ENV \
    PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/opt/homebridge/node_modules/.bin" \
    HOME="/root" \
    TERM="xterm" \
    TZ="Europe/London" \
    USER="root" \
    NODE_ENV="production" \
    NODE_PATH="/opt/homebridge/node_modules:/var/lib/homebridge/node_modules:/usr/local/lib/node_modules" \
    NPM_CONFIG_PREFIX="/usr/local" \
    npm_config_prefix="/usr/local" \
    NPM_CONFIG_CACHE="/tmp/.npm" \
    npm_config_cache="/tmp/.npm" \
    npm_config_update_notifier="false" \
    NPM_CONFIG_UPDATE_NOTIFIER="false" \
    NPM_CONFIG_DEVDIR="/tmp/.node-gyp" \
    npm_config_devdir="/tmp/.node-gyp" \
    XDG_CONFIG_HOME="/tmp/.config" \
    NODE_OPTIONS="--max-old-space-size=256" \
    UV_THREADPOOL_SIZE="4" \
    MDNS_INTERFACE="br-lan" \
    HOMEBRIDGE_IP="0.0.0.0" \
    HOMEBRIDGE_CONFIG_UI="1" \
    HOMEBRIDGE_CONFIG_UI_TERMINAL="1" \
    UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
    UIX_CONFIG_PATH="/var/lib/homebridge/config.json" \
    UIX_STORAGE_PATH="/var/lib/homebridge" \
    UIX_STRICT_PLUGIN_RESOLUTION="1" \
    UIX_DEBUG_LOGGING="0" \
    UIX_INSECURE_MODE="1"

# ============================================================
# Working directory
# ============================================================

WORKDIR /var/lib/homebridge

# ============================================================
# UXC containers run the actual command from config.json.
# ============================================================

CMD ["/usr/local/bin/homebridge-uxc-run"]