import Foundation
import UIKit

/// 娃娃（小饭团形象）存库：内置一只默认娃娃，自定义娃娃存在 Documents/Dolls。
final class DollStore {
    static let shared = DollStore()
    static let defaultDollID = "default"

    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directory = base.appendingPathComponent("Dolls", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// 自定义娃娃的文件名列表（升序）。
    func customDollFileNames() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files
            .filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") || $0.hasSuffix(".png") }
            .sorted()
    }

    /// 全部娃娃：内置默认 + 自定义。
    func allDollIDs() -> [String] {
        [Self.defaultDollID] + customDollFileNames()
    }

    func url(for dollID: String) -> URL? {
        if dollID == Self.defaultDollID {
            return Bundle.main.url(forResource: "default-doll", withExtension: "jpg")
        }
        let url = directory.appendingPathComponent(dollID)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 把存储的 ID 解析成可用 ID：失效或为空时回退到默认娃娃。
    func resolvedID(stored: String) -> String {
        if stored != Self.defaultDollID, url(for: stored) != nil {
            return stored
        }
        return Self.defaultDollID
    }

    /// 把一张图片加进娃娃列表，返回文件名。
    @discardableResult
    func add(image: UIImage) throws -> String {
        let name = "doll-\(UUID().uuidString.prefix(8).lowercased()).jpg"
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw DollStoreError.encodingFailed
        }
        try data.write(to: directory.appendingPathComponent(name))
        return name
    }

    func delete(dollID: String) {
        guard dollID != Self.defaultDollID else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(dollID))
    }
}

enum DollStoreError: Error {
    case encodingFailed
}
