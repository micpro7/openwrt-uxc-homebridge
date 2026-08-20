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
    gzip \
    file \
    tzdata \
    ca-certificates \
    avahi \
    avahi-compat-libdns_sd \
    dbus \
    libstdc++ \
    libc6-compat \
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
# Writable npm runtime directories (symlink /root/.npm to /tmp)
# ==========================================================
RUN mkdir -p \
    /tmp/.npm \
    /tmp/.config \
    /tmp/.node-gyp \
 && rm -rf /root/.npm /root/.config \
 && ln -s /tmp/.npm /root/.npm \
 && ln -s /tmp/.config /root/.config

# ==========================================================
# Global Node/npm environment & Known-Working Configs
# ==========================================================
ENV NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/usr/local/lib/node_modules \
    npm_config_unsafe_perm=true \
    PYTHON=/usr/bin/python3 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin

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
 && ln -sf /var/lib/homebridge/node_modules /var/lib/homebridge/plugins

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

CMD ["/bin/sh", "-c", "while true; do /usr/local/bin/hb-service run --allow-root -U /var/lib/homebridge; RC=$?; echo \"$(date) Homebridge exited with code ${RC} - restarting in 3s\"; sleep 3; done"]
