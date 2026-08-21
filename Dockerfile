# syntax=docker/dockerfile:1

FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/homebridge-uxc"

ENV NODE_ENV=production \
    HOMEBRIDGE_CONFIG_UI=1 \
    HOMEBRIDGE_CONFIG_UI_VERSION=latest \
    HOMEBRIDGE_STORAGE_PATH=/var/lib/homebridge \
    HOMEBRIDGE_PLUGIN_PATH=/var/lib/homebridge/node_modules \
    NPM_CONFIG_PREFIX=/usr/local \
    NPM_CONFIG_CACHE=/tmp/.npm \
    npm_config_prefix=/usr/local \
    npm_config_cache=/tmp/.npm \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    npm_config_loglevel=warn \
    HOME=/var/lib/homebridge

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Persistent Homebridge directories
#
# /opt/homebridge
#   Immutable application installation inside the UXC rootfs.
#
# /var/lib/homebridge
#   Persistent runtime/config/plugin storage.
# ---------------------------------------------------------------------------

RUN set -eux; \
    mkdir -p \
        /opt/homebridge \
        /var/lib/homebridge \
        /var/lib/homebridge/node_modules \
        /var/lib/homebridge/accessories \
        /var/lib/homebridge/persist \
        /var/lib/homebridge/log \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp; \
    chmod 1777 \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp; \
    chmod 0755 \
        /opt/homebridge \
        /var/lib/homebridge \
        /var/lib/homebridge/node_modules

# ---------------------------------------------------------------------------
# Keep the official Node installation completely intact in /usr/local
# ---------------------------------------------------------------------------

RUN set -eux; \
    node --version; \
    npm --version; \
    npm config set prefix /usr/local; \
    npm config set cache /tmp/.npm

# ---------------------------------------------------------------------------
# Install Homebridge into /opt/homebridge
# ---------------------------------------------------------------------------

