import SwiftUI

/// Папка или Markdown-файл. Для файла `children` равен nil.
struct FileNode: Identifiable, Sendable {
    let path: String
    let children: [FileNode]?

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}

enum FileTree {
    static let markdownExtensions: Set<String> = ["md", "markdown"]
    private static let maxDepth = 8

    /// Дерево Markdown-файлов внутри папки. Скрытые элементы и папки без Markdown пропускаются.
    static func scan(directory: String) -> [FileNode] {
        scan(URL(fileURLWithPath: directory, isDirectory: true), depth: 0)
    }

    private static func scan(_ directory: URL, depth: Int) -> [FileNode] {
        guard depth < maxDepth,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                  options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else { return [] }

        var folders: [FileNode] = []
        var files: [FileNode] = []
        for item in items {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
            if values?.isDirectory == true {
                // Симлинки на папки пропускаем: они могут образовать цикл. Пакеты (.app, .key и т.п.) тоже не обходим.
                guard values?.isSymbolicLink != true, values?.isPackage != true else { continue }
                let children = scan(item, depth: depth + 1)
                if !children.isEmpty {
                    folders.append(FileNode(path: item.path(percentEncoded: false), children: children))
                }
            } else if markdownExtensions.contains(item.pathExtension.lowercased()) {
                files.append(FileNode(path: item.path(percentEncoded: false), children: nil))
            }
        }
        return sorted(folders) + sorted(files)
    }

    private static func sorted(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Боковая панель с деревом Markdown-файлов. Выбор файла переключает документ в том же окне.
struct FileSidebar: View {
    let title: String
    let nodes: [FileNode]
    @Binding var selection: String?
    @Binding var expanded: Set<String>

    var body: some View {
        List(selection: $selection) {
            Section(title) {
                FileRows(nodes: nodes, expanded: $expanded)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 380)
    }
}

private struct FileRows: View {
    let nodes: [FileNode]
    @Binding var expanded: Set<String>

    var body: some View {
        ForEach(nodes) { node in
            if let children = node.children {
                DisclosureGroup(isExpanded: isExpanded(node.id)) {
                    FileRows(nodes: children, expanded: $expanded)
                } label: {
                    Label(node.name, systemImage: "folder")
                }
            } else {
                Label(node.name, systemImage: "doc.text")
                    .tag(node.id)
            }
        }
    }

    private func isExpanded(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { open in
                if open { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }
}
