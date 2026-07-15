# Homebridge UXC (OpenWrt)
A lightweight, automated, and secure Homebridge deployment designed specifically for **OpenWrt** using native containerization (UXC).

### Architecture Overview
This project provides a fully automated pipeline to build an OCI-compliant bundle for ARM64 architectures. By moving away from traditional Docker runtime requirements and utilizing native UXC containerization, this setup minimizes system overhead and protects internal flash memory by utilizing external SSD storage for persistent data.

### Key Features
 * **Security-First**: Tight Linux capability restrictions, masked sensitive paths, and noNewPrivileges enabled to ensure host system integrity.
 * **Flash-Friendly**: Persistent storage (plugins, config, backups) is offloaded to external SSD mounts (/mnt/SSD/Config/OpenWrt/UXC/homebridge).
 * **Automated Pipeline**: Built via GitHub Actions using Docker Buildx to ensure a deterministic, lean filesystem export.
 * **Native Performance**: Optimized for ARM64 OpenWrt environments with native process binding to br-lan.

### Automated Build Pipeline
The project utilizes a GitHub Actions workflow to:
 1. **Build** a containerized rootfs using a custom Dockerfile.
 2. **Assemble** an OCI bundle, stripping unnecessary documentation and cache to reduce bundle size.
 3. **Publish** a versioned release, making the latest stable OCI bundle available for deployment.

### Deployment
To deploy this bundle on your OpenWrt router, use the provided installation script:
 1. **Ensure Requirements**: Verify your router has uxc installed and external storage mounts are correctly configured.
 2. **Run Installer**: Download and execute the installer script (customized to your local paths):
   bash
   # Example deployment command
curl -sL https://raw.githubusercontent.com/micpro7/openwrt-uxc-homebridge/main/install.sh | sh

 3. **Validation**: The installer automatically validates the OCI bundle integrity and registers the container with the uxc runtime.
### Configuration Design
 * **Host Persistence**: Configuration and plugins are bound via rbind to external SSD storage.
 * **Resource Limits**: Strict RLIMIT_NOFILE and memory constraints prevent the container from impacting overall router performance.
 * **Auto-Restart**: The containerized hb-service is configured to monitor and auto-restart immediately upon any crash.

*Built for the OpenWrt community.*
