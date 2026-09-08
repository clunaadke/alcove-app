#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
smoke_dir="${RUNNER_TEMP:-/tmp}/alcove-mist-smoke"
app_dir="$smoke_dir/MistSmoke.app"
mkdir -p "$app_dir" "$repo_root/mist-smoke-results"
sim_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
sim_arch="$(uname -m)"
xcrun swiftc -sdk "$sim_sdk" -target "$sim_arch-apple-ios16.0-simulator" \
  "$repo_root/scripts/mist-splash-smoke/AppDelegate.swift" \
  "$repo_root/ios/App/App/NativeChat/SplashView.swift" -o "$app_dir/MistSmoke"
cp -R "$repo_root/ios/App/App/MistSplash" "$app_dir/MistSplash"
cat > "$app_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.alcove.mistsmoke</string>
<key>CFBundleName</key><string>MistSmoke</string>
<key>CFBundleExecutable</key><string>MistSmoke</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>16.0</string>
<key>UILaunchScreen</key><dict/>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
device_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for v in d["devices"].values() for x in v if x["name"].startswith("iPhone")))')"
xcrun simctl boot "$device_id" || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_dir"
xcrun simctl launch "$device_id" app.alcove.mistsmoke
data_dir="$(xcrun simctl get_app_container "$device_id" app.alcove.mistsmoke data)"
for attempt in $(seq 1 50); do
  if [ -f "$data_dir/Documents/result.json" ]; then break; fi
  sleep 1
done
cp "$data_dir/Documents/"*.json "$repo_root/mist-smoke-results/"
cp "$data_dir/Documents/"*.png "$repo_root/mist-smoke-results/" || true
xcrun simctl io "$device_id" screenshot "$repo_root/mist-smoke-results/full-screen.png"
python3 - "$repo_root/mist-smoke-results/result.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
print(json.dumps(result,ensure_ascii=False,indent=2))
assert result['success'],result.get('error')
PY
