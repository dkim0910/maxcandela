import AppKit
import XCTest
@testable import MaxCandela

/// The Scratchpad's autosave timing, file location, and the undoable Clear.
final class ScratchpadTests: XCTestCase {

    // MARK: - Autosave

    func testNothingToSaveUntilEdited() {
        let autosave = ScratchpadAutosave()
        XCTAssertFalse(autosave.isDirty)
        XCTAssertNil(autosave.deadline)
        XCTAssertFalse(autosave.shouldSave(at: 1_000))
    }

    func testSavesAfterAPauseInTyping() {
        var autosave = ScratchpadAutosave()
        autosave.edited(at: 0)
        autosave.edited(at: 0.4)
        XCTAssertEqual(autosave.deadline, 0.4 + ScratchpadAutosave.quietPeriod)
        XCTAssertFalse(autosave.shouldSave(at: 1.2))
        XCTAssertTrue(autosave.shouldSave(at: 1.4))
    }

    func testNonStopTypingStillSavesAtTheMaximumDelay() {
        var autosave = ScratchpadAutosave()
        var now: TimeInterval = 0
        while now < 30 {
            autosave.edited(at: now)
            if autosave.shouldSave(at: now) { break }
            now += 0.25   // a keystroke every quarter second, never a pause
        }
        XCTAssertEqual(now, ScratchpadAutosave.maximumDelay)
    }

    func testSavingStartsAFreshWindow() {
        var autosave = ScratchpadAutosave()
        autosave.edited(at: 0)
        autosave.saved()
        XCTAssertFalse(autosave.isDirty)
        XCTAssertNil(autosave.deadline)
        autosave.edited(at: 20)
        XCTAssertEqual(autosave.firstUnsavedEdit, 20, "the cap counts from the first edit since the save")
        XCTAssertEqual(autosave.deadline, 21)
    }

    func testFileLivesInTheAppsOwnApplicationSupportFolder() throws {
        let url = try XCTUnwrap(ScratchpadTool.storeURL)
        XCTAssertEqual(url.lastPathComponent, "scratchpad.txt")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "MaxCandela")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent,
                       "Application Support")
    }

    // MARK: - Text view

    func testTextViewIsPlainWithNoSmartSubstitutions() {
        let textView = NSTextView()
        ScratchpadPanel.configure(textView)
        XCTAssertFalse(textView.isRichText)
        XCTAssertTrue(textView.allowsUndo)
        XCTAssertFalse(textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticTextReplacementEnabled)
    }

    func testClearIsOneUndoableStep() {
        let textView = NSTextView()
        ScratchpadPanel.configure(textView)
        let owner = UndoOwner()
        textView.delegate = owner
        textView.string = "milk\neggs"

        XCTAssertTrue(ScratchpadPanel.clearUndoably(textView))
        XCTAssertEqual(textView.string, "")
        XCTAssertTrue(owner.undo.canUndo)
        XCTAssertEqual(owner.undo.undoActionName, "Clear")
        XCTAssertEqual(owner.changes, 1, "Clear must notify, or it would never be autosaved")

        owner.undo.undo()
        XCTAssertEqual(textView.string, "milk\neggs")
        XCTAssertFalse(ScratchpadPanel.clearUndoably(NSTextView()), "nothing to clear")
    }
}

/// Stands in for the panel: supplies the undo manager and counts change
/// notifications.
private final class UndoOwner: NSObject, NSTextViewDelegate {
    let undo = UndoManager()
    var changes = 0
    func undoManager(for view: NSTextView) -> UndoManager? { undo }
    func textDidChange(_ notification: Notification) { changes += 1 }
}
