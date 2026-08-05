# OpenWrt UXC Homebridge 🍏🤖
An enterprise-grade, high-performance **Homebridge** distribution engineered natively for **OpenWrt** platforms.
By leveraging native user-space **UXC (User Containers)** instead of resource-heavy Docker engines, this deployment runs straight against the native OpenWrt container runtime—extending your router into a smart home hub with zero CPU overhead and microsecond-level local latency.
## 🛠️ Architecture & Data Flow
This project is split into components to ensure clean execution, hardware safety, and robust service lifecycle management:
```
                  ┌────────────────────────────────────┐
                  │      GitHub Actions CI Pipeline    │
                  │   (alpine:3.24 + node:24 + arm64)  │
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
                  │   - Verifies external flash media  │
                  │   - Configures /etc/homebridge.conf│
                  └─────────────────┬──────────────────┘
                                    │ Dynamic JQ Injection
                                    ▼
                  ┌────────────────────────────────────┐
                  │     UXC Container Environment      │
                  │   - Pre-built with root sandbox    │
                  │   - Flash-optimized storage mounts │
                  │   - Full build tools (python/make) │
                  └────────────────────────────────────┘

```
## ✨ Key Technical Highlights
 * **💾 External Flash Media Protection:** Installs and maps all heavy filesystems straight to your external flash media (/mnt/X6 or designated mount points) via high-performance bind mount points. This fully insulates your router's internal storage from write-wear.
 * **🛡️ Sandboxed OCI Spec:** Uses a locked-down filesystem structure paired with OpenWrt's procd-ujail and native UXC runtime configuration framework.
 * **🔧 Runtime Native Plugin Compilation:** Built with full toolchain packages (python3, make, g++, git, linux-headers) natively retained in the final bundle image, allowing plugins with native C++ bindings or Python dependencies to compile seamlessly directly on your router.
 * **⚡ Sudo Wrapper Optimization:** Includes a robust option-stripping sudo wrapper (/usr/bin/sudo) tailored specifically for UXC environments to prevent flag-rejection errors during global plugin installs and updates.
 * **🔄 procd Daemon Integration:** Generates a custom /etc/init.d/homebridge init script. It handles startup wait sequences for your physical storage media, purges stale instances, dynamically re-registers the UXC container runtime, and manages multi-stage clean shutdown operations.
## 📂 Repository Breakdown
 * **Dockerfile**: Sets up Alpine 3.24 + Node 24 (musl build), core utilities (ffmpeg, curl, avahi, dbus), and compilation tools (python3, make, g++) alongside the Tini init process manager.
 * **config.json**: The OCI-compliant runtime configuration template. Dictates namespace isolation, mount points, and container capabilities.
 * **install.sh**: The master automation script that handles environment validations, automated downloading, JQ injection mapping, and procd registration.
 * **build.yml**: The automated GitHub Actions CI/CD compiler that builds the system on a native ubuntu-24.04-arm runner and publishes the release assets.
## 🚀 Quick Start Deployment
### 1. Configure and Run the Master Installation Engine
Download the install.sh script to your router, customize your host-specific variables (like target mount paths or network parameters) directly at the top of the file, and execute it:
```bash
chmod +x install.sh
./install.sh

```
### 2. Configuration Environment Variables
The installer automatically writes your environment matrix directly to /etc/homebridge.conf. This is read by both the runner and the procd init system on boot:
```ini
CONTAINER_NAME="homebridge"
TARGET_MOUNT="/mnt/SSD"
BUNDLE_PATH="/mnt/SSD/UXC/homebridge/bundle"
PERSISTENT_DATA_SOURCE="/mnt/SSD/UXC/homebridge/data"
TIMEZONE="UTC"
MDNS_NET_INTERFACE="br-lan"
NODE_MEMORY_LIMIT="256"
BIND_IP="0.0.0.0"

```
## 🔄 Lifecycle & Service Controls
The container acts as a native system daemon on OpenWrt and is controlled through standard service commands:
```bash
# Verify if the Homebridge container is running
service homebridge status

# Start the Homebridge container service
service homebridge start

# Restart the service (cleanly halts, clears state, and re-registers the UXC blueprint)
service homebridge restart

# Stop the container gracefully
service homebridge stop

```
## 🌊 Start Command Flow Explanation (Autount Workaround)
When you execute /etc/init.d/homebridge start, the script acts as a robust workaround for native auto-mount timing issues or boot race conditions on OpenWrt. It executes a strict, multi-step validation and deployment sequence:
 1. **Storage Availability Check (Mount Loop):** It actively polls /proc/mounts for up to 30 seconds (seq 1 30) waiting for your external flash media ($TARGET_MOUNT) to become ready. If it fails to mount in time, it safely aborts to protect your router's internal overlay storage from accidental write wear.
 2. **Configuration Validation:** It verifies that the critical runtime configuration file (config.json) exists inside the bundle directory before proceeding.
 3. **Stale State Cleanup:** It forcefully purges any leftover runtime locks or orphaned instances by executing /sbin/uxc kill and /sbin/uxc delete --force.
 4. **UXC Blueprint Re-registration:** It compiles and registers a fresh container instance using /sbin/uxc create, binding the designated bundle path and external storage mounts.
 5. **Daemon Launch:** Finally, it triggers /sbin/uxc start to bring the service online, logging the operational state directly to the system log via logger.
