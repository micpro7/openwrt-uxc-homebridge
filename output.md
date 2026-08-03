root@MX5300:~# sh 1.sh
========================================================
 ⚡ HOMEBRIDGE UXC MASTER INITIALIZATION ENGINE ⚡
========================================================



📝 Creating persistent Homebridge variable map...
✅ Central variable map saved to /etc/homebridge.conf
========(+) DONE ✅ (+)========



🔄 [Phase 1] Syncing OpenWrt core infrastructure dependencies...
🔍 Verifying target storage...
✅ /mnt/X6 verified successfully.
 [https://downloads.openwrt.org/releases/25.12.5/targets/qualcommax/ipq807x/packages/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/base/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/targets/qualcommax/ipq807x/kmods/6.12.94-1-dbd7ac5945a1d38dbc7f22bedd674e40/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/luci/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/packages/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/routing/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/telephony/packages.adb]
 [https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/video/packages.adb]
OK: 11251 distinct packages available
OK: 172.0 MiB in 473 packages
========(+) DONE ✅ (+)========



🧹 [Phase 2] Clearing out stale runtime structures...
[i] Removing previous container bundle...
========(+) DONE ✅ (+)========



📂 [Phase 3] Constructing host storage target directories...
[i] Creating directories...
========(+) DONE ✅ (+)========



📥 [Phase 4] Pulling production blueprint package from GitHub...
/mnt/X6/homebridge.ta 100%[========================>] 355.97M  4.79MB/s    in 75s     



📦 Extracting package payload onto /mnt/X6 storage...



   config.json validated  ✅
   rootfs engine verified ✅
🚀 OCI application bundle fully authenticated.
========(+) DONE ✅ (+)========



📝 [Phase 5] Injecting master variable matrix via individual JQ splits...
   ↳ OCI runtime spec downgraded to: 1.0.2 ✅
   ↳ Mount Target bound to: /mnt/X6/UXC/homebridge/data -> /homebridge ✅
   ↳ Timezone assigned to: Europe/London ✅
   ↳ mDNS broadcast mapped to: br-lan ✅
   ↳ Node engine memory threshold set to: 256MB ✅
   ↳ Libuv backend worker threads balanced at: 4 ✅
   ↳ Network socket interface listening on: 0.0.0.0 ✅
   ↳ Web UI socket host forced to: 0.0.0.0 ✅
   ↳ Kernel privilege escalation guard: false ✅



⚙️ OCI JSON blueprints compiled permanently onto flash drive.
========(+) DONE ✅ (+)========



🏗️ [Phase 6] Registering container blueprint with UXC engine...



⏳ Holding engine execution for stabilization (3s)...



🏁 Spawning Homebridge runtime daemon...



✨ Active container framework status verified:
[ ] homebridge running runtime pid: 31846 container pid: 31858
========(+) DONE ✅ (+)========



🛠️ Installing persistent Homebridge procd startup service...
✅ Persistent Homebridge service installed.
========(+) DONE ✅ (+)========



🛠️ Probing Container Size...
1.2G    /mnt/X6/UXC/homebridge/bundle



🎉 ======== MASTER PIPELINE DEPLOYMENT COMPLETE ======== 🎉
root@MX5300:~# uxc list
[ ] homebridge running runtime pid: 31846 container pid: 31858
root@MX5300:~# uxc state homebridge
{
        "ociVersion": "1.0.2",
        "id": "homebridge",
        "status": "running",
        "pid": 31858,
        "bundle": "/mnt/X6/UXC/homebridge/bundle",
        "annotations": {
                "org.opencontainers.image.architecture": "arm64",
                "org.opencontainers.image.authors": "homebridge",
                "org.opencontainers.image.created": "2026-07-31T11:06:38.029226579Z",
                "org.opencontainers.image.description": "Official Homebridge Docker Image",
                "org.opencontainers.image.exposedPorts": "8581/tcp",
                "org.opencontainers.image.licenses": "GPL-3.0",
                "org.opencontainers.image.os": "linux",
                "org.opencontainers.image.title": "Homebridge in Docker",
                "org.opencontainers.image.url": "https://github.com/homebridge/docker-homebridge",
                "org.opencontainers.image.version": "2026-07-31"
        }
}
root@MX5300:~# grep -i "HOME" /mnt/X6/UXC/homebridge/bundle/config.json
      "HOME=/homebridge",
      "HOME=/root",
      "HOMEBRIDGE_APT_PACKAGE=1",
      "HOMEBRIDGE_CONFIG_UI=1",
      "PATH=/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "UIX_CUSTOM_PLUGIN_PATH=/var/lib/homebridge/node_modules",
      "npm_config_prefix=/opt/homebridge",
      "HOMEBRIDGE_IP=0.0.0.0",
      "HOMEBRIDGE_CONFIG_UI_HOST=0.0.0.0"
    "cwd": "/homebridge",
      "destination": "/homebridge",
      "source": "/mnt/X6/UXC/homebridge/data",
    "org.opencontainers.image.authors": "homebridge",
    "org.opencontainers.image.description": "Official Homebridge Docker Image",
    "org.opencontainers.image.title": "Homebridge in Docker",
    "org.opencontainers.image.url": "https://github.com/homebridge/docker-homebridge",
root@MX5300:~# 
