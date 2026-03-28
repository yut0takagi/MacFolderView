#!/bin/bash
set -e

cd "$(dirname "$0")"

VERSION="${VERSION:-1.2.0}"

# ビルド
swift build 2>&1

# .appバンドル作成
APP="$PWD/.build/MacFolderView.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/Resources"

# 実行ファイルをコピー
cp .build/debug/MacFolderView "$APP/Contents/MacOS/MacFolderView"

# アイコンをコピー
cp MacFolderView/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sparkle.frameworkをバンドル
SPARKLE_FW="$(find .build/artifacts -name "Sparkle.framework" -path "*/macos*" -type d | head -1)"
if [ -n "$SPARKLE_FW" ]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
fi

# Info.plist
cat > "$APP/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacFolderView</string>
    <key>CFBundleIdentifier</key>
    <string>com.macfolderview.app</string>
    <key>CFBundleName</key>
    <string>MacFolderView</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>SUFeedURL</key>
    <string>https://yut0takagi.github.io/MacFolderView/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>dwt0rk9TEzdauQ1HG/Qok17udIusmyVc1rAXxsqfLWs=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

# rpathにFrameworksを追加
install_name_tool -add_rpath @loader_path/../Frameworks "$APP/Contents/MacOS/MacFolderView" 2>/dev/null || true

# 内側から外側へ順番にad-hoc署名（identifier指定で安定したdesignated requirement）
DR='designated => identifier "com.macfolderview.app"'
SPARKLE_DIR="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign - "$SPARKLE_DIR/XPCServices/Installer.xpc"
codesign --force --sign - "$SPARKLE_DIR/XPCServices/Downloader.xpc"
codesign --force --sign - "$SPARKLE_DIR/Autoupdate"
codesign --force --sign - "$SPARKLE_DIR/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - -i com.macfolderview.app -r="$DR" "$APP"

echo "✓ ビルド完了: $APP"

# 既存プロセスを終了
killall MacFolderView 2>/dev/null || true
sleep 0.5

# 起動
open "$APP"
echo "✓ 起動しました"
