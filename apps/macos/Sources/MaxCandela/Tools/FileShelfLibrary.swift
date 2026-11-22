import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What a shelf entry is, which decides the actions that apply to it.
enum ShelfItemKind: Equatable {
    case image, pdf, folder, other

    /// Pure, unit-tested. A package (an .app, a .key) is a directory on disk
    /// but one item to the user, so it is `other`, not `folder`.
    init(contentType: UTType?, isDirectory: Bool) {
        if isDirectory, contentType?.conforms(to: .package) != true {
            self = .folder
        } else if let type = contentType, type.conforms(to: .pdf) {
            self = .pdf
        } else if let type = contentType, type.conforms(to: .image) {
            self = .image
        } else {
            self = .other
        }
    }

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        self.init(contentType: values?.contentType ?? UTType(filenameExtension: url.pathExtension),
                  isDirectory: values?.isDirectory ?? false)
    }
}

/// One thing on the shelf. Normally a *reference* to the user's own file,
/// which the shelf never moves, renames or deletes. `isOwnedCopy` marks the
/// exception: a copy in MaxCandela's own container, made because what was
/// dropped was a temporary file about to vanish (see `ShelfIngest`). Only
/// those are ever deleted, and only when they leave the shelf.
struct ShelfItem: Equatable {
    let id: UUID
    let url: URL
    let kind: ShelfItemKind
    let isOwnedCopy: Bool

    var name: String { url.lastPathComponent }
}

/// The ordered list, and nothing else. Pure, unit-tested.
struct ShelfModel {
    /// Every entry holds a security scope open for as long as it is on the
    /// shelf, and developers report the sandbox caps how many one process
    /// may hold at once (no Apple figure found). 100 is far more than a
    /// shelf is for, and keeps well clear of any such cap.
    static let capacity = 100

    private(set) var items: [ShelfItem] = []

    init(items: [ShelfItem] = []) {
        add(items)
    }

    static func key(for url: URL) -> String { url.standardizedFileURL.path }

    var remainingCapacity: Int { max(0, Self.capacity - items.count) }

    func contains(_ url: URL) -> Bool {
        let key = Self.key(for: url)
        return items.contains { Self.key(for: $0.url) == key }
    }

    /// Appends what is not already on the shelf, up to the capacity, and
    /// returns what was actually added.
    @discardableResult
    mutating func add(_ new: [ShelfItem]) -> [ShelfItem] {
        var keys = Set(items.map { Self.key(for: $0.url) })
        var added: [ShelfItem] = []
        for item in new where items.count < Self.capacity {
            guard keys.insert(Self.key(for: item.url)).inserted else { continue }
            items.append(item)
            added.append(item)
        }
        return added
    }

    @discardableResult
    mutating func remove(ids: Set<UUID>) -> [ShelfItem] {
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        return removed
    }

    /// Moves `ids`, keeping their order among themselves, to sit before the
    /// item that was at `index` — an index into the list *before* the move,
    /// which is what a collection view proposes for a drop.
    mutating func move(ids: Set<UUID>, to index: Int) {
        let moving = items.filter { ids.contains($0.id) }
        guard !moving.isEmpty else { return }
        let clamped = max(0, min(index, items.count))
        let insertAt = items.prefix(clamped).filter { !ids.contains($0.id) }.count
        items.removeAll { ids.contains($0.id) }
        items.insert(contentsOf: moving, at: insertAt)
    }

    /// The chosen items in *shelf* order, not the order they were clicked —
    /// that is the order a PDF merge uses.
    func selected(_ ids: Set<UUID>, kind: ShelfItemKind? = nil) -> [ShelfItem] {
        items.filter { ids.contains($0.id) && (kind == nil || $0.kind == kind) }
    }
}

/// What is written to disk for one entry. Exactly one of the two is set.
struct ShelfRecord: Codable, Equatable {
    let id: UUID
    /// Security-scoped bookmark to the user's file.
    var bookmark: Data?
    /// An owned copy's path, relative to the owned-copies folder.
    var ownedPath: String?
}

/// Security-scoped bookmarks: how a sandboxed app keeps access to a file the
/// user handed it after a relaunch.
enum ShelfBookmark {
    /// Read-only scope: the shelf reads, thumbnails, converts and hands files
    /// on, and never writes to them — which is also all the
    /// `files.user-selected.read-only` entitlement allows. Falls back to a
    /// plain bookmark, which is what an unsandboxed process (`swift run`,
    /// the tests) gets; in the sandbox that one would resolve but not grant
    /// access, and `ShelfLibrary.load` then drops the entry quietly.
    static func make(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                            includingResourceValuesForKeys: nil, relativeTo: nil) {
            return data
        }
        NSLog("MaxCandela: shelf could not make a security-scoped bookmark for %@; it will not survive a relaunch", url.lastPathComponent)
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    struct Resolved {
        let url: URL
        let isStale: Bool
    }

