import AppKit

/// The Calendar tool's month grid, hosted in an NSMenuItem (`item.view`) the
/// way SliderMenuItemView hosts a slider.
///
/// Clicking inside an open menu, which is the part that needs care:
///  - An open menu delivers mouse events to an item's view, never key events.
///    So there is no keyboard focus to manage here, and the grid offers none;
///    every control is a click.
///  - Previous / Today / Next are plain NSButtons. A button runs its own
///    tracking loop from mouse-down and sends its action on release. A menu
///    closes when one of its *items* is chosen; a control inside an item's
///    view is not an item being chosen, so paging leaves the menu open.
///    Nothing here calls `cancelTracking()`, which is how a view would close
///    the menu on purpose.
///  - The days are drawn rather than built from 42 controls, and a day is
///    picked on mouseUp by hit-testing (`MonthGridGeometry.cellIndex`, pure
///    and tested). The pick does not depend on having seen the mouse-down,
///    so it works however the menu was opened.
///  - The owner reacts by changing `model` (a redraw) and by inserting and
///    removing *other* items of the open menu, which NSMenu supports live.
///
/// ⚠️ Click handling inside a menu cannot be unit-tested; see the tool's
/// comment for the hardware check.
final class MonthGridView: NSView {
    struct Model {
        var layout: MonthLayout
        var title: String
        /// Seven short names starting on the first weekday, and the narrow
        /// ones used when any short one is wider than a column.
        var weekdaySymbols: [String]
        var narrowWeekdaySymbols: [String]
        var dayLabels: [String]
        var todayIndex: Int?
        var selectedIndex: Int?
        /// Cells with at least one event (Pro; empty otherwise).
        var eventDays: Set<Int>
        var showsWeekNumbers: Bool
    }

    var model: Model {
        didSet { modelChanged(from: oldValue) }
    }
    var onPrevious: () -> Void = {}
    var onToday: () -> Void = {}
    var onNext: () -> Void = {}
    var onSelect: (Int) -> Void = { _ in }

    private let previousButton = NSButton()
    private let todayButton = NSButton()
    private let nextButton = NSButton()

