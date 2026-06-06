#!/bin/sh
# Apply AT&T APN profile on comma device.
# Usage: apply_dataplan.sh [profile]
# Profiles: consumer (default), nxtgenphone, iot_m2m, firstnet

set -e
PROFILE="${1:-consumer}"
DIR="$(cd "$(dirname "$0")" && pwd)"

params set AttDataPlanProfile "$PROFILE"
params set AttDataPlanEnabled 1
params set AttWifiHotspot 1
params set V2ICarrier att
params set V2IAttApn "$(python3 -c "import json; print(json.load(open('$DIR/dataplan.json'))['profiles']['$PROFILE']['apn'])")"
params set TmobileDataPlanEnabled 0
params set VerizonDataPlanEnabled 0
params set OnroadCycleRequested 1

echo "AT&T profile '$PROFILE' applied. Cycle onroad to activate attd."
