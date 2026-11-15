#!/usr/bin/env bash
# Save to ~/bin/netcheck, then: chmod +x ~/bin/netcheck

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
if [[ -z "$IFACE" ]]; then
  echo "No active network connection found."
  exit 1
fi

if [[ -d "/sys/class/net/${IFACE}/wireless" ]] || iw dev "$IFACE" info &>/dev/null; then
  SSID=$(iw dev "$IFACE" link 2>/dev/null | awk '/SSID/{print $2}')

  # Try /proc/net/wireless first (no sudo needed)
  SIGNAL=$(awk -v iface="$IFACE" '$1 ~ iface {gsub(/\./, "", $3); print $3}' /proc/net/wireless 2>/dev/null)

  # Fallback to iw (may need sudo)
  if [[ -z "$SIGNAL" ]]; then
    SIGNAL=$(iw dev "$IFACE" link 2>/dev/null | awk '/signal/{print $2}')
  fi

  # Fallback to nmcli
  if [[ -z "$SIGNAL" ]]; then
    SIGNAL=$(nmcli -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk '/^\*/{print $2}')
    SIGNAL_SOURCE="nmcli (0-100 scale)"
    # Convert 0-100 to score directly
    if [[ -n "$SIGNAL" ]]; then
      if   [[ "$SIGNAL" -ge 80 ]]; then STRENGTH="Excellent 🟢"; SCORE=5
      elif [[ "$SIGNAL" -ge 60 ]]; then STRENGTH="Good 🟢";      SCORE=4
      elif [[ "$SIGNAL" -ge 40 ]]; then STRENGTH="Fair 🟡";      SCORE=3
      elif [[ "$SIGNAL" -ge 20 ]]; then STRENGTH="Weak 🟠";      SCORE=2
      else                               STRENGTH="Very weak 🔴"; SCORE=1
      fi
      echo "WiFi"
      echo "  Interface : $IFACE"
      [[ -n "$SSID" ]] && echo "  Network   : $SSID"
      echo "  Signal    : ${SIGNAL}% — ${STRENGTH}"
      echo "  Score     : ${SCORE}/5"
      exit 0
    fi
  fi

  if [[ -z "$SIGNAL" ]]; then
    echo "WiFi (interface: $IFACE) — signal unavailable (try: sudo netcheck)"
    exit 1
  fi

  # dBm scale
  if   [[ "$SIGNAL" -ge -50 ]]; then STRENGTH="Excellent 🟢"; SCORE=5
  elif [[ "$SIGNAL" -ge -60 ]]; then STRENGTH="Good 🟢";      SCORE=4
  elif [[ "$SIGNAL" -ge -70 ]]; then STRENGTH="Fair 🟡";      SCORE=3
  elif [[ "$SIGNAL" -ge -80 ]]; then STRENGTH="Weak 🟠";      SCORE=2
  else                               STRENGTH="Very weak 🔴"; SCORE=1
  fi

  echo "WiFi"
  echo "  Interface : $IFACE"
  [[ -n "$SSID" ]] && echo "  Network   : $SSID"
  echo "  Signal    : ${SIGNAL} dBm — ${STRENGTH}"
  echo "  Score     : ${SCORE}/5"

else
  echo "Ethernet"
  echo "  Interface : $IFACE"
  echo "  Score     : N/A (wired connection)"
fi