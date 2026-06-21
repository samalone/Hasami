import Testing
import Hasami

struct DurationParserTests {
    @Test func parsesSuffixedDurations() {
        #expect(DurationParser.seconds(from: "45s") == 45.0)
        #expect(DurationParser.seconds(from: "90m") == 5400.0)
        #expect(DurationParser.seconds(from: "12h") == 43200.0)
        #expect(DurationParser.seconds(from: "30d") == 2_592_000.0)
        #expect(DurationParser.seconds(from: "2w") == 1_209_600.0)
    }

    @Test func bareNumberIsSeconds() {
        #expect(DurationParser.seconds(from: "3600") == 3600.0)
    }

    @Test func acceptsFractionalAndWhitespaceAndCase() {
        #expect(DurationParser.seconds(from: "1.5d") == 129_600.0)
        #expect(DurationParser.seconds(from: "  7D  ") == 604_800.0)
    }

    @Test func rejectsInvalidInput() {
        #expect(DurationParser.seconds(from: "") == nil)
        #expect(DurationParser.seconds(from: "d") == nil)
        #expect(DurationParser.seconds(from: "abc") == nil)
        #expect(DurationParser.seconds(from: "0d") == nil)     // not positive
        #expect(DurationParser.seconds(from: "-5h") == nil)    // not positive
        #expect(DurationParser.seconds(from: "10y") == nil)    // unsupported suffix
    }
}
