#!/bin/bash
# Netspeed probe for vm.netspeed.
# Prints exactly one JSON line so the QML widget can JSON.parse it:
#   {"state":"ok","iface":"wlan0","rx":123,"tx":456,"time":1234567890123456789}
#   {"state":"offline"}   no default route (disconnected)
#
# Rates are computed in QML as deltas between successive samples, so this
# script only reports raw cumulative counters from /sys plus a timestamp.
iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [[ -z $iface ]]; then
  echo '{"state":"offline"}'
  exit 0
fi

rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
now=$(date +%s%N)

printf '{"state":"ok","iface":"%s","rx":%s,"tx":%s,"time":%s}\n' "$iface" "$rx" "$tx" "$now"