    /// No UI and no mounting: a file on an unplugged drive or an absent
    /// server just fails to resolve, rather than a launch putting up a
    /// "connect to server" dialog.
    static func resolve(_ data: Data) -> Resolved? {
        let attempts: [URL.BookmarkResolutionOptions] = [
            [.withSecurityScope, .withoutUI, .withoutMounting],
            [.withoutUI, .withoutMounting],
        ]
        for options in attempts {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: options,
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                return Resolved(url: url, isStale: stale)
            }
        }
        return nil
    }
}

/// What arrives in a drop, and the macOS 26 trap in it.
///
/// **The regression.** On macOS 26 a file dragged out of a SwiftUI app (any
/// app using `.draggable` / `Transferable`) arrives not as the original but
/// as a system-made temporary copy: a path containing a
/// `com.apple.SwiftUI.Drag-<UUID>` folder (reported inside the *receiving*
/// app's own `Caches`), and in some cases a nameless
/// `.com.apple.Foundation.NSItemProvider.XXXXXX.tmp`. Reported on 26.5.2,
/// 26.7 and a macOS 27 beta; one report says the nameless variant is fixed
/// in 27 (Apple Developer Forums 837005, 802279, no Apple fix confirmed;
/// HN 47442781 names Yoink and Dropover as broken by it). A shelf that
/// merely *references* such a path is left pointing at a file the system
/// may clean up.
///
/// **What the shelf does.** Anything dropped from a temporary location —
/// that folder, that name, the per-user temporary and cache folders under
/// `/var/folders`, another app's container `tmp`, `/tmp` — is copied into
/// MaxCandela's container *inside the drop handler*, before the drag
/// session ends and the source can clean up, and the shelf holds the copy.
/// A nameless copy is given a readable name with an extension sniffed from
/// its contents. File promises (Photos, Mail attachments, images from a
/// browser) are received into the same place. Everything else stays a
/// reference to the user's original.
enum ShelfIngest {
    static let unnamedPrefix = ".com.apple.Foundation.NSItemProvider."

    /// Pure, unit-tested.
    static func isTransientDragCopy(path: String) -> Bool {
        let components = (path as NSString).pathComponents
        if components.contains(where: { $0.hasPrefix("com.apple.SwiftUI.Drag-") }) { return true }
        if let name = components.last, name.hasPrefix(unnamedPrefix) { return true }
        for prefix in ["/var/folders/", "/private/var/folders/", "/tmp/", "/private/tmp/"] where path.hasPrefix(prefix) {
            return true
        }
        // Another sandboxed app's temporary folder:
        // ~/Library/Containers/<bundle id>/Data/tmp/…
        if let index = components.firstIndex(of: "Containers"), components.count > index + 3,
           components[index + 2] == "Data", components[index + 3] == "tmp" {
            return true
        }
        return false
    }

    /// Pure, unit-tested. The name to give a copy.
    static func recoveredFileName(_ name: String, sniffedExtension: String?) -> String {
        guard name.isEmpty || name.hasPrefix(unnamedPrefix) else { return name }
        return "Dropped Item" + (sniffedExtension.map { ".\($0)" } ?? "")
    }

    /// The extension a nameless file's contents call for: whatever ImageIO
    /// recognises it as, or PDF by its header. Nil when neither.
    static func sniffedExtension(of url: URL) -> String? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let type = CGImageSourceGetType(source),
           let ext = UTType(type as String)?.preferredFilenameExtension {
            return ext
        }
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            if let head = try? handle.read(upToCount: 5), head == Data("%PDF-".utf8) { return "pdf" }
        }
        return nil
    }
}

/// The shelf's contents, kept across launches, plus the bookkeeping the
/// sandbox needs: every `startAccessingSecurityScopedResource()` that
/// returned true gets exactly one `stop…` — when the item leaves the shelf,
/// when Pro lapses, or at quit.
///
/// Main thread only.
final class ShelfLibrary {
    let directory: URL
    var storeURL: URL { directory.appendingPathComponent("shelf.json") }
    var ownedDirectory: URL { directory.appendingPathComponent("Shelf Files", isDirectory: true) }

