#!/usr/bin/env bash
# Register an iPhone for Ad Hoc installs, then publish a build that includes it.
#   scripts/add-iphone.sh "Karolina iPhone" 00008150-XXXXXXXXXXXXXXXX
set -euo pipefail
cd "$(dirname "$0")/.."
source /Volumes/ZlotikaDev/toolchain/env.sh
name="${1:?name}"; udid="${2:?udid}"
node scripts/asc.mjs POST /v1/devices "{\"data\":{\"type\":\"devices\",\"attributes\":{\"name\":\"$name\",\"udid\":\"$udid\",\"platform\":\"IOS\"}}}" >/dev/null
echo "✓ Registered $name. Next: scripts/release.sh \"notes\" patch (the new build includes this iPhone)."
