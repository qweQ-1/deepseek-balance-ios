import Foundation

/// 自定义音效存库：用户导入的音效存为 Documents/Sounds/{pop|eat|ding}.{ext}，优先于内置音效。
final class SoundStore {
    static let shared = SoundStore()

    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directory = base.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// 指定音效当前的自定义文件；没有则返回 nil（用内置音效）。
    func customURL(for sound: AppSound) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let prefix = sound.rawValue + "."
        guard let name = files.first(where: { $0.hasPrefix(prefix) && $0.count > prefix.count }) else {
            return nil
        }
        return directory.appendingPathComponent(name)
    }

    func hasCustom(for sound: AppSound) -> Bool {
        customURL(for: sound) != nil
    }

    /// 导入一个音频文件作为指定音效（替换旧的）。
    func importFile(from source: URL, for sound: AppSound) throws {
        reset(sound)
        let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension.lowercased()
        let destination = directory.appendingPathComponent(sound.rawValue + "." + ext)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    /// 恢复内置音效（删除自定义文件）。
    func reset(_ sound: AppSound) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let prefix = sound.rawValue + "."
        for name in files where name.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
