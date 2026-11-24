import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class NativeFilePickerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var result: FlutterResult?
  private var presentingViewController: UIViewController?
  private var progressSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_file_picker", binaryMessenger: registrar.messenger())
    let progressChannel = FlutterEventChannel(name: "native_file_picker/progress", binaryMessenger: registrar.messenger())
    let instance = NativeFilePickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    progressChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    self.result = result

    switch call.method {
    case "pickFiles":
      pickFiles(call: call, result: result)
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getDirectoryPath":
      getDirectoryPath(result: result)
    case "clearTemporaryFiles":
      clearTemporaryFiles(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    progressSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    progressSink = nil
    return nil
  }

  private func pickFiles(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    let allowMultiple = args["allowMultiple"] as? Bool ?? false
    let type = args["type"] as? String ?? "any"
    let allowedExtensions = args["allowedExtensions"] as? [String]

    DispatchQueue.main.async {
      self.presentDocumentPicker(
        allowMultiple: allowMultiple,
        type: type,
        allowedExtensions: allowedExtensions,
        result: result
      )
    }
  }

  private func presentDocumentPicker(allowMultiple: Bool, type: String, allowedExtensions: [String]?, result: @escaping FlutterResult) {
    var documentTypes: [String] = []

    switch type {
    case "image":
      if #available(iOS 14.0, *) {
        documentTypes = [UTType.image.identifier]
      } else {
        documentTypes = [kUTTypeImage as String]
      }
    case "video":
      if #available(iOS 14.0, *) {
        documentTypes = [UTType.movie.identifier]
      } else {
        documentTypes = [kUTTypeMovie as String]
      }
    case "audio":
      if #available(iOS 14.0, *) {
        documentTypes = [UTType.audio.identifier]
      } else {
        documentTypes = [kUTTypeAudio as String]
      }
    case "media":
      if #available(iOS 14.0, *) {
        documentTypes = [UTType.image.identifier, UTType.movie.identifier, UTType.audio.identifier]
      } else {
        documentTypes = [kUTTypeImage as String, kUTTypeMovie as String, kUTTypeAudio as String]
      }
    case "custom":
      if let extensions = allowedExtensions {
        documentTypes = extensions.compactMap { ext in
          if #available(iOS 14.0, *) {
            return UTType(filenameExtension: ext)?.identifier
          } else {
            return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeRetainedValue() as String?
          }
        }
      }
      if documentTypes.isEmpty {
        if #available(iOS 14.0, *) {
          documentTypes = [UTType.data.identifier]
        } else {
          documentTypes = [kUTTypeData as String]
        }
      }
    default:
      if #available(iOS 14.0, *) {
        documentTypes = [UTType.data.identifier]
      } else {
        documentTypes = [kUTTypeData as String]
      }
    }

    let documentPicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = allowMultiple
    
    // Use .overFullScreen to avoid some view service issues
    documentPicker.modalPresentationStyle = .overFullScreen
    
    // Disable thumbnail generation to avoid the QLThumbnailErrorDomain errors
    if #available(iOS 13.0, *) {
      documentPicker.shouldShowFileExtensions = true
      // Don't set directoryURL as it can cause issues with CloudDocs
    }

    // Add a small delay to ensure the view hierarchy is stable
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      guard let presenter = self.getRootViewController(), presenter.view.window != nil else {
        result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
        return
      }
      self.presentingViewController = presenter
      presenter.present(documentPicker, animated: true, completion: nil)
    }
  }

  /// Top-most view controller that can present a modal in the active window.
  /// Walking `presentedViewController` avoids presenting on the window root
  /// while it is already presenting something (modal / SwiftUI / add-to-app),
  /// which fails with "already presenting" or "view is not in the window
  /// hierarchy".
  private func getRootViewController() -> UIViewController? {
    guard let window = Self.activeWindow() else { return nil }
    var top = window.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private static func activeWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
      let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
      return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    } else {
      return UIApplication.shared.keyWindow
    }
  }

  private func getDirectoryPath(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)
      documentPicker.delegate = self
      documentPicker.allowsMultipleSelection = false

      guard let presenter = self.getRootViewController(), presenter.view.window != nil else {
        result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
        return
      }
      self.presentingViewController = presenter
      presenter.present(documentPicker, animated: true, completion: nil)
    }
  }

  private func clearTemporaryFiles(result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    let tempDirectory = NSTemporaryDirectory()
    let tempURL = URL(fileURLWithPath: tempDirectory)

    do {
      let tempFiles = try fileManager.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil, options: [])

      for file in tempFiles {
        if file.lastPathComponent.hasPrefix("native_file_picker_") {
          try fileManager.removeItem(at: file)
        }
      }

      result(true)
    } catch {
      result(FlutterError(code: "CLEAR_ERROR", message: "Failed to clear temporary files: \(error.localizedDescription)", details: nil))
    }
  }

  func processPickedFiles(_ urls: [URL]) -> [[String: Any]]? {
    var files: [[String: Any]] = []

    for url in urls {
      // Start accessing security scoped resource
      let accessing = url.startAccessingSecurityScopedResource()
      
      defer {
        if accessing {
          url.stopAccessingSecurityScopedResource()
        }
      }

      do {
        // Get file attributes with error handling
        var resourceValues: URLResourceValues
        do {
          resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .isRegularFileKey])
        } catch {
          print("Error getting resource values for \(url): \(error)")
          continue
        }
        
        // Ensure it's a regular file, not a directory
        guard resourceValues.isRegularFile == true else {
          print("Skipping non-regular file: \(url)")
          continue
        }
        
        let fileName = resourceValues.name ?? url.lastPathComponent
        let fileSize = resourceValues.fileSize ?? 0
        let fileExtension = (fileName as NSString).pathExtension.isEmpty ? nil : (fileName as NSString).pathExtension

        let tempDirectory = NSTemporaryDirectory()
        let pickDirectory = URL(fileURLWithPath: tempDirectory)
          .appendingPathComponent("native_file_picker_\(UUID().uuidString)", isDirectory: true)

        do {
          try FileManager.default.createDirectory(at: pickDirectory, withIntermediateDirectories: true)
        } catch {
          print("Error creating temporary directory: \(error)")
          continue
        }

        let tempURL = pickDirectory.appendingPathComponent(fileName)

        // Stream-copy the file (instead of loading it fully into memory) so
        // large media does not spike memory, and report copy progress.
        guard copyFileWithProgress(from: url, to: tempURL, totalBytes: Int64(fileSize)) != nil else {
          print("Error copying file: \(url)")
          continue
        }

        let fileMap: [String: Any] = [
          "name": fileName,
          "path": tempURL.path,
          "size": fileSize,
          "extension": fileExtension as Any,
          "identifier": url.absoluteString
        ]

        files.append(fileMap)

      } catch {
        print("Unexpected error processing file \(url): \(error)")
        continue
      }
    }

    return files.isEmpty ? nil : files
  }

  /// Copies a file in chunks via streams and emits 0.0..1.0 progress events.
  private func copyFileWithProgress(from sourceURL: URL, to destinationURL: URL, totalBytes: Int64) -> Int64? {
    guard let input = InputStream(url: sourceURL) else { return nil }
    guard let output = OutputStream(url: destinationURL, append: false) else { return nil }

    input.open()
    output.open()
    defer {
      input.close()
      output.close()
    }

    emitProgress(0)

    let bufferSize = 64 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var copied: Int64 = 0
    var lastReported: Double = -1

    while true {
      let readCount = input.read(buffer, maxLength: bufferSize)
      if readCount < 0 {
        print("Read error while copying file: \(String(describing: input.streamError))")
        return nil
      }
      if readCount == 0 { break }

      let written = output.write(buffer, maxLength: readCount)
      if written < 0 || written == 0 {
        print("Write error while copying file: \(String(describing: output.streamError))")
        return nil
      }

      copied += Int64(written)

      if totalBytes > 0 {
        let fraction = Double(copied) / Double(totalBytes)
        if fraction - lastReported >= 0.01 || fraction >= 1.0 {
          lastReported = fraction
          emitProgress(min(fraction, 1.0))
        }
      }
    }

    emitProgress(1.0)
    return copied
  }

  private func emitProgress(_ fraction: Double) {
    DispatchQueue.main.async {
      self.progressSink?(min(max(fraction, 0.0), 1.0))
    }
  }
}

extension NativeFilePickerPlugin: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = self.result else { return }

    // Dismiss the picker immediately to avoid view service issues
    controller.dismiss(animated: true) {
      if urls.isEmpty {
        result(nil)
        return
      }

      // Check if this is a directory picker (for getDirectoryPath)
      if urls.count == 1 && urls[0].hasDirectoryPath {
        result(urls[0].absoluteString)
        return
      }

      // Process picked files in background queue to avoid blocking UI
      DispatchQueue.global(qos: .userInitiated).async {
        if let processedFiles = self.processPickedFiles(urls) {
          let resultMap = ["files": processedFiles]
          DispatchQueue.main.async {
            result(resultMap)
          }
        } else {
          DispatchQueue.main.async {
            result(nil)
          }
        }
      }
    }
    
    self.result = nil
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    controller.dismiss(animated: true) {
      self.result?(nil)
      self.result = nil
    }
  }
}