RUN set -eux; \
    cd /opt/homebridge; \
    printf '{\n  "private": true\n}\n' > package.json; \
    if [ "${HOMEBRIDGE_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge; \
    else \
        npm install --omit=dev "homebridge@${HOMEBRIDGE_VERSION}"; \
    fi

# ---------------------------------------------------------------------------
# Install Homebridge Config UI X into the same application tree
# ---------------------------------------------------------------------------

RUN set -eux; \
    cd /opt/homebridge; \
    if [ "${CONFIG_UI_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge-config-ui-x; \
    else \
        npm install --omit=dev "homebridge-config-ui-x@${CONFIG_UI_VERSION}"; \
    fi

# ---------------------------------------------------------------------------
# Verify the application installation
# ---------------------------------------------------------------------------

RUN set -eux; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x; \
    test -f /opt/homebridge/node_modules/homebridge/package.json; \
    test -f /opt/homebridge/node_modules/homebridge-config-ui-x/package.json; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    HB_VER="$$(node -p "require('/opt/homebridge/node_modules/homebridge/package.json').version")"; \
    UI_VER="$$(node -p "require('/opt/homebridge/node_modules/homebridge-config-ui-x/package.json').version")"; \
    NODE_VER="$$(node --version)"; \
    NPM_VER="$$(npm --version)"; \
    printf '%s\n' \
        "Node: $${NODE_VER}" \
        "npm: $${NPM_VER}" \
        "Homebridge: $${HB_VER}" \
        "Config UI X: $${UI_VER}"

# ---------------------------------------------------------------------------
# Installation manifest
# ---------------------------------------------------------------------------

RUN set -eux; \
    HB_VER="$$(node -p "require('/opt/homebridge/node_modules/homebridge/package.json').version")"; \
    UI_VER="$$(node -p "require('/opt/homebridge/node_modules/homebridge-config-ui-x/package.json').version")"; \
    NODE_VER="$$(node --version)"; \
    NPM_VER="$$(npm --version)"; \
    cat > /opt/homebridge/Docker.manifest <<EOF
{
  "node": "${NODE_VER}",
  "npm": "${NPM_VER}",
  "homebridge": "${HB_VER}",
  "configUiX": "${UI_VER}",
  "applicationPath": "/opt/homebridge",
  "storagePath": "/var/lib/homebridge",
  "pluginPath": "/var/lib/homebridge/node_modules"
}
EOF

# ---------------------------------------------------------------------------
# UXC bootstrap
#
# Creates the persistent Homebridge directory structure and compatibility
# configuration every time the container starts.
# ---------------------------------------------------------------------------

RUN cat > /usr/local/bin/homebridge-uxc-bootstrap <<'EOF'
#!/bin/sh
set -eu

STORAGE="/var/lib/homebridge"
PLUGIN_DIR="${STORAGE}/node_modules"

mkdir -p \
    "${STORAGE}" \
    "${PLUGIN_DIR}" \
    "${STORAGE}/accessories" \
    "${STORAGE}/persist" \
    "${STORAGE}/log"

chmod 0755 "${STORAGE}" "${PLUGIN_DIR}"

# -------------------------------------------------------------------------
# npm configuration
#
# Plugins installed from Config UI X must live in persistent storage.
# -------------------------------------------------------------------------

npm config set prefix /usr/local
npm config set cache /tmp/.npm

# Keep npm from attempting to use /root or another non-persistent location.
export HOME="${STORAGE}"

# -------------------------------------------------------------------------
# Homebridge plugin search path
# -------------------------------------------------------------------------

export HOMEBRIDGE_PLUGIN_PATH="${PLUGIN_DIR}"

# -------------------------------------------------------------------------
# Create a local npm configuration for the persistent plugin tree.
# -------------------------------------------------------------------------

if [ ! -f "${STORAGE}/.npmrc" ]; then
    cat > "${STORAGE}/.npmrc" <<'NPMRC'
prefix=/usr/local
cache=/tmp/.npm
NPMRC
fi

# -------------------------------------------------------------------------
# Make sure the plugin directory exists before Config UI X starts.
# -------------------------------------------------------------------------

mkdir -p "${PLUGIN_DIR}"

exit 0
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-bootstrap

# ---------------------------------------------------------------------------
# Homebridge runtime wrapper
#
# IMPORTANT:
# Do NOT use /usr/local/bin/hb-service.
#
# Homebridge itself is installed in /opt/homebridge and is launched directly.
# ---------------------------------------------------------------------------

RUN cat > /usr/local/bin/homebridge-uxc-run <<'EOF'
#!/bin/sh
set -eu

APP="/opt/homebridge"
STORAGE="/var/lib/homebridge"
PLUGIN_DIR="${STORAGE}/node_modules"

export HOME="${STORAGE}"
export NODE_ENV=production

export HOMEBRIDGE_STORAGE_PATH="${STORAGE}"
export HOMEBRIDGE_PLUGIN_PATH="${PLUGIN_DIR}"

# Node/npm remain the official installation from node:24-alpine.
export PATH="/usr/local/bin:${PATH}"

# Initialise persistent storage.
/usr/local/bin/homebridge-uxc-bootstrap

# -------------------------------------------------------------------------
# Homebridge executable
# -------------------------------------------------------------------------

HOMEBRIDGE_BIN="${APP}/node_modules/homebridge/bin/homebridge"

if [ ! -x "${HOMEBRIDGE_BIN}" ]; then
    echo "ERROR: Homebridge executable not found:"
    echo "       ${HOMEBRIDGE_BIN}"
    exit 1
fi

# -------------------------------------------------------------------------
# Configuration directory
# -------------------------------------------------------------------------

CONFIG_ARGS="-U ${STORAGE}"

# -------------------------------------------------------------------------
# Execute Homebridge directly.
#
# Do not invoke hb-service because UXC is not a normal systemd environment
# and hb-service is unnecessary for running Homebridge itself.
# -------------------------------------------------------------------------

exec /usr/local/bin/node \
    "${HOMEBRIDGE_BIN}" \
    -U "${STORAGE}"
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-run

# ---------------------------------------------------------------------------
# Compatibility symlink
#
# Some Homebridge tooling expects the application directory to be discoverable
# through /usr/local/lib/node_modules. Do NOT copy Node or Homebridge there.
# ---------------------------------------------------------------------------

RUN set -eux; \
    mkdir -p /usr/local/lib/node_modules; \
    ln -sfn /opt/homebridge/node_modules/homebridge \
        /usr/local/lib/node_modules/homebridge; \
    ln -sfn /opt/homebridge/node_modules/homebridge-config-ui-x \
        /usr/local/lib/node_modules/homebridge-config-ui-x

# ---------------------------------------------------------------------------
# Final image validation
# ---------------------------------------------------------------------------

RUN set -eux; \
    /usr/local/bin/node --version; \
    /usr/local/bin/npm --version; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/homebridge-uxc-bootstrap; \
    test -x /usr/local/bin/homebridge-uxc-run; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x; \
    test -x /opt/homebridge/node_modules/homebridge/bin/homebridge; \
    test -d /var/lib/homebridge/node_modules

# ---------------------------------------------------------------------------
# Runtime defaults
# ---------------------------------------------------------------------------

WORKDIR /var/lib/homebridge

ENTRYPOINT ["/sbin/tini", "-g", "--"]

CMD ["/usr/local/bin/homebridge-uxc-run"]