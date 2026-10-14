#!/bin/zsh
# Log HID sensors and `macfanpro status` side by side, one JSON line per sample.
# Usage: log.sh <samples> <gap-seconds> <tag>   (build hid-sample.swift first)
n=${1:-120}; gap=${2:-5}; tag=${3:-run}
out="${OUT_DIR:-.}/$tag.jsonl"
: > $out
for i in $(seq 1 $n); do
  hid=$("${HID_SAMPLE:-./hid-sample}" 1 | tr -d '\n')
  smc=$(macfanpro status 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(json.dumps({'temps':d['temperatures'],'fans':[[f['index'],f['actual_rpm'],f['mode']] for f in d['fans']]}))
except Exception: print('{}')")
  load=$(sysctl -n vm.loadavg | awk '{print $2}')
  echo "{\"hid\":$hid,\"smc\":$smc,\"load\":$load}" >> $out
  sleep $gap
done
echo "DONE $out"
