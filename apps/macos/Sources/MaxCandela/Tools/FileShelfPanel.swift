import AppKit
import Carbon.HIToolbox
import QuickLookThumbnailing

/// What the shelf window asks of its owner. Everything that changes the
/// shelf goes through here; the panel itself only shows and selects.
protocol FileShelfPanelDelegate: AnyObject {
    var shelfItems: [ShelfItem] { get }
    var resize: ShelfResize { get set }
    var stripMetadata: Bool { get set }
    func shelfPanelDidDrop(urls: [URL], promises: [NSFilePromiseReceiver])
    func shelfPanelMove(_ ids: Set<UUID>, to index: Int)
    func shelfPanelRemove(_ ids: Set<UUID>)
    func shelfPanelClear()
    func shelfPanelConvert(_ ids: Set<UUID>, to format: ShelfImageFormat)
    func shelfPanelMergePDFs(_ ids: Set<UUID>)
}

/// The File Shelf window (Pro): a floating, non-activating panel. Drop files
/// on it from Finder or any app; drag them back out to any app. It never
/// takes focus from the app the user is working in — the whole point is to
/// park files mid-task.
///
/// Dragging *out* offers copy (and link) only, never move: Finder would
/// otherwise move the original out of its folder on a same-volume drag, and
/// the Trash refuses the drag outright, so the shelf cannot be used to
/// delete or relocate a user's file by accident.
final class FileShelfPanel: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate, NSMenuDelegate {
    private let panel: NSPanel
    private let collection = ShelfCollectionView()
    private let emptyLabel = NSTextField(labelWithString: "Drop files here.\nDrag them out again into any app.")
    private let statusLabel = NSTextField(labelWithString: "")
    private let convertButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private let revealButton = NSButton(title: "Show in Finder", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)

    private weak var delegate: FileShelfPanelDelegate?
    private var items: [ShelfItem] = []
    private var thumbnails: [UUID: NSImage] = [:]
    private var pendingThumbnails: Set<UUID> = []
    /// What a drag that started on the shelf is carrying, for reordering.
    private var draggedIDs: Set<UUID> = []
    private var isBusy = false

    private static let autosaveName = "MaxCandelaFileShelf"
    private static let thumbnailSize = CGSize(width: 64, height: 64)

