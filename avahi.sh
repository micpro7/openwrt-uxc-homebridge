Yes — removing the UXC /run tmpfs mount is potentially useful, but by itself it doesn’t guarantee Avahi will work.

Right now your UXC config explicitly creates an isolated /run:

{
  "destination": "/run",
  "type": "tmpfs",
  "source": "tmpfs"
}

That’s why the container sees:

/run/avahi-daemon/
/run/dbus/

as empty directories instead of seeing the host sockets.

If you remove /run

The container’s /run would no longer be isolated by that mount. Depending on how UXC constructs the container mount namespace, it could expose the underlying host /run.

If that happened, Homebridge could potentially see:

/run/avahi-daemon/socket
/run/dbus/system_bus_socket

and that could make the Avahi advertiser available.

However, there is an important distinction:

Removing /run is not the same as explicitly sharing the two sockets.

I would prefer not to expose the entire host /run to Homebridge. /run contains lots of host runtime state and sockets.

Better approach

If UXC supports bind-mounting individual paths, expose only what is actually required:

/run/avahi-daemon/socket
/run/dbus/system_bus_socket

rather than:

/run

But there’s another issue: Homebridge’s Avahi implementation needs the appropriate Avahi/D-Bus integration, and the host’s Avahi daemon must be usable from the container’s namespace. So we’d want to test it rather than assume the socket mount solves everything.

Your current setup

You have:

Host:
/run/avahi-daemon/socket
/run/dbus/system_bus_socket

Container:
/run/avahi-daemon/       ← empty
/run/dbus/               ← empty

That’s directly explained by your:

/run → tmpfs

mount.

If your goal is specifically to make Avahi work

I’d test the least invasive change first:
	1.	Remove the /run tmpfs mount.
	2.	Don’t add any other mounts yet.
	3.	Restart UXC.
	4.	Enter the container:

PID=$(uxc state homebridge | jq -r '.pid')
nsenter -t "$PID" -m -u -i -n /bin/sh

	5.	Check:

ls -la /run/avahi-daemon/
ls -la /run/dbus/

If you suddenly see:

/run/avahi-daemon/socket
/run/dbus/system_bus_socket

then we know the /run isolation was the missing piece.

Then set Homebridge to Avahi and check:

grep -i -E 'avahi|ciao|mdns' /var/lib/homebridge/homebridge.log | tail -50

The desired result is no:

selected advertiser, "avahi", isn't available

and no fallback to Ciao.

I would test this before settling on Ciao, because you specifically have a properly configured host Avahi reflector and your intention appears to be to have Homebridge use that infrastructure.