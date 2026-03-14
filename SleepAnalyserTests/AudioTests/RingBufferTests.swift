import XCTest
@testable import SleepAnalyser

final class RingBufferTests: XCTestCase {
    func test_writeAndRead() {
        let buffer = RingBuffer<Int>(capacity: 5)
        buffer.write(1)
        buffer.write(2)
        buffer.write(3)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.readAll(), [1, 2, 3])
    }

    func test_overflowWraps() {
        let buffer = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { buffer.write(i) }
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.readAll(), [3, 4, 5])
    }

    func test_readLastN() {
        let buffer = RingBuffer<Int>(capacity: 10)
        for i in 1...7 { buffer.write(i) }
        XCTAssertEqual(buffer.readLast(3), [5, 6, 7])
    }

    func test_emptyBuffer() {
        let buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.readAll(), [])
    }

    func test_clear() {
        let buffer = RingBuffer<Int>(capacity: 5)
        buffer.write(1)
        buffer.write(2)
        buffer.clear()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
    }
}
