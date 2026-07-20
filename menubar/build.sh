#!/usr/bin/env bash
# Builds KeepAwake.app from KeepAwake.swift. Needs Xcode Command Line Tools:
#   xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

command -v swiftc >/dev/null || {
  echo "swiftc not found. Install the Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
}

APP="KeepAwake.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

echo "Compiling KeepAwake.swift..."
swiftc -O KeepAwake.swift -o "$APP/Contents/MacOS/KeepAwake"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>      <string>KeepAwake</string>
    <key>CFBundleIdentifier</key>      <string>local.keepawake</string>
    <key>CFBundleName</key>            <string>KeepAwake</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>2.4</string>
    <key>LSMinimumSystemVersion</key>  <string>10.13</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
EOF

echo "Done. Launch with:  open $APP"
echo "To start it automatically: System Settings > General > Login Items > add KeepAwake.app"
