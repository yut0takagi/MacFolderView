#!/bin/bash
set -e

VERSION="${1:?Usage: ./release.sh <version>}"
cd "$(dirname "$0")"

echo "=== MacFolderView v${VERSION} リリースビルド ==="

# リリースビルド
swift build -c release 2>&1

# .appバンドル作成
DIST="$PWD/dist"
APP="$DIST/MacFolderView.app"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/Resources"

# 実行ファイルをコピー
cp .build/release/MacFolderView "$APP/Contents/MacOS/MacFolderView"

# アイコンをコピー
cp MacFolderView/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sparkle.frameworkをバンドル
SPARKLE_FW="$(find .build/artifacts -name "Sparkle.framework" -path "*/macos*" -type d | head -1)"
if [ -n "$SPARKLE_FW" ]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
    echo "✓ Sparkle.framework をバンドル"
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

# 内側から外側へ順番にad-hoc署名
SPARKLE_DIR="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign - "$SPARKLE_DIR/XPCServices/Installer.xpc"
codesign --force --sign - "$SPARKLE_DIR/XPCServices/Downloader.xpc"
codesign --force --sign - "$SPARKLE_DIR/Autoupdate"
codesign --force --sign - "$SPARKLE_DIR/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
echo "✓ 署名完了"

# ZIP作成
cd "$DIST"
rm -f MacFolderView.zip
ditto -c -k --keepParent MacFolderView.app MacFolderView.zip
cd ..

echo "✓ ZIP作成: dist/MacFolderView.zip"

# EdDSA署名
SIGN_TOOL=".build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ -x "$SIGN_TOOL" ]; then
    echo ""
    echo "=== Sparkle EdDSA署名 ==="
    SIGN_OUTPUT=$("$SIGN_TOOL" dist/MacFolderView.zip)
    echo "$SIGN_OUTPUT"
    echo ""
    echo "appcast.xml の enclosure に上記の値を設定してください"
else
    echo "⚠ sign_update が見つかりません"
fi

ZIP_SIZE=$(stat -f%z dist/MacFolderView.zip)
echo ""
echo "=== リリース情報 ==="
echo "バージョン: ${VERSION}"
echo "ファイル: dist/MacFolderView.zip (${ZIP_SIZE} bytes)"