    private(set) var model = ShelfModel()
    private(set) var isLoaded = false
    private var records: [UUID: ShelfRecord] = [:]
    private var accessing: [UUID: URL] = [:]

    init(directory: URL) {
        self.directory = directory
    }

    /// Application Support inside the sandbox container — the same folder
    /// the clipboard history uses.
    static func standard() -> ShelfLibrary {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return ShelfLibrary(directory: support.appendingPathComponent("MaxCandela", isDirectory: true))
    }

    // MARK: - Pure helpers (unit-tested)

    /// True only for something strictly inside `directory`. `..` is
    /// resolved first, so a crafted relative path cannot escape — this is
    /// the guard on every delete the shelf makes.
    static func isInside(_ url: URL, _ directory: URL) -> Bool {
        let base = directory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return path.hasPrefix(prefix) && path.count > prefix.count
    }

    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    /// Top-level entries of the owned folder that no record refers to:
    /// leftovers from a crash or an interrupted file promise.
    static func orphanedSlots(present: [String], referencedPaths: [String]) -> [String] {
        let used = Set(referencedPaths.compactMap { $0.split(separator: "/").first.map(String.init) })
        return present.filter { !used.contains($0) }
    }

    // MARK: - Loading and saving

    /// Restores the saved shelf. Entries whose file is gone, unreachable,
    /// or in the Trash are dropped without a word; a bookmark the system
    /// reports as stale (the file moved or was renamed) is re-made.
    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        let saved = Self.readRecords(from: storeURL)
        var changed = false
        for var record in saved {
            guard let item = restore(&record, changed: &changed) else {
                changed = true
                continue
            }
            if model.add([item]).isEmpty {
                release(item.id)        // a duplicate of an earlier entry
                changed = true
            } else {
                records[item.id] = record
            }
        }
        let present = (try? FileManager.default.contentsOfDirectory(atPath: ownedDirectory.path)) ?? []
        let referenced = records.values.compactMap(\.ownedPath)
        for slot in Self.orphanedSlots(present: present, referencedPaths: referenced) {
            let url = ownedDirectory.appendingPathComponent(slot)
            if Self.isInside(url, ownedDirectory) { try? FileManager.default.removeItem(at: url) }
        }
        if changed { save() }
    }

    private func restore(_ record: inout ShelfRecord, changed: inout Bool) -> ShelfItem? {
        if let owned = record.ownedPath {
            let url = ownedDirectory.appendingPathComponent(owned)
            guard Self.isInside(url, ownedDirectory), FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ShelfItem(id: record.id, url: url, kind: ShelfItemKind(url: url), isOwnedCopy: true)
        }
        guard let data = record.bookmark, let resolved = ShelfBookmark.resolve(data) else { return nil }
        let url = resolved.url
        let started = url.startAccessingSecurityScopedResource()
        guard FileManager.default.fileExists(atPath: url.path), !Self.isInTrash(url) else {
            if started { url.stopAccessingSecurityScopedResource() }
            return nil
        }
        if started { accessing[record.id] = url }
        if resolved.isStale, let fresh = ShelfBookmark.make(for: url) {
            record.bookmark = fresh
            changed = true
        }
        return ShelfItem(id: record.id, url: url, kind: ShelfItemKind(url: url), isOwnedCopy: false)
    }

    func save() {
        let list = model.items.compactMap { records[$0.id] }.filter { $0.bookmark != nil || $0.ownedPath != nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(list).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("MaxCandela: could not save the shelf: \(error.localizedDescription)")
        }
    }

    static func readRecords(from url: URL) -> [ShelfRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ShelfRecord].self, from: data)) ?? []
    }

    /// Lets go of every security scope and forgets the in-memory shelf.
    /// Deletes nothing: the saved shelf and the owned copies are kept for
    /// the next `load()`. Used when Pro lapses and at quit.
    func unload() {
        accessing.values.forEach { $0.stopAccessingSecurityScopedResource() }
        accessing.removeAll()
        records.removeAll()
        model = ShelfModel()
        isLoaded = false
    }

    // MARK: - Adding

    /// Adds what was dropped. Must run synchronously inside the drop
    /// handler: a temporary drag copy has to be copied before the drag
    /// session ends (see `ShelfIngest`).
    func ingest(_ urls: [URL]) -> [ShelfItem] {
        var added: [ShelfItem] = []
        for url in urls {
            guard model.remainingCapacity > 0 else { break }
            if ShelfIngest.isTransientDragCopy(path: url.path) {
                if let item = copyIntoContainer(url) { added.append(item) }
            } else {
                added += addReferences([url])
            }
        }
        return added
    }

    /// Adds references to the user's own files: dropped originals, and the
    /// outputs of a conversion.
    ///
    /// DTS's advice for a URL handed over by the system (Apple Developer
    /// Forums 798402): bookmark it, resolve the bookmark, and use *that* URL.
    /// The dropped URL's own grant is left alone — it lasts until quit and
    /// is not ours to stop.
    func addReferences(_ urls: [URL]) -> [ShelfItem] {
        var added: [ShelfItem] = []
        for url in urls where model.remainingCapacity > 0 && !model.contains(url) {
            let bookmark = ShelfBookmark.make(for: url)
            let target = bookmark.flatMap(ShelfBookmark.resolve)?.url ?? url
            let id = UUID()
            let started = target.startAccessingSecurityScopedResource()
            let item = ShelfItem(id: id, url: target, kind: ShelfItemKind(url: target), isOwnedCopy: false)
            guard model.add([item]).first != nil else {
                if started { target.stopAccessingSecurityScopedResource() }
                continue
            }
            if started { accessing[id] = target }
            records[id] = ShelfRecord(id: id, bookmark: bookmark, ownedPath: nil)
            added.append(item)
        }
        return added
    }

    /// A fresh folder for one owned copy or one file promise. One folder per
    /// drop keeps two files of the same name apart without renaming either.
    func makeOwnedSlot() -> URL? {
        let slot = ownedDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
            return slot
        } catch {
            NSLog("MaxCandela: shelf could not create \(slot.path): \(error.localizedDescription)")
            return nil
        }
    }

    func discardSlotIfEmpty(_ slot: URL) {
        guard Self.isInside(slot, ownedDirectory),
              (try? FileManager.default.contentsOfDirectory(atPath: slot.path))?.isEmpty == true else { return }
        try? FileManager.default.removeItem(at: slot)
    }

    /// Puts a file that is already in the owned folder (a received promise)
    /// on the shelf. If the shelf is full the copy is deleted again.
    @discardableResult
    func adoptOwnedFile(_ url: URL) -> ShelfItem? {
        guard isLoaded, Self.isInside(url, ownedDirectory) else { return nil }
        let base = ownedDirectory.standardizedFileURL.path
        let relative = String(url.standardizedFileURL.path.dropFirst(base.count + 1))
        let item = ShelfItem(id: UUID(), url: url, kind: ShelfItemKind(url: url), isOwnedCopy: true)
        guard model.add([item]).first != nil else {
            discard(item)
            return nil
        }
        records[item.id] = ShelfRecord(id: item.id, bookmark: nil, ownedPath: relative)
        return item
    }

    private func copyIntoContainer(_ url: URL) -> ShelfItem? {
        guard let slot = makeOwnedSlot() else { return nil }
        let original = url.lastPathComponent
        let sniffed = original.hasPrefix(ShelfIngest.unnamedPrefix) ? ShelfIngest.sniffedExtension(of: url) : nil
        let destination = slot.appendingPathComponent(ShelfIngest.recoveredFileName(original, sniffedExtension: sniffed))
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            NSLog("MaxCandela: shelf could not keep a temporary drop (\(original)): \(error.localizedDescription)")
            discardSlotIfEmpty(slot)
            return nil
        }
        return adoptOwnedFile(destination)
    }

    // MARK: - Changing

    func move(ids: Set<UUID>, to index: Int) {
        model.move(ids: ids, to: index)
    }

    func remove(ids: Set<UUID>) {
        model.remove(ids: ids).forEach(discard)
    }

    func removeAll() {
        let all = model.items
        model = ShelfModel()
        all.forEach(discard)
    }

    private func release(_ id: UUID) {
        accessing.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
    }

    /// Forgets an entry. A reference only loses its security scope; the
    /// user's file is not touched. An owned copy is deleted — it is ours,
    /// in our container, and nothing else points at it.
    private func discard(_ item: ShelfItem) {
        release(item.id)
        records[item.id] = nil
        guard item.isOwnedCopy, Self.isInside(item.url, ownedDirectory) else { return }
        try? FileManager.default.removeItem(at: item.url)
        let slot = item.url.deletingLastPathComponent()
        if slot.standardizedFileURL != ownedDirectory.standardizedFileURL { discardSlotIfEmpty(slot) }
    }
}
