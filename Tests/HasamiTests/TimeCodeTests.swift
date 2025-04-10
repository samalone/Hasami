import Foundation
import Testing
import Hasami

struct TimeCodeTests {
    @Test func testTimeCodeCreation() {
        let timeCode = TimeCode(value: 42)
        #expect(timeCode.value == 42)
        
        let date = Date()
        let dateTimeCode = TimeCode(date: date)
        #expect(dateTimeCode.value == Int(date.timeIntervalSince1970))
    }
    
    @Test func testDigitComputation() {
        let timeCode = TimeCode(value: 42)
        
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
        let zero = TimeCode(value: 0)
        #expect(zero.digit(at: 0, base: 2) == 0)
        #expect(zero.digit(at: 0, base: 10) == 0)
    }
    
    @Test func testDigitCount() {
        let timeCode = TimeCode(value: 42)
        
        #expect(timeCode.digitCount(base: 2) == 6)   // 101010
        #expect(timeCode.digitCount(base: 3) == 4)   // 1120
        #expect(timeCode.digitCount(base: 10) == 2)  // 42
        
        let zero = TimeCode(value: 0)
        #expect(zero.digitCount(base: 2) == 1)
        #expect(zero.digitCount(base: 10) == 1)
        
        let one = TimeCode(value: 1)
        #expect(one.digitCount(base: 2) == 1)
        #expect(one.digitCount(base: 10) == 1)
    }
    
    @Test func testMostSignificantDifferingDigitPosition() {
        let timeCode1 = TimeCode(value: 42)   // 101010 in binary
        let timeCode2 = TimeCode(value: 45)   // 101101 in binary
        let timeCode3 = TimeCode(value: 42)   // Same as timeCode1
        
        // Test with base 2
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, base: 2) == 2)
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode3, base: 2) == nil)
        
        // Test with base 3
        // 42 in base 3 is 1120
        // 45 in base 3 is 1200
        // The most significant differing digit is at position 2 (1120 vs 1200)
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode2, base: 3) == 2)
        
        // Test with different lengths
        let timeCode4 = TimeCode(value: 7)    // 111 in binary
        #expect(timeCode1.mostSignificantDifferingDigitPosition(from: timeCode4, base: 2) == 5)
    }
}