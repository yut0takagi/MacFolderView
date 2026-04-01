<p align="center">
  <img src="MacFolderView/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="MacFolderView Icon">
</p>

<h1 align="center">MacFolderView</h1>

<p align="center">
  <strong>メニューバーで動く、軽量ファイルブラウザ for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/yut0takagi/MacFolderView/releases/latest">
    <img src="https://img.shields.io/github/v/release/yut0takagi/MacFolderView?style=flat-square&color=3b82f6" alt="Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon-orange?style=flat-square" alt="Architecture">
  <a href="https://github.com/yut0takagi/MacFolderView/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yut0takagi/MacFolderView?style=flat-square" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://yut0takagi.github.io/MacFolderView/">ダウンロードページ</a>
</p>

---

## 特徴

| | 機能 | 説明 |
|---|---|---|
| **⚡** | **メニューバー常駐** | Dockに表示されず、メニューバーからワンクリックで起動 |
| **📁** | **サイドバー** | ホーム・デスクトップ・書類・ダウンロードなどに即アクセス |
| **🔍** | **検索 & ソート** | リアルタイム検索。名前・日付・サイズ・種類でソート |
| **⌨️** | **キーボード操作** | 矢印キーで移動、Enter で開く、Space で Quick Look |
| **📋** | **コンテキストメニュー** | 開く、クイックルック、Finder表示、ターミナル、情報、コピー、ペースト、共有 等 |
| **👁** | **隠しファイル表示** | ワンクリックで隠しファイルの表示/非表示を切替（設定永続化） |
| **📖** | **アプリ内ドキュメント** | メニューバー右クリックから使い方・ショートカット一覧を確認 |

## インストール

### ダウンロード（推奨）

1. [最新リリース](https://github.com/yut0takagi/MacFolderView/releases/latest)から **MacFolderView.zip** をダウンロード
2. 解凍して `MacFolderView.app` を「アプリケーション」フォルダへ移動
3. ターミナルで以下を実行（macOS のセキュリティ解除）：

```bash
xattr -cr /Applications/MacFolderView.app
```

4. ダブルクリックで起動 — メニューバーにフォルダアイコンが表示されます

### ソースからビルド

```bash
git clone https://github.com/yut0takagi/MacFolderView.git
cd MacFolderView
./run.sh
```

## キーボードショートカット

| キー | アクション |
|---|---|
| `↑` `↓` | ファイル選択を移動 |
| `Enter` | ファイルを開く / フォルダに移動 |
| `←` | 戻る |
| `→` | 進む / フォルダに入る |
| `Space` | Quick Look プレビュー |
| `⌘F` | 検索にフォーカス |
| `Esc` | 検索クリア / 選択解除 / 戻る |

## 動作環境

- **OS:** macOS 14 (Sonoma) 以降
- **CPU:** Apple Silicon (M1 / M2 / M3 / M4)
- **Swift:** 5.9+

## 技術スタック

- **SwiftUI** — UI フレームワーク
- **AppKit** — NSWorkspace / NSImage / NSPasteboard 連携
- **QuickLookUI** — ファイルプレビュー
- **Swift Package Manager** — ビルドシステム

## ライセンス

MIT
