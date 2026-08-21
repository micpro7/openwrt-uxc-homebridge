# syntax=docker/dockerfile:1

# ==========================================================
# Homebridge UXC - Alpine
#
# Architecture:
#
# /usr/local
#   ├── Node.js
#   ├── npm
#   └── supporting Node runtime
#
# /var/lib/homebridge
#   ├── Homebridge
#   ├── Config UI X
#   ├── user plugins
#   ├── config.json
#   ├── persist/
#   └── accessories/
#
# The entire /var/lib/homebridge directory is persistent.
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

ENV NODE_ENV=production \
    HOME=/var/lib/homebridge \
    TZ=Europe/London \
    USER=root \
    NPM_CONFIG_PREFIX=/usr/local \
    npm_config_prefix=/usr/local \
    NPM_CONFIG_CACHE=/tmp/.npm \
    npm_config_update_notifier=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_DEVDIR=/tmp/.node-gyp \
    XDG_CONFIG_HOME=/tmp/.config \
    NODE_PATH=/var/lib/homebridge/node_modules:/usr/local/lib/node_modules \
    UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules \
    UIX_CONFIG_PATH=/var/lib/homebridge/config.json \
    UIX_STORAGE_PATH=/var/lib/homebridge \
    UIX_STRICT_PLUGIN_RESOLUTION=1 \
    HOMEBRIDGE_CONFIG_UI=1 \
    HOMEBRIDGE_CONFIG_UI_TERMINAL=1 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# ==========================================================
# Alpine packages
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

# ==========================================================
# Temporary / persistent directories
# ==========================================================

RUN set -eux; \
    mkdir -p \
        /var/lib/homebridge \
        /var/lib/homebridge/node_modules \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp; \
    chmod 1777 \
        /tmp/.npm \
        /tmp/.config \
        /tmp/.node-gyp

# ==========================================================
# Verify Node.js / npm
# ==========================================================

RUN set -eux; \
    node --version; \
    npm --version; \
    npm config set prefix /usr/local; \
    npm config set cache /tmp/.npm

# ==========================================================
# Install Homebridge into a temporary image location
#
# We DON'T install directly into /var/lib/homebridge here
# because UXC mounts the persistent SSD over that directory.
# ==========================================================

