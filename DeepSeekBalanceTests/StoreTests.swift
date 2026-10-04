import Foundation
import Testing
import UIKit
@testable import DeepSeekBalance

@Suite struct StoreTests {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func dollStoreAddDeleteResolve() throws {
        let store = DollStore(directory: tempDir())
        #expect(store.customDollFileNames().isEmpty)
        #expect(store.resolvedID(stored: "") == DollStore.defaultDollID)
        #expect(store.resolvedID(stored: "missing.jpg") == DollStore.defaultDollID)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let name = try store.add(image: image)
        #expect(store.customDollFileNames() == [name])
        #expect(store.resolvedID(stored: name) == name)
        #expect(store.url(for: name) != nil)

        store.delete(dollID: name)
        #expect(store.customDollFileNames().isEmpty)
        #expect(store.resolvedID(stored: name) == DollStore.defaultDollID)
    }

    @Test func soundStoreImportReset() throws {
        let store = SoundStore(directory: tempDir())
        #expect(store.customURL(for: .pop) == nil)
        #expect(store.hasCustom(for: .pop) == false)

        let source = store.directory.appendingPathComponent("my-sound.m4a")
        try Data([0x00, 0x01, 0x02]).write(to: source)
        try store.importFile(from: source, for: .pop)

        #expect(store.hasCustom(for: .pop))
        #expect(store.customURL(for: .pop)?.pathExtension == "m4a")
        #expect(store.customURL(for: .eat) == nil)

        store.reset(.pop)
        #expect(store.hasCustom(for: .pop) == false)
    }
}
