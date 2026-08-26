# syntax=docker/dockerfile:1

FROM debian:trixie-slim

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

LABEL org.opencontainers.image.title="openwrt-uxc-homebridge" \
      org.opencontainers.image.description="Homebridge deployment for OpenWrt using native UXC containers" \
      org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"

# ==========================================================
# System dependencies
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
        | awk -v arch="linux-${NODE_ARCH}" '$1 ~ /^v24\./ && $0 ~ arch { print $1; exit }' \
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
# UXC FIX: Replace sudo with option-stripping wrapper
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
# NPM configuration
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/usr/local/lib/node_modules \
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
# Persistent Homebridge directory structure
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
# UXC Runtime Entrypoint
# ==========================================================
RUN cat > /usr/local/bin/entrypoint.sh <<'EOF'
#!/bin/sh

set -u

mkdir -p \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/tmp \
    /var/lib/homebridge/tmp/.npm \
    /var/lib/homebridge/tmp/.config \
    /var/lib/homebridge/tmp/.node-gyp

child_pid=""

term_handler() {
    if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi

    exit 143
}

trap term_handler TERM INT

while true; do
    /usr/local/bin/hb-service run \
        --allow-root \
        -U /var/lib/homebridge &

    child_pid=$!

    wait "$child_pid"
    RC=$?

    child_pid=""

    echo "$(date) Homebridge exited with code ${RC} - restarting in 3s"

    sleep 3
done
EOF

RUN chmod 0755 /usr/local/bin/entrypoint.sh

# ==========================================================
# HARD VALIDATION
# ==========================================================
RUN set -eux; \
    test -f /etc/os-release; \
    grep -q "Debian" /etc/os-release; \
    grep -q "trixie" /etc/os-release; \
    \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/homebridge; \
    test -x /usr/local/bin/hb-service; \
    test -x /usr/local/bin/entrypoint.sh; \
    \
    test -x /usr/bin/tini; \
    test -x /usr/bin/python3; \
    test -x /usr/bin/bash; \
    test -x /usr/bin/sudo; \
    \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    \
    node --version; \
    npm --version; \
    \
    node -e "console.log('Homebridge OK:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"

# ==========================================================
# Runtime Environment
# ==========================================================
ENV HOME=/root \
    TZ=Europe/London \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/var/lib/homebridge/tmp/.npm \
    NPM_CONFIG_DEVDIR=/var/lib/homebridge/tmp/.node-gyp \
    XDG_CONFIG_HOME=/var/lib/homebridge/tmp/.config

WORKDIR /root

EXPOSE 8581

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]

CMD ["/usr/local/bin/entrypoint.sh"]