    init(model: Model) {
        self.model = model
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: MonthGridGeometry.naturalWidth(showsWeekNumbers: model.showsWeekNumbers),
                                 height: MonthGridGeometry.height))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(model.title)

        configure(previousButton, symbol: "chevron.left", label: "Previous Month", action: #selector(previousPressed))
        configure(nextButton, symbol: "chevron.right", label: "Next Month", action: #selector(nextPressed))
        todayButton.title = "Today"
        todayButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        configure(todayButton, symbol: nil, label: "Today", action: #selector(todayPressed))
        todayButton.sizeToFit()
        placeButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    private var geometry: MonthGridGeometry {
        MonthGridGeometry(width: bounds.width, showsWeekNumbers: model.showsWeekNumbers)
    }

    private func configure(_ button: NSButton, symbol: String?, label: String, action: Selector) {
        if let symbol {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            button.imagePosition = .imageOnly
        }
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = action
        button.toolTip = label
        button.setAccessibilityLabel(label)
        addSubview(button)
    }

    private func modelChanged(from old: Model) {
        if old.showsWeekNumbers != model.showsWeekNumbers {
            // Only ever changed while the menu is closed (by one of its items),
            // so the menu measures the new width when it next opens.
            setFrameSize(NSSize(width: MonthGridGeometry.naturalWidth(showsWeekNumbers: model.showsWeekNumbers),
                                height: MonthGridGeometry.height))
        }
        setAccessibilityLabel(model.title)
        placeButtons()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // The menu widens the view to its own width; keep the controls at
        // the grid's right edge, which moves when the grid is centred.
        placeButtons()
    }

    private func placeButtons() {
        let g = geometry
        let side = MonthGridGeometry.buttonSize
        let y = MonthGridGeometry.headerTop + (MonthGridGeometry.headerHeight - side) / 2
        let todayWidth = max(todayButton.frame.width, 36)
        nextButton.frame = NSRect(x: g.blockMaxX - side, y: y, width: side, height: side)
        todayButton.frame = NSRect(x: nextButton.frame.minX - todayWidth, y: y, width: todayWidth, height: side)
        previousButton.frame = NSRect(x: todayButton.frame.minX - side, y: y, width: side, height: side)
    }

    @objc private func previousPressed() { onPrevious() }
    @objc private func todayPressed() { onToday() }
    @objc private func nextPressed() { onNext() }

    // MARK: - Mouse

    /// Swallowed so the press is ours; the pick happens on release.
    override func mouseDown(with event: NSEvent) {
        if geometry.cellIndex(at: convert(event.locationInWindow, from: nil)) == nil {
            super.mouseDown(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let index = geometry.cellIndex(at: convert(event.locationInWindow, from: nil)) else {
            super.mouseUp(with: event)
            return
        }
        onSelect(index)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let g = geometry
        drawTitle(in: g)
        drawWeekdays(in: g)
        if model.showsWeekNumbers { drawWeekNumbers(in: g) }
        for index in 0 ..< min(model.layout.cells.count, model.dayLabels.count) {
            drawDay(index, in: g.cellRect(index), geometry: g)
        }
    }

    private func drawTitle(in g: MonthGridGeometry) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
        let text = model.title as NSString
        let height = text.size(withAttributes: attributes).height
        let rect = NSRect(x: g.blockX,
                          y: MonthGridGeometry.headerTop + (MonthGridGeometry.headerHeight - height) / 2,
                          width: max(0, previousButton.frame.minX - g.blockX - 4), height: height)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
    }

    private func drawWeekdays(in g: MonthGridGeometry) {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        let fits = model.weekdaySymbols.allSatisfy {
            ($0 as NSString).size(withAttributes: attributes).width <= MonthGridGeometry.columnWidth - 2
        }
        let symbols = fits ? model.weekdaySymbols : model.narrowWeekdaySymbols
        for (column, symbol) in symbols.prefix(7).enumerated() {
            drawCentred(symbol, in: g.weekdayRect(column: column), attributes: attributes)
        }
    }

    private func drawWeekNumbers(in g: MonthGridGeometry) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        for (row, week) in model.layout.weekNumbers.enumerated() {
            drawCentred(String(week), in: g.circleRect(in: g.weekNumberRect(row: row)), attributes: attributes)
        }
    }

    private func drawDay(_ index: Int, in cell: NSRect, geometry g: MonthGridGeometry) {
        let inMonth = model.layout.cells[index].isInMonth
        let isToday = index == model.todayIndex
        let circle = g.circleRect(in: cell)

        if isToday {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: circle).fill()
        } else if index == model.selectedIndex {
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(ovalIn: circle).fill()
        }

        let colour: NSColor = isToday ? .white : (inMonth ? .labelColor : .tertiaryLabelColor)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1,
                                                    weight: isToday ? .semibold : .regular),
            .foregroundColor: colour,
        ]
        drawCentred(model.dayLabels[index], in: circle, attributes: attributes)

        if model.eventDays.contains(index) {
            let d = MonthGridGeometry.dotDiameter
            let dot = NSRect(x: cell.midX - d / 2, y: circle.maxY + 1.5, width: d, height: d)
            (inMonth ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    private func drawCentred(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        let string = text as NSString
        let size = string.size(withAttributes: attributes)
        string.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                    withAttributes: attributes)
    }
}

/// Pure, unit-tested. Where everything in the grid sits, in the view's
/// flipped (y-down) coordinates. The block — week column plus seven day
/// columns — is centred when the menu is wider than the grid needs.
struct MonthGridGeometry {
    static let inset: CGFloat = 14
    static let columnWidth: CGFloat = 32
    static let weekColumnWidth: CGFloat = 24
    static let rowHeight: CGFloat = 26
    static let circleDiameter: CGFloat = 20
    static let dotDiameter: CGFloat = 3.5
    static let buttonSize: CGFloat = 22
    static let headerTop: CGFloat = 6
    static let headerHeight: CGFloat = 24
    static let weekdayTop: CGFloat = headerTop + headerHeight + 2
    static let weekdayHeight: CGFloat = 16
    static let gridTop: CGFloat = weekdayTop + weekdayHeight
    static let height: CGFloat = gridTop + rowHeight * CGFloat(MonthLayout.rows) + 4

    let width: CGFloat
    let showsWeekNumbers: Bool

    static func blockWidth(showsWeekNumbers: Bool) -> CGFloat {
        (showsWeekNumbers ? weekColumnWidth : 0) + 7 * columnWidth
    }

    static func naturalWidth(showsWeekNumbers: Bool) -> CGFloat {
        2 * inset + blockWidth(showsWeekNumbers: showsWeekNumbers)
    }

    var blockX: CGFloat {
        max(Self.inset, ((width - Self.blockWidth(showsWeekNumbers: showsWeekNumbers)) / 2).rounded(.down))
    }
    var blockMaxX: CGFloat { blockX + Self.blockWidth(showsWeekNumbers: showsWeekNumbers) }
    var daysX: CGFloat { blockX + (showsWeekNumbers ? Self.weekColumnWidth : 0) }

    func cellRect(_ index: Int) -> CGRect {
        CGRect(x: daysX + CGFloat(index % 7) * Self.columnWidth,
               y: Self.gridTop + CGFloat(index / 7) * Self.rowHeight,
               width: Self.columnWidth, height: Self.rowHeight)
    }

    func weekdayRect(column: Int) -> CGRect {
        CGRect(x: daysX + CGFloat(column) * Self.columnWidth, y: Self.weekdayTop,
               width: Self.columnWidth, height: Self.weekdayHeight)
    }

    func weekNumberRect(row: Int) -> CGRect {
        CGRect(x: blockX, y: Self.gridTop + CGFloat(row) * Self.rowHeight,
               width: Self.weekColumnWidth, height: Self.rowHeight)
    }

    /// The day's circle: centred across the cell, at its top, leaving room
    /// for the event dot beneath.
    func circleRect(in cell: CGRect) -> CGRect {
        let d = Self.circleDiameter
        return CGRect(x: cell.midX - d / 2, y: cell.minY + 1, width: d, height: d)
    }

    /// The cell under `point`, or nil outside the day grid.
    func cellIndex(at point: CGPoint) -> Int? {
        let column = Int(((point.x - daysX) / Self.columnWidth).rounded(.down))
        let row = Int(((point.y - Self.gridTop) / Self.rowHeight).rounded(.down))
        guard (0 ..< 7).contains(column), (0 ..< MonthLayout.rows).contains(row) else { return nil }
        return row * 7 + column
    }
}
