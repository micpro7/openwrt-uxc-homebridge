# ==============================================================================
# ⚡ HOMEBRIDGE UXC ALPINE CONTAINER
#    Based on the architecture of the official Homebridge Docker image
#    Adapted for OpenWrt UXC / ARM64
# ==============================================================================
#
# Base:
#   Official Node.js 24 Alpine
#
# Runtime:
#   Node.js 24
#   Homebridge
#   Homebridge Config UI X
#   Alpine FFmpeg
#
# Persistent:
#   /var/lib/homebridge
#
# Immutable application:
#   /usr/local
#
# IMPORTANT:
#   - Does NOT install ffmpeg-for-homebridge
#   - Uses Alpine's normal /usr/bin/ffmpeg
#   - Does NOT use s6-overlay
#   - Does NOT use the Homebridge Debian package
#
# ==============================================================================

# ==============================================================================
# BASE IMAGE
# ==============================================================================

FROM node:24-alpine

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

# ==============================================================================
# IMAGE METADATA
# ==============================================================================

LABEL org.opencontainers.image.title="Homebridge UXC Alpine"
LABEL org.opencontainers.image.description="Homebridge for OpenWrt UXC using Node.js 24 Alpine"
LABEL org.opencontainers.image.source="https://github.com/micpro7/openwrt-uxc-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# ==============================================================================
# STAGE 1: SYSTEM RUNTIME + NATIVE NPM BUILD DEPENDENCIES
# ==============================================================================

RUN echo "========================================================" \
 && echo " 🔄 [Stage 1] Installing Alpine Runtime Dependencies" \
 && echo "========================================================"

RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    avahi-compat-libdns_sd \
    libstdc++ \
    libc6-compat \
    curl \
    ffmpeg \
    python3 \
    build-base \
    git \
    linux-headers \
    sudo \
    bash \
    openssh-client \
    tini

# ------------------------------------------------------------------------------
# Verify critical runtime components
# ------------------------------------------------------------------------------

RUN set -eux; \
    command -v node; \
    command -v npm; \
    command -v ffmpeg; \
    command -v tini; \
    node --version; \
    npm --version; \
    ffmpeg -version | head -n 1; \
    test -x /usr/bin/ffmpeg; \
    test -x /sbin/tini

RUN echo "✅ Alpine runtime and FFmpeg verified."

# ==============================================================================
# STAGE 2: ENVIRONMENT
# ==============================================================================

RUN echo "========================================================" \
 && echo " 📝 [Stage 2] Configuring Runtime Environment" \
 && echo "========================================================"

ENV USER=root \
    HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/usr/local/lib/node_modules \
    NPM_CONFIG_CACHE=/tmp/.npm \
    NPM_CONFIG_DEVDIR=/tmp/.node-gyp \
    XDG_CONFIG_HOME=/tmp/.config \
    UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules \
    PATH=/usr/local/bin:/usr/local/sbin:/var/lib/homebridge/node_modules/.bin:/usr/bin:/usr/sbin:/sbin:/bin

# ------------------------------------------------------------------------------
# NPM configuration
# ------------------------------------------------------------------------------

RUN npm config set prefix /usr/local && \
    npm config set cache /tmp/.npm && \
    npm config set update-notifier false && \
    npm config set fund false && \
    npm config set audit false

# ------------------------------------------------------------------------------
# Runtime writable locations
# ------------------------------------------------------------------------------

RUN mkdir -p \
    /tmp/.npm \
    /tmp/.config \
    /tmp/.node-gyp \
    /var/lib/homebridge \
    /var/lib/homebridge/node_modules \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/persist

# ------------------------------------------------------------------------------
# Redirect root's npm/config directories to tmpfs-backed locations.
#
# /tmp is mounted as tmpfs by the UXC OCI configuration.
# ------------------------------------------------------------------------------

RUN rm -rf /root/.npm /root/.config && \
    ln -s /tmp/.npm /root/.npm && \
    ln -s /tmp/.config /root/.config

RUN echo "✅ Runtime environment configured."

# ==============================================================================
# STAGE 3: UXC SUDO COMPATIBILITY
# ==============================================================================

RUN echo "========================================================" \
 && echo " 🛡️ [Stage 3] Installing UXC-Compatible sudo Wrapper" \
 && echo "========================================================"

# ------------------------------------------------------------------------------
# UXC does not provide the setresuid/setresgid behaviour expected by normal sudo.
#
# Homebridge/plugin installers can still invoke sudo, so provide a root-only
# compatibility wrapper that strips sudo options and executes the command.
# ------------------------------------------------------------------------------

RUN rm -f /usr/bin/sudo && \
    printf '%s\n' \
'#!/bin/sh' \
'' \
'while [ $# -gt 0 ]; do' \
'    case "$1" in' \
'        -n|-E|-H|-S|-k|-K|-b|-v)' \
'            shift' \
'            ;;' \
'        -u|-g|-C)' \
'            shift 2' \
'            ;;' \
'        --)' \
'            shift' \
'            break' \
'            ;;' \
'        -*)' \
'            shift' \
'            ;;' \
'        *)' \
'            break' \
'            ;;' \
'    esac' \
'done' \
'' \
'if [ $# -eq 0 ]; then' \
'    echo "sudo: no command specified" >&2' \
'    exit 1' \
'fi' \
'' \
'exec "$@"' \
    > /usr/bin/sudo && \
    chmod 0755 /usr/bin/sudo

