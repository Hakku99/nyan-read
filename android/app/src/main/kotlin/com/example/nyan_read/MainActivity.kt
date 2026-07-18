package com.example.nyan_read

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.nyan_read/book_source"
        // readUriBytes loads the whole file into a ByteArray; guard against
        // OOM on unusually large files (>100 MB). Callers that need to handle
        // larger files should use copyUriToTempFile + stream-read instead.
        private const val MAX_MEMORY_READ_BYTES = 100L * 1024L * 1024L
    }

    // MethodChannel handlers run on the platform main thread, but every call
    // on this channel does SAF/provider I/O — copyUriToTempFile streams the
    // whole book, which froze rendering (ANR risk) on 100MB+ files. All work
    // is dispatched here; Result callbacks must still fire on the main
    // thread, hence mainHandler.
    // ponytail: one shared I/O thread serializes SAF calls; pool it if
    // parallel imports ever matter.
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val uriString = call.argument<String>("uri")

                // Computes [compute] on the I/O thread and posts the result
                // (or a domain error) back to the platform thread.
                fun respond(compute: () -> Any?) {
                    ioExecutor.execute {
                        try {
                            val value = compute()
                            mainHandler.post { result.success(value) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("book_source_error", e.message, null)
                            }
                        }
                    }
                }

                when (call.method) {
                    "persistReadPermission" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        persistReadPermission(uriString)
                    }

                    "isUriReadable" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        isUriReadable(uriString)
                    }

                    "readUriBytes" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        readUriBytes(uriString)
                    }

                    "copyUriToTempFile" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        copyUriToTempFile(uriString, call.argument<String>("extension"))
                    }

                    "deletePersistedUriDocument" -> respond {
                        require(!uriString.isNullOrBlank()) { "uri is required" }
                        deletePersistedUriDocument(uriString)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun persistReadPermission(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        // Prefer read+write persistence so SAF deletes can succeed when the
        // provider allows it; fall back to read-only if the picker grant lacks write.
        val readWriteFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        return try {
            contentResolver.takePersistableUriPermission(uri, readWriteFlags)
            true
        } catch (_: SecurityException) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                true
            } catch (_: SecurityException) {
                false
            } catch (_: UnsupportedOperationException) {
                false
            }
        } catch (_: UnsupportedOperationException) {
            false
        }
    }

    private fun isUriReadable(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return try {
            contentResolver.openInputStream(uri)?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun readUriBytes(uriString: String): ByteArray {
        val uri = Uri.parse(uriString)
        // Check file size before allocating — avoids OOM on very large files.
        contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
            val sizeBytes = pfd.statSize
            if (sizeBytes > MAX_MEMORY_READ_BYTES) {
                val sizeMb = sizeBytes / (1024L * 1024L)
                throw IllegalStateException(
                    "File too large to load into memory (${sizeMb} MB). " +
                    "Maximum supported size for in-memory reading is " +
                    "${MAX_MEMORY_READ_BYTES / (1024L * 1024L)} MB."
                )
            }
        }
        contentResolver.openInputStream(uri)?.use { input ->
            return input.readBytes()
        }
        throw IllegalStateException("Unable to open Uri: $uriString")
    }

    private fun copyUriToTempFile(uriString: String, extension: String?): String {
        val uri = Uri.parse(uriString)
        val tempDir = File(cacheDir, "book_sources").apply {
            mkdirs()
        }
        val safeExtension = sanitizeExtension(extension)
        val tempFile = File(tempDir, "${UUID.randomUUID()}$safeExtension")

        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Unable to open Uri: $uriString")

        return tempFile.absolutePath
    }

    private fun sanitizeExtension(extension: String?): String {
        val normalized = extension?.trim()?.lowercase().orEmpty()
        if (normalized.isEmpty()) return ".tmp"
        return if (normalized.startsWith('.')) normalized else ".$normalized"
    }

    private fun deletePersistedUriDocument(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            return false
        }
        return try {
            DocumentsContract.deleteDocument(contentResolver, uri)
        } catch (_: SecurityException) {
            false
        } catch (_: UnsupportedOperationException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }
}

