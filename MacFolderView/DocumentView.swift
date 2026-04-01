import SwiftUI

struct DocumentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacFolderView")
                            .font(.system(size: 22, weight: .bold))
                        Text("メニューバーで動く、軽量ファイルブラウザ for macOS")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                            Text("v\(version)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // 特徴
                sectionHeader("特徴")
                featureGrid

                Divider()

                // キーボードショートカット
                sectionHeader("キーボードショートカット")
                shortcutTable

                Divider()

                // 右クリックメニュー
                sectionHeader("コンテキストメニュー（右クリック）")
                contextMenuList

                Divider()

                // 使い方
                sectionHeader("基本操作")
                usageList

                Divider()

                // 動作環境
                sectionHeader("動作環境")
                VStack(alignment: .leading, spacing: 6) {
                    infoRow("OS", "macOS 14 (Sonoma) 以降")
                    infoRow("CPU", "Apple Silicon (M1 / M2 / M3 / M4)")
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .frame(width: 520, height: 600)
    }

    // MARK: - 特徴グリッド

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            featureCard(icon: "menubar.rectangle", title: "メニューバー常駐", desc: "Dockに表示されず、ワンクリックで起動")
            featureCard(icon: "sidebar.left", title: "サイドバー", desc: "よく使うフォルダに即アクセス")
            featureCard(icon: "magnifyingglass", title: "検索 & ソート", desc: "リアルタイム検索。名前・日付・サイズでソート")
            featureCard(icon: "keyboard", title: "キーボード操作", desc: "矢印キーで移動、Enter で開く")
            featureCard(icon: "eye", title: "クイックルック", desc: "Space キーでファイルをプレビュー")
            featureCard(icon: "eye.slash", title: "隠しファイル表示", desc: "ワンクリックで表示/非表示を切替")
            featureCard(icon: "doc.on.clipboard", title: "クリップボード", desc: "コピー履歴の管理とピン留め")
            featureCard(icon: "tray.2", title: "ステージ", desc: "ファイルを一時的にまとめて操作")
        }
    }

    private func featureCard(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - ショートカット表

    private var shortcutTable: some View {
        VStack(spacing: 0) {
            shortcutRow("↑ ↓", "ファイル選択を移動")
            shortcutRow("Enter", "ファイルを開く / フォルダに移動")
            shortcutRow("←", "親フォルダに戻る")
            shortcutRow("→", "進む / フォルダに入る")
            shortcutRow("Space", "クイックルック プレビュー")
            shortcutRow("⌘F", "検索にフォーカス")
            shortcutRow("⌘C", "ファイルをコピー")
            shortcutRow("⌘V", "ファイルをペースト")
            shortcutRow("⌘⌫", "ゴミ箱に入れる")
            shortcutRow("Esc", "検索クリア / 選択解除 / 戻る")
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func shortcutRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 80, alignment: .center)
                .padding(.vertical, 6)
            Divider().frame(height: 20)
            Text(action)
                .font(.system(size: 12))
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    // MARK: - コンテキストメニュー一覧

    private var contextMenuList: some View {
        VStack(alignment: .leading, spacing: 4) {
            contextItem("arrow.up.forward", "開く")
            contextItem("eye", "クイックルック")
            contextItem("folder", "Finderで表示")
            contextItem("cursorarrow.click.2", "Cursorで開く（フォルダ）")
            contextItem("terminal", "ターミナルで開く（フォルダ）")
            contextItem("info.circle", "情報を見る")
            contextItem("pin", "ピン留め / お気に入り（フォルダ）")
            contextItem("doc.on.doc", "コピー")
            contextItem("clipboard", "ペースト")
            contextItem("pencil", "名前を変更")
            contextItem("plus.square.on.square", "複製")
            contextItem("archivebox", "圧縮")
            contextItem("folder.badge.plus", "新規フォルダ")
            contextItem("square.and.arrow.up", "共有")
            contextItem("text.document", "パスをコピー / 名前をコピー")
            contextItem("trash", "ゴミ箱に入れる")
        }
    }

    private func contextItem(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
        }
        .padding(.vertical, 1)
    }

    // MARK: - 使い方

    private var usageList: some View {
        VStack(alignment: .leading, spacing: 8) {
            usageStep("1", "メニューバーのフォルダアイコンをクリックでブラウザを表示")
            usageStep("2", "サイドバーからフォルダを選択、またはパンくずリストで移動")
            usageStep("3", "ファイルをダブルクリックで開く、右クリックで各種操作")
            usageStep("4", "右クリック → アイコンを右クリックで「アップデート確認」や「終了」")
        }
    }

    private func usageStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.system(size: 12))
        }
    }

    // MARK: - ヘルパー

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
        }
    }
}
