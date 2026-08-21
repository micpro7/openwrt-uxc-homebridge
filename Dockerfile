# ==============================================================================
# ⚡ HOMEBRIDGE UXC ALPINE CONTAINER BLUEPRINT FOR OPENWRT (ARM64) ⚡
# ==============================================================================
# Base Image: Official Node.js 24 Alpine Runtime Core
# Target Architecture: linux/arm64
# ==============================================================================
FROM node:24-alpine

# ==============================================================================
# STAGE 1: SYSTEM DEPENDENCY PROVISIONING & RUNTIME TOOLCHAIN
# ==============================================================================
RUN echo "========================================================" \
 && echo " 🔄 [Dockerfile Stage 1] Installing Alpine Packages..." \
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

# Validate system FFmpeg availability immediately
RUN set -eux; \
    command -v ffmpeg; \
    ffmpeg -version | head -n 1; \
    test -x /usr/bin/ffmpeg

RUN echo "✅ Comprehensive runtime toolchain and system FFmpeg verified."
RUN printf '\n\n\n'


# ==============================================================================
# STAGE 2: NPM ENVIRONMENT MATRICES & CACHE WORKAROUNDS
# ==============================================================================
RUN echo "========================================================" \
 && echo " 📝 [Dockerfile Stage 2] Configuring NPM & Cache Workarounds..." \
 && echo "========================================================"

# Define authoritative core Node and NPM execution variables
ENV NPM_CONFIG_PREFIX=/usr/local \
    NODE_PATH=/usr/local/lib/node_modules \
    npm_config_unsafe_perm=true \
    HOME=/root \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/tmp/.npm \
    NPM_CONFIG_DEVDIR=/tmp/.node-gyp \
    XDG_CONFIG_HOME=/tmp/.config \
    UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules

# Ensure global binary paths are accessible system-wide
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/sbin:/bin"

# Configure robust low-level NPM settings via environment and safe cache symlinks
RUN npm config set prefix /usr/local && \
    npm config set cache /tmp/.npm && \
    npm config set update-notifier false && \
    npm config set fund false && \
    npm config set audit false

RUN mkdir -p /tmp/.npm /tmp/.config /tmp/.node-gyp && \
    rm -rf /root/.npm /root/.config && \
    ln -s /tmp/.npm /root/.npm && \
    ln -s /tmp/.config /root/.config

RUN echo "✅ NPM workspace and cache redirection initialized."
RUN printf '\n\n\n'


# ==============================================================================
# STAGE 3: ROBUST SUDO WRAPPER WORKAROUND FOR UXC PERMISSIONS
# ==============================================================================
RUN echo "========================================================" \
 && echo " 🛡️ [Dockerfile Stage 3] Injecting Robust Sudo Wrapper..." \
 && echo "========================================================"

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

RUN echo "✅ Sudo compatibility wrapper successfully installed."
RUN printf '\n\n\n'


# ==============================================================================
# STAGE 4: CORE APPLICATION BINARY INSTALLATION & VALIDATION
# ==============================================================================
RUN echo "========================================================" \
 && echo " 📥 [Dockerfile Stage 4] Installing Homebridge Stack..." \
 && echo "========================================================"

ARG HOMEBRIDGE_VERSION=latest
ARG CONFIG_UI_VERSION=latest

RUN echo "[i] Target Homebridge Version: ${HOMEBRIDGE_VERSION}"
RUN echo "[i] Target Config UI X Version: ${CONFIG_UI_VERSION}"

# Globally install core application suite into the immutable /usr/local boundary
RUN npm install -g --unsafe-perm \
    homebridge@${HOMEBRIDGE_VERSION} \
    homebridge-config-ui-x@${CONFIG_UI_VERSION}

# Hard validation checks to fail the build immediately if binaries or modules are malformed
RUN set -eux; \
    test -f /usr/local/lib/node_modules/homebridge/package.json; \
    test -f /usr/local/lib/node_modules/homebridge-config-ui-x/package.json; \
    command -v node; \
    command -v npm; \
    command -v homebridge; \
    command -v hb-service; \
    node -e "console.log('Node.js Version:', process.version)"; \
    node -e "console.log('Homebridge:', require('/usr/local/lib/node_modules/homebridge/package.json').version)"; \
    node -e "console.log('Config UI X:', require('/usr/local/lib/node_modules/homebridge-config-ui-x/package.json').version)"

RUN echo "✅ Homebridge core and UIX successfully built, locked, and verified."
RUN printf '\n\n\n'


# ==============================================================================
# STAGE 5: PERSISTENT DIRECTORY SCAFFOLDING
# ==============================================================================
RUN echo "========================================================" \
 && echo " 📂 [Dockerfile Stage 5] Scaffolding Runtime File Tree..." \
 && echo "========================================================"

# Initialize mount point targets with clean separation for persistent plugins
RUN mkdir -p \
    /var/lib/homebridge \
    /var/lib/homebridge/node_modules \
    /var/lib/homebridge/persist \
    /var/lib/homebridge/accessories

# Validate structural baseline rootfs setup
RUN test -d /var/lib/homebridge && test -d /var/lib/homebridge/node_modules

RUN echo "✅ Base placeholder directories and plugin paths initialized cleanly."
RUN printf '\n\n\n'


# ==============================================================================
# STAGE 6: RUNTIME EXECUTION PREREQUISITES & WATCHDOG
# ==============================================================================
RUN echo "========================================================" \
 && echo " ⚙️ [Dockerfile Stage 6] Finalizing Execution Handlers..." \
 && echo "========================================================"

WORKDIR /var/lib/homebridge

# Utilize Tini as PID 1 to gracefully propagate POSIX signals and reap zombie processes
ENTRYPOINT ["/sbin/tini", "-g", "--"]

# Standard Homebridge runtime watchdog.
# FFmpeg is provided by Alpine as /usr/bin/ffmpeg.
CMD ["/bin/sh", "-c", "while true; do \
    /usr/local/bin/hb-service run \
        --allow-root \
        -U /var/lib/homebridge \
        -P /var/lib/homebridge/node_modules; \
    echo \"$(date) ⚠️ Homebridge runtime exited - restarting watchdog in 3s...\"; \
    sleep 3; \
done"]

RUN echo "🎉 Unified Dockerfile recipe compiled and verified successfully."
# ==============================================================================
# BUILD PIPELINE COMPLETE 🚀
# ==============================================================================
