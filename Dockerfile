# syntax=docker/dockerfile:1

FROM debian:trixie-slim

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ==========================================================
# System dependencies & Tini PID 1 Engine
# ==========================================================
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    tzdata \
    python3 \
    make \
    g++ \
    git \
    sudo \
    bash \
    tini \
 && rm -rf /var/lib/apt/lists/*

# ==========================================================
# Install latest Node.js 24.x
# Official Node.js ARM64 glibc build
# ==========================================================
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
        aarch64) NODE_ARCH="arm64" ;; \
        x86_64)  NODE_ARCH="x64" ;; \
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    \
    NODE_VERSION="$( \
        curl -fsSL https://nodejs.org/dist/index.tab \
        | awk -v arch="linux-${NODE_ARCH}" \
          '$1 ~ /^v24\./ && $0 ~ arch { print $1; exit }' \
    )"; \
    \
    test -n "$NODE_VERSION"; \
    \
    TARBALL="node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
    BASE_URL="https://nodejs.org/dist/${NODE_VERSION}"; \
    \
    curl -fsSL "${BASE_URL}/${TARBALL}" \
        -o "/tmp/${TARBALL}"; \
    \
    curl -fsSL "${BASE_URL}/SHASUMS256.txt" \
        -o /tmp/SHASUMS256.txt; \
    \
    cd /tmp; \
    grep " ${TARBALL}\$" SHASUMS256.txt | sha256sum -c -; \
    \
    tar -xJf "/tmp/${TARBALL}" \
        --strip-components=1 \
        -C /usr/local; \
    \
    rm -f \
        "/tmp/${TARBALL}" \
        /tmp/SHASUMS256.txt

# ==========================================================
# UXC FIX
# Replace sudo with an option-stripping wrapper.
#
# UXC does not provide the setresuid/setresgid behaviour
# expected by normal sudo. Homebridge plugins may still
# invoke sudo, so provide a compatible direct-exec wrapper.
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
# NPM / Node global paths
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/usr/local/lib/node_modules \
    npm_config_unsafe_perm=true \
    npm_config_update_notifier=false \
    npm_config_audit=false \
    npm_config_fund=false \
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
# Persistent Homebridge directory structure
#
# These directories are recreated at runtime as
# /var/lib/homebridge is replaced by the UXC bind mount.
# ==========================================================
RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/tmp \
    /var/lib/homebridge/tmp/.npm \
    /var/lib/homebridge/tmp/.config \
    /var/lib/homebridge/tmp/.node-gyp

# ==========================================================
# Homebridge UXC runtime entrypoint
#
# Tini is PID 1.
# This script is PID 2 and owns the Homebridge process.
# If Homebridge exits, it is restarted automatically.
# ==========================================================
RUN cat > /usr/local/bin/homebridge-entrypoint.sh <<'EOF'
#!/bin/sh

set -u

# ==========================================================
# Runtime directory initialisation
# ==========================================================
mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/tmp \
    /var/lib/homebridge/tmp/.npm \
    /var/lib/homebridge/tmp/.node-gyp \
    /var/lib/homebridge/tmp/.config

echo "========================================================"
echo " HOMEbridge UXC runtime"
echo "========================================================"
echo "Node:       $(node --version)"
echo "Homebridge: $(node -e "console.log(require('/usr/local/lib/node_modules/homebridge/package.json').version)")"
echo "UID:        $(id -u)"
echo "GID:        $(id -g)"
echo "Workdir:    $(pwd)"
echo "========================================================"

# ==========================================================
# Homebridge restart supervisor
# ==========================================================
while true; do

    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting Homebridge..."

    /usr/local/bin/hb-service run \
        --allow-root \
        -U /var/lib/homebridge

    RC=$?

    echo "$(date '+%Y-%m-%d %H:%M:%S') Homebridge exited with code ${RC}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Restarting Homebridge in 3 seconds..."

    sleep 3

done
EOF

RUN chmod 0755 /usr/local/bin/homebridge-entrypoint.sh

# ==========================================================
# HARD VALIDATION
# ==========================================================
RUN set -eux; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    command -v node; \
    command -v npm; \
    command -v homebridge; \
    command -v hb-service; \
    command -v tini; \
    command -v python3; \
    command -v bash; \
    node --version; \
    npm --version; \
    node -e "console.log('Homebridge OK:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"; \
    test -x /usr/local/bin/homebridge-entrypoint.sh

# ==========================================================
# Runtime Environment
# ==========================================================
ENV HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/var/lib/homebridge/tmp/.npm \
    NPM_CONFIG_DEVDIR=/var/lib/homebridge/tmp/.node-gyp \
    XDG_CONFIG_HOME=/var/lib/homebridge/tmp/.config \
    TMPDIR=/var/lib/homebridge/tmp \
    TEMP=/var/lib/homebridge/tmp \
    TMP=/var/lib/homebridge/tmp

WORKDIR /var/lib/homebridge

EXPOSE 8581

# ==========================================================
# Docker runtime default
#
# UXC uses config.json instead, but keeping this correct
# makes the image independently runnable as well.
# ==========================================================
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]

CMD ["/usr/local/bin/homebridge-entrypoint.sh"]