import XCTest
@testable import FramePickerCore

final class ExportNamingTests: XCTestCase {
    func testFilenameUsesThreeDigitsForNormalSequence() {
        XCTAssertEqual(ExportNaming.filename(index: 0, totalCount: 8), "001.png")
        XCTAssertEqual(ExportNaming.filename(index: 7, totalCount: 8), "008.png")
    }

    func testFilenameExpandsForLargeSequence() {
        XCTAssertEqual(ExportNaming.filename(index: 999, totalCount: 1_000), "1000.png")
    }

    func testFolderNameIsStable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 8,
            hour: 13,
            minute: 49,
            second: 43
        ))!

        XCTAssertEqual(
            ExportNaming.folderName(date: date, calendar: calendar),
            "FramePicker-20260808-134943"
        )
    }
}
