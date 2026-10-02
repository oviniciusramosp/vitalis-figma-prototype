#!/bin/zsh
set -euo pipefail

prototype_root="$(cd "$(dirname "$0")" && pwd)"
cd "$prototype_root"

prototype_device="${1:-$(xcrun simctl list devices available --json | python3 -c 'import json,sys; data=json.load(sys.stdin); devices=[d for runtime,items in data["devices"].items() if "iOS" in runtime for d in items if "iPhone" in d["name"]]; booted=[d for d in devices if d["state"]=="Booted"]; print((booted or devices)[0]["udid"])')}"
mkdir -p .build

xcrun simctl boot "$prototype_device" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$prototype_device" -b
xcodebuild -project VitalisPrototype.xcodeproj -scheme VitalisPrototype \
  -configuration Debug -destination "id=$prototype_device" \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build > .build/build.log 2>&1 || {
    tail -80 .build/build.log
    exit 1
  }
xcrun simctl install "$prototype_device" .build/DerivedData/Build/Products/Debug-iphonesimulator/VitalisPrototype.app
xcrun simctl launch --terminate-running-process "$prototype_device" com.example.vitalisprototype

print "Protótipo aberto no simulador. Log: $prototype_root/.build/build.log"
