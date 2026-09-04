#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Building SkillArchive (release)…"
swift build -c release

APP="SkillArchive.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp ".build/release/SkillArchive" "$APP/Contents/MacOS/SkillArchive"

if [ -d "Assets.xcassets" ]; then
    echo "Compiling AppIcon asset catalog…"
    xcrun actool --output-format human-readable-text --notices --warnings \
        --app-icon AppIcon \
        --output-partial-info-plist /tmp/skillarchive_actool_partial.plist \
        --minimum-deployment-target 13.0 \
        --platform macosx \
        --compile "$APP/Contents/Resources" \
        Assets.xcassets
fi

STRINGS_CATALOG="Sources/SkillArchive/Localizable.xcstrings"
if [ -f "$STRINGS_CATALOG" ]; then
    echo "Compiling localizations (ko/en/ja)…"
    xcrun xcstringstool compile "$STRINGS_CATALOG" --output-directory "$APP/Contents/Resources"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SkillArchive</string>
    <key>CFBundleIdentifier</key>
    <string>local.skillarchive</string>
    <key>CFBundleExecutable</key>
    <string>SkillArchive</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.2</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>ko</string>
        <string>en</string>
        <string>ja</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Code-signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

touch "$APP"

echo "Done: $(pwd)/$APP"
echo "실행: open $APP"
echo "(Dock/Finder에 예전 아이콘이 캐시돼 있으면 'killall Dock'로 새로고침)"