    /// File URLs plus every kind of file promise (Photos, Mail, Safari…).
    static let acceptedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    init(delegate: FileShelfPanelDelegate) {
        self.delegate = delegate
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()

        panel.title = "File Shelf"
        panel.isFloatingPanel = true
        panel.level = .floating
        // An accessory app is almost never the active one; without this the
        // shelf would vanish the moment the user clicked anywhere else.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 340, height: 220)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 88, height: 96)
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 6
        collection.collectionViewLayout = layout
        collection.register(ShelfCell.self, forItemWithIdentifier: ShelfCell.identifier)
        collection.dataSource = self
        collection.delegate = self
        collection.isSelectable = true
        collection.allowsMultipleSelection = true
        collection.allowsEmptySelection = true
        collection.backgroundColors = [.clear]
        collection.registerForDraggedTypes(Self.acceptedTypes)
        collection.setDraggingSourceOperationMask([.copy, .link], forLocal: false)
        collection.setDraggingSourceOperationMask(.move, forLocal: true)
        collection.onDelete = { [weak self] in self?.removeSelected() }

        let scroll = NSScrollView()
        scroll.documentView = collection
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        convertButton.menu?.delegate = self
        convertButton.menu?.autoenablesItems = false
        convertButton.addItem(withTitle: "Convert")
        revealButton.target = self
        revealButton.action = #selector(revealSelected)
        removeButton.target = self
        removeButton.action = #selector(removeSelected)
        clearButton.target = self
        clearButton.action = #selector(clearAll)
        clearButton.toolTip = "Takes everything off the shelf. Your files stay where they are."
        for control in [convertButton, revealButton, removeButton, clearButton] as [NSControl] {
            control.controlSize = .small
            control.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        let buttons = NSStackView(views: [convertButton, revealButton, removeButton, NSView(), clearButton])
        buttons.orientation = .horizontal
        buttons.spacing = 6
        buttons.translatesAutoresizingMaskIntoConstraints = false

        // The whole window takes drops, not just the grid: over the label
        // or the buttons a drop lands here and is handled the same way.
        let content = ShelfDropView()
        content.registerForDraggedTypes(Self.acceptedTypes)
        content.canAccept = { [weak self] in self?.canAccept($0) ?? false }
        content.onDrop = { [weak self] in self?.acceptExternalDrop($0) ?? false }
        content.addSubview(scroll)
        content.addSubview(emptyLabel)
        content.addSubview(statusLabel)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            statusLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
        panel.contentView = content

        // First run: top-right of the main screen, under the menu bar where
        // the ☀️ lives. After that, wherever the user left it.
        if !panel.setFrameUsingName(Self.autosaveName), let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - panel.frame.width - 20, y: visible.maxY - 10))
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        reload()
    }

    var isVisible: Bool { panel.isVisible }

    /// Key without activating the app (non-activating panel), so Delete and
    /// ⌘A work while the app the user was in stays frontmost.
    func show() {
        reload()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() { panel.orderOut(nil) }

    /// Re-read the shelf. `selecting` replaces the selection (the outputs of
    /// a conversion, so Show in Finder reveals them); otherwise it is kept.
    func reload(selecting: Set<UUID>? = nil) {
        let keep = selecting ?? selectedIDs
        items = delegate?.shelfItems ?? []
        let live = Set(items.map(\.id))
        thumbnails = thumbnails.filter { live.contains($0.key) }
        collection.reloadData()
        let paths = items.enumerated().filter { keep.contains($0.element.id) }.map { IndexPath(item: $0.offset, section: 0) }
        collection.selectionIndexPaths = Set(paths)
        if selecting != nil, let last = paths.max() {
            collection.scrollToItems(at: [last], scrollPosition: .nearestHorizontalEdge)
        }
        emptyLabel.isHidden = !items.isEmpty
        updateButtons()
    }

    func showStatus(_ text: String) { statusLabel.stringValue = text }

    func setBusy(_ busy: Bool, status: String? = nil) {
        isBusy = busy
        if let status { showStatus(status) }
        updateButtons()
    }

    private var selectedIDs: Set<UUID> {
        Set(collection.selectionIndexPaths.compactMap { items.indices.contains($0.item) ? items[$0.item].id : nil })
    }

    private var selectedItems: [ShelfItem] {
        let ids = selectedIDs
        return items.filter { ids.contains($0.id) }
    }

    private func updateButtons() {
        let selection = selectedItems
        revealButton.isEnabled = !selection.isEmpty
        removeButton.isEnabled = !selection.isEmpty
        clearButton.isEnabled = !items.isEmpty
        convertButton.isEnabled = !isBusy && selection.contains { $0.kind == .image || $0.kind == .pdf }
    }

    // MARK: - Actions

    @objc private func revealSelected() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        // Public AppKit call, no Apple Events, fine in the sandbox.
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @objc private func removeSelected() {
        let ids = selectedIDs
        guard !ids.isEmpty else { return }
        delegate?.shelfPanelRemove(ids)
    }

    @objc private func clearAll() {
        delegate?.shelfPanelClear()
    }

    @objc private func convert(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let format = ShelfImageFormat(rawValue: raw) else { return }
        delegate?.shelfPanelConvert(selectedIDs, to: format)
    }

    @objc private func chooseResize(_ sender: NSMenuItem) {
        guard let preset = ShelfResize(rawValue: sender.tag) else { return }
        delegate?.resize = preset
    }

    @objc private func toggleStrip() {
        delegate?.stripMetadata.toggle()
    }

    @objc private func mergePDFs() {
        delegate?.shelfPanelMergePDFs(selectedIDs)
    }

    /// The Convert pull-down is rebuilt each time it opens, from the current
    /// selection: only what applies is enabled.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let delegate else { return }
        let selection = selectedItems
        let images = selection.filter { $0.kind == .image }.count
        let pdfs = selection.filter { $0.kind == .pdf }.count

        menu.removeAllItems()
        menu.addItem(withTitle: "Convert", action: nil, keyEquivalent: "")   // the pull-down's own title
        menu.addItem(.sectionHeader(title: images > 1 ? "Save \(images) Images As" : "Save Image As"))
        for format in ShelfImageFormat.supported {
            let item = NSMenuItem(title: format.title, action: #selector(convert(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            item.isEnabled = images > 0
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Size"))
        for preset in ShelfResize.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(chooseResize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = preset.rawValue
            item.state = delegate.resize == preset ? .on : .off
            menu.addItem(item)
        }
        let strip = NSMenuItem(title: "Remove Location and Camera Details", action: #selector(toggleStrip), keyEquivalent: "")
        strip.target = self
        strip.state = delegate.stripMetadata ? .on : .off
        strip.toolTip = "Leaves out EXIF, GPS, IPTC and TIFF metadata. The colour profile is kept."
        menu.addItem(strip)
        menu.addItem(.separator())
        let merge = NSMenuItem(title: pdfs > 1 ? "Merge \(pdfs) PDFs in Shelf Order" : "Merge PDFs",
                               action: #selector(mergePDFs), keyEquivalent: "")
        merge.target = self
        merge.isEnabled = pdfs > 1
        merge.toolTip = "Select two or more PDFs. Drag them on the shelf to change the order."
        menu.addItem(merge)
        let note = NSMenuItem(title: "New files go to Downloads", action: nil, keyEquivalent: "")
        note.isEnabled = false
        menu.addItem(note)
    }

    // MARK: - Data source

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: ShelfCell.identifier, for: indexPath)
        guard let shelfCell = cell as? ShelfCell, items.indices.contains(indexPath.item) else { return cell }
        let item = items[indexPath.item]
        shelfCell.configure(name: item.name, image: thumbnails[item.id] ?? NSWorkspace.shared.icon(forFile: item.url.path))
        requestThumbnail(for: item)
        return shelfCell
    }

    private func requestThumbnail(for item: ShelfItem) {
        guard thumbnails[item.id] == nil, pendingThumbnails.insert(item.id).inserted else { return }
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: Self.thumbnailSize,
                                                   scale: panel.backingScaleFactor, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pendingThumbnails.remove(item.id)
                guard let image = representation?.nsImage,
                      let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                self.thumbnails[item.id] = image
                // Update the visible cell in place; a reload would reset the
                // selection and any drag in progress.
                (self.collection.item(at: IndexPath(item: index, section: 0)) as? ShelfCell)?.setImage(image)
            }
        }
    }

    // MARK: - Selection

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateButtons()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateButtons()
    }

    // MARK: - Dragging out

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        true
    }

    /// The file URL itself. The receiving app gets its own sandbox grant
    /// from the drag pasteboard, which works because the shelf holds the
    /// file's security scope open while it is on the shelf.
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard items.indices.contains(indexPath.item) else { return nil }
        return items[indexPath.item].url as NSURL
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        draggedIDs = Set(indexPaths.compactMap { items.indices.contains($0.item) ? items[$0.item].id : nil })
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        draggedIDs = []
    }

    // MARK: - Dropping in

    private func isFromShelf(_ info: NSDraggingInfo) -> Bool {
        (info.draggingSource as AnyObject?) === collection
    }

    private func canAccept(_ info: NSDraggingInfo) -> Bool {
        guard !isFromShelf(info) else { return false }
        let pasteboard = info.draggingPasteboard
        return pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            || pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if proposedDropOperation.pointee == .on { proposedDropOperation.pointee = .before }
        if isFromShelf(draggingInfo) { return draggedIDs.isEmpty ? [] : .move }
        guard canAccept(draggingInfo) else { return [] }
        // New things always go on the end.
        proposedDropIndexPath.pointee = NSIndexPath(forItem: items.count, inSection: 0)
        return .copy
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        if isFromShelf(draggingInfo) {
            guard !draggedIDs.isEmpty else { return false }
            delegate?.shelfPanelMove(draggedIDs, to: indexPath.item)
            return true
        }
        return acceptExternalDrop(draggingInfo)
    }

    /// Hands the drop to the owner *synchronously*: a temporary drag copy
    /// (the macOS 26 behaviour, see `ShelfIngest`) must be copied before
    /// this returns and the drag session ends.
    private func acceptExternalDrop(_ info: NSDraggingInfo) -> Bool {
        guard canAccept(info) else { return false }
        // Per pasteboard item, the first class that can read it: a real file
        // URL is preferred, so a promise is used only when there is no file.
        let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self, NSFilePromiseReceiver.self],
                                                          options: [.urlReadingFileURLsOnly: true]) ?? []
        let urls = objects.compactMap { $0 as? URL }
        let promises = objects.compactMap { $0 as? NSFilePromiseReceiver }
        guard !urls.isEmpty || !promises.isEmpty else { return false }
        delegate?.shelfPanelDidDrop(urls: urls, promises: promises)
        return true
    }
}

