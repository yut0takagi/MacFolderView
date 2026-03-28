#!/bin/bash
set -e

cd "$(dirname "$0")"

# ビルド
swift build 2>&1

# .appバンドル作成
APP="$PWD/.build/MacFolderView.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# 実行ファイルをコピー
cp .build/debug/MacFolderView "$APP/Contents/MacOS/MacFolderView"

# Info.plist（LSUIElement=trueでDock非表示、メニューバーアプリとして動作）
cat > "$APP/Contents/Info.plist" << 'EOF'
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
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
EOF

echo "✓ ビルド完了: $APP"

# 既存プロセスを終了
killall MacFolderView 2>/dev/null || true
sleep 0.5

# 起動
open "$APP"
echo "✓ 起動しました"