RUN /usr/bin/sudo true

RUN echo "✅ UXC sudo compatibility layer verified."

# ==============================================================================
# STAGE 4: HOMEBRIDGE INSTALLATION
# ==============================================================================

RUN echo "========================================================" \
 && echo " 📥 [Stage 4] Installing Homebridge" \
 && echo "========================================================"

RUN echo "[i] Homebridge version: ${HOMEBRIDGE_VERSION}" \
 && echo "[i] Config UI X version: ${CONFIG_UI_VERSION}"

# ------------------------------------------------------------------------------
# Install Homebridge and Config UI X into immutable /usr/local.
#
# This is the Alpine equivalent of the official image's /opt/homebridge
# application installation.
# ------------------------------------------------------------------------------

RUN npm install -g --unsafe-perm \
    homebridge@${HOMEBRIDGE_VERSION} \
    homebridge-config-ui-x@${CONFIG_UI_VERSION}

# ==============================================================================
# STAGE 5: HOMEBRIDGE INSTALLATION VALIDATION
# ==============================================================================

RUN echo "========================================================" \
 && echo " 🔍 [Stage 5] Validating Homebridge Installation" \
 && echo "========================================================"

RUN set -eux; \
    command -v node; \
    command -v npm; \
    command -v homebridge; \
    command -v hb-service; \
    test -x /usr/local/bin/node; \
    test -x /usr/local/bin/npm; \
    test -x /usr/local/bin/homebridge; \
    test -x /usr/local/bin/hb-service; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    node -e "console.log('Node.js:', process.version)"; \
    node -e "console.log('Homebridge:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"; \
    node -e "console.log('Config UI X:', require('/usr/local/lib/node_modules/homebridge-config-ui-x/package.json').version)"

RUN echo "✅ Homebridge installation verified."

# ==============================================================================
# STAGE 6: FFmpeg RUNTIME CONTRACT
# ==============================================================================

RUN echo "========================================================" \
 && echo " 🎥 [Stage 6] Validating System FFmpeg" \
 && echo "========================================================"

# ------------------------------------------------------------------------------
# IMPORTANT:
#
# We deliberately use Alpine's normal FFmpeg.
#
# We do NOT install:
#
#   ffmpeg-for-homebridge
#
# Plugins discover FFmpeg through PATH:
#
#   /usr/bin/ffmpeg
# ------------------------------------------------------------------------------

RUN set -eux; \
    test -x /usr/bin/ffmpeg; \
    /usr/bin/ffmpeg -version | head -n 1; \
    /usr/bin/ffmpeg -hide_banner -filters >/dev/null

RUN echo "✅ System FFmpeg available at /usr/bin/ffmpeg."

# ==============================================================================
# STAGE 7: PERSISTENT HOMEBRIDGE STORAGE
# ==============================================================================

RUN echo "========================================================" \
 && echo " 📂 [Stage 7] Preparing Persistent Homebridge Storage" \
 && echo "========================================================"

RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/node_modules \
    /var/lib/homebridge/accessories \
    /var/lib/homebridge/persist

RUN set -eux; \
    test -d /var/lib/homebridge; \
    test -d /var/lib/homebridge/node_modules; \
    test -d /var/lib/homebridge/accessories; \
    test -d /var/lib/homebridge/persist

RUN echo "✅ Persistent Homebridge directory tree prepared."

# ==============================================================================
# STAGE 8: WORKING DIRECTORY
# ==============================================================================

WORKDIR /var/lib/homebridge

# ==============================================================================
# STAGE 9: CONTAINER ENTRYPOINT
# ==============================================================================

# Tini provides:
#
#   PID 1
#   signal forwarding
#   zombie reaping
#
# UXC supplies the actual container namespace/runtime.
#
ENTRYPOINT ["/sbin/tini", "-g", "--"]

# ==============================================================================
# STAGE 10: HOMEBRIDGE RUNTIME
# ==============================================================================

# ------------------------------------------------------------------------------
# Homebridge runs entirely from the immutable application installation while:
#
#   config.json
#   accessories
#   persistent data
#   plugins
#
# live under /var/lib/homebridge.
#
# The -P option explicitly points Homebridge at the persistent plugin directory.
#
# No ffmpeg-for-homebridge bootstrap is performed.
# ------------------------------------------------------------------------------

CMD ["/bin/sh", "-c", "\
while true; do \
    echo \"$(date) 🚀 Starting Homebridge...\"; \
    /usr/local/bin/hb-service run \
        --allow-root \
        -U /var/lib/homebridge \
        -P /var/lib/homebridge/node_modules; \
    EXIT_CODE=$?; \
    echo \"$(date) ⚠️ Homebridge exited with code ${EXIT_CODE}; restarting in 3s...\"; \
    sleep 3; \
done"]

# ==============================================================================
# BUILD COMPLETE
# ==============================================================================

RUN echo "========================================================" \
 && echo " 🎉 Homebridge UXC Alpine image prepared successfully" \
 && echo "========================================================"