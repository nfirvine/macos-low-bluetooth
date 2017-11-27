#!/bin/bash -eu

# requires blueutil, jq:
# brew install blueutil jq

# disables bluetooth if not on AC power and no paired devices
# are within range; otherwise, enables

#cron hack :(
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

max_rssi(){
  system_profiler -xml SPBluetoothDataType |\
    sed -E 's#(</?)date>#\1string>#g' |\
    plutil  -convert json -o - -  |\
    jq '.[0]._items[0].device_title | [-1000, .[][].device_RSSI] | max'
}

on_ac(){
  pmset -g ac | grep -v 'No adapter attached.' > /dev/null
}

notify(){
  local msg="$1"
  osascript -e 'display notification "'"$msg"'" with title "Bluetooth Threshold"' 2>&1 > /dev/null
}

main(){
  local thresh="${1:-}"

  if [ -z "$thresh" ]; then
    echo "usage: $0 <lower_threshold>"
    exit 1
  fi

  local am_on_ac="$(on_ac && echo 1 || echo 0)"
  local current_max_rssi="$(max_rssi)"

  if [ "$am_on_ac" != "1" ] && [ "$current_max_rssi" -lt "$thresh" ]; then
    if [ $(blueutil p) = 1 ]; then
      blueutil off
      notify "Disabled; AC? $am_on_ac; max RSSI: $current_max_rssi"
    fi
  else
    if [ $(blueutil p) = 0 ]; then
      blueutil on
      notify "Enabled; AC? $am_on_ac; max RSSI: $current_max_rssi"
    fi
  fi
}

main $@
