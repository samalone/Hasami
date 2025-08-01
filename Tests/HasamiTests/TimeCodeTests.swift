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
    }
    
    @Test func testDigitComputation() {
        let timeCode: TimeCode = 42
        
        // Test base 2 (binary)
        #expect(timeCode.digit(at: 0, base: 2) == 0)  // 42 in binary: 101010
        #expect(timeCode.digit(at: 1, base: 2) == 1)
        #expect(timeCode.digit(at: 2, base: 2) == 0)
        #expect(timeCode.digit(at: 3, base: 2) == 1)
        #expect(timeCode.digit(at: 4, base: 2) == 0)
        #expect(timeCode.digit(at: 5, base: 2) == 1)
        
        // Test base 3
        #expect(timeCode.digit(at: 0, base: 3) == 0)  // 42 in base 3: 1120
        #expect(timeCode.digit(at: 1, base: 3) == 2)
        #expect(timeCode.digit(at: 2, base: 3) == 1)
        #expect(timeCode.digit(at: 3, base: 3) == 1)
        
        // Test base 10 (decimal)
        #expect(timeCode.digit(at: 0, base: 10) == 2)  // 42 in decimal: 42
        #expect(timeCode.digit(at: 1, base: 10) == 4)
        
        // Test zero
        let zero: TimeCode = 0
        #expect(zero.digit(at: 0, base: 2) == 0)
        #expect(zero.digit(at: 0, base: 10) == 0)
    }
    
    @Test func testDigitCount() {
        let timeCode: TimeCode = 42
        
        #expect(timeCode.digitCount(base: 2) == 6)   // 101010
        #expect(timeCode.digitCount(base: 3) == 4)   // 1120
        #expect(timeCode.digitCount(base: 10) == 2)  // 42
        
        let zero: TimeCode = 0
        #expect(zero.digitCount(base: 2) == 1)
        #expect(zero.digitCount(base: 10) == 1)
        
        let one: TimeCode = 1
        #expect(one.digitCount(base: 2) == 1)
        #expect(one.digitCount(base: 10) == 1)
    }
    
    @Test func testMostSignificantDifferingDigitPosition() {
        let timeCode1: TimeCode = 42   // 101010 in binary
        let timeCode2: TimeCode = 45   // 101101 in binary
        let timeCode3: TimeCode = 42   // Same as timeCode1
        
        // Test with base 2
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, base: 2) == 2)
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode3, base: 2) == nil)
        
        // Test with base 3
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, base: 3) == 2)
        
        // Test with different lengths
        let timeCode4: TimeCode = 7    // 111 in binary
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode4, base: 2) == 5)
    }
}