import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class NativeFilePickerPlugin: NSObject, FlutterPlugin {
  private var result: FlutterResult?
  private var presentingViewController: UIViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_file_picker", binaryMessenger: registrar.messenger())
    let instance = NativeFilePickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    self.result = result

    switch call.method {
    case "pickFiles":
      pickFiles(call: call, result: result)
    case "getDirectoryPath":
      getDirectoryPath(result: result)
    case "clearTemporaryFiles":
      clearTemporaryFiles(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
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
      if let viewController = self.getRootViewController() {
        self.presentingViewController = viewController
        viewController.present(documentPicker, animated: true, completion: nil)
      } else {
        result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
      }
    }
  }

  private func getRootViewController() -> UIViewController? {
    // For iOS 13+ use scene-based approach
    if #available(iOS 13.0, *) {
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
        return window.rootViewController
      }
      
      // Fallback for iOS 13+ if scene approach fails
      return UIApplication.shared.windows.first?.rootViewController
    } else {
      // For iOS 12 and below
      if let keyWindow = UIApplication.shared.keyWindow {
        return keyWindow.rootViewController
      }
      
      return UIApplication.shared.windows.first?.rootViewController
    }
  }

  private func getDirectoryPath(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)
      documentPicker.delegate = self
      documentPicker.allowsMultipleSelection = false

      if let viewController = self.getRootViewController() {
        self.presentingViewController = viewController
        viewController.present(documentPicker, animated: true, completion: nil)
      } else {
        result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
      }
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

  private func processPickedFiles(_ urls: [URL]) -> [[String: Any]]? {
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
        let fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension

        // Create a more robust temporary file handling
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "native_file_picker_\(UUID().uuidString)_\(fileName)"
        let tempURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(tempFileName)

        // Simple file copy without coordinator to avoid complexities
        do {
          let fileData = try Data(contentsOf: url)
          try fileData.write(to: tempURL)
        } catch {
          print("Error copying file: \(error)")
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
