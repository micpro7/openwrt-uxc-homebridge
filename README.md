# OpenWrt UXC Homebridge 🍏🤖
Build Homebridge UXC Bundle
An enterprise-grade, high-performance **Homebridge** distribution engineered natively for **OpenWrt** platforms.
By leveraging native user-space **UXC (User Containers)** instead of resource-heavy Docker engines, this deployment runs straight against the native OpenWrt container runtime—extending your router into a smart home hub with zero CPU overhead and microsecond-level local latency.


## 🛠️ Architecture & Data Flow
This project is split into three main components to ensure clean execution, hardware safety, and robust service lifecycle management:
```
                  ┌────────────────────────────────────┐
                  │      GitHub Actions CI Pipeline    │
                  │   (alpine:3.22 + node:24 + arm64)  │
                  └─────────────────┬──────────────────┘
                                    │ Compiles rootfs & tarballs
                                    ▼
                  ┌────────────────────────────────────┐
                  │    homebridge-arm64.tar.gz Asset   │
                  └─────────────────┬──────────────────┘
                                    │ Pulled & Extracted via
                                    ▼
                  ┌────────────────────────────────────┐
                  │             install.sh             │
                  │   - Installs host dependencies     │
                  │   - Verifies external host SSD     │
                  │   - Configures /etc/homebridge.conf│
                  └─────────────────┬──────────────────┘
                                    │ Dynamic JQ Injection
                                    ▼
                  ┌────────────────────────────────────┐
                  │     UXC Container Environment      │
                  │   - Pre-built with non-root FS     │
                  │   - 256MB Node RAM constraint      │
                  │   - External SSD directory mounts  │
                  └────────────────────────────────────┘
```

## ✨ Key Technical Highlights
 * **💾 External Storage Protection (Zero Flash Wear):** Installs and maps all heavy filesystems straight to your external SSD (/mnt/SSD/UXC/homebridge) via high-performance rbind mount points. This fully insulates your router's internal flash storage from write-wear.


 * **🛡️ Sandboxed OCI Spec:** The filesystem is prepared for non-root execution (UID/GID 10001). UXC utilizes a locked-down, read-only rootfs specification with strict Linux Capability sets (CAP_NET_BIND_SERVICE, CAP_NET_RAW, CAP_CHOWN) and toggleable kernel-level privilege guards (noNewPrivileges).


 * **🧠 Memory Ceiling Optimization:** Deeply tuned for embedded routing hardware. Automatically injects NODE_OPTIONS="--max-old-space-size=256" directly into the container's environment to restrict the V8 engine heap, keeping your router safe from Out Of Memory (OOM) kernel terminations.

 * 
 * **⚡ Sudo Environment Stability:** Pre-configured /etc/sudoers.d/ rules inside the container preserve essential NPM environment paths (NPM_CONFIG_CACHE, NPM_CONFIG_TMP, PATH) during runtime installations and plug-in updates.

 * 
 * ** procd Daemon Integration:** Generates a custom /etc/init.d/homebridge init script. It handles startup wait sequences for your physical SSD, purges stale registrations, dynamically re-registers the UXC container instance, and handles clean, multi-stage shutdown operations (SIGTERM cascading to SIGKILL).


## 📂 Repository Breakdown
 * **Dockerfile**: Sets up Alpine 3.22 + Node 24, core tools (ffmpeg, curl, avahi), compilation frameworks (make, g++, git), permissions, and maps the non-root homebridge user.

 * **config.json**: The OCI-compliant runtime configuration template. Dictates sandbox namespaces, namespaces isolation, mounts, and hardware capabilities.

 * **install.sh**: The master automation script that handles environment validations, automated downloading, JQ injection mapping, and procd registration.

 * **build-release.yml**: The automated GitHub Actions CI/CD compiler that builds the system on a native ubuntu-24.04-arm runner and publishes the release.


## 🚀 Quick Start Deployment
### 1. Configure and Run the Master Installation Engine
Simply download the install.sh script to your router, customize your host-specific variables (like TARGET_MOUNT or network interfaces) directly at the top of the file, and run it:

bash
chmod +x install.sh
./install.sh


### 2. Configuration Eviroment Variables
The installer automatically writes your environment matrix directly to /etc/homebridge.conf. This is read by both the runner and the procd init system on boot:
ini
CONTAINER_NAME="homebridge"
TARGET_MOUNT="/mnt/SSD"
BUNDLE_PATH="/mnt/SSD/UXC/homebridge/bundle"
PERSISTENT_DATA_SOURCE="/mnt/SSD/UXC/homebridge/data"
TIMEZONE="Europe/London"
MDNS_NET_INTERFACE="br-lan"
NODE_MEMORY_LIMIT="256"
THREAD_POOL_SIZE="4"
BIND_IP="0.0.0.0"
NO_NEW_PRIVILEGES=false

## 🔄 Lifecycle & Service Controls
The container acts as a native system daemon on OpenWrt and is controlled through standard system service calls:

bash
# Verify if the Homebridge container is running
/etc/init.d/homebridge status

# Restart the service (cleanly halts, clears state, and re-registers the UXC blueprint)
/etc/init.d/homebridge restart

# Stop the container gracefully (SIGTERM -> fallback SIGKILL after 3 seconds)
/etc/init.d/homebridge stop

## 📜 License
Distributed under the MIT License. See LICENSE for more information.
