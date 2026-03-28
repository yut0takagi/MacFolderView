import Foundation
import AppKit

struct FileItem: Identifiable, Comparable, Equatable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let isHidden: Bool
    let isSymlink: Bool
    let isPackage: Bool

    init(url: URL, name: String, isDirectory: Bool, size: Int64,
         modificationDate: Date, isHidden: Bool,
         isSymlink: Bool = false, isPackage: Bool = false) {
        self.id = url
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.isPackage = isPackage
    }

    var nsImage: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var formattedSize: String {
        if isDirectory { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var childItemCount: Int? {
        guard isDirectory else { return nil }
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.count
    }

    var formattedChildCount: String? {
        guard let count = childItemCount else { return nil }
        return "\(count)項目"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ja_JP")
        let interval = Date().timeIntervalSince(modificationDate)
        if interval < 60 {
            return "たった今"
        } else if interval < 86400 * 7 {
            return formatter.localizedString(for: modificationDate, relativeTo: Date())
        } else {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ja_JP")
            let calendar = Calendar.current
            if calendar.isDate(modificationDate, equalTo: Date(), toGranularity: .year) {
                df.dateFormat = "M月d日"
            } else {
                df.dateFormat = "yyyy/M/d"
            }
            return df.string(from: modificationDate)
        }
    }

    var kindDescription: String {
        if isDirectory { return "フォルダ" }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "PDF"
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "svg", "tiff": return "画像"
        case "mp4", "mov", "avi", "mkv", "m4v": return "動画"
        case "mp3", "wav", "aac", "flac", "m4a": return "音声"
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "xml", "yaml", "yml": return "設定"
        case "zip", "tar", "gz", "rar", "7z": return "圧縮"
        case "txt": return "テキスト"
        case "md": return "Markdown"
        case "app": return "アプリ"
        case "dmg": return "ディスクイメージ"
        case "xls", "xlsx", "csv": return "表計算"
        case "doc", "docx", "pages": return "文書"
        case "ppt", "pptx", "key": return "プレゼン"
        default: return ext.uppercased()
        }
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }

    static func < (lhs: FileItem, rhs: FileItem) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