/// Delete / Forward Delete take the selection off the shelf. The files
/// themselves are never touched by this.
private final class ShelfCollectionView: NSCollectionView {
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            onDelete?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// The window's background view, so a drop anywhere in the window counts.
private final class ShelfDropView: NSView {
    var canAccept: ((NSDraggingInfo) -> Bool)?
    var onDrop: ((NSDraggingInfo) -> Bool)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept?(sender) == true ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept?(sender) == true ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender) ?? false
    }
}

/// One tile: thumbnail over name.
private final class ShelfCell: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ShelfCell")
    private let thumbnail = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override func loadView() {
        let root = ShelfCellView()
        root.wantsLayer = true
        root.layer?.cornerRadius = 8
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(thumbnail)
        root.addSubview(label)
        NSLayoutConstraint.activate([
            thumbnail.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            thumbnail.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: 64),
            thumbnail.heightAnchor.constraint(equalToConstant: 64),
            label.topAnchor.constraint(equalTo: thumbnail.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -4),
        ])
        view = root
        // The default drag image is built from these two outlets; without
        // them a drag out of the shelf would carry no picture.
        imageView = thumbnail
        textField = label
    }

    func configure(name: String, image: NSImage) {
        label.stringValue = name
        label.toolTip = name
        thumbnail.image = image
    }

    func setImage(_ image: NSImage) { thumbnail.image = image }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).cgColor
                : nil
        }
    }
}

/// Transparent to the mouse, so every click and drag reaches the collection
/// view itself — which is what does selection, rubber-banding and dragging.
/// (An image view inside a tile otherwise eats the mouse-down.)
private final class ShelfCellView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
