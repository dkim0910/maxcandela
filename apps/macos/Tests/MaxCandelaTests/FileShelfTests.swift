import XCTest
import ImageIO
import PDFKit
import UniformTypeIdentifiers
@testable import MaxCandela

/// File Shelf: naming, ordering, bookmark bookkeeping, and the conversions
/// themselves (ImageIO and PDFKit run fine headless). Everything works in a
/// fresh folder under NSTemporaryDirectory. What is *not* covered: the
/// panel, dragging in and out, and the sandboxed bookmark round trip — the
/// test process is not sandboxed.
final class FileShelfTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FileShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Naming

    func testUniqueNamesNeverReuseATakenName() {
        let taken: Set<String> = ["photo.jpg", "photo 2.jpg", "README"]
        XCTAssertEqual(ShelfOutput.uniqueName("photo.jpg", exists: taken.contains), "photo 3.jpg")
        XCTAssertEqual(ShelfOutput.uniqueName("other.jpg", exists: taken.contains), "other.jpg")
        XCTAssertEqual(ShelfOutput.uniqueName("README", exists: taken.contains), "README 2")
        // Only the last extension moves, as in Finder.
        XCTAssertEqual(ShelfOutput.candidateName("archive.tar.gz", attempt: 2), "archive.tar 2.gz")
    }

    func testWriteNeverOverwritesAnExistingFile() throws {
        let existing = directory.appendingPathComponent("a.jpg")
        try Data("original".utf8).write(to: existing)
        let written = try ShelfOutput.write(Data("new".utf8), preferredName: "a.jpg", in: directory)
        XCTAssertEqual(written.lastPathComponent, "a 2.jpg")
        XCTAssertEqual(try Data(contentsOf: existing), Data("original".utf8))
        let again = try ShelfOutput.write(Data("newer".utf8), preferredName: "a.jpg", in: directory)
        XCTAssertEqual(again.lastPathComponent, "a 3.jpg")
    }

    func testOutputNames() {
        XCTAssertEqual(ShelfOutput.convertedName(source: "IMG_0042.HEIC", longestSide: 1920, fileExtension: "jpg"),
                       "IMG_0042 1920px.jpg")
        XCTAssertEqual(ShelfOutput.convertedName(source: "shot.png", longestSide: nil, fileExtension: "heic"), "shot.heic")
        XCTAssertEqual(ShelfOutput.mergedName(first: "Report.pdf", count: 3), "Report + 2 more.pdf")
        XCTAssertEqual(ShelfOutput.mergedName(first: "Report.pdf", count: 1), "Report.pdf")
    }

    func testResultMessages() {
        XCTAssertEqual(ShelfOutput.resultMessage(saved: 1, failed: 0), "Saved 1 file to Downloads")
        XCTAssertEqual(ShelfOutput.resultMessage(saved: 3, failed: 1), "Saved 3 files to Downloads — 1 couldn’t be converted")
        XCTAssertEqual(ShelfOutput.resultMessage(saved: 0, failed: 1), "Couldn’t convert that file")
        XCTAssertEqual(FileShelfTool.countTitle(0), "The shelf is empty")
        XCTAssertEqual(FileShelfTool.countTitle(2), "2 items on the shelf")
    }

    // MARK: - The macOS 26 drag copies

    func testTransientDragCopiesAreRecognised() {
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path:
            "/Users/me/Library/Containers/com.maxcandela.MaxCandela/Data/Library/Caches/com.apple.SwiftUI.Drag-1A2B/photo.png"))
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path: "/Users/me/Somewhere/.com.apple.Foundation.NSItemProvider.gKZ91u.tmp"))
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path: "/private/var/folders/xy/abc/T/export.pdf"))
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path: "/var/folders/xy/abc/T/export.pdf"))
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path: "/Users/me/Library/Containers/com.example.App/Data/tmp/x.png"))
        XCTAssertFalse(ShelfIngest.isTransientDragCopy(path: "/Users/me/Documents/photo.png"))
        XCTAssertFalse(ShelfIngest.isTransientDragCopy(path: "/Users/me/Library/Containers/com.example.App/Data/Documents/x.png"))
        XCTAssertFalse(ShelfIngest.isTransientDragCopy(path: "/Volumes/Backup/tmp/x.png"))
    }

    func testNamelessCopiesGetAReadableName() {
        XCTAssertEqual(ShelfIngest.recoveredFileName(".com.apple.Foundation.NSItemProvider.gKZ91u.tmp", sniffedExtension: "png"),
                       "Dropped Item.png")
        XCTAssertEqual(ShelfIngest.recoveredFileName(".com.apple.Foundation.NSItemProvider.gKZ91u.tmp", sniffedExtension: nil),
                       "Dropped Item")
        XCTAssertEqual(ShelfIngest.recoveredFileName("photo.png", sniffedExtension: "jpeg"), "photo.png")
    }

    // MARK: - Model

    private func item(_ name: String, kind: ShelfItemKind = .other) -> ShelfItem {
        ShelfItem(id: UUID(), url: URL(fileURLWithPath: "/Users/me/\(name)"), kind: kind, isOwnedCopy: false)
    }

    func testModelKeepsDropOrderAndSkipsDuplicates() {
        var model = ShelfModel()
        let a = item("a"), b = item("b")
        XCTAssertEqual(model.add([a, b]).count, 2)
        let sameFileAgain = ShelfItem(id: UUID(), url: URL(fileURLWithPath: "/Users/me/./a"), kind: .other, isOwnedCopy: false)
        XCTAssertTrue(model.add([sameFileAgain]).isEmpty)
        XCTAssertEqual(model.items.map(\.name), ["a", "b"])
    }

    func testModelIsCapped() {
        var model = ShelfModel()
        model.add((0..<(ShelfModel.capacity + 5)).map { item("f\($0)") })
        XCTAssertEqual(model.items.count, ShelfModel.capacity)
        XCTAssertEqual(model.remainingCapacity, 0)
        XCTAssertTrue(model.add([item("late")]).isEmpty)
    }

    func testMoveKeepsTheMovedItemsInTheirOwnOrder() {
        let items = ["a", "b", "c", "d", "e"].map { item($0) }
        var model = ShelfModel(items: items)
        // Drag b and d to the front.
        model.move(ids: [items[1].id, items[3].id], to: 0)
        XCTAssertEqual(model.items.map(\.name), ["b", "d", "a", "c", "e"])
        // Drop a after e (index == count, before the move).
        model.move(ids: [items[0].id], to: 5)
        XCTAssertEqual(model.items.map(\.name), ["b", "d", "c", "e", "a"])
        // An index inside the moved block lands them where they were.
        model.move(ids: [items[2].id], to: 3)
        XCTAssertEqual(model.items.map(\.name), ["b", "d", "c", "e", "a"])
    }

    func testSelectionIsReturnedInShelfOrderNotClickOrder() {
        let first = item("1.pdf", kind: .pdf), photo = item("p.jpg", kind: .image), second = item("2.pdf", kind: .pdf)
        let model = ShelfModel(items: [first, photo, second])
        let chosen: Set<UUID> = [second.id, first.id, photo.id]
        XCTAssertEqual(model.selected(chosen, kind: .pdf).map(\.name), ["1.pdf", "2.pdf"])
        XCTAssertEqual(model.selected(chosen, kind: .image).map(\.name), ["p.jpg"])
        XCTAssertEqual(model.selected([photo.id]).map(\.name), ["p.jpg"])
    }

    func testItemKinds() {
        XCTAssertEqual(ShelfItemKind(contentType: .heic, isDirectory: false), .image)
        XCTAssertEqual(ShelfItemKind(contentType: .png, isDirectory: false), .image)
        XCTAssertEqual(ShelfItemKind(contentType: .pdf, isDirectory: false), .pdf)
        XCTAssertEqual(ShelfItemKind(contentType: .folder, isDirectory: true), .folder)
        XCTAssertEqual(ShelfItemKind(contentType: .applicationBundle, isDirectory: true), .other)
        XCTAssertEqual(ShelfItemKind(contentType: .plainText, isDirectory: false), .other)
        XCTAssertEqual(ShelfItemKind(contentType: nil, isDirectory: false), .other)
    }

    // MARK: - Owned-copy safety

    func testDeletesCanOnlyHappenInsideTheOwnedFolder() {
        let owned = URL(fileURLWithPath: "/c/Shelf Files")
        XCTAssertTrue(ShelfLibrary.isInside(URL(fileURLWithPath: "/c/Shelf Files/AB/x.png"), owned))
        XCTAssertFalse(ShelfLibrary.isInside(owned, owned))
        XCTAssertFalse(ShelfLibrary.isInside(URL(fileURLWithPath: "/c/Shelf Files/../shelf.json"), owned))
        XCTAssertFalse(ShelfLibrary.isInside(URL(fileURLWithPath: "/c/Shelf Files Else/x"), owned))
        XCTAssertFalse(ShelfLibrary.isInside(URL(fileURLWithPath: "/Users/me/Documents/x.png"), owned))
    }

    func testOrphanedSlotsAndTrash() {
        XCTAssertEqual(ShelfLibrary.orphanedSlots(present: ["A", "B", ".DS_Store"], referencedPaths: ["A/x.png"]),
                       ["B", ".DS_Store"])
        XCTAssertTrue(ShelfLibrary.isInTrash(URL(fileURLWithPath: "/Users/me/.Trash/x.png")))
        XCTAssertTrue(ShelfLibrary.isInTrash(URL(fileURLWithPath: "/Volumes/USB/.Trashes/501/x.png")))
        XCTAssertFalse(ShelfLibrary.isInTrash(URL(fileURLWithPath: "/Users/me/Trash notes.txt")))
    }

    // MARK: - Library (real files)

    private func makeFile(_ name: String, in folder: String = "files", contents: String = "x") throws -> URL {
        let dir = directory.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func freshLibrary() -> ShelfLibrary {
        let library = ShelfLibrary(directory: directory.appendingPathComponent("support", isDirectory: true))
        library.load()
        return library
    }

    func testShelfSurvivesARelaunchAndDropsVanishedFilesQuietly() throws {
        let one = try makeFile("one.txt"), two = try makeFile("two.txt"), three = try makeFile("three.txt")
        let library = freshLibrary()
        XCTAssertEqual(library.addReferences([one, two, three]).count, 3)
        library.save()
        library.unload()

        XCTAssertEqual(freshLibrary().model.items.map(\.name), ["one.txt", "two.txt", "three.txt"])

        // Deleted → gone without a word; renamed → followed.
        try FileManager.default.removeItem(at: one)
        try FileManager.default.moveItem(at: two, to: two.deletingLastPathComponent().appendingPathComponent("renamed.txt"))
        let relaunched = freshLibrary()
        XCTAssertEqual(relaunched.model.items.map(\.name), ["renamed.txt", "three.txt"])
        XCTAssertTrue(relaunched.model.items.allSatisfy { !$0.isOwnedCopy })
        // …and the saved shelf was rewritten without the dead entry.
        XCTAssertEqual(ShelfLibrary.readRecords(from: relaunched.storeURL).count, 2)
    }

    func testRemovingAReferenceNeverTouchesTheFile() throws {
        let file = try makeFile("keep.txt")
        let library = freshLibrary()
        let added = library.addReferences([file])
        library.remove(ids: Set(added.map(\.id)))
        XCTAssertTrue(library.model.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        _ = library.addReferences([file])
        library.removeAll()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    /// Everything under NSTemporaryDirectory counts as a temporary drop, so
    /// `ingest` takes the macOS 26 path here: a copy in the owned folder.
    func testTemporaryDropsAreCopiedAndOnlyTheCopyIsDeleted() throws {
        let original = try makeFile("from-a-swiftui-app.txt", contents: "payload")
        XCTAssertTrue(ShelfIngest.isTransientDragCopy(path: original.path))
        let library = freshLibrary()
        let added = library.ingest([original])
        let copy = try XCTUnwrap(added.first)
        XCTAssertTrue(copy.isOwnedCopy)
        XCTAssertTrue(ShelfLibrary.isInside(copy.url, library.ownedDirectory))
        XCTAssertEqual(copy.name, "from-a-swiftui-app.txt")

        // The source cleaning up its temporary file no longer matters.
        try FileManager.default.removeItem(at: original)
        library.save()
        library.unload()
        let relaunched = freshLibrary()
        XCTAssertEqual(relaunched.model.items.map(\.name), ["from-a-swiftui-app.txt"])
        XCTAssertEqual(try Data(contentsOf: relaunched.model.items[0].url), Data("payload".utf8))

        relaunched.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.url.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: relaunched.ownedDirectory.path), [])
    }

    func testNamelessDropIsRenamedFromItsContents() throws {
        let nameless = directory.appendingPathComponent(".com.apple.Foundation.NSItemProvider.abc123.tmp")
        try writeImage(width: 8, height: 8, to: nameless, type: .png)
        let library = freshLibrary()
        let copy = try XCTUnwrap(library.ingest([nameless]).first)
        XCTAssertEqual(copy.name, "Dropped Item.png")
        XCTAssertEqual(copy.kind, .image)
    }

    func testLeftoverCopiesAreClearedAtLoad() throws {
        let library = freshLibrary()
        let slot = try XCTUnwrap(library.makeOwnedSlot())
        try Data("orphan".utf8).write(to: slot.appendingPathComponent("lost.png"))
        library.unload()
        let relaunched = freshLibrary()
        XCTAssertFalse(FileManager.default.fileExists(atPath: slot.path))
        XCTAssertTrue(relaunched.model.items.isEmpty)
    }

    // MARK: - Image conversion

    func testResizeNeverEnlarges() {
        XCTAssertNil(ShelfResize.original.targetLongestSide(width: 4000, height: 3000))
        XCTAssertEqual(ShelfResize.px1920.targetLongestSide(width: 4000, height: 3000), 1920)
        XCTAssertEqual(ShelfResize.px1920.targetLongestSide(width: 1000, height: 3000), 1920)
        XCTAssertNil(ShelfResize.px1920.targetLongestSide(width: 1000, height: 800))
        XCTAssertNil(ShelfResize.px1920.targetLongestSide(width: 1920, height: 1080))
    }

    func testHEICIsOfferedOnlyWhereImageIOCanWriteIt() {
        XCTAssertEqual(ShelfImageFormat.available(destinationTypes: ["public.jpeg", "public.png"]), [.jpeg, .png])
        XCTAssertEqual(ShelfImageFormat.available(destinationTypes: ["public.png", "public.heic", "public.jpeg"]), [.jpeg, .png, .heic])
        XCTAssertTrue(ShelfImageFormat.supported.contains(.jpeg))
    }

    func testMetadataIsStrippedOrKept() {
        let source: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyPixelWidth: 4000,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifPixelXDimension: 4000,
                                             kCGImagePropertyExifLensModel: "Lens"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFOrientation: 6, kCGImagePropertyTIFFModel: "Cam"],
        ]
        let stripped = ShelfImageConverter.outputProperties(source: source, stripMetadata: true, quality: 0.8)
        XCTAssertEqual(stripped.count, 1)
        XCTAssertEqual(stripped[kCGImageDestinationLossyCompressionQuality] as? Double, 0.8)

        let kept = ShelfImageConverter.outputProperties(source: source, stripMetadata: false, quality: nil)
        XCTAssertNotNil(kept[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(kept[kCGImagePropertyOrientation] as? Int, 1)
        XCTAssertNil(kept[kCGImagePropertyPixelWidth])
        let tiff = kept[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFOrientation] as? Int, 1)
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFModel] as? String, "Cam")
        let exif = kept[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifPixelXDimension])
        XCTAssertEqual(exif?[kCGImagePropertyExifLensModel] as? String, "Lens")
        XCTAssertNil(kept[kCGImageDestinationLossyCompressionQuality])
    }

    func testOnlyJPEGWithAlphaIsFlattened() {
        XCTAssertTrue(ShelfImageConverter.needsFlatten(format: .jpeg, alphaInfo: .premultipliedLast))
        XCTAssertFalse(ShelfImageConverter.needsFlatten(format: .jpeg, alphaInfo: .noneSkipLast))
        XCTAssertFalse(ShelfImageConverter.needsFlatten(format: .png, alphaInfo: .premultipliedLast))
        XCTAssertFalse(ShelfImageConverter.needsFlatten(format: .heic, alphaInfo: .premultipliedLast))
    }

    private func writeImage(width: Int, height: Int, to url: URL, type: UTType,
                            orientation: Int = 1, gps: Bool = false, alpha: Bool = false) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space, bitmapInfo: info.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: alpha ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
        if gps {
            properties[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude: 51.5,
                                                         kCGImagePropertyGPSLatitudeRef: "N",
                                                         kCGImagePropertyGPSLongitude: 0.12,
                                                         kCGImagePropertyGPSLongitudeRef: "W"]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func properties(of url: URL) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    func testConvertResizesUprightsAndStripsLocation() throws {
        // 1000×500 stored, tagged "rotate 90°": the picture is 500×1000.
        let source = directory.appendingPathComponent("IMG_1.jpg")
        try writeImage(width: 1000, height: 500, to: source, type: .jpeg, orientation: 6, gps: true)
        let out = directory.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let stripped = try ShelfImageConverter.convert(source, to: .jpeg, resize: .px640, stripMetadata: true, into: out)
        XCTAssertEqual(stripped.lastPathComponent, "IMG_1 640px.jpg")
        let props = try properties(of: stripped)
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 320)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 640)
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        XCTAssertNotEqual(props[kCGImagePropertyOrientation] as? Int, 6)

        let kept = try ShelfImageConverter.convert(source, to: .jpeg, resize: .px640, stripMetadata: false, into: out)
        XCTAssertEqual(kept.lastPathComponent, "IMG_1 640px 2.jpg")
        let keptProps = try properties(of: kept)
        XCTAssertNotNil(keptProps[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(keptProps[kCGImagePropertyOrientation] as? Int ?? 1, 1)
        XCTAssertEqual(keptProps[kCGImagePropertyPixelHeight] as? Int, 640)
        // The source is untouched.
        XCTAssertEqual(try properties(of: source)[kCGImagePropertyOrientation] as? Int, 6)
    }

    func testTransparentPNGBecomesAnOpaqueJPEGAtFullSize() throws {
        let source = directory.appendingPathComponent("logo.png")
        try writeImage(width: 40, height: 20, to: source, type: .png, alpha: true)
        let output = try ShelfImageConverter.convert(source, to: .jpeg, resize: .px640, stripMetadata: true, into: directory)
        XCTAssertEqual(output.lastPathComponent, "logo.jpg")
        let props = try properties(of: output)
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 40)
        XCTAssertNotEqual(props[kCGImagePropertyHasAlpha] as? Bool, true)
    }

    func testHEICRoundTripWhereSupported() throws {
        try XCTSkipUnless(ShelfImageFormat.supported.contains(.heic), "No HEIC encoder on this Mac")
        let source = directory.appendingPathComponent("p.png")
        try writeImage(width: 64, height: 48, to: source, type: .png)
        let output = try ShelfImageConverter.convert(source, to: .heic, resize: .original, stripMetadata: true, into: directory)
        XCTAssertEqual(output.pathExtension, "heic")
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetType(imageSource) as String?, UTType.heic.identifier)
    }

    func testUnreadableImageThrowsAndWritesNothing() throws {
        let bogus = try makeFile("not-an-image.jpg", contents: "hello")
        let out = directory.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        XCTAssertThrowsError(try ShelfImageConverter.convert(bogus, to: .png, resize: .original, stripMetadata: true, into: out))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: out.path), [])
    }

    // MARK: - PDF merge

    private func writePDF(pages: Int, side: CGFloat, to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: side, height: side)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
    }

    func testMergeKeepsTheGivenOrder() throws {
        let small = directory.appendingPathComponent("Small.pdf")
        let large = directory.appendingPathComponent("Large.pdf")
        try writePDF(pages: 1, side: 100, to: small)
        try writePDF(pages: 2, side: 200, to: large)
        let merged = try ShelfPDFMerger.merge([large, small], into: directory)
        XCTAssertEqual(merged.lastPathComponent, "Large + 1 more.pdf")
        let document = try XCTUnwrap(PDFDocument(url: merged))
        XCTAssertEqual(document.pageCount, 3)
        XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).width, 200)
        XCTAssertEqual(document.page(at: 2)?.bounds(for: .mediaBox).width, 100)
        // The inputs are untouched.
        XCTAssertEqual(PDFDocument(url: small)?.pageCount, 1)
        XCTAssertEqual(PDFDocument(url: large)?.pageCount, 2)
    }

    func testMergeOfNothingOrJunkFails() throws {
        XCTAssertThrowsError(try ShelfPDFMerger.merge([], into: directory))
        let junk = try makeFile("junk.pdf", contents: "not a pdf")
        XCTAssertThrowsError(try ShelfPDFMerger.merge([junk, junk], into: directory))
    }
}
