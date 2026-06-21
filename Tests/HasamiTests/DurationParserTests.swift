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

    @Test func rejectsNonFiniteValues() {
        // `Double` parses these, but an infinite half-life produces a degenerate
        // retention curve (and would crash the verbose duration formatter).
        #expect(DurationParser.seconds(from: "inf") == nil)
        #expect(DurationParser.seconds(from: "infinity") == nil)
        #expect(DurationParser.seconds(from: "nan") == nil)
        #expect(DurationParser.seconds(from: "1e400") == nil)   // overflows to +inf
        #expect(DurationParser.seconds(from: "1e400w") == nil)  // suffix product overflows
    }
}

struct RetentionPolicyTests {
    @Test func defaultsToRelativeFourWhenNeitherGiven() throws {
        #expect(try RetentionPolicy.resolve(halfLife: nil, halfLives: nil) == .halfLivesAcrossSpan(4))
    }

    @Test func absoluteParsesDuration() throws {
        #expect(try RetentionPolicy.resolve(halfLife: "30d", halfLives: nil) == .absoluteHalfLife(seconds: 2_592_000))
    }

    @Test func relativeUsesGivenValue() throws {
        #expect(try RetentionPolicy.resolve(halfLife: nil, halfLives: 8) == .halfLivesAcrossSpan(8))
    }

    @Test func rejectsConflictingOptions() {
        #expect(throws: RetentionPolicyError.conflictingHalfLifeOptions) {
            try RetentionPolicy.resolve(halfLife: "1d", halfLives: 4)
        }
    }

    @Test func rejectsInvalidDuration() {
        #expect(throws: RetentionPolicyError.invalidDuration("nope")) {
            try RetentionPolicy.resolve(halfLife: "nope", halfLives: nil)
        }
    }

    @Test func rejectsNonPositiveHalfLives() {
        #expect(throws: RetentionPolicyError.nonPositiveHalfLives) {
            try RetentionPolicy.resolve(halfLife: nil, halfLives: 0)
        }
    }
}
