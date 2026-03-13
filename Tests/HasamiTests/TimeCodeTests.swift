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

    @Test func testDigitComputation() {
        let timeCode: TimeCode = 42

        // Test radix 2 (binary)
        #expect(timeCode.digit(at: 0, radix: 2) == 0)  // 42 in binary: 101010
        #expect(timeCode.digit(at: 1, radix: 2) == 1)
        #expect(timeCode.digit(at: 2, radix: 2) == 0)
        #expect(timeCode.digit(at: 3, radix: 2) == 1)
        #expect(timeCode.digit(at: 4, radix: 2) == 0)
        #expect(timeCode.digit(at: 5, radix: 2) == 1)

        // Test radix 3
        #expect(timeCode.digit(at: 0, radix: 3) == 0)  // 42 in base 3: 1120
        #expect(timeCode.digit(at: 1, radix: 3) == 2)
        #expect(timeCode.digit(at: 2, radix: 3) == 1)
        #expect(timeCode.digit(at: 3, radix: 3) == 1)

        // Test radix 10 (decimal)
        #expect(timeCode.digit(at: 0, radix: 10) == 2)  // 42 in decimal: 42
        #expect(timeCode.digit(at: 1, radix: 10) == 4)

        // Test zero
        let zero: TimeCode = 0
        #expect(zero.digit(at: 0, radix: 2) == 0)
        #expect(zero.digit(at: 0, radix: 10) == 0)
    }

    @Test func testDigitCount() {
        let timeCode: TimeCode = 42

        #expect(timeCode.digitCount(radix: 2) == 6)   // 101010
        #expect(timeCode.digitCount(radix: 3) == 4)   // 1120
        #expect(timeCode.digitCount(radix: 10) == 2)  // 42

        let zero: TimeCode = 0
        #expect(zero.digitCount(radix: 2) == 1)
        #expect(zero.digitCount(radix: 10) == 1)

        let one: TimeCode = 1
        #expect(one.digitCount(radix: 2) == 1)
        #expect(one.digitCount(radix: 10) == 1)
    }

    @Test func testMostSignificantDifferingDigitPosition() {
        let timeCode1: TimeCode = 42   // 101010 in binary
        let timeCode2: TimeCode = 45   // 101101 in binary
        let timeCode3: TimeCode = 42   // Same as timeCode1

        // Test with radix 2
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, radix: 2) == 2)
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode3, radix: 2) == nil)

        // Test with radix 3
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, radix: 3) == 2)

        // Test with different lengths
        let timeCode4: TimeCode = 7    // 111 in binary
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode4, radix: 2) == 5)
    }
}
