package com.example.native_file_picker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.annotation.NonNull
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream

class NativeFilePickerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var result: Result? = null

    companion object {
        private const val REQUEST_CODE_PICK_FILE = 1001
        private const val REQUEST_CODE_PICK_DIRECTORY = 1002
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_file_picker")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "pickFiles" -> pickFiles(call, result)
            "getDirectoryPath" -> getDirectoryPath(result)
            "clearTemporaryFiles" -> clearTemporaryFiles(result)
            else -> result.notImplemented()
        }
    }

    private fun pickFiles(call: MethodCall, result: Result) {
        this.result = result

        val allowMultiple = call.argument<Boolean>("allowMultiple") ?: false
        val type = call.argument<String>("type") ?: "any"
        val allowedExtensions = call.argument<List<String>>("allowedExtensions")

        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)

            when (type) {
                "image" -> this.type = "image/*"
                "video" -> this.type = "video/*"
                "audio" -> this.type = "audio/*"
                "media" -> this.type = "*/*"
                "custom" -> {
                    if (allowedExtensions != null && allowedExtensions.isNotEmpty()) {
                        if (allowedExtensions.size == 1) {
                            this.type = getMimeType(allowedExtensions[0])
                        } else {
                            this.type = "*/*"
                        }
                    } else {
                        this.type = "*/*"
                    }
                }

                else -> this.type = "*/*"
            }

            if (allowMultiple && Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }

        try {
            activity?.startActivityForResult(
                Intent.createChooser(intent, "Select File(s)"),
                REQUEST_CODE_PICK_FILE
            )
        } catch (e: Exception) {
            result.error("ACTIVITY_ERROR", "Failed to start file picker: ${e.message}", null)
        }
    }

    private fun getDirectoryPath(result: Result) {
        this.result = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)

        try {
            activity?.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
        } catch (e: Exception) {
            result.error("ACTIVITY_ERROR", "Failed to start directory picker: ${e.message}", null)
        }
    }

    private fun clearTemporaryFiles(result: Result) {
        try {
            val tempDir = File(activity?.cacheDir, "file_picker")
            if (tempDir.exists()) {
                val deleted = tempDir.deleteRecursively()
                result.success(deleted)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("CLEAR_ERROR", "Failed to clear temporary files: ${e.message}", null)
        }
    }

    private fun getMimeType(extension: String): String {
        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
        return mimeType ?: "*/*"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_PICK_FILE -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    handleFilePickResult(data)
                } else {
                    result?.success(null)
                }
                return true
            }

            REQUEST_CODE_PICK_DIRECTORY -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    handleDirectoryPickResult(data)
                } else {
                    result?.success(null)
                }
                return true
            }
        }
        return false
    }

    private fun handleFilePickResult(data: Intent) {
        try {
            val files = mutableListOf<Map<String, Any?>>()

            if (data.clipData != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                // Multiple files selected
                for (i in 0 until data.clipData!!.itemCount) {
                    val uri = data.clipData!!.getItemAt(i).uri
                    processFileUri(uri, files)
                }
            } else if (data.data != null) {
                // Single file selected
                processFileUri(data.data!!, files)
            }

            if (files.isNotEmpty()) {
                result?.success(mapOf("files" to files))
            } else {
                result?.success(null)
            }
        } catch (e: Exception) {
            result?.error(
                "PROCESSING_ERROR",
                "Failed to process selected files: ${e.message}",
                null
            )
        }
    }

    private fun processFileUri(uri: Uri, files: MutableList<Map<String, Any?>>) {
        try {
            val context = activity ?: return

            var fileName = "unknown"
            var fileSize = 0L
            var filePath = ""

            // Get file info using content resolver
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)

                    if (nameIndex != -1) {
                        fileName = cursor.getString(nameIndex) ?: "unknown"
                    }
                    if (sizeIndex != -1) {
                        fileSize = cursor.getLong(sizeIndex)
                    }
                }
            }

            // Copy file to app's cache directory
            val tempDir = File(context.cacheDir, "file_picker")
            if (!tempDir.exists()) {
                tempDir.mkdirs()
            }

            val tempFile = File(tempDir, fileName)
            context.contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(tempFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            filePath = tempFile.absolutePath

            val extension = fileName.substringAfterLast('.', "")

            @Suppress("UNCHECKED_CAST")
            val fileMap = mapOf<String, Any>(
                "name" to fileName,
                "path" to filePath,
                "size" to (if (fileSize > 0) fileSize else tempFile.length()).toInt(),
                "extension" to (if (extension.isNotEmpty()) extension else ""),
                "identifier" to uri.toString()
            )


            files.add(fileMap)
        } catch (e: Exception) {
            // Log error but continue processing other files
            e.printStackTrace()
        }
    }

    private fun handleDirectoryPickResult(data: Intent) {
        try {
            val uri = data.data
            if (uri != null) {
                val documentFile = DocumentFile.fromTreeUri(activity!!, uri)
                result?.success(documentFile?.uri?.toString())
            } else {
                result?.success(null)
            }
        } catch (e: Exception) {
            result?.error(
                "DIRECTORY_ERROR",
                "Failed to process directory selection: ${e.message}",
                null
            )
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}