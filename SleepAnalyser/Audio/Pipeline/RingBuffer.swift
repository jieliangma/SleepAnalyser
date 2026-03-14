import Foundation

final class RingBuffer<Element: Sendable>: @unchecked Sendable {
    private var storage: [Element?]
    private var writeIndex: Int = 0
    private var count_: Int = 0
    private let lock = NSLock()
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Element?](repeating: nil, count: capacity)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return count_
    }

    var isEmpty: Bool { count == 0 }

    func write(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count_ = min(count_ + 1, capacity)
    }

    func readLast(_ n: Int) -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        let readCount = min(n, count_)
        guard readCount > 0 else { return [] }

        var result = [Element]()
        result.reserveCapacity(readCount)
        for i in 0..<readCount {
            let idx = (writeIndex - readCount + i + capacity) % capacity
            if let elem = storage[idx] { result.append(elem) }
        }
        return result
    }

    func readAll() -> [Element] { readLast(count) }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage = [Element?](repeating: nil, count: capacity)
        writeIndex = 0
        count_ = 0
    }
}
