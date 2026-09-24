import Flutter
import UIKit
import XCTest


@testable import native_file_picker

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = NativeFilePickerPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testProcessPickedFilesPreservesOriginalFilename() throws {
    let plugin = NativeFilePickerPlugin()
    let fileManager = FileManager.default

    let sourceURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("document_test.pdf")
    try Data("test content".utf8).write(to: sourceURL)
    defer {
      try? fileManager.removeItem(at: sourceURL)
    }

    let files = plugin.processPickedFiles([sourceURL])
    XCTAssertNotNil(files)
    let file = files?.first
    XCTAssertEqual(file?["name"] as? String, "document_test.pdf")
    XCTAssertEqual(file?["extension"] as? String, "pdf")

    guard let path = file?["path"] as? String else {
      return XCTFail("Expected a path to be returned")
    }
    let storedURL = URL(fileURLWithPath: path)
    XCTAssertEqual(storedURL.lastPathComponent, "document_test.pdf")
    XCTAssertTrue(fileManager.fileExists(atPath: path))
    XCTAssertEqual(storedURL.pathExtension, "pdf")
    XCTAssertEqual(try Data(contentsOf: storedURL), Data("test content".utf8))

    try? fileManager.removeItem(at: storedURL.deletingLastPathComponent())
  }

}
