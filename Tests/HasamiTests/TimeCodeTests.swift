import Foundation
import Testing
import Hasami

struct TimeCodeTests {
    @Test func testTimeCodeCreation() {
        let timeCode: TimeCode = 42
        #expect(timeCode.value == 42)

        let dateTimeCode: TimeCode = "2024-03-20T12:00:00Z"
        let expectedValue = Int(ISO8601DateFormatter().date(from: "2024-03-20T12:00:00Z")!.timeIntervalSince1970)
        #expect(dateTimeCode.value == expectedValue)

        // Test init(date:)
        let date = Date(timeIntervalSince1970: 1000)
        let fromDate = TimeCode(date: date)
        #expect(fromDate.value == 1000)
    }

    @Test func testTimeCodeDescription() {
        let timeCode = TimeCode(value: 42)
        #expect(timeCode.description == "42")
        #expect(String(describing: timeCode) == "42")
    }
}
