PID=$(uxc state homebridge | jq -r '.pid')
nsenter -t "$PID" -m -u -i -n /bin/sh