import SwiftUI
import MarkdownUI

@main
struct MDPeekApp: App {
    @State private var scale = ReadingScale()

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { configuration in
            ReaderView(document: configuration.document, url: configuration.fileURL, scale: scale)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Open…") { NSDocumentController.shared.openDocument(nil) }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Zoom In") { scale.change(1) }.keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { scale.change(-1) }.keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { scale.reset() }.keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Reload") { NotificationCenter.default.post(name: .reloadMarkdown, object: nil) }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

import AppKit
import UniformTypeIdentifiers

extension UTType {
    static let markdownDocument = UTType(filenameExtension: "md") ?? .plainText
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    var text: String
    init(configuration: ReadConfiguration) throws {
        text = decodeMarkdown(configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}

/// UTF-8 с удалённым BOM; некорректные байты заменяются, файл всё равно открывается.
func decodeMarkdown(_ data: Data) -> String {
    let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    let bytes = data.starts(with: bom) ? data.dropFirst(3) : data[...]
    return String(decoding: bytes, as: UTF8.self)
}

extension Notification.Name { static let reloadMarkdown = Notification.Name("MDPeekReloadMarkdown") }

@MainActor final class ReadingScale: ObservableObject {
    @Published private(set) var value: Double = UserDefaults.standard.object(forKey: "readingScale") as? Double ?? 1
    func change(_ step: Double) { value = min(1.6, max(0.75, value + step * 0.1)); UserDefaults.standard.set(value, forKey: "readingScale") }
    func reset() { value = 1; UserDefaults.standard.set(value, forKey: "readingScale") }
}

struct ReaderView: View {
    @State var document: MarkdownDocument
    let url: URL?
    @ObservedObject var scale: ReadingScale
    @State private var watcher: FileWatcher?

    var body: some View {
        ScrollView {
            Markdown(document.text, baseURL: url?.deletingLastPathComponent())
                .markdownTheme(.reader)
                .textSelection(.enabled)
                .markdownTextStyle(\.text) { FontSize(17 * scale.value) }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 44)
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(url?.lastPathComponent ?? "Markdown")
        .onAppear { beginWatching() }
        .onDisappear { watcher?.stop(); watcher = nil }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMarkdown)) { _ in reload() }
    }

    private func beginWatching() {
        guard let url else { return }
        watcher = FileWatcher(url: url) { reload() }
        watcher?.start()
    }
    private func reload() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        let content = decodeMarkdown(data)
        guard content != document.text else { return }
        document.text = content
    }
}

final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var timer: DispatchSourceTimer?
    private var lastSignature = ""
    init(url: URL, onChange: @escaping () -> Void) { self.url = url; self.onChange = onChange }
    func start() {
        lastSignature = signature()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.7, repeating: 0.7)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let signature = self.signature()
            if signature != self.lastSignature { self.lastSignature = signature; self.onChange() }
        }
        self.timer = timer
        timer.resume()
    }
    func stop() { timer?.cancel(); timer = nil }
    private func signature() -> String {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .fileResourceIdentifierKey]) else { return "missing" }
        return "\(String(describing: values.fileResourceIdentifier))|\(values.fileSize ?? -1)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }
    deinit { timer?.cancel() }
}
