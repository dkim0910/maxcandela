import AppKit
import Carbon.HIToolbox

/// File Shelf (Pro): a floating window to park files on mid-task — drop them
/// from Finder or any app, drag them back out into any app — plus quick
/// conversions: images to JPEG / PNG / HEIC at a few sizes with the
/// location and camera details left out, and selected PDFs merged in shelf
/// order. The Yoink / Dropover idea.
///
/// The shelf holds *references*. It never moves, renames, overwrites or
/// deletes the user's files; conversions write new files to Downloads under
/// names that are not taken yet, add them to the shelf, and reveal nothing
/// unless the user clicks Show in Finder. The one thing it does delete is
/// its own copy of a temporary drop (see `ShelfIngest`), when that copy
/// leaves the shelf.
///
/// The shelf survives a relaunch through security-scoped bookmarks
/// (`ShelfLibrary`); entries whose file has gone are dropped without a word.
///
/// Entitlements — the first tool that needs any beyond the base set:
///  - `files.user-selected.read-only`: keep using a dropped file after a
///    relaunch. Read-only, because the shelf never writes to the user's
///    files.
///  - `files.downloads.read-write`: where conversions go. No folder picker
///    and no writing next to the original, which the sandbox refuses.
/// No system permission prompt is involved.
///
/// ⚠️ Not exercised at runtime during development (the build machine is
/// shared and windows must not open). Naming, ordering, bookmark
/// bookkeeping, the conversions and the merge are unit-tested; the panel,
/// dragging in and out, and the sandboxed bookmark round trip are not.
final class FileShelfTool: MenuTool, FileShelfPanelDelegate {
    let menuItem = NSMenuItem(title: "File Shelf", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let library = ShelfLibrary.standard()
    private let hotKey = GlobalHotKey()
    private var panelIfBuilt: FileShelfPanel?
    private let countItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "Clear Shelf", action: nil, keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    /// Where file promises call back; the result hops to main.
    private let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    static let panelShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_F),
                                        carbonModifiers: Shortcut.standard.carbonModifiers,
                                        display: "⌃⌥⌘F")

    private static let shortcutKey = "com.maxcandela.shelf.shortcut"
    private static let resizeKey = "com.maxcandela.shelf.resize"
    private static let stripKey = "com.maxcandela.shelf.stripMetadata"

    private var shortcutEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.shortcutKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.shortcutKey) }
    }

    var resize: ShelfResize {
        get { ShelfResize(rawValue: UserDefaults.standard.integer(forKey: Self.resizeKey)) ?? .original }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.resizeKey) }
    }

    /// On by default: a converted file is usually on its way to someone
    /// else, and the location a photo was taken at should not ride along
    /// unless the user decides it should.
    var stripMetadata: Bool {
        get { UserDefaults.standard.object(forKey: Self.stripKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.stripKey) }
    }

    var shelfItems: [ShelfItem] { library.model.items }

    init() {
        let submenu = NSMenu()
        let show = NSMenuItem(title: "Show Shelf", action: #selector(showPanel), keyEquivalent: "")
        show.target = self
        submenu.addItem(show.symbol("tray.and.arrow.down"))
        countItem.isEnabled = false
        submenu.addItem(countItem)
        clearItem.target = self
        clearItem.action = #selector(clearFromMenu)
        clearItem.toolTip = "Takes everything off the shelf. Your files stay where they are."
        submenu.addItem(clearItem)
        submenu.addItem(.separator())
        shortcutItem.title = "Shortcut \(Self.panelShortcut.display) Shows the Shelf"
        shortcutItem.target = self
        shortcutItem.action = #selector(toggleShortcut)
        submenu.addItem(shortcutItem.symbol("keyboard"))
        menuItem.submenu = submenu
        menuItem.symbol("tray.full")

        hotKey.onPress = { [weak self] in self?.togglePanel() }
        ProGate.shared.observe { [weak self] allowed in self?.proChanged(allowed) }
        if ProGate.shared.isAllowed { proChanged(true) }
        updateMenu()
    }

    func menuWillOpen() { updateMenu() }

    func shutdown() {
        hotKey.unregister()
        panelIfBuilt?.close()
        library.unload()
    }

    /// Pure, unit-tested.
    static func countTitle(_ count: Int) -> String {
        switch count {
        case 0: return "The shelf is empty"
        case 1: return "1 item on the shelf"
        default: return "\(count) items on the shelf"
        }
    }

    // MARK: - Pro

    /// Pro arriving restores the saved shelf and arms the shortcut. Pro
    /// lapsing closes the window, lets the shortcut go and releases every
    /// file the shelf had access to. The saved shelf is kept — Pro may come
    /// back.
    private func proChanged(_ allowed: Bool) {
        if allowed {
            library.load()
            if shortcutEnabled { hotKey.register(Self.panelShortcut) }
            panelIfBuilt?.reload()
        } else {
            hotKey.unregister()
            panelIfBuilt?.close()
            library.unload()
        }
        updateMenu()
    }

    private func updateMenu() {
        let count = library.model.items.count
        countItem.title = Self.countTitle(count)
        clearItem.isEnabled = count > 0
        shortcutItem.state = hotKey.isRegistered ? .on : .off
    }

    /// Persist, refresh what shows the shelf.
    private func changed(selecting: Set<UUID>? = nil) {
        library.save()
        panelIfBuilt?.reload(selecting: selecting)
        updateMenu()
    }

    private func makePanel() -> FileShelfPanel {
        if let panelIfBuilt { return panelIfBuilt }
        let built = FileShelfPanel(delegate: self)
        panelIfBuilt = built
        return built
    }

    // MARK: - Menu actions

    @objc private func showPanel() {
        ProGate.shared.run { makePanel().show() }
    }

    private func togglePanel() {
        ProGate.shared.run {
            let panel = makePanel()
            if panel.isVisible { panel.close() } else { panel.show() }
        }
    }

    @objc private func clearFromMenu() {
        ProGate.shared.run { shelfPanelClear() }
    }

    @objc private func toggleShortcut() {
        ProGate.shared.run {
            shortcutEnabled.toggle()
            if shortcutEnabled { hotKey.register(Self.panelShortcut) } else { hotKey.unregister() }
            updateMenu()
        }
    }

    // MARK: - Panel delegate

    func shelfPanelDidDrop(urls: [URL], promises: [NSFilePromiseReceiver]) {
        guard library.isLoaded else { return }
        let before = library.model.items.count
        _ = library.ingest(urls)
        receive(promises)
        if library.model.remainingCapacity == 0, library.model.items.count - before < urls.count {
            NSSound.beep()
            panelIfBuilt?.showStatus("The shelf holds up to \(ShelfModel.capacity) items")
        }
        changed()
    }

    /// File promises are written by the *source* app, asynchronously, into
    /// a fresh folder in our container; each file joins the shelf as it
    /// lands.
    private func receive(_ promises: [NSFilePromiseReceiver]) {
        for promise in promises {
            guard let slot = library.makeOwnedSlot() else { continue }
            promise.receivePromisedFiles(atDestination: slot, options: [:], operationQueue: promiseQueue) { [weak self] url, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error {
                        NSLog("MaxCandela: shelf did not receive a promised file: \(error.localizedDescription)")
                        self.library.discardSlotIfEmpty(slot)
                        return
                    }
                    // Not loaded means Pro lapsed meanwhile: the file stays
                    // as an orphan and the next load() clears it.
                    guard self.library.isLoaded else { return }
                    if self.library.adoptOwnedFile(url) != nil { self.changed() }
                }
            }
        }
    }

    func shelfPanelMove(_ ids: Set<UUID>, to index: Int) {
        library.move(ids: ids, to: index)
        changed(selecting: ids)
    }

    func shelfPanelRemove(_ ids: Set<UUID>) {
        library.remove(ids: ids)
        changed(selecting: [])
    }

    func shelfPanelClear() {
        library.removeAll()
        panelIfBuilt?.showStatus("")
        changed(selecting: [])
    }

    func shelfPanelConvert(_ ids: Set<UUID>, to format: ShelfImageFormat) {
        let sources = library.model.selected(ids, kind: .image).map(\.url)
        let resize = self.resize, strip = stripMetadata
        run(count: sources.count, verb: "Converting") { downloads in
            sources.map { source in
                Result { try ShelfImageConverter.convert(source, to: format, resize: resize,
                                                         stripMetadata: strip, into: downloads) }
            }
        }
    }

    func shelfPanelMergePDFs(_ ids: Set<UUID>) {
        let sources = library.model.selected(ids, kind: .pdf).map(\.url)
        guard sources.count > 1 else { return }
        run(count: 1, verb: "Merging") { downloads in
            [Result { try ShelfPDFMerger.merge(sources, into: downloads) }]
        }
    }

    /// Does the work off the main thread, then puts the new files on the
    /// shelf, selected — so Show in Finder is one click away — and says
    /// where they went. Nothing is revealed or opened automatically.
    private func run(count: Int, verb: String, work: @escaping (URL) -> [Result<URL, Error>]) {
        guard count > 0, let downloads = ShelfOutput.downloadsDirectory() else {
            NSSound.beep()
            return
        }
        let panel = panelIfBuilt
        panel?.setBusy(true, status: "\(verb)…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = work(downloads)
            DispatchQueue.main.async {
                guard let self else { return }
                var outputs: [URL] = []
                var failed = 0
                for result in results {
                    switch result {
                    case .success(let url): outputs.append(url)
                    case .failure(let error):
                        failed += 1
                        NSLog("MaxCandela: shelf conversion failed: \(error)")
                    }
                }
                let added = self.library.isLoaded ? self.library.addReferences(outputs) : []
                if failed > 0 { NSSound.beep() }
                self.changed(selecting: Set(added.map(\.id)))
                panel?.setBusy(false, status: ShelfOutput.resultMessage(saved: outputs.count, failed: failed))
            }
        }
    }
}
