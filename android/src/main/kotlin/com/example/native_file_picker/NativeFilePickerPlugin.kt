package com.example.native_file_picker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.annotation.NonNull
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeFilePickerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var progressChannel: EventChannel? = null
    private var progressSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var result: Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val copyExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    companion object {
        private const val REQUEST_CODE_PICK_FILE = 1001
        private const val REQUEST_CODE_PICK_DIRECTORY = 1002
        private const val PROGRESS_THRESHOLD = 0.01
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_file_picker")
        channel.setMethodCallHandler(this)

        progressChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "native_file_picker/progress"
        )
        progressChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "pickFiles" -> pickFiles(call, result)
            "getPlatformVersion" -> result.success("Android " + android.os.Build.VERSION.RELEASE)
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
            this.result = null
            result.error("ACTIVITY_ERROR", "Failed to start file picker: ${e.message}", null)
        }
    }

    private fun getDirectoryPath(result: Result) {
        this.result = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)

        try {
            activity?.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
        } catch (e: Exception) {
            this.result = null
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
                val pendingResult = result
                result = null
                if (resultCode == Activity.RESULT_OK && data != null) {
                    handleFilePickResult(data, pendingResult)
                } else {
                    pendingResult?.success(null)
                }
                return true
            }

            REQUEST_CODE_PICK_DIRECTORY -> {
                val pendingResult = result
                result = null
                if (resultCode == Activity.RESULT_OK && data != null) {
                    handleDirectoryPickResult(data, pendingResult)
                } else {
                    pendingResult?.success(null)
                }
                return true
            }
        }
        return false
    }

    /**
     * Copies the selected files into the cache directory on a background
     * thread so the main/UI (and therefore the Flutter UI) thread is never
     * blocked by a large file copy.
     */
    private fun handleFilePickResult(data: Intent, pendingResult: Result?) {
        copyExecutor.execute {
            try {
                val files = mutableListOf<Map<String, Any?>>()

                if (data.clipData != null &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2
                ) {
                    // Multiple files selected
                    for (i in 0 until data.clipData!!.itemCount) {
                        val uri = data.clipData!!.getItemAt(i).uri
                        processFileUri(uri, files)
                    }
                } else if (data.data != null) {
                    // Single file selected
                    processFileUri(data.data!!, files)
                }

                val fileResult: Map<String, Any>? =
                    if (files.isNotEmpty()) mapOf("files" to files) else null

                mainHandler.post {
                    pendingResult?.success(fileResult)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    pendingResult?.error(
                        "PROCESSING_ERROR",
                        "Failed to process selected files: ${e.message}",
                        null
                    )
                }
            }
        }
    }

    private fun processFileUri(uri: Uri, files: MutableList<Map<String, Any?>>) {
        try {
            val context = activity ?: return

            var fileName = "unknown"
            var fileSize = 0L

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
            copyFileWithProgress(uri, tempFile, fileSize, context)

            val extension = fileName.substringAfterLast('.', "")

            // Use Long (not Int) so files larger than 2 GB do not overflow.
            val resolvedSize = if (fileSize > 0) fileSize else tempFile.length()

            @Suppress("UNCHECKED_CAST")
            val fileMap = mapOf<String, Any>(
                "name" to fileName,
                "path" to tempFile.absolutePath,
                "size" to resolvedSize,
                "extension" to (if (extension.isNotEmpty()) extension else ""),
                "identifier" to uri.toString()
            )

            files.add(fileMap)
        } catch (e: Exception) {
            // Log error but continue processing other files
            e.printStackTrace()
        }
    }

    /**
     * Streams the file into the given target in chunks on the calling
     * (background) thread and reports copy progress through the event channel.
     */
    private fun copyFileWithProgress(
        uri: Uri,
        target: File,
        totalBytes: Long,
        context: Context
    ) {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var lastReported = -1.0

        context.contentResolver.openInputStream(uri)?.use { inputStream ->
            BufferedInputStream(inputStream).use { bufferedInput ->
                FileOutputStream(target).use { fileOutput ->
                    BufferedOutputStream(fileOutput).use { bufferedOutput ->
                        var copied = 0L
                        while (true) {
                            val read = bufferedInput.read(buffer)
                            if (read == -1) break
                            bufferedOutput.write(buffer, 0, read)
                            copied += read

                            if (totalBytes > 0) {
                                val fraction = copied.toDouble() / totalBytes.toDouble()
                                if (fraction - lastReported >= PROGRESS_THRESHOLD ||
                                    fraction >= 1.0
                                ) {
                                    lastReported = fraction
                                    reportProgress(fraction.coerceIn(0.0, 1.0))
                                }
                            }
                        }
                        bufferedOutput.flush()
                    }
                }
            }
        }

        // Ensure the stream settles at 100% even when the source size is unknown.
        reportProgress(1.0)
    }

    private fun reportProgress(fraction: Double) {
        mainHandler.post {
            progressSink?.success(fraction.coerceIn(0.0, 1.0))
        }
    }

    private fun handleDirectoryPickResult(data: Intent, pendingResult: Result?) {
        try {
            val uri = data.data
            if (uri != null) {
                val documentFile = DocumentFile.fromTreeUri(activity!!, uri)
                pendingResult?.success(documentFile?.uri?.toString())
            } else {
                pendingResult?.success(null)
            }
        } catch (e: Exception) {
            pendingResult?.error(
                "DIRECTORY_ERROR",
                "Failed to process directory selection: ${e.message}",
                null
            )
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        progressChannel?.setStreamHandler(null)
        progressSink = null
        result = null
        copyExecutor.shutdownNow()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        completePendingResultAsCancelled()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        completePendingResultAsCancelled()
        activity = null
    }

    /**
     * Resolves any in-flight picker request so the Dart side never waits
     * forever (e.g. when the activity is destroyed/detached mid-pick).
     */
    private fun completePendingResultAsCancelled() {
        val pending = result
        if (pending != null) {
            result = null
            pending.success(null)
        }
    }
}