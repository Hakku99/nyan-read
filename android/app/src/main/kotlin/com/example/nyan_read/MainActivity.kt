package com.example.nyan_read

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.nyan_read/book_source"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val uriString = call.argument<String>("uri")

                try {
                    when (call.method) {
                        "persistReadPermission" -> {
                            require(!uriString.isNullOrBlank()) { "uri is required" }
                            result.success(persistReadPermission(uriString))
                        }

                        "isUriReadable" -> {
                            require(!uriString.isNullOrBlank()) { "uri is required" }
                            result.success(isUriReadable(uriString))
                        }

                        "readUriBytes" -> {
                            require(!uriString.isNullOrBlank()) { "uri is required" }
                            result.success(readUriBytes(uriString))
                        }

                        "copyUriToTempFile" -> {
                            require(!uriString.isNullOrBlank()) { "uri is required" }
                            val extension = call.argument<String>("extension")
                            result.success(copyUriToTempFile(uriString, extension))
                        }

                        "deletePersistedUriDocument" -> {
                            require(!uriString.isNullOrBlank()) { "uri is required" }
                            result.success(deletePersistedUriDocument(uriString))
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("book_source_error", e.message, null)
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

