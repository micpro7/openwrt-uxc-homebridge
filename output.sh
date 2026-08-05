root@MX5300:~# wget -qO- https://raw.githubusercontent.com/micpro7/openwrt-uxc-homebrid
ge/main/test.sh | sh
========================================================
 ⚡ HOMEBRIDGE UXC MASTER INITIALIZATION ENGINE (v5) ⚡
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
OK: 11256 distinct packages available
OK: 172.0 MiB in 473 packages
========(+) DONE ✅ (+)========



🧹 [Phase 2] Clearing out stale runtime structures...
[i] Removing previous container bundle...
========(+) DONE ✅ (+)========



📂 [Phase 3] Constructing host storage target directories...
[i] Creating persistent storage directories...
[i] Generating clean static container resolv.conf...
========(+) DONE ✅ (+)========



📥 [Phase 4] Pulling production blueprint package from GitHub (micpro7/openwrt-uxc-homebridge)...
/mnt/X6/homebridge.ta 100%[========================>] 229.51M  4.65MB/s    in 49s     



📦 Extracting package payload onto /mnt/X6 storage...



   config.json validated  ✅
   rootfs engine verified ✅
🚀 OCI application bundle fully authenticated.
========(+) DONE ✅ (+)========



📝 [Phase 5] Injecting host-specific variable matrix...
   ↳ Storage targets bound to /mnt/X6 ✅
   ↳ Environment matrix injected (TZ: Europe/London | RAM: 256MB | Threads: 4) ✅
   ↳ Security privilege escalation flag: false ✅



⚙️ OCI JSON blueprints compiled permanently onto flash drive.
========(+) DONE ✅ (+)========



🏗️ [Phase 6] Registering container blueprint with UXC engine...



⏳ Holding engine execution for stabilization (3s)...



🏁 Spawning Homebridge runtime daemon...



✨ Active container framework status verified:
[ ] homebridge running runtime pid: 10006 container pid: 10018
========(+) DONE ✅ (+)========



🛠️ Installing persistent Homebridge procd startup service...
✅ Persistent Homebridge service installed.
========(+) DONE ✅ (+)========



🛠️ Probing Container Size...
770.5M  /mnt/X6/UXC/homebridge/bundle



🎉 ======== MASTER PIPELINE DEPLOYMENT COMPLETE ======== 🎉

========================================================
 🎉 HOMEBRIDGE UXC DEPLOYMENT COMPLETE 🎉
========================================================

Container:
 homebridge

Bundle:
 /mnt/X6/UXC/homebridge/bundle

Persistent Data:
 /mnt/X6/UXC/homebridge/data

Web UI:
 http://192.168.1.1/24:8581

Management:
 /etc/init.d/homebridge start
 /etc/init.d/homebridge stop
 /etc/init.d/homebridge restart
 /etc/init.d/homebridge status

========================================================
⚡ Homebridge is now running under OpenWrt UXC ⚡
========(+) DONE ✅ (+)========