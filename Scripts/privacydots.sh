#!/usr/bin/env bash
# privacy dots for Waybar
# mic: green, cam: orange

set -euo pipefail

# Dependencies: pipewire (pw-dump), jq, dbus-send (dbus)
JQ_BIN="${JQ:-jq}"
PW_DUMP_CMD="${PW_DUMP:-pw-dump}"
DBUS_SEND="${DBUS_SEND:-dbus-send}"

mic=0
cam=0

# mic & camera
if command -v "$PW_DUMP_CMD" >/dev/null 2>&1 && command -v "$JQ_BIN" >/dev/null 2>&1; then
  dump="$($PW_DUMP_CMD 2>/dev/null || true)"

  mic="$(
    printf '%s' "$dump" |
      $JQ_BIN -r '
      [ .[] 
        | select(.type=="PipeWire:Interface:Node")
        | select((.info.props."media.class"=="Audio/Source" or .info.props."media.class"=="Audio/Source/Virtual"))
        | select((.info.state=="running") or (.state=="running"))
      ] | (if length>0 then 1 else 0 end)
    ' 2>/dev/null || echo 0
  )"

  cam="$(
    printf '%s' "$dump" |
      $JQ_BIN -r '
      [ .[] 
        | select(.type=="PipeWire:Interface:Node")
        | select(.info.props."media.class"=="Video/Source")
        | select((.info.state=="running") or (.state=="running"))
      ] | (if length>0 then 1 else 0 end)
    ' 2>/dev/null || echo 0
  )"

  # Fallback check if PipeWire didn't detect
  if [[ "$cam" -eq 0 ]] && command -v fuser >/dev/null 2>&1; then
    if fuser /dev/video0 >/dev/null 2>&1; then
      cam=1
    fi
  fi

fi

# Colors
green="#30D158"  # mic
orange="#FF9F0A" # cam
grey="#555555"   # off

dot() {
  local on="$1" color="$2"
  if [[ "$on" -eq 1 ]]; then
    printf '<span foreground="%s">●</span>' "$color"
  else
    printf '<span foreground="%s">●</span>' "$grey"
  fi
}

text="$(dot "$mic" "$green") $(dot "$cam" "$orange")"
tooltip="Mic: $([[ $mic -eq 1 ]] && echo on || echo off) | Cam: $([[ $cam -eq 1 ]] && echo on || echo off)"

classes="privacydot"
[[ $mic -eq 1 ]] && classes="$classes mic-on" || classes="$classes mic-off"
[[ $cam -eq 1 ]] && classes="$classes cam-on" || classes="$classes cam-off"

jq -c -n --arg text "$text" --arg tooltip "$tooltip" --arg class "$classes" \
  '{text:$text, tooltip:$tooltip, class:$class}'
