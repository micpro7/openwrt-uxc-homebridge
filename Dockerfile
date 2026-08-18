# syntax=docker/dockerfile:1

# Official Node.js 24 LTS Alpine image
FROM node:24-alpine

ARG TARGETARCH
ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ==========================================================
# System dependencies & Tini PID 1 Engine
# (Retains build tools for runtime native plugin compilation)
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
    sudo \
    bash \
    tini

# ==========================================================
# Install latest Node.js 24.x (musl build for Alpine)
# ==========================================================
RUN set -eux; \
    case "${TARGETARCH}" in \
        arm64) NODE_ARCH="arm64"; EXPECTED_NODE_ARCH="arm64" ;; \
        amd64) NODE_ARCH="x64"; EXPECTED_NODE_ARCH="x64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    NODE_VERSION="$( \
        curl -fsSL https://unofficial-builds.nodejs.org/download/release/index.tab \
        | awk -v arch="linux-${NODE_ARCH}-musl" '$1 ~ /^v24\./ && $0 ~ arch { print $1; exit }' \
    )"; \
    if [ -z "$NODE_VERSION" ]; then \
        echo "Error: Failed to resolve Node.js version." >&2; \
        exit 1; \
    fi; \
    case "$NODE_VERSION" in \
        v24.*) ;; \
        *) echo "Invalid Node.js version: $NODE_VERSION" >&2; exit 1 ;; \
    esac; \
    echo "Resolved Node.js Version: ${NODE_VERSION}"; \
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
    # Explicitly clean inherited base image Node binaries and modules \
    rm -rf \
        /usr/local/bin/node \
        /usr/local/bin/nodejs \
        /usr/local/bin/npm \
        /usr/local/bin/npx \
        /usr/local/include/node \
        /usr/local/lib/node_modules/npm \
        /usr/local/lib/node_modules/corepack; \
    \
    # Extract custom musl build to /usr/local & clean up \
    tar -xJ -f "/tmp/${TARBALL}" --strip-components=1 -C /usr/local; \
    rm -f "/tmp/${TARBALL}" /tmp/SHASUMS256.txt; \
    \
    # Recreate conventional nodejs symlink \
    ln -sf /usr/local/bin/node /usr/local/bin/nodejs; \
    \
    # Strict architecture assertion \
    ACTUAL_ARCH="$(node -p 'process.arch')"; \
    if [ "$ACTUAL_ARCH" != "$EXPECTED_NODE_ARCH" ]; then \
        echo "Architecture mismatch! Expected $EXPECTED_NODE_ARCH, got $ACTUAL_ARCH" >&2; \
        exit 1; \
    fi; \
    \
    # Strict Node.js major-version assertion \
    ACTUAL_NODE_VERSION="$(node -p 'process.versions.node')"; \
    case "$ACTUAL_NODE_VERSION" in \
        24.*) ;; \
        *) echo "Node.js version mismatch! Expected 24.x, got $ACTUAL_NODE_VERSION" >&2; exit 1 ;; \
    esac; \
    \
    node --version; \
    npm --version

# ==========================================================
# Avahi & DBus run directory setup
# ==========================================================
RUN mkdir -p /var/run/dbus /var/run/avahi-daemon \
 && chown -R root:root /var/run/dbus /var/run/avahi-daemon

# ==========================================================
# UXC FIX: sudo compatibility shim
#
# UXC blocks the privilege-changing syscalls used by real sudo.
# This wrapper intentionally executes commands with the
# container's existing UID/GID and does NOT perform privilege
# changes. This is appropriate because Homebridge runs as root.
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
            echo "sudo wrapper: unsupported option $1" >&2
            exit 1
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
# READ-ONLY / OVERLAY ROOTFS FIX: Setup /tmp transient dirs
# ==========================================================
RUN mkdir -p /tmp/.npm /tmp/.config /tmp/.node-gyp

# ==========================================================
# CRITICAL CONFIG: Deterministic npm prefix and clean environment
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    PYTHON=/usr/bin/python3 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin

RUN npm config set update-notifier false \
 && npm config set audit false \
 && npm config set fund false

# ==========================================================
# Install Homebridge stack globally
# ==========================================================
RUN npm install -g --unsafe-perm \
    homebridge@${HOMEBRIDGE_VERSION} \
    homebridge-config-ui-x@${CONFIG_UI_VERSION} \
 && npm cache clean --force

# ==========================================================
# Persistent mount points for host flash media
# ==========================================================
RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/node_modules \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories

# ==========================================================
# HARD VALIDATION (fail fast with enhanced diagnostics)
# ==========================================================
RUN set -eux; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    command -v homebridge; \
    command -v hb-service; \
    node --version; \
    npm --version; \
    node -p "process.execPath"; \
    npm prefix -g; \
    npm root -g; \
    npm config get prefix; \
    node -p "process.versions.modules"; \
    node -p "process.platform + '/' + process.arch"; \
    readlink -f "$(command -v node)"; \
    readlink -f "$(command -v npm)"; \
    node -e "console.log('Homebridge OK:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"; \
    node -e "console.log('UI OK:', require('/usr/local/lib/node_modules/homebridge-config-ui-x/package.json').version)"

# ==========================================================
# Runtime Environment & Container Launch
# ==========================================================
ENV HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/tmp/.npm \
    NPM_CONFIG_DEVDIR=/tmp/.node-gyp \
    XDG_CONFIG_HOME=/tmp/.config

WORKDIR /var/lib/homebridge

EXPOSE 8581

ENTRYPOINT ["/sbin/tini", "-g", "--"]

CMD ["/bin/sh", "-c", "while true; do /usr/local/bin/hb-service run --allow-root -U /var/lib/homebridge -P /var/lib/homebridge/node_modules; echo \"$(date) Homebridge crashed - restarting in 3s\"; sleep 3; done"]
