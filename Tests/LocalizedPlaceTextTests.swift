import XCTest
@testable import SheltersKit

final class LocalizedPlaceTextTests: XCTestCase {
    func testBestValuePrefersSelectedLanguageThenEnglishThenOriginal() {
        let text = LocalizedPlaceText(
            original: "מקלט",
            english: "Shelter",
            russian: nil,
            hebrew: "מקלט"
        )

        XCTAssertEqual(text.bestValue(for: .hebrew), "מקלט")
        XCTAssertEqual(text.bestValue(for: .russian), "Shelter")
        XCTAssertEqual(text.bestValue(for: .english), "Shelter")
    }
}

