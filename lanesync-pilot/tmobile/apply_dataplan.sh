#!/bin/sh
# Apply T-Mobile APN profile on comma device.
# Usage: apply_dataplan.sh [profile]
# Profiles: consumer (default), wholesale, iot_m2m, firstnet

set -e
PROFILE="${1:-consumer}"
DIR="$(cd "$(dirname "$0")" && pwd)"

params set TmobileDataPlanProfile "$PROFILE"
params set TmobileDataPlanEnabled 1
params set TmobileWifiHotspot 1
params set V2ICarrier tmobile
params set V2ITmobileApn "$(python3 -c "import json; print(json.load(open('$DIR/dataplan.json'))['profiles']['$PROFILE']['apn'])")"
params set AttDataPlanEnabled 0
params set VerizonDataPlanEnabled 0
params set OnroadCycleRequested 1

echo "T-Mobile profile '$PROFILE' applied. Cycle onroad to activate tmobiled."
