import SwiftUI
import MarkdownUI

@main
struct MDPeekApp: App {
    @State private var scale = ReadingScale()

    init() {
        // Переключение между файлами идёт через боковую панель, поэтому системные вкладки окна не нужны.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

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

/// Состояние окна: выбранный файл, его текст, дерево папки и наблюдение за изменениями.
@MainActor final class ReaderModel: ObservableObject {
    /// Путь файла, который показан сейчас. Меняется боковой панелью.
    @Published var selection: String? {
        didSet {
            guard selection != oldValue else { return }
            // Пустое выделение в списке не сбрасывает документ: заголовок и baseURL должны совпадать с показанным текстом.
            guard selection != nil else { selection = oldValue; return }
            select()
        }
    }
    @Published var expanded: Set<String> = []
    @Published private(set) var text: String
    @Published private(set) var nodes: [FileNode] = []

    let folderName: String
    private let folderPath: String?
    private var watcher: FileWatcher?
    private var treeTask: Task<Void, Never>?
    private var hasLoadedTree = false

    init(text: String, fileURL: URL?) {
        self.text = text
        selection = fileURL?.path(percentEncoded: false)
        folderPath = fileURL?.deletingLastPathComponent().path(percentEncoded: false)
        folderName = fileURL?.deletingLastPathComponent().lastPathComponent ?? "Markdown"
        loadTree()
    }

    var title: String {
        selection.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Markdown"
    }

    var baseURL: URL? {
        selection.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
    }

    func startWatching() { restartWatcher() }

    func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    /// Перечитывает текущий файл и дерево папки.
    func reload() {
        loadTree()
        reloadText()
    }

    private func select() {
        guard let selection else { return }
        text = readFile(selection) ?? "*The file could not be read.*"
        restartWatcher()
    }

    private func reloadText() {
        guard let selection, let content = readFile(selection), content != text else { return }
        text = content
    }

    private func restartWatcher() {
        stopWatching()
        guard let selection else { return }
        let watcher = FileWatcher(url: URL(fileURLWithPath: selection)) { [weak self] in self?.reloadText() }
        watcher.start()
        self.watcher = watcher
    }

    private func loadTree() {
        guard let folderPath else { return }
        treeTask?.cancel()
        treeTask = Task {
            let scanned = await Task.detached(priority: .utility) { FileTree.scan(directory: folderPath) }.value
            guard !Task.isCancelled else { return }
            nodes = scanned
            // Папки верхнего уровня раскрываем только при первой загрузке, чтобы не сбивать выбор пользователя.
            if !hasLoadedTree {
                hasLoadedTree = true
                expanded = Set(scanned.filter { $0.children != nil }.map(\.id))
            }
        }
    }

    private func readFile(_ path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return decodeMarkdown(data)
    }
}

struct ReaderView: View {
    @StateObject private var model: ReaderModel
    @ObservedObject var scale: ReadingScale

    init(document: MarkdownDocument, url: URL?, scale: ReadingScale) {
        _model = StateObject(wrappedValue: ReaderModel(text: document.text, fileURL: url))
        self.scale = scale
    }

    var body: some View {
        NavigationSplitView {
            FileSidebar(
                title: model.folderName,
                nodes: model.nodes,
                selection: $model.selection,
                expanded: $model.expanded
            )
        } detail: {
            ScrollView {
                Markdown(model.text, baseURL: model.baseURL)
                    .markdownTheme(.reader)
                    .textSelection(.enabled)
                    .markdownTextStyle(\.text) { FontSize(17 * scale.value) }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 44)
                    .frame(maxWidth: .infinity)
            }
            // При смене файла новая прокрутка начинается сверху.
            .id(model.selection)
            .background(Color(nsColor: .textBackgroundColor))
            .navigationTitle(model.title)
        }
        .onAppear { model.startWatching() }
        .onDisappear { model.stopWatching() }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMarkdown)) { _ in model.reload() }
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
