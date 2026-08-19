# syntax=docker/dockerfile:1

FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ==========================================================
# System dependencies & Tini PID 1 Engine
# ==========================================================
RUN apk add --no-cache \
    curl \
    xz \
    tzdata \
    ca-certificates \
    avahi \
    avahi-compat-libdns_sd \
    dbus \
    libstdc++ \
    ffmpeg \
    python3 \
    make \
    g++ \
    git \
    linux-headers \
    sudo \
    bash \
    openssh-client \
    tini

# ==========================================================
# Install latest Node.js 24.x (musl build for Alpine)
# ==========================================================
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
        aarch64) NODE_ARCH="arm64" ;; \
        x86_64) NODE_ARCH="x64" ;; \
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    \
    NODE_VERSION="$( \
        curl -fsSL https://unofficial-builds.nodejs.org/download/release/index.tab \
        | awk -v arch="linux-${NODE_ARCH}-musl" '$1 ~ /^v24\./ && $0 ~ arch { print $1; exit }' \
    )"; \
    \
    TARBALL="node-${NODE_VERSION}-linux-${NODE_ARCH}-musl.tar.xz"; \
    BASE_URL="https://unofficial-builds.nodejs.org/download/release/${NODE_VERSION}"; \
    \
    curl -fsSL "${BASE_URL}/${TARBALL}" -o "/tmp/${TARBALL}"; \
    curl -fsSL "${BASE_URL}/SHASUMS256.txt" -o "/tmp/SHASUMS256.txt"; \
    \
    cd /tmp; \
    grep " ${TARBALL}\$" SHASUMS256.txt | sha256sum -c -; \
    \
    tar -xJ -f "/tmp/${TARBALL}" --strip-components=1 -C /usr/local; \
    rm -f "/tmp/${TARBALL}" /tmp/SHASUMS256.txt

# ==========================================================
# Avahi & DBus run directory setup
# ==========================================================
RUN mkdir -p /var/run/dbus /var/run/avahi-daemon \
 && chown -R root:root /var/run/dbus /var/run/avahi-daemon

# ==========================================================
# UXC FIX: Replace sudo binary with robust option-stripping wrapper
# ==========================================================
RUN rm -f /usr/bin/sudo \
 && cat > /usr/bin/sudo <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in
        -n|-E|-H|-S|-k|-K|-b|-v)
            shift
            ;;
        -u|-g|-C)
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "sudo: no command specified" >&2
    exit 1
fi

exec "$@"
EOF
RUN chmod 0755 /usr/bin/sudo

# ==========================================================
# NPM Config & Global Paths Target Integration
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/var/lib/homebridge/node_modules:/usr/local/lib/node_modules \
    npm_config_unsafe_perm=true \
    PYTHON=/usr/bin/python3 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

RUN npm config set prefix /usr/local \
 && npm config set update-notifier false \
 && npm config set audit false \
 && npm config set fund false \
 && npm cache verify

# ==========================================================
# Install Homebridge stack globally
# ==========================================================
RUN npm install -g --unsafe-perm \
    homebridge@${HOMEBRIDGE_VERSION} \
    homebridge-config-ui-x@${CONFIG_UI_VERSION} \
 && npm cache clean --force

# ==========================================================
# Persistent mount layout target setup (/var/lib/homebridge)
# ==========================================================
RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/node_modules \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/tmp/.npm \
    /var/lib/homebridge/tmp/.config \
    /var/lib/homebridge/tmp/.node-gyp

# ==========================================================
# HARD VALIDATION
# ==========================================================
RUN set -eux; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    command -v homebridge; \
    command -v hb-service; \
    node -e "console.log('Homebridge OK:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"

# ==========================================================
# Inline Entrypoint Script Generation
# ==========================================================
RUN cat > /usr/local/bin/entrypoint.sh <<'EOF'
#!/bin/sh

HOMEBRIDGE_DIR="/var/lib/homebridge"
LOCAL_HB_PKG="$HOMEBRIDGE_DIR/node_modules/homebridge"

mkdir -p "$HOMEBRIDGE_DIR/node_modules" \
         "$HOMEBRIDGE_DIR/persist" \
         "$HOMEBRIDGE_DIR/accessories" \
         "$HOMEBRIDGE_DIR/tmp/.npm" \
         "$HOMEBRIDGE_DIR/tmp/.config" \
         "$HOMEBRIDGE_DIR/tmp/.node-gyp"

if [ -f "$LOCAL_HB_PKG/package.json" ]; then
    if [ "$(node -p "require('$LOCAL_HB_PKG/package.json').name" 2>/dev/null)" = "homebridge" ]; then
        echo "==> Removing redundant local Homebridge package..."
        rm -rf "$LOCAL_HB_PKG"
    fi
fi

while true; do
    /usr/local/bin/hb-service run --allow-root -U "$HOMEBRIDGE_DIR" -P "$HOMEBRIDGE_DIR/node_modules"
    RC=$?
    echo "$(date) Homebridge exited with code ${RC} - restarting in 3s"
    sleep 3
done
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

# ==========================================================
# Runtime Environment & Container Launch
# ==========================================================
ENV HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/var/lib/homebridge/tmp/.npm \
    NPM_CONFIG_DEVDIR=/var/lib/homebridge/tmp/.node-gyp \
    XDG_CONFIG_HOME=/var/lib/homebridge/tmp/.config

WORKDIR /var/lib/homebridge

EXPOSE 8581

ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