RUN set -eux; \
    mkdir -p /opt/homebridge/node_modules; \
    cd /opt/homebridge; \
    printf '{\n  "private": true\n}\n' > package.json; \
    if [ "${HOMEBRIDGE_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge; \
    else \
        npm install --omit=dev "homebridge@${HOMEBRIDGE_VERSION}"; \
    fi

# ==========================================================
# Install Config UI X into the same npm tree
# ==========================================================

RUN set -eux; \
    cd /opt/homebridge; \
    if [ "${CONFIG_UI_VERSION}" = "latest" ]; then \
        npm install --omit=dev homebridge-config-ui-x; \
    else \
        npm install --omit=dev "homebridge-config-ui-x@${CONFIG_UI_VERSION}"; \
    fi

# ==========================================================
# Verify temporary Homebridge installation
# ==========================================================

RUN set -eux; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x; \
    test -f /opt/homebridge/node_modules/homebridge/package.json; \
    test -f /opt/homebridge/node_modules/homebridge-config-ui-x/package.json

# ==========================================================
# Record installed versions
# ==========================================================

RUN set -eux; \
    HB_VER="$(node -p "require('/opt/homebridge/node_modules/homebridge/package.json').version")"; \
    UI_VER="$(node -p "require('/opt/homebridge/node_modules/homebridge-config-ui-x/package.json').version")"; \
    NODE_VER="$(node --version)"; \
    cat > /opt/homebridge/Docker.manifest <<EOF
Homebridge UXC Alpine

Node.js: ${NODE_VER}
Homebridge: ${HB_VER}
Homebridge Config UI X: ${UI_VER}
Homebridge path: /var/lib/homebridge/node_modules/homebridge
Config UI path: /var/lib/homebridge/node_modules/homebridge-config-ui-x
Plugin path: /var/lib/homebridge/node_modules
EOF

# ==========================================================
# Bootstrap script
#
# The UXC SSD bind mount hides /var/lib/homebridge from the
# image, so copy the bundled Homebridge installation there
# on first boot.
# ==========================================================

RUN cat > /usr/local/bin/homebridge-uxc-bootstrap <<'EOF'
#!/bin/sh
set -eu

SOURCE="/opt/homebridge/node_modules"
TARGET="/var/lib/homebridge/node_modules"

echo "==> Homebridge UXC bootstrap"

mkdir -p "$TARGET"

# ----------------------------------------------------------
# Install Homebridge + Config UI X if they aren't already
# present on persistent storage.
# ----------------------------------------------------------

if [ ! -f "$TARGET/homebridge/package.json" ]; then
    echo "==> Installing bundled Homebridge into persistent storage..."

    cp -a "$SOURCE/homebridge" "$TARGET/"
fi

if [ ! -f "$TARGET/homebridge-config-ui-x/package.json" ]; then
    echo "==> Installing bundled Homebridge Config UI X..."

    cp -a "$SOURCE/homebridge-config-ui-x" "$TARGET/"
fi

# ----------------------------------------------------------
# Preserve the bundled npm metadata.
# ----------------------------------------------------------

if [ ! -f "/var/lib/homebridge/package.json" ]; then
    cp -a /opt/homebridge/package.json /var/lib/homebridge/package.json
fi

if [ -f "/opt/homebridge/package-lock.json" ] &&
   [ ! -f "/var/lib/homebridge/package-lock.json" ]; then
    cp -a /opt/homebridge/package-lock.json \
          /var/lib/homebridge/package-lock.json
fi

# ----------------------------------------------------------
# Ensure expected permissions.
# ----------------------------------------------------------

chown -R root:root "$TARGET"

chmod 0755 "$TARGET"

echo "==> Homebridge installation:"
node -e '
const fs = require("fs");

const hb = "/var/lib/homebridge/node_modules/homebridge/package.json";
const ui = "/var/lib/homebridge/node_modules/homebridge-config-ui-x/package.json";

console.log("Homebridge:", JSON.parse(fs.readFileSync(hb)).version);
console.log("Config UI X:", JSON.parse(fs.readFileSync(ui)).version);
console.log("Plugin path:", process.env.UIX_CUSTOM_PLUGIN_PATH);
'

echo "==> Bootstrap complete"
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-bootstrap

# ==========================================================
# Runtime launcher
# ==========================================================

RUN cat > /usr/local/bin/homebridge-uxc-run <<'EOF'
#!/bin/sh
set -eu

export HOME=/var/lib/homebridge
export UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules
export UIX_CONFIG_PATH=/var/lib/homebridge/config.json
export UIX_STORAGE_PATH=/var/lib/homebridge
export UIX_STRICT_PLUGIN_RESOLUTION=1

export NODE_PATH=/var/lib/homebridge/node_modules:/usr/local/lib/node_modules

export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

/usr/local/bin/homebridge-uxc-bootstrap

echo "==> Starting Homebridge"
echo "    Node:        $(node --version)"
echo "    Homebridge:  $(node -p "require('/var/lib/homebridge/node_modules/homebridge/package.json').version")"
echo "    Config UI X: $(node -p "require('/var/lib/homebridge/node_modules/homebridge-config-ui-x/package.json').version")"
echo "    Plugins:     /var/lib/homebridge/node_modules"

exec /usr/local/bin/hb-service run \
    --allow-root \
    -U /var/lib/homebridge \
    -P /var/lib/homebridge/node_modules
EOF

RUN chmod 0755 /usr/local/bin/homebridge-uxc-run

# ==========================================================
# Final image verification
# ==========================================================

RUN set -eux; \
    /usr/local/bin/node --version; \
    /usr/local/bin/npm --version; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/hb-service; \
    test -d /opt/homebridge/node_modules/homebridge; \
    test -d /opt/homebridge/node_modules/homebridge-config-ui-x

# ==========================================================
# Working directory
# ==========================================================

WORKDIR /var/lib/homebridge

# ==========================================================
# UXC entrypoint
# ==========================================================

ENTRYPOINT ["/sbin/tini", "-g", "--"]

CMD ["/bin/sh", "-c", \
     "while true; do \
        /usr/local/bin/homebridge-uxc-run; \
        echo \"$(date) Homebridge crashed - restarting in 3s\"; \
        sleep 3; \
      done"]