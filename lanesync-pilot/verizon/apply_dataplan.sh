#!/bin/sh
# Apply Verizon APN profile on comma device.
# Usage: apply_dataplan.sh [profile]
# Profiles: consumer (default), ims, iot_m2m, firstnet

set -e
PROFILE="${1:-consumer}"
DIR="$(cd "$(dirname "$0")" && pwd)"

params set VerizonDataPlanProfile "$PROFILE"
params set VerizonDataPlanEnabled 1
params set VerizonWifiHotspot 1
params set V2ICarrier verizon
params set V2IVerizonApn "$(python3 -c "import json; print(json.load(open('$DIR/dataplan.json'))['profiles']['$PROFILE']['apn'])")"
params set AttDataPlanEnabled 0
params set TmobileDataPlanEnabled 0
params set OnroadCycleRequested 1

echo "Verizon profile '$PROFILE' applied. Cycle onroad to activate verizond."
