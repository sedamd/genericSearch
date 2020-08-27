import XCTest
@testable import genericSearchLib

final class genericSearchLibTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(genericSearchLib().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
